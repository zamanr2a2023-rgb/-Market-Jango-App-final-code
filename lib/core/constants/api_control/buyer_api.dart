import 'global_api.dart';

class BuyerAPIController {
  static final String _base_api = "$api/api";
  static String buyer_product = "$_base_api/product";
  static String banner = "$_base_api/banner";
  static String cart = "$_base_api/cart";
  static String get cartDeliveryCharges => "$_base_api/cart/delivery-charges";
  static String cartDelete(int id) => "$_base_api/cart/$id";
  static String cart_create = "$_base_api/cart/create";
  static String category = "$_base_api/category";
  static String language = "$_base_api/language";
  static String user_update = "$_base_api/user/update";
  static String invoice_createate = "$_base_api/invoice/create";
  static String just_for_you = "$_base_api/admin-selects/just-for-you";
  static String top_products = "$_base_api/admin-selects/top-products";
  static String new_items = "$_base_api/admin-selects/new-items";
  static String top_categories = "$_base_api/admin-selects/top-categories";
  static String product_detail(int id) => "$_base_api/product/detail/$id";
  static String vendor_list(id) => "$_base_api/vendor/list/$id";
  static String categoryVendorProducts(int vendorId, {int page = 1}) =>
      "$_base_api/category/vendor/product/$vendorId?page=$page";

  /// GET api/product/vendor/{id} — vendor's products (paginated).
  /// Optional: `business_type_id`, `name` (search).
  static String productVendor(
    int vendorId, {
    int page = 1,
    int? businessTypeId,
    String? name,
  }) {
    final q = <String, String>{'page': '$page'};
    if (businessTypeId != null && businessTypeId > 0) {
      q['business_type_id'] = '$businessTypeId';
    }
    final n = name?.trim();
    if (n != null && n.isNotEmpty) {
      q['name'] = n;
    }
    return Uri.parse('$_base_api/product/vendor/$vendorId')
        .replace(queryParameters: q)
        .toString();
  }

  /// GET api/vendor/{vendorId}/business-types — public business types for a vendor shop.
  static String vendorPublicBusinessTypes(int vendorId) =>
      '$_base_api/vendor/$vendorId/business-types';

  // static Uri _u(String path) => Uri.parse(_base_api).resolve(path);
  static String paymen_tresponse = "$_base_api/payment/response";
  static String invoice_tracking(oderId) =>
      "$_base_api/invoice/tracking/$oderId";
  static String all_order = "$_base_api/buyer/all-order";
  static String popular_product(id) => "$_base_api/popular/product/$id";
  static String vendor_first_product = "$_base_api/vendor/first/product";
  static String vendor_search(name) => "$_base_api/vendor/search/?name=$name";
  static String buyer_tracking_details(int id) =>
      "$_base_api/buyer/invoice/tracking/details/$id";

  /// GET api/InvoiceProductList/{id} — invoice details with items (product, vendor per item)
  static String invoiceProductList(int id) => "$_base_api/InvoiceProductList/$id";

  static String buyer_search_product(name) =>
      "$_base_api/search/product?name=$name";
  /// GET api/product/search?visibility_country=&category_id=&visibility_state=
  static String productSearch({
    required String visibilityCountry,
    required int categoryId,
    String? visibilityState,
    String? visibilityTown,
  }) {
    final country = Uri.encodeComponent(visibilityCountry.trim());
    var url = '$_base_api/product/search?visibility_country=$country&category_id=$categoryId';
    if (visibilityState != null && visibilityState.trim().isNotEmpty) {
      url += '&visibility_state=${Uri.encodeComponent(visibilityState.trim())}';
    }
    if (visibilityTown != null && visibilityTown.trim().isNotEmpty) {
      url += '&visibility_town=${Uri.encodeComponent(visibilityTown.trim())}';
    }
    return url;
  }
  static String review_buyer(id) => "$_base_api/review/create/buyer/$id";
  static String review_vendor(id) => "$_base_api/review/vendor/$id";

  // --- Buyer wallet (doc/details.md §D) — `/api/wallet` ---
  static String get buyerWallet => '$_base_api/wallet';

