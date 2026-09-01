import 'package:flutter/material.dart';

/// Buyer brief / `doc/details.md` — card accent from `order_color_key`.
class OrderSourceColor {
  OrderSourceColor._();

  static const Color singleVendor = Color(0xFF2196F3);
  static const Color multiVendor = Color(0xFF4CAF50);
  static const Color outlet = Color(0xFFFF9800);
  static const Color transport = Color(0xFFF44336);
  static const Color fallback = Color(0xFF455A64);

  /// Normalize API / legacy keys to canonical `order_color_key` values.
  static String normalizeKey(String? raw) {
    final k = (raw ?? '').trim().toLowerCase();
    switch (k) {
      case 'single_vendor':
      case 'multi_vendor':
      case 'outlet':
      case 'transport':
        return k;
      case 'vendor':
        return 'single_vendor';
      case 'outlet_bin':
      case 'outlet_assigned':
      case 'outlet_direct':
      case 'outlet_bin_claim':
        return 'outlet';
      default:
        return k.isEmpty ? 'single_vendor' : k;
    }
  }

  static Color fromKey(String? orderColorKey) {
    switch (normalizeKey(orderColorKey)) {
      case 'single_vendor':
        return singleVendor;
      case 'multi_vendor':
        return multiVendor;
      case 'outlet':
        return outlet;
      case 'transport':
        return transport;
      default:
        return fallback;
    }
  }

  /// Prefer `suggested_color` hex when valid; else map [orderColorKey].
  static Color resolve({String? orderColorKey, String? suggestedColor}) {
    final hex = _parseHex(suggestedColor);
    if (hex != null) return hex;
    return fromKey(orderColorKey);
  }

  static Color? _parseHex(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}
