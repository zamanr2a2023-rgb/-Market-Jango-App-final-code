import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/offline_sync/model/offline_sale_queue_item.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

/// `POST /api/sync/offline` — STEP_13.
class OfflineSyncApi {
  OfflineSyncApi._();
  static final OfflineSyncApi instance = OfflineSyncApi._();

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

  Future<String> syncSale(OfflineSaleQueueItem item) async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(VendorAPIController.vendorOfflineSync);
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(item.toSyncRequestJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res.body, res.statusCode));
    }
    try {
      final top = jsonDecode(res.body);
      if (top is Map<String, dynamic>) {
        final st = top['status']?.toString().toLowerCase();
        if (st == 'error' || st == 'fail' || st == 'failed') {
          throw Exception(top['message']?.toString() ?? 'Sync failed');
        }
        final msg = top['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } on FormatException {
      // non-JSON success
    }
    return 'Synced';
  }
}
