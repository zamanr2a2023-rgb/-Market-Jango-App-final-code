import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/features/buyer/screens/cart/logic/cart_data.dart';
import 'package:market_jango/features/buyer/screens/prement/data/delivery_charges_data.dart';
import 'package:market_jango/features/buyer/screens/prement/logic/global_logger.dart';
import 'package:market_jango/features/buyer/screens/prement/logic/prement_reverpod.dart';
import 'package:market_jango/features/buyer/screens/prement/model/prement_line_items.dart';
import 'package:market_jango/features/buyer/screens/prement/model/prement_page_data_model.dart';
import 'package:market_jango/features/buyer/screens/prement/screen/payment_complete_screen.dart';
import 'package:market_jango/features/buyer/screens/prement/screen/web_view_screen.dart';
import 'package:market_jango/features/buyer/screens/wallet/data/buyer_wallet_api.dart';
import 'package:market_jango/features/buyer/screens/wallet/provider/buyer_wallet_provider.dart';

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

double _payableFromRouterExtra(BuildContext context) {
  try {
    final extra = GoRouterState.of(context).extra;
    if (extra is PaymentPageData) return extra.grandTotal;
  } catch (_) {}
  return 0;
}

double _resolvePayableTotal(ProviderContainer container, BuildContext context) {
  final charges = container.read(cartDeliveryChargesProvider).valueOrNull;
  final selectedIndex = container.read(shippingMethodIndexProvider);
  if (charges != null) {
    if (selectedIndex == 0) {
      return charges.grandTotal.toDouble();
    }
    return (charges.merchandiseSubtotal + charges.platformFee + charges.tax)
        .toDouble();
  }
  return _payableFromRouterExtra(context);
}

enum _CheckoutPaymentChoice { wallet, gateway }

Future<void> _showMessagePopup(BuildContext context, String message) {
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

Future<void> startCheckout(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final selectedIndex = container.read(shippingMethodIndexProvider);

  // Own pick up: only place order after explicit Checkout + confirm (no gateway dialog).
  if (selectedIndex == 1) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm own pick up'),
        content: const Text(
          'Place this order for own pick up?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Place order'),
          ),
        ],
      ),
    );
    if (!context.mounted || ok != true) return;
    await _executeInvoiceCheckout(
      context,
      paymentMethod: 'OPU',
      shippingPaymentMethod: 'OPU',
    );
    return;
  }

  final choice = await showDialog<_CheckoutPaymentChoice>(
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
            onTap: () =>
                Navigator.of(ctx).pop(_CheckoutPaymentChoice.wallet),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Payment by bank and mobile'),
            onTap: () =>
                Navigator.of(ctx).pop(_CheckoutPaymentChoice.gateway),
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
    case _CheckoutPaymentChoice.wallet:
      await _checkoutWithWallet(context);
      break;
    case _CheckoutPaymentChoice.gateway:
      await _checkoutWithGateway(context);
      break;
  }
}

/// Wallet: GET `/api/wallet` then POST `/api/invoice/create` with `Wallet` if balance covers total.
Future<void> _checkoutWithWallet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final payableTotal = _resolvePayableTotal(container, context);
  const String shippingPaymentMethod = 'FW';

  if (payableTotal <= 0) {
    await _showMessagePopup(context, 'Invalid order total.');
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Text('Checking wallet...'),
          ],
        ),
      ),
    ),
  );

  try {
    num? walletBalance;
    try {
      final overview = await BuyerWalletApi.instance.fetchWallet();
      walletBalance = overview.balanceNumeric;
    } catch (e) {
      log.i('Wallet balance fetch failed: $e');
      walletBalance = null;
    }

    if (context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    }

    if (!context.mounted) return;

    if (walletBalance == null) {
      await _showMessagePopup(
        context,
        'Could not load your wallet balance. Please try again or use bank and mobile payment.',
      );
      return;
    }

    final balance = walletBalance.toDouble();
    if (balance + 1e-9 < payableTotal) {
      await _showMessagePopup(
        context,
        'Insufficient wallet balance.\n'
        'Available: $walletBalance · Required: $payableTotal',
      );
      return;
    }

    await _executeInvoiceCheckout(
      context,
      paymentMethod: 'Wallet',
      shippingPaymentMethod: shippingPaymentMethod,
    );
  } catch (e, st) {
    if (context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    }
    log.e('Wallet checkout exception: $e\nStack trace: $st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
  }
}

