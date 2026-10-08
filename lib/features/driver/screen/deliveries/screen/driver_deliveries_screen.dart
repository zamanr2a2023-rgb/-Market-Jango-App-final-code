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
class DriverDeliveriesScreen extends ConsumerStatefulWidget {
  const DriverDeliveriesScreen({super.key, this.asTab = false});

  static const routeName = '/driver/deliveries';

  /// When true (Order bottom-nav), hide the back AppBar.
  final bool asTab;

  @override
  ConsumerState<DriverDeliveriesScreen> createState() =>
      _DriverDeliveriesScreenState();
}

class _DriverDeliveriesScreenState extends ConsumerState<DriverDeliveriesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(driverDeliveriesListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(driverDeliveriesPageProvider);
    final statusFilter = ref.watch(driverDeliveriesStatusFilterProvider);
    final async = ref.watch(driverDeliveriesListProvider);

    return Scaffold(
      backgroundColor: AllColor.white,
      appBar: widget.asTab
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
        top: widget.asTab,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: widget.asTab ? 12.h : 4.h),
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
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: _DeliveriesSearchFiltersPanel(),
            ),
            SizedBox(height: 8.h),
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
                      final isPendingFilter =
                          statusFilter?.toLowerCase() == 'pending';
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        children: [
                          SizedBox(height: 48.h),
                          Center(
                            child: Text(
                              ref.t(
                                BKeys.driver_deliveries_empty,
                                fallback: 'No deliveries to show.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AllColor.grey500,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isPendingFilter) ...[
                            SizedBox(height: 12.h),
                            Text(
                              'Transport shipments appear here after the customer pays '
                              '(status booked). Draft or unpaid jobs stay on the transport app only. '
                              'Try the All tab, or search by shipment # (e.g. 17).',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AllColor.grey500,
                                fontSize: 12.sp,
                                height: 1.4,
                              ),
                            ),
                          ],
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
                            DriverDeliveryDetailScreen.routePath(
                              row.detailId,
                              jobType: row.isTransport ? 'transport' : null,
                            ),
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

class _DeliveriesSearchFiltersPanel extends ConsumerStatefulWidget {
  const _DeliveriesSearchFiltersPanel();

  @override
  ConsumerState<_DeliveriesSearchFiltersPanel> createState() =>
      _DeliveriesSearchFiltersPanelState();
}

class _DeliveriesSearchFiltersPanelState
    extends ConsumerState<_DeliveriesSearchFiltersPanel> {
  final _orderNumberC = TextEditingController();
  final _pickupC = TextEditingController();
  final _dropC = TextEditingController();
  String _fromDate = '';
  String _toDate = '';
  bool _expanded = false;

  @override
  void dispose() {
    _orderNumberC.dispose();
    _pickupC.dispose();
    _dropC.dispose();
    super.dispose();
  }

  DriverDeliveriesSearchFilters _currentFilters() {
    return DriverDeliveriesSearchFilters(
      orderNumber: _orderNumberC.text.trim(),
      pickLocation: _pickupC.text.trim(),
      dropLocation: _dropC.text.trim(),
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _applyTextDebounced() {
    ref
        .read(driverDeliveriesAppliedFiltersProvider.notifier)
        .applyTextDebounced(_currentFilters());
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final s =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (isFrom) {
        _fromDate = s;
      } else {
        _toDate = s;
      }
    });
    ref
        .read(driverDeliveriesAppliedFiltersProvider.notifier)
        .applyImmediately(_currentFilters());
  }

  void _clearFilters() {
    _orderNumberC.clear();
    _pickupC.clear();
    _dropC.clear();
    setState(() {
      _fromDate = '';
      _toDate = '';
    });
    ref.read(driverDeliveriesAppliedFiltersProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: AllColor.grey200),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 22.sp,
                  color: AllColor.black87,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Search & filters',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AllColor.black,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          TextField(
            controller: _orderNumberC,
            onChanged: (_) => _applyTextDebounced(),
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              labelText: 'Shipment # (transport)',
              hintText: 'Numeric id from transport app',
              isDense: true,
              border: inputBorder,
              enabledBorder: inputBorder,
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _pickupC,
            onChanged: (_) => _applyTextDebounced(),
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              labelText: 'Pickup location',
              isDense: true,
              border: inputBorder,
              enabledBorder: inputBorder,
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _dropC,
            onChanged: (_) => _applyTextDebounced(),
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              labelText: 'Drop location',
              isDense: true,
              border: inputBorder,
              enabledBorder: inputBorder,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: true),
                  child: Text(
                    _fromDate.isEmpty ? 'From date' : 'From: $_fromDate',
                    style: TextStyle(fontSize: 12.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: false),
                  child: Text(
                    _toDate.isEmpty ? 'To date' : 'To: $_toDate',
                    style: TextStyle(fontSize: 12.sp),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
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
