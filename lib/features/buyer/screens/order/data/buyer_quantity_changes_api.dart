import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/buyer/screens/order/model/buyer_quantity_change_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';

Map<String, dynamic> _decodeObj(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw Exception('Invalid JSON');
}

Map<String, dynamic>? _unwrapDataMap(Map<String, dynamic> top) {
  final d = top['data'];
  if (d is Map<String, dynamic>) return d;
  return null;
}

String _formatApiError(Map<String, dynamic> j, int code) {
  final msg = j['message']?.toString();
  if (msg != null && msg.isNotEmpty) return msg;
  return 'HTTP $code';
}

void _assertJsonSuccess(Map<String, dynamic> top) {
  final st = top['status']?.toString().toLowerCase();
  if (st == 'error' || st == 'fail' || st == 'failed') {
    final msg = top['message']?.toString().trim();
    throw Exception(
      (msg != null && msg.isNotEmpty) ? msg : 'Request failed',
    );
  }
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

Future<Map<String, String>> _buyerAuthHeaders() async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final id = await storage.getUserId();
  final userType = await storage.getUserType();
  final userJson = await storage.getUserJson();
  final email = userJson?['email']?.toString();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (id != null && id.isNotEmpty) 'id': id,
    if (userType != null && userType.isNotEmpty) 'user_type': userType,
    if (email != null && email.isNotEmpty) 'email': email,
  };
}

class BuyerQuantityChangeAcceptResult {
  const BuyerQuantityChangeAcceptResult({this.autoRefund});

  final AutoRefundModel? autoRefund;
}

class BuyerQuantityChangesApi {
  BuyerQuantityChangesApi._();
  static final BuyerQuantityChangesApi instance = BuyerQuantityChangesApi._();

  Future<BuyerPendingQuantityChangesPayload> fetchPending({
    int page = 1,
    int perPage = 15,
  }) async {
    final headers = await _buyerAuthHeaders();
    final uri = Uri.parse(
      BuyerAPIController.buyerQuantityChangesPending(
        page: page,
        perPage: perPage,
      ),
    );
    final res = await http.get(uri, headers: headers);
    _throwIfBad(res);
    final top = _decodeObj(res.body);
    _assertJsonSuccess(top);
    final data = _unwrapDataMap(top) ?? top;
    return BuyerPendingQuantityChangesPayload.parse(data);
  }

  Future<BuyerQuantityChangeAcceptResult> accept({
    required int invoiceItemId,
    required int requestId,
  }) async {
    final headers = await _buyerAuthHeaders();
    final uri = Uri.parse(
      BuyerAPIController.buyerQuantityChangeAccept(
        invoiceItemId,
        requestId,
      ),
    );
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    _throwIfBad(res);
    final top = _decodeObj(res.body);
    _assertJsonSuccess(top);
    return BuyerQuantityChangeAcceptResult(
      autoRefund: AutoRefundModel.tryParse(top),
    );
  }
}
