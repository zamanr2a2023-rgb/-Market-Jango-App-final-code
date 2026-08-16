import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/driver/screen/deliveries/model/driver_assignment_models.dart';

class AssignmentMetricsRow extends StatelessWidget {
  const AssignmentMetricsRow({
    super.key,
    required this.metrics,
    this.compact = false,
  });

  final DriverAssignmentMetrics metrics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _cell('Distance', metrics.distanceLabel),
        _divider(),
        _cell('Est. Time', metrics.etaLabel),
        _divider(),
        _cell('Payment', metrics.paymentLabel),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: compact ? 28.h : 34.h,
      color: AllColor.grey200,
      margin: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }

  Widget _cell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.sp : 12.sp,
              color: AllColor.grey500,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12.sp : 14.sp,
              fontWeight: FontWeight.w800,
              color: AllColor.black,
            ),
          ),
        ],
      ),
    );
  }
}
