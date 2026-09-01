import 'package:flutter/material.dart';
import 'package:market_jango/core/utils/order_source_color.dart';

/// Maps `order_color_key` / `source_color_key` from `doc/details.md` to a card accent.
class AssignmentSourceStyle {
  AssignmentSourceStyle._();

  static Color accent(String sourceColorKey, {String? suggestedColor}) {
    return OrderSourceColor.resolve(
      orderColorKey: sourceColorKey,
      suggestedColor: suggestedColor,
    );
  }
}
