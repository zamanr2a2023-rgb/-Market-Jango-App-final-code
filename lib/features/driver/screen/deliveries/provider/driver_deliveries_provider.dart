import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/features/driver/screen/deliveries/data/driver_deliveries_api.dart';
import 'package:market_jango/features/driver/screen/deliveries/model/driver_assignment_models.dart';

final driverDeliveriesPageProvider = StateProvider<int>((ref) => 1);

/// `null` = All → API sends `status=all`.
final driverDeliveriesStatusFilterProvider =
    StateProvider<String?>((ref) => null);

class DriverDeliveriesSearchFilters {
  const DriverDeliveriesSearchFilters({
    this.orderNumber = '',
    this.pickLocation = '',
    this.dropLocation = '',
    this.fromDate = '',
    this.toDate = '',
  });

  final String orderNumber;
  final String pickLocation;
  final String dropLocation;
  /// `yyyy-MM-dd` when set.
  final String fromDate;
  final String toDate;

  DriverDeliveriesSearchFilters copyWith({
    String? orderNumber,
    String? pickLocation,
    String? dropLocation,
    String? fromDate,
    String? toDate,
  }) {
    return DriverDeliveriesSearchFilters(
      orderNumber: orderNumber ?? this.orderNumber,
      pickLocation: pickLocation ?? this.pickLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }
}

final driverDeliveriesAppliedFiltersProvider =
    NotifierProvider<DriverDeliveriesAppliedFiltersNotifier,
        DriverDeliveriesSearchFilters>(
  DriverDeliveriesAppliedFiltersNotifier.new,
);

class DriverDeliveriesAppliedFiltersNotifier
    extends Notifier<DriverDeliveriesSearchFilters> {
  Timer? _debounce;

  @override
  DriverDeliveriesSearchFilters build() => const DriverDeliveriesSearchFilters();

  void applyTextDebounced(DriverDeliveriesSearchFilters next) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      state = next;
      ref.read(driverDeliveriesPageProvider.notifier).state = 1;
    });
  }

  void applyImmediately(DriverDeliveriesSearchFilters next) {
    _debounce?.cancel();
    state = next;
    ref.read(driverDeliveriesPageProvider.notifier).state = 1;
  }

  void clear() {
    _debounce?.cancel();
    state = const DriverDeliveriesSearchFilters();
    ref.read(driverDeliveriesPageProvider.notifier).state = 1;
  }
}

final driverDeliveriesListProvider =
    FutureProvider.autoDispose<DriverAssignmentsPage>((ref) async {
  final page = ref.watch(driverDeliveriesPageProvider);
  final st = ref.watch(driverDeliveriesStatusFilterProvider);
  final status = (st == null || st.trim().isEmpty) ? 'all' : st.trim();
  final filters = ref.watch(driverDeliveriesAppliedFiltersProvider);
  return DriverDeliveriesApi.instance.fetchDeliveries(
    page: page,
    status: status,
    orderNumber: filters.orderNumber,
    pickLocation: filters.pickLocation,
    dropLocation: filters.dropLocation,
    fromDate: filters.fromDate,
    toDate: filters.toDate,
  );
});

class DriverDeliveryDetailArgs {
  const DriverDeliveryDetailArgs({
    required this.id,
    this.jobType,
  });

  final int id;
  final String? jobType;

  bool get isTransport =>
      (jobType ?? '').trim().toLowerCase() == 'transport';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverDeliveryDetailArgs &&
          id == other.id &&
          (jobType ?? '') == (other.jobType ?? '');

  @override
  int get hashCode => Object.hash(id, jobType ?? '');
}

final driverDeliveryDetailProvider = FutureProvider.autoDispose
    .family<DriverAssignmentRow, DriverDeliveryDetailArgs>((ref, args) async {
  return DriverDeliveriesApi.instance.fetchDelivery(
    args.id,
    jobType: args.isTransport ? 'transport' : null,
  );
});
