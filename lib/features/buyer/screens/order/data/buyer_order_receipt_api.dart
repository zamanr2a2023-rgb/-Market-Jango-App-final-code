import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_auth_headers.dart';

Map<String, dynamic> _decodeObj(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw Exception('Invalid JSON');
}

String _formatApiError(Map<String, dynamic> j, int code) {
  final msg = j['message']?.toString();
  if (msg != null && msg.isNotEmpty) return msg;
  return 'HTTP $code';
}

void _throwIfBad(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  try {
    final j = _decodeObj(res.body);
    throw Exception(_formatApiError(j, res.statusCode));
  } catch (e) {
    if (e is Exception &&
        e.toString().startsWith('Exception:') &&
        !e.toString().contains('Invalid JSON')) {
      rethrow;
    }
    throw Exception('HTTP ${res.statusCode}');
  }
}

class BuyerOrderReceiptApi {
  BuyerOrderReceiptApi._();
  static final BuyerOrderReceiptApi instance = BuyerOrderReceiptApi._();

  /// POST /api/buyer/orders/{invoice_item_id}/received — idempotent when already received.
  Future<void> markReceived(int invoiceItemId) async {
    final headers = await buyerAuthHeaders(includeJsonContentType: true);
    final uri = Uri.parse(
      BuyerAPIController.buyerOrderMarkReceived(invoiceItemId),
    );
    final res = await http.post(uri, headers: headers);
    _throwIfBad(res);
  }
}
