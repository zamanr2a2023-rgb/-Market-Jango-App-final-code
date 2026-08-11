import 'package:flutter/material.dart';

class CartItem {
  final String title;
  final String imageUrl; // Network/Asset/file path
  final int qty;
  final double price;
  final String? vendorName;
  CartItem({
    required this.title,
    required this.imageUrl,
    required this.qty,
    required this.price,
    this.vendorName,
  });
}

class ShippingOption {
  final String title;
  final double cost; // 0.0 => Free/Pickup
  /// When set, shown instead of auto "Free" / currency formatting.
  final String? displayPrice;

  ShippingOption({required this.title, required this.cost, this.displayPrice});
}

/// Single payment option model
class PaymentOption {
  final String label;
  final IconData? icon; // use when there is a Material icon (e.g., card, cash)
  final String?
  asset; // use when no icon available (e.g., GPay, PayPal png/svg)

  PaymentOption({required this.label, this.icon, this.asset});
}
