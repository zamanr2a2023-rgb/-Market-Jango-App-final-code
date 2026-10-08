import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_order_assign_rules.dart';
import 'package:market_jango/features/vendor/screens/vendor_outlets/data/vendor_outlets_api.dart';

/// Bottom sheet to assign an invoice line to a vendor outlet.
class VendorAssignOutletSheet extends StatefulWidget {
  const VendorAssignOutletSheet({
    super.key,
    required this.lineId,
    required this.invoiceStatus,
    required this.lineStatus,
    required this.onAssigned,
  });

  final int lineId;
  final String invoiceStatus;
  final String lineStatus;
  final Future<void> Function() onAssigned;

  @override
  State<VendorAssignOutletSheet> createState() =>
      _VendorAssignOutletSheetState();
}

class _VendorAssignOutletSheetState extends State<VendorAssignOutletSheet> {
  final _search = TextEditingController();
  List<VendorOutlet> _outlets = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await VendorOutletsApi.instance.fetchOutlets();
      if (mounted) {
        setState(() {
          _outlets = list;
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

  List<VendorOutlet> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _outlets;
    return _outlets.where((o) {
      final name = o.name.toLowerCase();
      final zone = (o.zone ?? '').toLowerCase();
      final town = (o.town ?? '').toLowerCase();
      return name.contains(q) || zone.contains(q) || town.contains(q);
    }).toList();
  }

  Future<void> _assign(VendorOutlet outlet) async {
    if (!VendorOrderAssignRules.sheetAllowsAssignDriver(
      widget.invoiceStatus,
      widget.lineStatus,
    )) {
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Cannot assign outlet',
        message: 'This line must be Pending or Processing to assign an outlet.',
        type: CustomSnackType.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final msg = await VendorOutletsApi.instance.assignOrderToOutlet(
        orderItemId: widget.lineId,
        outletId: outlet.id,
      );
      if (!mounted) return;
      GlobalSnackbar.show(
        context,
        title: 'Assigned',
        message: msg,
        type: CustomSnackType.success,
      );
      await widget.onAssigned();
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Cannot assign outlet',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
          duration: const Duration(seconds: 4),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Assign outlet',
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
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search outlets',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
            ),
            onChanged: (_) => setState(() {}),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AllColor.grey500,
                            fontSize: 13.sp,
                          ),
                        ),
                        TextButton(
                          onPressed: _fetch,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'No outlets found.',
                    style: TextStyle(color: AllColor.grey500, fontSize: 13.sp),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final o = filtered[i];
                    final subtitle = [
                      if (o.zone != null && o.zone!.isNotEmpty) o.zone,
                      if (o.town != null && o.town!.isNotEmpty) o.town,
                    ].join(' · ');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(o.name.isEmpty ? 'Outlet #${o.id}' : o.name),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
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
                      onTap: _submitting ? null : () => _assign(o),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
