import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_available_drivers_loader.dart';

/// Pickup / drop / transport type filters for vendor driver assignment lists.
class VendorDriverAssignFilters extends StatelessWidget {
  const VendorDriverAssignFilters({
    super.key,
    required this.pickupController,
    required this.dropController,
    required this.selectedTransport,
    required this.onTransportChanged,
    required this.onSearch,
    required this.onClear,
    this.enabled = true,
    this.compact = false,
  });

  final TextEditingController pickupController;
  final TextEditingController dropController;
  final String? selectedTransport;
  final ValueChanged<String?> onTransportChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final bool enabled;
  final bool compact;

  static String labelForTransport(String value) {
    switch (value) {
      case 'motorcycle':
        return 'Motorcycle';
      case 'car':
        return 'Car';
      case 'air':
        return 'Air';
      case 'water':
        return 'Water';
      default:
        return value;
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AllColor.grey100,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: AllColor.grey200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: AllColor.grey200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: Text(
              'Filters match driver service area (town, zone, state), not exact order GPS.',
              style: TextStyle(fontSize: 11.sp, color: AllColor.grey500),
            ),
          ),
        TextField(
          controller: pickupController,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('Pickup location'),
          onSubmitted: (_) => onSearch(),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: dropController,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration('Drop location'),
          onSubmitted: (_) => onSearch(),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String?>(
          value: selectedTransport,
          decoration: _fieldDecoration('Transport type'),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All transport types', style: TextStyle(fontSize: 14.sp)),
            ),
            ...kVendorDriverTransportTypes.map(
              (t) => DropdownMenuItem<String?>(
                value: t,
                child: Text(
                  labelForTransport(t),
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
            ),
          ],
          onChanged: enabled ? onTransportChanged : null,
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onSearch : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AllColor.loginButtomColor,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: const Text('Apply filters'),
              ),
            ),
            SizedBox(width: 8.w),
            TextButton(onPressed: enabled ? onClear : null, child: const Text('Clear')),
          ],
        ),
      ],
    );
  }
}
