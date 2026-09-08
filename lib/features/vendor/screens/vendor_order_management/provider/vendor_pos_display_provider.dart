import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_pos_display_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_pos_display_model.dart';

/// Live cart from the vendor walk-in POS (same device / shared session).
final vendorPosCartSessionProvider =
    StateProvider<VendorPosCartSession>((ref) => const VendorPosCartSession());

/// Polled server snapshot when an invoice id is known (separate device path).
final vendorPosDisplayRemoteProvider = StreamProvider.autoDispose
    .family<VendorPosDisplayData, int>((ref, invoiceId) {
  if (invoiceId <= 0) {
    return Stream.value(VendorPosDisplayData.empty());
  }

  final controller = StreamController<VendorPosDisplayData>();
  var closed = false;

  Future<void> tick({required bool first}) async {
    try {
      final data = await VendorPosDisplayApi.instance.fetch(invoiceId);
      if (!closed && !controller.isClosed) controller.add(data);
    } catch (e, st) {
      if (first && !closed && !controller.isClosed) {
        controller.addError(e, st);
      }
      // Later poll failures keep last successful frame (no rethrow).
    }
  }

  tick(first: true);
  final timer = Timer.periodic(const Duration(seconds: 3), (_) {
    tick(first: false);
  });

  ref.onDispose(() {
    closed = true;
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
