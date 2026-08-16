import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/buyer_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/driver/screen/deliveries/data/driver_deliveries_api.dart';
import 'package:market_jango/features/driver/screen/deliveries/model/driver_assignment_models.dart';
import 'package:market_jango/features/driver/screen/deliveries/provider/driver_deliveries_provider.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_metrics_row.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_route_block.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_source_style.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_status_badge.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// `GET/POST .../api/driver/deliveries/{id}/...` — `doc/details.md`.
class DriverDeliveryDetailScreen extends ConsumerStatefulWidget {
  const DriverDeliveryDetailScreen({super.key, required this.assignmentId});

  final int assignmentId;

  /// Use with GoRouter path `/driver/deliveries/:assignmentId`.
  static String routePath(int id) => '/driver/deliveries/$id';

  @override
  ConsumerState<DriverDeliveryDetailScreen> createState() =>
      _DriverDeliveryDetailScreenState();
}

class _DriverDeliveryDetailScreenState
    extends ConsumerState<DriverDeliveryDetailScreen> {
  bool _busy = false;
  Timer? _locationTimer;
  Timer? _acceptTimer;
  bool _autoLocation = false;
  int _acceptSeconds = 0;

  @override
  void dispose() {
    _locationTimer?.cancel();
    _acceptTimer?.cancel();
    super.dispose();
  }

  void _syncAcceptTimer(DriverAssignmentRow row) {
    final shouldRun = row.status == 'pending' && row.actions.canAccept;
    if (!shouldRun) {
      _acceptTimer?.cancel();
      _acceptTimer = null;
      if (_acceptSeconds != 0 && mounted) {
        setState(() => _acceptSeconds = 0);
      }
      return;
    }
    if (_acceptTimer != null) return;
    _acceptSeconds =
        row.acceptTimeoutSeconds > 0 ? row.acceptTimeoutSeconds : 30;
    _acceptTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_acceptSeconds <= 0) return;
      setState(() => _acceptSeconds -= 1);
    });
  }

  void _toastSuccess(String message) {
    if (!mounted) return;
    GlobalSnackbar.show(
      context,
      title: 'Done',
      message: message,
      type: CustomSnackType.success,
    );
  }

  Future<void> _invalidate() async {
    ref.invalidate(driverDeliveryDetailProvider(widget.assignmentId));
    ref.invalidate(driverDeliveriesListProvider);
    await ref.read(driverDeliveryDetailProvider(widget.assignmentId).future);
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) await _invalidate();
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendLocation({bool quiet = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!quiet && mounted) {
          GlobalSnackbar.show(
            context,
            title: 'Location',
            message: 'Location permission denied.',
            type: CustomSnackType.error,
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await DriverDeliveriesApi.instance.postLocation(
        widget.assignmentId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        heading: pos.heading,
        speed: pos.speed >= 0 ? pos.speed : null,
      );
      if (!quiet && mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Location',
          message: 'GPS sent',
          type: CustomSnackType.success,
        );
      }
    } catch (e) {
      if (!quiet && mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Location',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    }
  }

  void _setAutoLocation(bool on, DriverAssignmentRow row) {
    final st = row.status;
    final can = st == 'accepted' || st == 'in_transit';
    if (!can) return;

    _locationTimer?.cancel();
    _locationTimer = null;
    setState(() => _autoLocation = on);
    if (on) {
      _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _sendLocation(quiet: true);
      });
      _sendLocation(quiet: true);
    }
  }

  Future<void> _showRejectDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline order'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Required (max 500 chars)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = ctrl.text.trim();
    if (reason.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Validation',
        message: 'Reason is required.',
        type: CustomSnackType.error,
      );
      return;
    }
    await _run(() async {
      await DriverDeliveriesApi.instance.reject(
        widget.assignmentId,
        reason: reason,
      );
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Done',
        message: 'Assignment declined',
        type: CustomSnackType.success,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(driverDeliveryDetailProvider(widget.assignmentId), (prev, next) {
      if (!next.hasValue) return;
      final row = next.value!;
      _syncAcceptTimer(row);
      final st = row.status;
      if (st != 'accepted' && st != 'in_transit') {
        _locationTimer?.cancel();
        _locationTimer = null;
        if (_autoLocation && mounted) {
          setState(() => _autoLocation = false);
        }
      }
    });

    final async = ref.watch(driverDeliveryDetailProvider(widget.assignmentId));

    return Scaffold(
      backgroundColor: AllColor.white,
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const CustomBackButton(),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverDeliveryDetailProvider(widget.assignmentId));
              await ref.read(
                driverDeliveryDetailProvider(widget.assignmentId).future,
              );
            },
            child: async.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20.w),
                children: [
                  Text(
                    e.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(color: AllColor.red, fontSize: 13.sp),
                  ),
                ],
              ),
              data: (row) {
                if (_acceptTimer == null &&
                    row.status == 'pending' &&
                    row.actions.canAccept) {
                  Future.microtask(() {
                    if (mounted) _syncAcceptTimer(row);
                  });
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                  children: [
                    _OrderHeader(row: row),
                    SizedBox(height: 16.h),
                    AssignmentRouteBlock(
                      pickup: row.pickup,
                      dropoff: row.dropoff,
                      showMap: true,
                    ),
                    SizedBox(height: 16.h),
                    AssignmentMetricsRow(metrics: row.metrics),
                    SizedBox(height: 20.h),
                    _PackageSection(row: row),
                    SizedBox(height: 20.h),
                    _ContactsRow(vendor: row.vendor, buyer: row.buyer),
                    SizedBox(height: 24.h),
                    _ActionsSection(
                      row: row,
                      busy: _busy,
                      autoLocation: _autoLocation,
                      acceptSeconds: _acceptSeconds,
                      onAccept: () => _run(() async {
                        await DriverDeliveriesApi.instance
                            .accept(widget.assignmentId);
                        _toastSuccess('Accepted');
                      }),
                      onReject: _showRejectDialog,
                      onPickup: () => _run(() async {
                        await DriverDeliveriesApi.instance
                            .pickup(widget.assignmentId);
                        _toastSuccess('Marked picked up (in transit)');
                      }),
                      onDeliver: () => _run(() async {
                        await DriverDeliveriesApi.instance
                            .deliver(widget.assignmentId);
                        _toastSuccess('Delivered');
                      }),
                      onSendLocation: () => _sendLocation(quiet: false),
                      onAutoLocation: (v) => _setAutoLocation(v, row),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.row});
  final DriverAssignmentRow row;

  @override
  Widget build(BuildContext context) {
    final accent = AssignmentSourceStyle.accent(row.sourceColorKey);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4.w,
          height: 28.h,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            row.displayOrderNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AllColor.black,
            ),
          ),
        ),
        AssignmentStatusBadge(row: row),
      ],
    );
  }
}

