import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_pos_display_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

/// `GET /api/vendor/manual-orders/{id}/pos-display` (STEP_04).
class VendorPosDisplayApi {
  VendorPosDisplayApi._();
  static final instance = VendorPosDisplayApi._();

  Future<VendorPosDisplayData> fetch(int invoiceId) async {
    if (invoiceId <= 0) {
      throw Exception('Invalid walk-in order id');
    }
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(
      VendorAPIController.vendorManualOrderPosDisplay(invoiceId),
    );
    final res = await http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'POS display failed (${res.statusCode})';
      try {
        final top = jsonDecode(res.body);
        if (top is Map && top['message'] != null) {
          msg = top['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid POS display response');
    }
    final data = decoded['data'];
    final map = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(decoded);
    return VendorPosDisplayData.fromJson(map);
  }
}
