import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/buyer/screens/billing/data/invoice_details_data.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_order_receipt_api.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_orders_data.dart';

Future<void> buyerConfirmAndMarkReceived(
  BuildContext context,
  WidgetRef ref, {
  required int invoiceItemId,
  required int invoiceId,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'Confirm receipt',
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Mark this order line as received? You can still request a refund afterward if needed.',
        style: TextStyle(fontSize: 14.sp),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AllColor.loginButtomColor,
          ),
          child: const Text('Received'),
        ),
      ],
    ),
  );

  if (ok != true) return;

  try {
    await BuyerOrderReceiptApi.instance.markReceived(invoiceItemId);
    ref.invalidate(invoiceDetailsProvider(invoiceId));
    ref.invalidate(buyerOrdersProvider);
    if (context.mounted) {
      GlobalSnackbar.show(
        context,
        title: 'Confirmed',
        message: 'This line is marked as received',
        type: CustomSnackType.success,
      );
    }
  } on Exception catch (e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (context.mounted) {
      GlobalSnackbar.show(
        context,
        title: 'Could not confirm',
        message: msg.contains('422') || msg.toLowerCase().contains('delivered')
            ? 'This item must be delivered before you can confirm receipt'
            : msg,
        type: CustomSnackType.error,
      );
    }
  }
}
