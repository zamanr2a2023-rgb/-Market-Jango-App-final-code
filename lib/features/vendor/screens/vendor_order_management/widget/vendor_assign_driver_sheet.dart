import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_available_drivers_loader.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_driver_assign_filters.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_order_assign_rules.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';

/// Bottom sheet to pick an available driver for an invoice line (order item).
class VendorAssignDriverSheet extends StatefulWidget {
  const VendorAssignDriverSheet({
    super.key,
    required this.lineId,
    required this.invoiceStatus,
    required this.lineStatus,
    required this.onAssigned,
    required this.onAssignFailed,
    this.initialPickup,
    this.initialDrop,
  });

  final int lineId;
  final String invoiceStatus;
  final String lineStatus;
  final Future<void> Function() onAssigned;
  final Future<void> Function() onAssignFailed;
  final String? initialPickup;
  final String? initialDrop;

  @override
  State<VendorAssignDriverSheet> createState() =>
      _VendorAssignDriverSheetState();
}

class _VendorAssignDriverSheetState extends State<VendorAssignDriverSheet> {
  final _search = TextEditingController();
  final _pickup = TextEditingController();
  final _drop = TextEditingController();
  String? _transportType;
  List<VendorAvailableDriver> _drivers = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    final pick = widget.initialPickup?.trim();
    if (pick != null && pick.isNotEmpty) _pickup.text = pick;
    final drop = widget.initialDrop?.trim();
    if (drop != null && drop.isNotEmpty) _drop.text = drop;
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    _pickup.dispose();
    _drop.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _search.text.trim();
      final list = await VendorAvailableDriversLoader.instance.fetch(
        search: q.isEmpty ? null : q,
        pickLocation: _pickup.text.trim(),
        dropLocation: _drop.text.trim(),
        transportType: _transportType,
      );
      if (mounted) {
        setState(() {
          _drivers = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _clearFilters() {
    _pickup.clear();
    _drop.clear();
    setState(() => _transportType = null);
    _fetch();
  }

  Future<void> _assign(VendorAvailableDriver dr) async {
    if (!VendorOrderAssignRules.sheetAllowsAssignDriver(
      widget.invoiceStatus,
      widget.lineStatus,
    )) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Cannot assign driver',
        message: 'This line must be Pending or Processing to assign a driver.',
        type: CustomSnackType.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await VendorOrderApi.instance.assignDriverToOrderItem(
        invoiceItemId: widget.lineId,
        driverId: dr.id,
      );
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Assigned',
        message: 'Driver assigned to this line',
        type: CustomSnackType.success,
      );
      await widget.onAssigned();
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Cannot assign driver',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
          duration: const Duration(seconds: 4),
        );
        setState(() => _submitting = false);
        await widget.onAssignFailed();
      }
    }
  }

  String _driverSubtitle(VendorAvailableDriver dr) {
    final parts = <String>[];
    if (dr.location != null && dr.location!.isNotEmpty) {
      parts.add(dr.location!);
    }
    if (dr.transportType != null && dr.transportType!.isNotEmpty) {
      parts.add(VendorDriverAssignFilters.labelForTransport(
        dr.transportType!.toLowerCase(),
      ));
    }
    if (dr.phone != null && dr.phone!.isNotEmpty) parts.add(dr.phone!);
    return parts.isEmpty ? 'Tap to assign' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Available drivers',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AllColor.black,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading || _submitting
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: InkWell(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            child: Row(
              children: [
                Icon(
                  _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 22.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  'Pickup, drop & transport',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AllColor.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_filtersExpanded)
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
            child: VendorDriverAssignFilters(
              pickupController: _pickup,
              dropController: _drop,
              selectedTransport: _transportType,
              onTransportChanged: (v) => setState(() => _transportType = v),
              onSearch: _fetch,
              onClear: _clearFilters,
              enabled: !_loading && !_submitting,
              compact: true,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search by name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                  ),
                  onSubmitted: (_) => _fetch(),
                ),
              ),
              SizedBox(width: 8.w),
              FilledButton(
                onPressed: _loading || _submitting ? null : _fetch,
                style: FilledButton.styleFrom(
                  backgroundColor: AllColor.loginButtomColor,
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AllColor.grey500,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                )
              : _drivers.isEmpty
              ? Center(
                  child: Text(
                    'No drivers match your search.',
                    style: TextStyle(color: AllColor.grey500, fontSize: 13.sp),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: _drivers.length,
                  itemBuilder: (ctx, i) {
                    final dr = _drivers[i];
                    final label = dr.name.isEmpty
                        ? 'Driver #${dr.id}'
                        : dr.name;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(label),
                      subtitle: Text(
                        _driverSubtitle(dr),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AllColor.grey500,
                        ),
                      ),
                      trailing: _submitting
                          ? SizedBox(
                              width: 22.w,
                              height: 22.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: _submitting ? null : () => _assign(dr),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
