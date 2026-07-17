import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/driver/screen/outlets/data/driver_outlets_api.dart';
import 'package:market_jango/features/driver/screen/outlets/screen/driver_outlet_bin_screen.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';

class DriverOutletsScreen extends ConsumerStatefulWidget {
  const DriverOutletsScreen({super.key});

  static const routeName = '/driver/outlets';

  @override
  ConsumerState<DriverOutletsScreen> createState() =>
      _DriverOutletsScreenState();
}

class _DriverOutletsScreenState extends ConsumerState<DriverOutletsScreen> {
  final _joining = <int>{};

  Future<void> _join(DriverOutlet outlet) async {
    if (_joining.contains(outlet.id)) return;
    setState(() => _joining.add(outlet.id));
    try {
      final message = await DriverOutletsApi.instance.joinOutlet(outlet.id);
      ref.invalidate(driverOutletsProvider);
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Success',
        message: message,
        type: CustomSnackType.success,
      );
    } catch (error) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Unable to join outlet',
        message: error.toString().replaceFirst('Exception: ', ''),
        type: CustomSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _joining.remove(outlet.id));
    }
  }

  void _openBin(DriverOutlet outlet) {
    if (!outlet.isApproved) return;
    context.push(
      DriverOutletBinScreen.routeName,
      extra: DriverOutletBinArgs(
        outletId: outlet.id,
        outletName: outlet.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driverOutletsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const CustomBackButton(),
        ),
        title: Text(
          'Available outlets',
          style: TextStyle(
            color: AllColor.black,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
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
                  onPressed: () => ref.invalidate(driverOutletsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (outlets) {
          if (outlets.isEmpty) {
            return const Center(child: Text('No outlets available'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverOutletsProvider);
              await ref.read(driverOutletsProvider.future);
            },
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: outlets.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (_, index) {
                final outlet = outlets[index];
                return _OutletCard(
                  outlet: outlet,
                  joining: _joining.contains(outlet.id),
                  onJoin: () => _join(outlet),
                  onOpen: () => _openBin(outlet),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OutletCard extends StatelessWidget {
  const _OutletCard({
    required this.outlet,
    required this.joining,
    required this.onJoin,
    required this.onOpen,
  });

  final DriverOutlet outlet;
  final bool joining;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = outlet.membershipStatus?.trim().toLowerCase();
    final statusLabel = outlet.isApproved
        ? 'Approved'
        : status == null || status.isEmpty
        ? 'Not joined'
        : status[0].toUpperCase() + status.substring(1);
    final statusColor = outlet.isApproved
        ? Colors.green
        : status == 'pending'
        ? Colors.orange
        : Colors.grey;

    return Material(
      color: AllColor.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: outlet.isApproved ? onOpen : null,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AllColor.grey200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 54.h,
                    width: 54.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: AllColor.loginButtomColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outlet.name,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          outlet.phone.isEmpty ? 'No phone' : outlet.phone,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AllColor.black54,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'Max concurrent orders: '
                          '${outlet.maxConcurrentOrders ?? outlet.defaultMaxConcurrentOrders}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AllColor.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 9.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (outlet.isApproved)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View bin orders',
                      style: TextStyle(
                        color: AllColor.loginButtomColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.chevron_right,
                      color: AllColor.loginButtomColor,
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 42.h,
                  child: ElevatedButton(
                    onPressed:
                        outlet.hasRequestedMembership || joining ? null : onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AllColor.loginButtomColor,
                      disabledBackgroundColor: AllColor.grey200,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      joining
                          ? 'Joining...'
                          : outlet.hasRequestedMembership
                          ? 'Request ${statusLabel.toLowerCase()}'
                          : 'Join outlet',
                      style: TextStyle(
                        color: outlet.hasRequestedMembership
                            ? AllColor.black54
                            : AllColor.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
