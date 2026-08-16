import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/driver/screen/deliveries/model/driver_assignment_models.dart';

class AssignmentStatusBadge extends StatelessWidget {
  const AssignmentStatusBadge({super.key, required this.row});

  final DriverAssignmentRow row;

  @override
  Widget build(BuildContext context) {
    final isNew = row.showNewBadge;
    final Color fg;
    final Color bg;
    final Color border;
    if (isNew) {
      fg = AllColor.blue900;
      bg = AllColor.blue50;
      border = AllColor.blue200;
    } else {
      switch (row.status) {
        case 'accepted':
          fg = AllColor.green;
          bg = AllColor.green.withValues(alpha: 0.08);
          border = AllColor.green.withValues(alpha: 0.35);
          break;
        case 'in_transit':
          fg = AllColor.loginButtomColor;
          bg = AllColor.orange50;
          border = AllColor.orange200;
          break;
        case 'delivered':
          fg = AllColor.green;
          bg = AllColor.green.withValues(alpha: 0.08);
          border = AllColor.green.withValues(alpha: 0.35);
          break;
        case 'rejected':
        case 'cancelled':
          fg = AllColor.red;
          bg = AllColor.red200.withValues(alpha: 0.25);
          border = AllColor.red200;
          break;
        default:
          fg = AllColor.blue500;
          bg = AllColor.blue50;
          border = AllColor.blue200;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: border),
      ),
      child: Text(
        isNew ? 'New' : row.statusLabel,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12.sp,
        ),
      ),
    );
  }
}
