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

/// Item of `GET /vendor/outlets` → `data[]`.
class VendorOutlet {
  final int id;
  final String name;
  final String phone;
  final int defaultMaxConcurrentOrders;

  const VendorOutlet({
    required this.id,
    required this.name,
    required this.phone,
    required this.defaultMaxConcurrentOrders,
  });

  factory VendorOutlet.fromJson(Map<String, dynamic> j) {
    return VendorOutlet(
      id: _toInt(j['id']),
      name: j['name']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      defaultMaxConcurrentOrders: _toInt(j['default_max_concurrent_orders']),
    );
  }
}

String _errorMessage(String body, int code) {
  try {
    final top = jsonDecode(body);
    if (top is Map<String, dynamic>) {
      final msg = top['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
  } catch (_) {}
  return 'HTTP $code';
}

class VendorOutletsApi {
  VendorOutletsApi._();
  static final VendorOutletsApi instance = VendorOutletsApi._();

  /// `GET /vendor/outlets`
  Future<List<VendorOutlet>> fetchOutlets() async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(VendorAPIController.vendorOutlets);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.body, res.statusCode));
    }
    final top = jsonDecode(res.body);
    if (top is! Map<String, dynamic>) throw Exception('Invalid response');
    final st = top['status']?.toString().toLowerCase();
    if (st == 'error' || st == 'fail') {
      throw Exception(top['message']?.toString() ?? 'Request failed');
    }
    final data = top['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(VendorOutlet.fromJson)
        .toList();
  }

  /// `POST /vendor/orders/{order_item_id}/assign-outlet`
  Future<String> assignOrderToOutlet({
    required int orderItemId,
    required int outletId,
  }) async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(
      VendorAPIController.vendorOrderAssignOutlet(orderItemId),
    );
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'outlet_id': outletId}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res.body, res.statusCode));
    }
    try {
      final top = jsonDecode(res.body);
      if (top is Map<String, dynamic>) {
        final st = top['status']?.toString().toLowerCase();
        final msg = top['message']?.toString();
        if (st == 'error' || st == 'fail') {
          throw Exception(msg ?? 'Request failed');
        }
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } on FormatException {
      // non-JSON success body
    }
    return 'Order assigned to outlet';
  }
}

/// Active outlets — `GET /vendor/outlets`.
final vendorOutletsProvider =
    FutureProvider.autoDispose<List<VendorOutlet>>((ref) async {
  return VendorOutletsApi.instance.fetchOutlets();
});
