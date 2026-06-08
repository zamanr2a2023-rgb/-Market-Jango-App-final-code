import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/features/buyer/screens/prement/model/prement_line_items.dart';
import 'package:market_jango/features/buyer/screens/prement/screen/web_view_screen.dart';
import 'package:market_jango/features/transport/screens/booking_confirm/data/create_shipment_data.dart';
import 'package:market_jango/features/transport/screens/my_booking/screen/transport_booking.dart';
import 'package:market_jango/features/transport/screens/wallet/data/transport_wallet_api.dart';
import 'package:market_jango/features/transport/screens/wallet/provider/transport_wallet_provider.dart';

enum _ShipmentPaymentChoice { wallet, gateway }

bool _jsonStatusIsSuccess(Map<String, dynamic> top) {
  final st = top['status']?.toString().toLowerCase();
  return st == 'success';
}

String? _messageFromJson(Map<String, dynamic>? top) {
  if (top == null) return null;
  final m = top['message']?.toString().trim();
  if (m == null || m.isEmpty) return null;
  return m;
}

Future<void> _showNotice(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Notice'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showLoading(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

void _hideLoading(BuildContext context) {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) nav.pop();
}

/// Total due for wallet balance check (pricing.total_with_fees or fallbacks).
double shipmentPayableTotal(
  Map<String, dynamic> shipment, [
  Map<String, dynamic>? detailRoot,
]) {
  Map<String, dynamic>? pricing;
  final fromRoot = detailRoot?['pricing'];
  if (fromRoot is Map<String, dynamic>) {
    pricing = fromRoot;
  } else if (shipment['pricing'] is Map<String, dynamic>) {
    pricing = shipment['pricing'] as Map<String, dynamic>;
  }

  if (pricing != null) {
    final total = pricing['total_with_fees'];
    if (total is num && total > 0) return total.toDouble();
    final base = pricing['transport_base_price'];
    if (base is num) {
      final fee = (pricing['platform_fee'] as num?) ?? 0;
      final tax = (pricing['tax'] as num?) ?? 0;
      return base.toDouble() + fee.toDouble() + tax.toDouble();
    }
  }

  final finalPrice = shipment['final_price'];
  if (finalPrice is num && finalPrice > 0) return finalPrice.toDouble();
  final estimated = shipment['estimated_price'];
  if (estimated is num && estimated > 0) return estimated.toDouble();
  return 0;
}

/// Pay button: wallet (`POST /api/invoice/create`) or mobile/bank (initiate-payment WebView).
Future<void> startShipmentPayment(
  BuildContext context, {
  required WidgetRef ref,
  required int shipmentId,
  required double payableTotal,
}) async {
  final choice = await showDialog<_ShipmentPaymentChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choose payment method'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Payment by Wallet'),
            onTap: () => Navigator.of(ctx).pop(_ShipmentPaymentChoice.wallet),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Payment by bank and mobile'),
            onTap: () => Navigator.of(ctx).pop(_ShipmentPaymentChoice.gateway),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (!context.mounted || choice == null) return;

  switch (choice) {
    case _ShipmentPaymentChoice.wallet:
      await _payShipmentWithWallet(
        context,
        ref: ref,
        payableTotal: payableTotal,
      );
      break;
    case _ShipmentPaymentChoice.gateway:
      await _payShipmentWithGateway(
        context,
        ref: ref,
        shipmentId: shipmentId,
      );
      break;
  }
}

Future<void> _payShipmentWithWallet(
  BuildContext context, {
  required WidgetRef ref,
  required double payableTotal,
}) async {
  if (payableTotal <= 0) {
    await _showNotice(context, 'Invalid shipment total.');
    return;
  }

  _showLoading(context, 'Checking wallet...');

  try {
    num? walletBalance;
    try {
      final overview = await TransportWalletApi.instance.fetchWallet();
      walletBalance = overview.balanceNumeric;
    } catch (_) {
      walletBalance = null;
    }

    if (context.mounted) _hideLoading(context);
    if (!context.mounted) return;

    if (walletBalance == null) {
      await _showNotice(
        context,
        'Could not load your wallet balance. Please try again or use bank and mobile payment.',
      );
      return;
    }

    final balance = walletBalance.toDouble();
    if (balance + 1e-9 < payableTotal) {
      await _showNotice(
        context,
        'Insufficient wallet balance.\n'
        'Available: $walletBalance · Required: $payableTotal',
      );
      return;
    }

    _showLoading(context, 'Processing wallet payment...');

    final token = await ref.read(authTokenProvider.future) ?? '';
    final uri = Uri.parse(BuyerAPIController.invoice_createate);
    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'token': token,
      },
      body: jsonEncode({'payment_method': 'Wallet'}),
    );

    if (context.mounted) _hideLoading(context);
    if (!context.mounted) return;

    Map<String, dynamic>? top;
    try {
      top = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      top = null;
    }

    final success =
        res.statusCode == 200 && top != null && _jsonStatusIsSuccess(top);

    if (!success) {
      final msg = _messageFromJson(top) ??
          'Payment failed${res.statusCode != 200 ? ' (${res.statusCode})' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    ref.invalidate(transportWalletOverviewProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment success')),
    );
    context.go(TransportBooking.routeName);
  } catch (e) {
    if (context.mounted) _hideLoading(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wallet payment failed: $e')),
    );
  }
}

Future<void> _payShipmentWithGateway(
  BuildContext context, {
  required WidgetRef ref,
  required int shipmentId,
}) async {
  _showLoading(context, 'Preparing checkout...');

  try {
    final token = await ref.read(authTokenProvider.future) ?? '';
    final init = await initiateShipmentPayment(
      token: token,
      shipmentId: shipmentId,
    );

    if (context.mounted) _hideLoading(context);
    if (!context.mounted) return;

    if (init.paymentUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment URL not found')),
      );
      return;
    }

    final result = await Navigator.of(context).push<PaymentStatusResult>(
      MaterialPageRoute(
        builder: (_) => PaymentWebView(url: init.paymentUrl),
      ),
    );

    if (!context.mounted) return;

    if (result?.success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment success')),
      );
      context.go(TransportBooking.routeName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment not completed')),
      );
    }
  } catch (e) {
    if (context.mounted) _hideLoading(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}