/// Bank / mobile (Flutterwave) for delivery orders only.
Future<void> _checkoutWithGateway(BuildContext context) async {
  await _executeInvoiceCheckout(
    context,
    paymentMethod: 'FW',
    shippingPaymentMethod: 'FW',
  );
}

Future<void> _executeInvoiceCheckout(
  BuildContext context, {
  required String paymentMethod,
  required String shippingPaymentMethod,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Text('Preparing checkout...'),
          ],
        ),
      ),
    ),
  );

  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final payableTotal = _resolvePayableTotal(container, context);
    final token = await container.read(authTokenProvider.future);

    final uri = Uri.parse(BuyerAPIController.invoice_createate);
    log.i(
      'InvoiceCreate → POST $uri '
      '(payment_method=$paymentMethod, payable=$payableTotal, '
      'token: ${maskToken(token)})',
    );

    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'token': token,
      },
      body: jsonEncode({'payment_method': paymentMethod}),
    );

    if (context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    }

    log.i('InvoiceCreate ← status=${res.statusCode}');
    log.t(
      'InvoiceCreate body: '
      '${res.body.length > 400 ? '${res.body.substring(0, 400)}…' : res.body}',
    );

    Map<String, dynamic>? top;
    try {
      top = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      top = null;
    }

    final success = res.statusCode == 200 &&
        top != null &&
        _jsonStatusIsSuccess(top);

    if (!success) {
      if (!context.mounted) return;
      final msg = _messageFromJson(top) ??
          'Invoice failed${res.statusCode != 200 ? ' (${res.statusCode})' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final data = top['data'];
    Map<String, dynamic>? dataMap;
    if (data is Map<String, dynamic>) {
      dataMap = data;
    } else if (data is List && data.isNotEmpty && data.first is Map) {
      dataMap = data.first as Map<String, dynamic>;
    }

    final paymentField = dataMap?['paymentMethod'];

    // Wallet: order placed from balance — no hosted payment URL.
    if (paymentMethod == 'Wallet') {
      if (!context.mounted) return;
      container.invalidate(cartProvider);
      container.invalidate(buyerWalletOverviewProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PaymentCompleteScreen(),
        ),
      );
      return;
    }

    // Own pick up — success without WebView
    if (shippingPaymentMethod == 'OPU') {
      if (!context.mounted) return;
      container.invalidate(cartProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PaymentCompleteScreen(),
        ),
      );
      return;
    }

    // Flutterwave / online — open payment_url in WebView
    String? paymentUrl;
    if (paymentField is Map<String, dynamic>) {
      paymentUrl = paymentField['payment_url']?.toString();
    }

    log.i('payment_url = $paymentUrl');

    if (paymentUrl == null || paymentUrl.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment URL not found')));
      return;
    }

    if (!context.mounted) return;
    final result = await Navigator.of(context).push<PaymentStatusResult>(
      MaterialPageRoute(builder: (_) => PaymentWebView(url: paymentUrl ?? "")),
    );

    log.i('WebView result: ${result?.success}');

    if (!context.mounted) return;

    if (result?.success == true) {
      if (context.mounted) {
        container.invalidate(cartProvider);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const PaymentCompleteScreen(),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment not completed')));
    }
  } catch (e, st) {
    if (context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    }
    log.e('Checkout exception: $e\nStack trace: $st');
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
  }
}
