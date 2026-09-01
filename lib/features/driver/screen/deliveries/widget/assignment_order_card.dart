import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/driver/screen/deliveries/model/driver_assignment_models.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_metrics_row.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_route_block.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_source_style.dart';
import 'package:market_jango/features/driver/screen/deliveries/widget/assignment_status_badge.dart';

class AssignmentOrderCard extends StatelessWidget {
  const AssignmentOrderCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  final DriverAssignmentRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AssignmentSourceStyle.accent(
      row.sourceColorKey,
      suggestedColor: row.suggestedColor,
    );

    return Material(
      color: AllColor.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AllColor.grey200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4.w, color: accent),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.displayOrderNumber,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AllColor.black,
                                  ),
                                ),
                              ),
                              AssignmentStatusBadge(row: row),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          AssignmentRouteBlock(
                            pickup: row.pickup,
                            dropoff: row.dropoff,
                            compact: true,
                          ),
                          SizedBox(height: 12.h),
                          AssignmentMetricsRow(
                            metrics: row.metrics,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