  static String buyerWalletTransactions({
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
    return Uri.parse('$_base_api/wallet/transactions')
        .replace(queryParameters: q)
        .toString();
  }

  static String get buyerWalletTopup => '$_base_api/wallet/topup';
  /// Flutterwave (or gateway) hosted pay — returns `payment_url`, `tx_ref`, `redirect_url`.
  static String get buyerWalletTopupInitiate =>
      '$_base_api/wallet/topup/initiate';
  static String get buyerWalletPayout => '$_base_api/wallet/payout';

  static String buyerWalletPayouts({int page = 1, String? status}) {
    final q = <String, String>{'page': '$page'};
    if (status != null && status.trim().isNotEmpty) {
      q['status'] = status.trim();
    }
    return Uri.parse('$_base_api/wallet/payouts')
        .replace(queryParameters: q)
        .toString();
  }

  // --- Buyer refunds (doc/details.md §E) ---
  static String buyerRefunds({int page = 1, String? status}) {
    final q = <String, String>{'page': '$page'};
    if (status != null && status.trim().isNotEmpty) {
      q['status'] = status.trim();
    }
    return Uri.parse('$_base_api/buyer/refunds')
        .replace(queryParameters: q)
        .toString();
  }

  static String buyerRefundDetail(int id) => '$_base_api/buyer/refunds/$id';

  /// `item_id` = invoice line id.
  static String buyerOrderLineRefund(int invoiceItemId) =>
      '$_base_api/buyer/orders/$invoiceItemId/refund';

  // --- Live tracking (doc/details.md §5) — `order_id` = invoice id ---
  static String buyerOrderTrack(int invoiceId) =>
      '$_base_api/buyer/orders/$invoiceId/track';

  static String buyerOrderTrackPath(int invoiceId, {int? itemId}) {
    final base = '$_base_api/buyer/orders/$invoiceId/track/path';
    if (itemId == null) return base;
    return '$base?item_id=$itemId';
  }

  /// Query: `tx_ref` (required).
  static String paymentVerify({required String txRef}) =>
      Uri.parse('$_base_api/payment/verify')
          .replace(queryParameters: {'tx_ref': txRef})
          .toString();

  /// Successful-delivery invoices only; 10/page (doc B2).
  static String buyerInvoicesSuccessful({int page = 1}) =>
      Uri.parse('$_base_api/invoice').replace(queryParameters: {
        'page': '$page',
      }).toString();

  // --- Delivery charge locations (Postman: buyer/delivery-charge-locations/*) ---
  /// GET …/zones — `data.items` = zone names.
  static String get visibilityZones =>
      '$_base_api/buyer/delivery-charge-locations/zones';

  /// GET …/states?zone= — `data.items` = state names for the zone.
  static String visibilityStatesByZone({required String zone}) => Uri.parse(
        '$_base_api/buyer/delivery-charge-locations/states',
      ).replace(queryParameters: {'zone': zone.trim()}).toString();

  /// GET …/towns?zone_name= — `data.items` = town names.
  static String visibilityTownsByZone({required String zoneName}) => Uri.parse(
        '$_base_api/buyer/delivery-charge-locations/towns',
      ).replace(queryParameters: {'zone_name': zoneName.trim()}).toString();

  static String visibilityVendors({
    required String zone,
    String? state,
    String? town,
    int perPage = 20,
  }) {
    final q = <String, String>{
      'zone': zone.trim(),
      'per_page': '$perPage',
    };
    if (state != null && state.trim().isNotEmpty) q['state'] = state.trim();
    if (town != null && town.trim().isNotEmpty) q['town'] = town.trim();
    return Uri.parse('$_base_api/buyer/visibility-locations/vendors')
        .replace(queryParameters: q)
        .toString();
  }

  static String visibilityVendorsByCategory({
    required int categoryId,
    String? zone,
    String? state,
    String? town,
    int perPage = 20,
  }) {
    final q = <String, String>{
      'category_id': '$categoryId',
      'per_page': '$perPage',
    };
    if (zone != null && zone.trim().isNotEmpty) q['zone'] = zone.trim();
    if (state != null && state.trim().isNotEmpty) q['state'] = state.trim();
    if (town != null && town.trim().isNotEmpty) q['town'] = town.trim();
    return Uri.parse(
      '$_base_api/buyer/visibility-locations/vendors-by-category',
    ).replace(queryParameters: q).toString();
  }

  static String visibilityVendorsByBusinessType({
    required int businessTypeId,
    String? zone,
    String? state,
    String? town,
    int perPage = 20,
  }) {
    final q = <String, String>{
      'business_type_id': '$businessTypeId',
      'per_page': '$perPage',
    };
    if (zone != null && zone.trim().isNotEmpty) q['zone'] = zone.trim();
    if (state != null && state.trim().isNotEmpty) q['state'] = state.trim();
    if (town != null && town.trim().isNotEmpty) q['town'] = town.trim();
    return Uri.parse(
      '$_base_api/buyer/visibility-locations/vendors-by-business-type',
    ).replace(queryParameters: q).toString();
  }

  // --- Follow vendor (buyer) ---
  /// `GET /follows/vendor/{vendorId}/followers`
  static String vendorFollowers(int vendorId, {int page = 1}) =>
      '$_base_api/follows/vendor/$vendorId/followers?page=$page';

  /// `POST /follows/vendor/{vendorId}` — follow
  static String followVendor(int vendorId) =>
      '$_base_api/follows/vendor/$vendorId';

  /// `DELETE /follows/vendor/{vendorId}` — unfollow
  static String unfollowVendor(int vendorId) =>
      '$_base_api/follows/vendor/$vendorId';

  // --- Follow driver ---
  /// `GET /follows/driver/{driverId}/followers`
  static String driverFollowers(int driverId, {int page = 1}) =>
      '$_base_api/follows/driver/$driverId/followers?page=$page';

  /// `POST /follows/driver/{driverId}` — follow
  static String followDriver(int driverId) =>
      '$_base_api/follows/driver/$driverId';

  /// `DELETE /follows/driver/{driverId}` — unfollow
  static String unfollowDriver(int driverId) =>
      '$_base_api/follows/driver/$driverId';

  /// `GET /follows/me` — list of accounts the current user follows
  static String myFollowing({int page = 1}) =>
      '$_base_api/follows/me?page=$page';
}

// lib/core/constants/api_control/buyer_api.dart
class BuyerPaymentAPIController {
  static final String _base_api = "$api/api";
  
  static String get invoice_createate => "$_base_api/invoice/create";

  // ✅ payment verify/callback endpoint (GET) - using base URL
  static Uri get paymentResponse => Uri.parse("$_base_api/payment/response");
}
