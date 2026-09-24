import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_marketing_promotions/model/vendor_promotion_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

String _formatApiError(Map<String, dynamic> j, int code) {
  final parts = <String>[];
  final msg = j['message']?.toString();
  if (msg != null && msg.isNotEmpty) parts.add(msg);
  final errors = j['errors'];
  if (errors is Map) {
    for (final e in errors.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v is List) {
        for (final item in v) {
          parts.add('• $k: $item');
        }
      } else if (v != null) {
        parts.add('• $k: $v');
      }
    }
  }
  if (parts.isEmpty) return 'Request failed ($code)';
  return parts.join('\n');
}

List<VendorPromotion> _parsePromotionList(dynamic decoded) {
  if (decoded is! Map) return const [];
  final map = Map<String, dynamic>.from(decoded);
  dynamic raw = map['data'];
  if (raw is Map) {
    if (raw['items'] is List) {
      raw = raw['items'];
    } else if (raw['promotions'] is List) {
      raw = raw['promotions'];
    } else if (raw['data'] is List) {
      raw = raw['data'];
    }
  }
  if (raw is! List && map['promotions'] is List) raw = map['promotions'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => VendorPromotion.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

class VendorPromotionApi {
  /// `POST /api/vendor/promotions` — JSON body (STEP_05).
  /// Backend validates `image` as a **string** (URL or base64), not a file upload.
  static Future<VendorPromotion> create({
    required String title,
    required String zone,
    String? content,
    File? image,
  }) async {
    final headers = await vendorOrderApiHeaders();
    headers['Content-Type'] = 'application/json';

    final body = <String, dynamic>{
      'title': title.trim(),
      'zone': zone.trim(),
    };
    final c = content?.trim() ?? '';
    if (c.isNotEmpty) {
      body['content'] = c;
      body['text'] = c;
      body['description'] = c;
    }

    if (image != null && await image.exists()) {
      final bytes = await image.readAsBytes();
      final b64 = base64Encode(bytes);
      final lower = image.path.toLowerCase();
      final mime = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      // Laravel "image must be a string" — send data-URI / base64 string.
      body['image'] = 'data:$mime;base64,$b64';
    }

    final res = await http.post(
      Uri.parse(VendorAPIController.vendorPromotions),
      headers: headers,
      body: jsonEncode(body),
    );

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Promotion create failed (${res.statusCode}). Backend may not support this endpoint.',
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_formatApiError(json, res.statusCode));
    }
    final st = json['status']?.toString().toLowerCase();
    if (st == 'failed' || st == 'error') {
      throw Exception(json['message']?.toString() ?? 'Failed to create promotion');
    }

    final data = json['data'];
    if (data is Map) {
      return VendorPromotion.fromJson(Map<String, dynamic>.from(data));
    }
    return VendorPromotion(
      id: 0,
      title: title,
      content: content ?? '',
      zone: zone,
      status: 'pending',
    );
  }

  /// Optional vendor list — may 404 / HTML if backend has no list route.
  static Future<List<VendorPromotion>> listMine() async {
    final headers = await vendorOrderApiHeaders();
    final res = await http.get(
      Uri.parse(VendorAPIController.vendorPromotions),
      headers: headers,
    );
    final body = res.body.trimLeft();
    if (res.statusCode == 404 ||
        body.startsWith('<') ||
        body.startsWith('<!')) {
      // List endpoint not available — create still works via POST.
      return const [];
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return const [];
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        throw Exception(_formatApiError(decoded, res.statusCode));
      }
      return const [];
    }
    return _parsePromotionList(decoded);
  }

  /// Optional admin pending list.
  static Future<List<VendorPromotion>> listAdmin({String? status}) async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(VendorAPIController.adminPromotions).replace(
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final res = await http.get(uri, headers: headers);
    if (res.statusCode == 404) {
      throw Exception(
        'GET /api/admin/promotions is not available on the backend.',
      );
    }
    final decoded = jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        throw Exception(_formatApiError(decoded, res.statusCode));
      }
      throw Exception('Failed to load admin promotions (${res.statusCode})');
    }
    return _parsePromotionList(decoded);
  }

  /// `POST /api/admin/promotions/{id}/approve`
  static Future<void> approve(int id) async {
    final headers = await vendorOrderApiHeaders();
    final res = await http.post(
      Uri.parse(VendorAPIController.adminPromotionApprove(id)),
      headers: headers,
    );
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        json != null
            ? _formatApiError(json, res.statusCode)
            : 'Approve failed (${res.statusCode})',
      );
    }
    final st = json?['status']?.toString().toLowerCase();
    if (st == 'failed' || st == 'error') {
      throw Exception(json?['message']?.toString() ?? 'Approve failed');
    }
  }

  /// Optional reject — only if backend exposes it.
  static Future<void> reject(int id) async {
    final headers = await vendorOrderApiHeaders();
    final res = await http.post(
      Uri.parse(VendorAPIController.adminPromotionReject(id)),
      headers: headers,
    );
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode == 404) {
      throw Exception(
        'Reject endpoint not available. Backend only documents approve.',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        json != null
            ? _formatApiError(json, res.statusCode)
            : 'Reject failed (${res.statusCode})',
      );
    }
  }

  /// `POST /api/vendor/products/{id}/notify-followers`
  static Future<void> notifyFollowers(int productId) async {
    final headers = await vendorOrderApiHeaders();
    final res = await http.post(
      Uri.parse(VendorAPIController.vendorNotifyFollowers(productId)),
      headers: headers,
    );
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        json != null
            ? _formatApiError(json, res.statusCode)
            : 'Notify followers failed (${res.statusCode})',
      );
    }
    final st = json?['status']?.toString().toLowerCase();
    if (st == 'failed' || st == 'error') {
      throw Exception(json?['message']?.toString() ?? 'Notify failed');
    }
  }
}

final vendorPromotionsListProvider =
    FutureProvider.autoDispose<List<VendorPromotion>>((ref) async {
  return VendorPromotionApi.listMine();
});

final adminPromotionsListProvider =
    FutureProvider.autoDispose<List<VendorPromotion>>((ref) async {
  try {
    return await VendorPromotionApi.listAdmin(status: 'pending');
  } catch (_) {
    // Fall back to unfiltered list if status filter unsupported.
    return VendorPromotionApi.listAdmin();
  }
});
