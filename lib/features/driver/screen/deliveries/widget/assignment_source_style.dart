import 'package:flutter/material.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';

/// Maps `source_color_key` from `doc/details.md` to a card accent.
class AssignmentSourceStyle {
  AssignmentSourceStyle._();

  static Color accent(String sourceColorKey) {
    switch (sourceColorKey) {
      case 'vendor':
        return AllColor.loginButtomColor;
      case 'outlet_assigned':
        return AllColor.blue500;
      case 'outlet_bin':
        return const Color(0xFF2E7D32);
      default:
        return AllColor.blueGrey900;
    }
  }
}
