import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/features/driver/screen/deliveries/provider/driver_deliveries_provider.dart';
import 'package:market_jango/features/driver/screen/deliveries/screen/driver_delivery_detail_screen.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_order_card.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// `GET /api/driver/deliveries` — `doc/details.md`.
class DriverDeliveriesScreen extends ConsumerWidget {
  const DriverDeliveriesScreen({super.key, this.asTab = false});

  static const routeName = '/driver/deliveries';

  /// When true (Order bottom-nav), hide the back AppBar.
  final bool asTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(driverDeliveriesPageProvider);
    final statusFilter = ref.watch(driverDeliveriesStatusFilterProvider);
    final async = ref.watch(driverDeliveriesListProvider);

    return Scaffold(
      backgroundColor: AllColor.white,
      appBar: asTab
          ? null
          : AppBar(
              backgroundColor: AllColor.white,
              elevation: 0,
              leading: Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: const CustomBackButton(),
              ),
              title: Text(
                ref.t(BKeys.my_deliveries, fallback: 'My deliveries'),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AllColor.black,
                ),
              ),
              centerTitle: true,
            ),
      body: SafeArea(
        top: asTab,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: asTab ? 12.h : 4.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: _StatusChips(
                selected: statusFilter,
                onChanged: (v) {
                  ref.read(driverDeliveriesStatusFilterProvider.notifier).state =
                      v;
                  ref.read(driverDeliveriesPageProvider.notifier).state = 1;
                },
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(driverDeliveriesListProvider);
                  await ref.read(driverDeliveriesListProvider.future);
                },
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: 80.h),
                      _DeliveriesError(
                        message: _driverDeliveriesErrorText(ref, e),
                        onRetry: () =>
                            ref.invalidate(driverDeliveriesListProvider),
                      ),
                    ],
                  ),
                  data: (p) {
                    if (p.items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 80.h),
                          Center(
                            child: Text(
                              ref.t(
                                BKeys.driver_deliveries_empty,
                                fallback: 'No assignments.',
                              ),
                              style: TextStyle(
                                color: AllColor.grey500,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                      itemCount: p.items.length + 1,
                      separatorBuilder: (_, i) => i == p.items.length - 1
                          ? const SizedBox.shrink()
                          : SizedBox(height: 12.h),
                      itemBuilder: (context, i) {
                        if (i == p.items.length) {
                          return _PaginationRow(
                            page: page,
                            lastPage: p.lastPage,
                            onPrev: page <= 1
                                ? null
                                : () {
                                    ref
                                        .read(
                                          driverDeliveriesPageProvider.notifier,
                                        )
                                        .state = page - 1;
                                  },
                            onNext: page >= p.lastPage
                                ? null
                                : () {
                                    ref
                                        .read(
                                          driverDeliveriesPageProvider.notifier,
                                        )
                                        .state = page + 1;
                                  },
                          );
                        }
                        final row = p.items[i];
                        return AssignmentOrderCard(
                          row: row,
                          onTap: () => context.push(
                            DriverDeliveryDetailScreen.routePath(row.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _driverDeliveriesErrorText(WidgetRef ref, Object e) {
  final msg = e.toString().replaceFirst('Exception: ', '');
  if (msg.toLowerCase().contains('driver not found')) {
    return ref.t(BKeys.driver_not_found, fallback: msg);
  }
  return msg;
}

class _StatusChips extends ConsumerWidget {
  const _StatusChips({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = <({String? value, String label})>[
      (
        value: null,
        label: ref.t(BKeys.shipment_tab_all, fallback: 'All'),
      ),
      (
        value: 'pending',
        label: ref.t(BKeys.pending, fallback: 'Pending'),
      ),
      (
        value: 'accepted',
        label: ref.t(BKeys.delivery_status_accepted, fallback: 'Accepted'),
      ),
      (
        value: 'in_transit',
        label: ref.t(
          BKeys.delivery_status_in_transit,
          fallback: 'In transit',
        ),
      ),
      (
        value: 'delivered',
        label: ref.t(BKeys.delivered, fallback: 'Delivered'),
      ),
    ];

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 8.w),
                child: _Chip(
                  label: tabs[i].label,
                  selected: selected == tabs[i].value,
                  onTap: () => onChanged(tabs[i].value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AllColor.loginButtomColor : AllColor.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AllColor.loginButtomColor : AllColor.grey200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AllColor.white : AllColor.black,
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }
}

class _DeliveriesError extends StatelessWidget {
  const _DeliveriesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 48.sp,
            color: AllColor.grey500,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: AllColor.black87,
              height: 1.4,
            ),
          ),
          SizedBox(height: 22.h),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AllColor.loginButtomColor,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: const Text(
              'Try again',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationRow extends ConsumerWidget {
  const _PaginationRow({
    required this.page,
    required this.lastPage,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int lastPage;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lastPage <= 1) return SizedBox(height: 8.h);
    final mid = ref
        .t(BKeys.pagination_slash, fallback: '{current} / {total}')
        .replaceAll('{current}', '$page')
        .replaceAll('{total}', '$lastPage');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: onPrev,
            child: Text(ref.t(BKeys.prev, fallback: 'Prev')),
          ),
          Text(mid),
          TextButton(
            onPressed: onNext,
            child: Text(ref.t(BKeys.next, fallback: 'Next')),
          ),
        ],
      ),
    );
  }
}
