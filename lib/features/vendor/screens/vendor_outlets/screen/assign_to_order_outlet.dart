import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/widget/global_pagination.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_order_assign_rules.dart';
import 'package:market_jango/features/vendor/screens/vendor_outlets/data/vendor_outlets_api.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

/// Current page for the outlet-assign orders list (`GET /vendor/orders`).
final outletAssignOrdersPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Orders shown when assigning to an outlet — `GET /vendor/orders`.
final outletAssignOrdersProvider = FutureProvider.autoDispose<
    VendorOrdersPage<VendorMarketplaceLine>>((ref) async {
  final page = ref.watch(outletAssignOrdersPageProvider);
  return VendorOrderApi.instance.fetchMarketplaceOrders(
    page: page,
    perPage: 15,
  );
});

/// Pass this as `GoRouterState.extra` when opening [AssignToOrderOutlet].
class AssignToOrderOutletArgs {
  const AssignToOrderOutletArgs({required this.outletId, this.outletName});

  final int outletId;
  final String? outletName;
}

class AssignToOrderOutlet extends ConsumerStatefulWidget {
  const AssignToOrderOutlet({
    super.key,
    required this.outletId,
    this.outletName,
  });

  static const routeName = "/assign_order_outlet";

  final int outletId;
  final String? outletName;

  /// Text after "Assign order to outlet …" (name or `#id`).
  String get outletDisplaySuffix {
    final n = outletName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return '$outletId';
  }

  @override
  ConsumerState<AssignToOrderOutlet> createState() =>
      _AssignToOrderOutletState();
}

