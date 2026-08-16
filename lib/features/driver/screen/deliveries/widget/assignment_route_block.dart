import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/features/driver/screen/deliveries/model/driver_assignment_models.dart';

class AssignmentRouteBlock extends StatelessWidget {
  const AssignmentRouteBlock({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.showMap = false,
    this.compact = false,
  });

  final DriverAssignmentPlace pickup;
  final DriverAssignmentPlace dropoff;
  final bool showMap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _PlaceRow(
                place: pickup,
                compact: compact,
                isPickup: true,
              ),
              Padding(
                padding: EdgeInsets.only(left: compact ? 14.w : 18.w),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: compact ? 10.h : 16.h,
                    width: 2,
                    child: CustomPaint(painter: _DottedLinePainter()),
                  ),
                ),
              ),
              _PlaceRow(
                place: dropoff,
                compact: compact,
                isPickup: false,
              ),
            ],
          ),
        ),
        if (showMap) ...[
          SizedBox(width: 10.w),
          AssignmentMiniMap(pickup: pickup, dropoff: dropoff),
        ],
      ],
    );

    if (compact) return content;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.grey200),
      ),
      child: content,
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.isPickup,
    required this.compact,
  });

  final DriverAssignmentPlace place;
  final bool isPickup;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = isPickup ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final bg = isPickup
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);
    final icon = isPickup ? Icons.storefront_outlined : Icons.person_outline;
    final name = place.name.isNotEmpty ? place.name : '—';
    final address = place.address;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 28.w : 36.w,
          height: compact ? 28.w : 36.w,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: color, size: compact ? 16.sp : 20.sp),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.label.isNotEmpty
                    ? place.label
                    : (isPickup ? 'From (Pickup)' : 'To (Drop-off)'),
                style: TextStyle(
                  fontSize: compact ? 10.sp : 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 13.sp : 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AllColor.black,
                ),
              ),
              if (address.isNotEmpty && !compact) ...[
                SizedBox(height: 2.h),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AllColor.grey500,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AssignmentMiniMap extends StatelessWidget {
  const AssignmentMiniMap({
    super.key,
    required this.pickup,
    required this.dropoff,
  });

  final DriverAssignmentPlace pickup;
  final DriverAssignmentPlace dropoff;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    final points = <LatLng>[];
    if (pickup.hasCoords) {
      final p = LatLng(pickup.latitude!, pickup.longitude!);
      points.add(p);
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: p,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    if (dropoff.hasCoords) {
      final d = LatLng(dropoff.latitude!, dropoff.longitude!);
      points.add(d);
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: d,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: SizedBox(
        width: 96.w,
        height: 110.h,
        child: points.isEmpty
            ? ColoredBox(
                color: const Color(0xFFF3E5D0),
                child: Center(
                  child: Icon(
                    Icons.map_outlined,
                    color: AllColor.grey500,
                    size: 28.sp,
                  ),
                ),
              )
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: points.first,
                  zoom: points.length == 1 ? 13 : 12,
                ),
                markers: markers,
                polylines: points.length == 2
                    ? {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: points,
                          color: AllColor.blue500,
                          width: 3,
                        ),
                      }
                    : {},
                liteModeEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
              ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AllColor.grey300
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 3.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
