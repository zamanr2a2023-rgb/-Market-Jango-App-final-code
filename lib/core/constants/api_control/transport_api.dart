import 'package:market_jango/core/utils/auth_local_storage.dart';

import 'global_api.dart';

/// JSON shipment API errors (422 validation, etc.).
String formatTransportApiError(Map<String, dynamic> json, int statusCode) {
  final parts = <String>[];
  final msg = json['message']?.toString();
  if (msg != null && msg.isNotEmpty) parts.add(msg);
  final errors = json['errors'];
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
  if (parts.isEmpty) return 'Request failed (HTTP $statusCode)';
  return parts.join('\n');
}

class TransportAPIController {
  static final String _base_api = "$api/api";
  static String approved_driver = "$_base_api/approved-driver";
  static String all_order_transport = "$_base_api/all-order/transport";
  static String transport_invoice_create(int driverId) =>
      "$_base_api/transport/invoice/create/$driverId";

  /// Shipments: GET list of transport types (motorcycle, car, air, water)
  static String get transportTypes => "$_base_api/shipments/transport-types";

  /// Shipments: GET search transporters; query: transport_type, origin_address, destination_address
  static String get searchTransporters =>
      "$_base_api/shipments/search-transporters";

  /// POST create shipment (draft) with packages
  static String get createShipment => "$_base_api/shipments";

  /// Auth headers for shipment / transport APIs (token, id, user_type, email).
  ///
  /// Buyers keep `user_type: buyer` per POLISH; dedicated transport accounts
  /// keep `user_type: transport`.
  static Future<Map<String, String>> transportAuthHeaders({
    String? tokenOverride,
    bool jsonContentType = false,
    String accept = 'application/json',
  }) async {
    final storage = AuthLocalStorage();
    final token = tokenOverride ?? await storage.getToken();
    final userId = await storage.getUserId();
    final userType = await storage.getUserType();
    final userJson = await storage.getUserJson();
    final email = userJson?['email']?.toString() ?? '';

    final effectiveType = (userType != null && userType.trim().isNotEmpty)
        ? userType.trim().toLowerCase()
        : 'transport';

    return {
      'Accept': accept,
      if (jsonContentType) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
      if (userId != null && userId.isNotEmpty) 'id': userId,
      'user_type': effectiveType,
      if (email.isNotEmpty) 'email': email,
    };
  }

  /// Headers for `POST /api/shipments` (token, id, user_type, email).
  static Future<Map<String, String>> shipmentCreateHeaders({
    String? tokenOverride,
  }) =>
      transportAuthHeaders(
        tokenOverride: tokenOverride,
        jsonContentType: true,
      );

  /// GET single shipment details
  static String shipmentById(int id) => "$_base_api/shipments/$id";

  /// GET shipment invoice PDF (`doc/details.md` §2).
  static String shipmentDownloadInvoice(int id) =>
      "$_base_api/shipments/$id/download-invoice";

  /// GET shipment delivery label PDF (`doc/details.md` §2).
  static String shipmentDownloadDeliveryLabel(int id) =>
      "$_base_api/shipments/$id/download-delivery-label";

  /// POST pay for shipment
  static String payShipment(int id) => "$_base_api/shipments/$id/pay";

  /// POST confirm transport shipment receipt (after driver delivered).
  static String shipmentMarkReceived(int id) => "$_base_api/shipments/$id/received";

  /// POST initiate payment (returns payment_url for gateway/WebView)
  static String initiateShipmentPayment(int id) =>
      "$_base_api/shipments/$id/initiate-payment";

  // --- Transport wallet (doc/details.md) — `/api/transport/wallet/...` ---
  static String get transportWallet => '$_base_api/transport/wallet';

  static String transportWalletTransactions({
    int page = 1,
    int perPage = 20,
    String? fromDate,
    String? toDate,
    String? type,
    String? status,
  }) {
    final q = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (fromDate != null && fromDate.isNotEmpty) q['from_date'] = fromDate;
    if (toDate != null && toDate.isNotEmpty) q['to_date'] = toDate;
    if (type != null && type.trim().isNotEmpty) q['type'] = type.trim();
    if (status != null && status.trim().isNotEmpty) {
      q['status'] = status.trim();
    }
    return Uri.parse(
      '$_base_api/transport/wallet/transactions',
    ).replace(queryParameters: q).toString();
  }

  static String get transportWalletTopup => '$_base_api/transport/wallet/topup';

  /// Hosted gateway (Flutterwave) — returns `payment_url`, `tx_ref`, `redirect_url`.
  static String get transportWalletTopupInitiate =>
      '$_base_api/transport/wallet/topup/initiate';
  static String get transportWalletPayout =>
      '$_base_api/transport/wallet/payout';

  /// Payout list: backend uses 15 per page by default; `page` is supported.
  static String transportWalletPayouts({int page = 1, String? status}) {
    final q = <String, String>{'page': '$page'};
    if (status != null && status.trim().isNotEmpty) {
      q['status'] = status.trim();
    }
    return Uri.parse(
      '$_base_api/transport/wallet/payouts',
    ).replace(queryParameters: q).toString();
  }
}