class _PackageSection extends StatelessWidget {
  const _PackageSection({required this.row});
  final DriverAssignmentRow row;

  @override
  Widget build(BuildContext context) {
    final pkg = row.package;
    final title = pkg.title.isNotEmpty ? pkg.title : 'Package';
    final subtitle = pkg.subtitle;
    final count = pkg.itemCountLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product / Package',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AllColor.grey500,
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AllColor.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AllColor.grey200),
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: AllColor.loginButtomColor,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: AllColor.black,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AllColor.grey500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (count.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AllColor.blue50,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    count,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AllColor.blue900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactsRow extends StatelessWidget {
  const _ContactsRow({required this.vendor, required this.buyer});

  final DriverAssignmentVendor vendor;
  final DriverAssignmentBuyer buyer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ContactBlock(
            heading: 'Vendor Details',
            icon: Icons.storefront_rounded,
            iconColor: const Color(0xFF2E7D32),
            iconBg: const Color(0xFFE8F5E9),
            title: vendor.businessName.isNotEmpty
                ? vendor.businessName
                : 'Vendor',
            subtitle: vendor.contactName,
            phone: vendor.phone,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _ContactBlock(
            heading: 'Buyer Details',
            icon: Icons.person_rounded,
            iconColor: const Color(0xFFC62828),
            iconBg: const Color(0xFFFFEBEE),
            title: buyer.name.isNotEmpty ? buyer.name : 'Buyer',
            phone: buyer.phone,
          ),
        ),
      ],
    );
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({
    required this.heading,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.phone,
  });

  final String heading;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AllColor.grey500,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: iconColor, size: 20.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AllColor.black,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    (subtitle != null && subtitle!.isNotEmpty) ? subtitle! : ' ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AllColor.grey500,
                      height: 1.3,
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    InkWell(
                      onTap: () => launchUrlString('tel:$phone'),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14.sp,
                            color: AllColor.grey500,
                          ),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: AllColor.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({
    required this.row,
    required this.busy,
    required this.autoLocation,
    required this.acceptSeconds,
    required this.onAccept,
    required this.onReject,
    required this.onPickup,
    required this.onDeliver,
    required this.onSendLocation,
    required this.onAutoLocation,
  });

  final DriverAssignmentRow row;
  final bool busy;
  final bool autoLocation;
  final int acceptSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onPickup;
  final VoidCallback onDeliver;
  final VoidCallback onSendLocation;
  final ValueChanged<bool> onAutoLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = row.status;
    if (st == 'pending' && (row.actions.canAccept || row.actions.canReject)) {
      return Row(
        children: [
          if (row.actions.canReject)
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AllColor.blue500,
                  side: BorderSide(color: AllColor.blue500),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  ref.t(BKeys.decline, fallback: 'Decline'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          if (row.actions.canAccept && row.actions.canReject)
            SizedBox(width: 12.w),
          if (row.actions.canAccept)
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(
                  backgroundColor: AllColor.blue500,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Accept Order (${acceptSeconds}s)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: AllColor.white,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final children = <Widget>[];
    if (st == 'accepted') {
      children.add(
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : onPickup,
            style: FilledButton.styleFrom(
              backgroundColor: AllColor.blue500,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: const Text('Mark picked up'),
          ),
        ),
      );
    } else if (st == 'in_transit') {
      children.add(
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : onDeliver,
            style: FilledButton.styleFrom(
              backgroundColor: AllColor.loginButtomColor,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: const Text('Mark delivered'),
          ),
        ),
      );
    }

    if (st == 'accepted' || st == 'in_transit') {
      children.add(SizedBox(height: 12.h));
      children.add(
        OutlinedButton.icon(
          onPressed: busy ? null : onSendLocation,
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Send location now'),
        ),
      );
      children.add(SizedBox(height: 8.h));
      children.add(
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-send location every 15s'),
          value: autoLocation,
          onChanged: busy ? null : onAutoLocation,
        ),
      );
    } else if (st != 'pending') {
      children.add(
        Text(
          'No actions for this status.',
          style: TextStyle(color: AllColor.grey500, fontSize: 13.sp),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
