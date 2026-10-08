import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/transport/screens/booking_confirm/data/transport_shipment_receipt_api.dart';
import 'package:market_jango/features/transport/screens/my_booking/data/transport_booking_data.dart';

Future<void> transportConfirmAndMarkReceived(
  BuildContext context,
  WidgetRef ref, {
  required int shipmentId,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'Confirm receipt',
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Confirm that you received the goods for this shipment?',
        style: TextStyle(fontSize: 14.sp),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AllColor.blue500),
          child: const Text('Received'),
        ),
      ],
    ),
  );

  if (ok != true) return;

  try {
    await TransportShipmentReceiptApi.instance.markReceived(shipmentId);
    ref.invalidate(shipmentDetailProvider(shipmentId));
    ref.invalidate(myShipmentsProvider);
    if (context.mounted) {
      GlobalSnackbar.show(
        context,
        title: 'Confirmed',
        message: 'Shipment marked as received',
        type: CustomSnackType.success,
      );
    }
  } on Exception catch (e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (context.mounted) {
      GlobalSnackbar.show(
        context,
        title: 'Could not confirm',
        message: msg.toLowerCase().contains('delivered')
            ? 'Shipment must be delivered before you can confirm receipt'
            : msg,
        type: CustomSnackType.error,
      );
    }
  }
}
