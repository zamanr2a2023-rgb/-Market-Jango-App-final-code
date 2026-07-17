import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/core/widget/global_pagination.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/driver/screen/outlets/data/driver_outlets_api.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

class DriverOutletBinArgs {
  const DriverOutletBinArgs({
    required this.outletId,
    required this.outletName,
  });

  final int outletId;
  final String outletName;
}

class DriverOutletBinScreen extends ConsumerStatefulWidget {
  const DriverOutletBinScreen({
    super.key,
    required this.outletId,
    required this.outletName,
  });

  static const routeName = '/driver/outlet-bin';

  final int outletId;
  final String outletName;

  @override
  ConsumerState<DriverOutletBinScreen> createState() =>
      _DriverOutletBinScreenState();
}

class _DriverOutletBinScreenState
    extends ConsumerState<DriverOutletBinScreen> {
  int _page = 1;
  final _claiming = <int>{};

  DriverOutletBinQuery get _query =>
      DriverOutletBinQuery(outletId: widget.outletId, page: _page);

  Future<void> _claim(DriverOutletBinOrder order) async {
    if (_claiming.contains(order.id)) return;
    setState(() => _claiming.add(order.id));
    try {
      final message = await DriverOutletsApi.instance.claimOrder(order.id);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Order claimed',
        message: message,
        type: CustomSnackType.success,
      );
      ref.invalidate(driverOutletBinOrdersProvider);
    } catch (error) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Unable to claim order',
        message: error.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _claiming.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driverOutletBinOrdersProvider(_query));
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const CustomBackButton(),
        ),
        title: Column(
          children: [
            Text(
              'Bin orders',
              style: TextStyle(
                color: AllColor.black,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.outletName,
              style: TextStyle(color: AllColor.black54, fontSize: 11.sp),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(driverOutletBinOrdersProvider(_query)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (pageData) {
          if (pageData.orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(driverOutletBinOrdersProvider(_query));
                await ref.read(driverOutletBinOrdersProvider(_query).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * .3),
                  const Center(child: Text('No bin orders available')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverOutletBinOrdersProvider(_query));
              await ref.read(driverOutletBinOrdersProvider(_query).future);
            },
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: pageData.orders.length + 1,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (_, index) {
                if (index == pageData.orders.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: GlobalPagination(
                      currentPage: pageData.currentPage,
                      totalPages: pageData.lastPage,
                      onPageChanged: (page) => setState(() => _page = page),
                    ),
                  );
                }
                final order = pageData.orders[index];
                return _BinOrderCard(
                  order: order,
                  claiming: _claiming.contains(order.id),
                  onClaim: () => _claim(order),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _BinOrderCard extends StatelessWidget {
  const _BinOrderCard({
    required this.order,
    required this.claiming,
    required this.onClaim,
  });

  final DriverOutletBinOrder order;
  final bool claiming;
  final VoidCallback onClaim;

  String get _dropoff {
    if (order.dropoffAddress.isNotEmpty) return order.dropoffAddress;
    if (order.buyerName.isNotEmpty) return order.buyerName;
    return 'Not set';
  }

  /// Orders already assigned to a driver cannot be claimed.
  bool get _canClaim => order.status.trim().toLowerCase() != 'assigned';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: SizedBox(
                  width: 64.w,
                  height: 64.h,
                  child: order.productImage.isEmpty
                      ? Container(
                          color: AllColor.grey100,
                          child: Icon(Icons.inventory_2_outlined,
                              color: AllColor.grey),
                        )
                      : FirstTimeShimmerImage(
                          imageUrl: order.productImage,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      order.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Qty: ${order.quantity}  •  Total: \$${order.totalPay}',
                      style:
                          TextStyle(color: AllColor.black54, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'In bin',
                  style: TextStyle(
                    color: AllColor.loginButtomColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _AddressRow(
            icon: Icons.storefront_outlined,
            label: 'Pickup',
            value: order.pickupAddress.isEmpty
                ? order.vendorName
                : order.pickupAddress,
          ),
          SizedBox(height: 7.h),
          _AddressRow(
            icon: Icons.location_on_outlined,
            label: 'Drop-off',
            value: _dropoff,
          ),
          if (order.buyerPhone.isNotEmpty) ...[
            SizedBox(height: 7.h),
            _AddressRow(
              icon: Icons.phone_outlined,
              label: 'Buyer phone',
              value: order.buyerPhone,
            ),
          ],
          if (_canClaim) ...[
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              height: 43.h,
              child: ElevatedButton.icon(
                onPressed: claiming ? null : onClaim,
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: Text(claiming ? 'Claiming...' : 'Claim order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AllColor.loginButtomColor,
                  foregroundColor: AllColor.white,
                  disabledBackgroundColor: AllColor.grey200,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: AllColor.grey100,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16.sp, color: AllColor.black54),
                  SizedBox(width: 6.w),
                  Text(
                    'Already assigned',
                    style: TextStyle(
                      color: AllColor.black54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.sp, color: AllColor.loginButtomColor),
        SizedBox(width: 8.w),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value.isEmpty ? 'Not set' : value),
              ],
            ),
            style: TextStyle(fontSize: 12.sp, color: AllColor.black54),
          ),
        ),
      ],
    );
  }
}
