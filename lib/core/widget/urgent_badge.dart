import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

bool isUrgentFlag(dynamic raw) {
  if (raw == true || raw == 1) return true;
  final s = raw?.toString().trim().toLowerCase() ?? '';
  return s == 'urgent' || s == 'express' || s == 'true' || s == '1';
}

bool urgentFromMap(Map<String, dynamic> json) {
  return isUrgentFlag(
    json['is_urgent'] ?? json['urgent'] ?? json['delivery_type'],
  );
}

/// Driver assignment list/detail payloads may nest urgent flags.
bool urgentFromAssignmentJson(Map<String, dynamic> j) {
  if (urgentFromMap(j)) return true;
  final badge = j['badge']?.toString().toUpperCase() ?? '';
  if (badge.contains('URGENT')) return true;
  for (final key in ['order', 'invoice', 'invoice_item', 'shipment']) {
    final raw = j[key];
    if (raw is Map) {
      if (urgentFromMap(Map<String, dynamic>.from(raw))) return true;
    }
  }
  final feeRaw = j['urgent_fee'] ??
      (j['metrics'] is Map ? (j['metrics'] as Map)['urgent_fee'] : null);
  if (feeRaw != null) {
    final n = num.tryParse(feeRaw.toString());
    if (n != null && n > 0) return true;
  }
  return false;
}

class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFDC2626)),
      ),
      child: Text(
        'Urgent',
        style: TextStyle(
          color: const Color(0xFFB91C1C),
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
