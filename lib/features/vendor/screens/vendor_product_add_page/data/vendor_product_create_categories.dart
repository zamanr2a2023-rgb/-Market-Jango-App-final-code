import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

int _toInt(dynamic v, {int d = 0}) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

class ProductCreateBusinessType {
  final int id;
  final String name;
  final String slug;

  const ProductCreateBusinessType({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory ProductCreateBusinessType.fromJson(Map<String, dynamic> j) {
    return ProductCreateBusinessType(
      id: _toInt(j['id']),
      name: j['name']?.toString() ?? '',
      slug: j['slug']?.toString() ?? '',
    );
  }
}

class ProductCreateCategory {
  final int id;
  final String name;
  final String description;
  final int? parentId;
  final int businessTypeId;
  final String businessTypeName;

  const ProductCreateCategory({
    required this.id,
    required this.name,
    required this.description,
    this.parentId,
    required this.businessTypeId,
    required this.businessTypeName,
  });

  factory ProductCreateCategory.fromJson(Map<String, dynamic> j) {
    final bt = j['business_type'];
    return ProductCreateCategory(
      id: _toInt(j['id']),
      name: j['name']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      parentId: j['parent_id'] == null ? null : _toInt(j['parent_id']),
      businessTypeId: _toInt(j['business_type_id']),
      businessTypeName: bt is Map<String, dynamic>
          ? (bt['name']?.toString() ?? '')
          : '',
    );
  }
}

class ProductCreateCategoriesResult {
  final List<ProductCreateBusinessType> businessTypes;
  final List<ProductCreateCategory> categories;

  const ProductCreateCategoriesResult({
    required this.businessTypes,
    required this.categories,
  });
}

/// `GET /vendor/product-categories` — categories allowed for this vendor's
/// business types, used on product create.
final vendorProductCreateCategoriesProvider =
    FutureProvider.autoDispose<ProductCreateCategoriesResult>((ref) async {
  final headers = await vendorOrderApiHeaders();
  final uri = Uri.parse(VendorAPIController.vendorProductCategories);
  final res = await http.get(uri, headers: headers);
  if (res.statusCode != 200) {
    var msg = 'HTTP ${res.statusCode}';
    try {
      final top = jsonDecode(res.body);
      if (top is Map<String, dynamic>) {
        msg = top['message']?.toString() ?? msg;
      }
    } catch (_) {}
    throw Exception(msg);
  }

  final top = jsonDecode(res.body);
  if (top is! Map<String, dynamic>) throw Exception('Invalid response');
  // Payload may or may not be wrapped in `data`.
  final data = top['data'] is Map<String, dynamic>
      ? top['data'] as Map<String, dynamic>
      : top;

  final businessTypes = (data['business_types'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(ProductCreateBusinessType.fromJson)
      .toList();

  final categories = (data['categories'] as List? ?? [])
      .whereType<Map<String, dynamic>>()
      .map(ProductCreateCategory.fromJson)
      .toList();

  // Derive business types from categories if API omits the top-level list.
  if (businessTypes.isEmpty && categories.isNotEmpty) {
    final seen = <int>{};
    for (final c in categories) {
      if (c.businessTypeId > 0 && seen.add(c.businessTypeId)) {
        businessTypes.add(
          ProductCreateBusinessType(
            id: c.businessTypeId,
            name: c.businessTypeName,
            slug: '',
          ),
        );
      }
    }
  }

  return ProductCreateCategoriesResult(
    businessTypes: businessTypes,
    categories: categories,
  );
});