class _AssignToOrderOutletState extends ConsumerState<AssignToOrderOutlet> {
  final _search = TextEditingController();
  int? _selectedIndex;
  bool _submitting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _assign(VendorMarketplaceLine chosen) async {
    setState(() => _submitting = true);
    try {
      final msg = await VendorOutletsApi.instance.assignOrderToOutlet(
        orderItemId: chosen.id,
        outletId: widget.outletId,
      );
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Success',
        message: msg,
        type: CustomSnackType.success,
      );
      ref.invalidate(outletAssignOrdersProvider);
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Error',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(outletAssignOrdersProvider);

    return async.when(
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: Text('Loading...'))),
      ),
      error: (e, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString()),
                TextButton(
                  onPressed: () => ref.invalidate(outletAssignOrdersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (pageData) {
        final orders = pageData.items;
        // Assign only pending/processing lines not already sent to an outlet
        // (`outlet_status == null`).
        final assignable = orders
            .where(
              (o) =>
                  o.outletStatus == null &&
                  VendorOrderAssignRules.isPendingOrProcessingStatus(o.status),
            )
            .toList();

        final q = _search.text.trim().toLowerCase();
        final items = assignable.where((o) {
          if (q.isEmpty) return true;
          final orderNo = _orderNo(o).toLowerCase();
          final product = o.product.name.toLowerCase();
          final customer = (o.lineCustomerName ?? '').toLowerCase();
          return orderNo.contains(q) ||
              product.contains(q) ||
              customer.contains(q);
        }).toList();

        if (_selectedIndex != null && _selectedIndex! >= items.length) {
          _selectedIndex = null;
        }

        return Scaffold(
          backgroundColor: AllColor.white,
          bottomNavigationBar: _BottomAssignBar(
            outletDisplaySuffix: widget.outletDisplaySuffix,
            enabled:
                _selectedIndex != null && items.isNotEmpty && !_submitting,
            submitting: _submitting,
            onPressed: _selectedIndex == null
                ? null
                : () => _assign(items[_selectedIndex!]),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CustomBackButton(),
                      SizedBox(height: 20.h),
                      Text(
                        'Assign order to outlet ${widget.outletDisplaySuffix}',
                        style: TextStyle(
                          color: AllColor.black,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Only order lines in Pending or Processing can be assigned.',
                        style: TextStyle(
                          color: AllColor.black54,
                          fontSize: 12.sp,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: ref.t(BKeys.searchOrders),
                          hintStyle: TextStyle(color: AllColor.textHintColor),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AllColor.black54,
                          ),
                          filled: true,
                          fillColor: AllColor.grey100,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: AllColor.grey200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: AllColor.grey200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: AllColor.blue500),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Text(
                                assignable.isEmpty && orders.isNotEmpty
                                    ? 'No lines on this page can be assigned. '
                                        'Orders already sent to an outlet and '
                                        'final statuses are hidden. Try another '
                                        'page or wait until an order is Pending '
                                        'or Processing.'
                                    : orders.isEmpty
                                        ? 'No orders on this page.'
                                        : 'No matching orders for your search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AllColor.black54,
                                  fontSize: 14.sp,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(bottom: 12.h),
                            itemCount: items.length + 1,
                            separatorBuilder: (context, index) {
                              if (index < items.length - 1) {
                                return const Divider(height: 1);
                              }
                              return SizedBox(height: 12.h);
                            },
                            itemBuilder: (context, index) {
                              if (index == items.length) {
                                return GlobalPagination(
                                  currentPage: pageData.currentPage,
                                  totalPages: pageData.lastPage,
                                  onPageChanged: (newPage) {
                                    setState(() => _selectedIndex = null);
                                    ref
                                        .read(
                                          outletAssignOrdersPageProvider
                                              .notifier,
                                        )
                                        .state = newPage;
                                  },
                                );
                              }

                              final item = items[index];

                              return InkWell(
                                onTap: () =>
                                    setState(() => _selectedIndex = index),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.w),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Radio<int>(
                                        value: index,
                                        groupValue: _selectedIndex,
                                        onChanged: (v) =>
                                            setState(() => _selectedIndex = v),
                                        activeColor: AllColor.loginButtomColor,
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Order #${_orderNo(item)}',
                                              style: TextStyle(
                                                color: AllColor.black,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              _line1(item),
                                              style: TextStyle(
                                                color: AllColor.black54,
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                            Text(
                                              _line2(item),
                                              style: TextStyle(
                                                color: AllColor.black54,
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: Text(
                                          _formatStatusLabel(item.status),
                                          style: TextStyle(
                                            color: AllColor.blue500,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== helper text =====
  String _orderNo(VendorMarketplaceLine o) => o.invoice.orderNumber.isNotEmpty
      ? o.invoice.orderNumber
      : o.id.toString();

  String _line1(VendorMarketplaceLine o) {
    final product = o.product.name.trim();
    final base = 'Qty: ${o.quantity} • Sale: ${o.salePrice.toStringAsFixed(2)}';
    return product.isEmpty ? base : '$product • $base';
  }

  String _line2(VendorMarketplaceLine o) {
    final customer = (o.lineCustomerName ?? '').trim();
    final pickup = (o.pickupAddress ?? '').trim();
    final ship = (o.shipAddress ?? '').trim();
    if (customer.isNotEmpty) return 'Customer: $customer';
    if (pickup.isNotEmpty) return 'Pickup: $pickup';
    if (ship.isNotEmpty) return 'Ship to: $ship';
    return 'Pickup address: Not set';
  }

  String _formatStatusLabel(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    final lower = t.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

/// ================= Bottom button =================

class _BottomAssignBar extends StatelessWidget {
  final String outletDisplaySuffix;
  final bool enabled;
  final bool submitting;
  final VoidCallback? onPressed;

  const _BottomAssignBar({
    required this.outletDisplaySuffix,
    required this.enabled,
    required this.submitting,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = submitting
        ? 'Assigning...'
        : 'Assign order to outlet $outletDisplaySuffix';
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
      child: SizedBox(
        width: double.infinity,
        height: 48.h,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AllColor.loginButtomColor,
            disabledBackgroundColor: AllColor.grey200,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AllColor.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
    );
  }
}
