import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/transport_api.dart';

Map<String, dynamic> _decodeObj(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw Exception('Invalid JSON');
}

void _throwIfBad(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) return;
  try {
    final j = _decodeObj(res.body);
    throw Exception(formatTransportApiError(j, res.statusCode));
  } catch (e) {
    if (e is Exception && e.toString().startsWith('Exception:')) rethrow;
    throw Exception('HTTP ${res.statusCode}');
  }
}

class TransportShipmentReceiptApi {
  TransportShipmentReceiptApi._();
  static final TransportShipmentReceiptApi instance =
      TransportShipmentReceiptApi._();

  Future<void> markReceived(int shipmentId) async {
    final headers = await TransportAPIController.transportAuthHeaders(
      jsonContentType: true,
    );
    final uri = Uri.parse(
      TransportAPIController.shipmentMarkReceived(shipmentId),
    );
    final res = await http.post(uri, headers: headers);
    _throwIfBad(res);
  }
}
