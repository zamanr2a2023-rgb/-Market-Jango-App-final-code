import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:market_jango/core/constants/image_control/image_path.dart';

class ScreenBackground extends StatelessWidget {
  const ScreenBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SvgPicture.asset(
          width: double.maxFinite,
          height: double.maxFinite,
          ImagePath.authBackground,
          fit: BoxFit.cover,
        ),
        // Material ancestor for InkWell / ListTile / IconButton when used
        // without a Scaffold (e.g. profile tab shell).
        SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ],
    );
  }
}