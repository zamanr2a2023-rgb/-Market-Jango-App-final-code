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

Map<String, dynamic> _decodeMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw Exception('Invalid JSON');
}

String _message(Map<String, dynamic> top) =>
    top['message']?.toString() ?? 'Request failed';

class VendorBusinessType {
  final int id;
  final String name;
  final String slug;
  final String description;

  const VendorBusinessType({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
  });

  factory VendorBusinessType.fromJson(Map<String, dynamic> j) {
    return VendorBusinessType(
      id: _toInt(j['id']),
      name: j['name']?.toString() ?? '',
      slug: j['slug']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
    );
  }
}

class VendorBusinessTypesResult {
  final List<VendorBusinessType> selected;
  final List<VendorBusinessType> available;
  final int used;
  final int limit;
  final bool canAddMore;
  final int allowedCategoriesCount;

  const VendorBusinessTypesResult({
    required this.selected,
    required this.available,
    required this.used,
    required this.limit,
    required this.canAddMore,
    required this.allowedCategoriesCount,
  });

  factory VendorBusinessTypesResult.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return const VendorBusinessTypesResult(
        selected: [],
        available: [],
        used: 0,
        limit: 0,
        canAddMore: false,
        allowedCategoriesCount: 0,
      );
    }
    List<VendorBusinessType> parseList(dynamic v) => (v as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VendorBusinessType.fromJson)
        .toList();

    final usage = j['usage'];
    final usageMap = usage is Map<String, dynamic> ? usage : const <String, dynamic>{};

    return VendorBusinessTypesResult(
      selected: parseList(j['selected']),
      available: parseList(j['available']),
      used: _toInt(usageMap['business_types_used']),
      limit: _toInt(usageMap['business_types_limit']),
      canAddMore: usageMap['can_add_more'] == true,
      allowedCategoriesCount: _toInt(j['allowed_categories_count']),
    );
  }
}

class VendorBusinessTypesApi {
  VendorBusinessTypesApi._();
  static final VendorBusinessTypesApi instance = VendorBusinessTypesApi._();

  Future<VendorBusinessTypesResult> fetch() async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(VendorAPIController.vendorBusinessTypes);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      var msg = 'HTTP ${res.statusCode}';
      try {
        msg = _message(_decodeMap(res.body));
      } catch (_) {}
      throw Exception(msg);
    }
    final top = _decodeMap(res.body);
    final d = top['data'];
    return VendorBusinessTypesResult.fromJson(
      d is Map<String, dynamic> ? d : null,
    );
  }

  Future<String> add(List<int> businessTypeIds) async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(VendorAPIController.vendorBusinessTypes);
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'business_type_ids': businessTypeIds}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      var msg = 'HTTP ${res.statusCode}';
      try {
        msg = _message(_decodeMap(res.body));
      } catch (_) {}
      throw Exception(msg);
    }
    try {
      return _message(_decodeMap(res.body));
    } catch (_) {
      return 'Business type added';
    }
  }

  Future<String> remove(int businessTypeId) async {
    final headers = await vendorOrderApiHeaders();
    final uri =
        Uri.parse(VendorAPIController.vendorBusinessTypeDelete(businessTypeId));
    final res = await http.delete(uri, headers: headers);
    if (res.statusCode != 200 && res.statusCode != 204) {
      var msg = 'HTTP ${res.statusCode}';
      try {
        msg = _message(_decodeMap(res.body));
      } catch (_) {}
      throw Exception(msg);
    }
    try {
      if (res.body.trim().isEmpty) return 'Business type removed';
      return _message(_decodeMap(res.body));
    } catch (_) {
      return 'Business type removed';
    }
  }
}

final vendorBusinessTypesProvider =
    FutureProvider.autoDispose<VendorBusinessTypesResult>((ref) async {
  return VendorBusinessTypesApi.instance.fetch();
});
