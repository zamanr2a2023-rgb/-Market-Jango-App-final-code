import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/driver_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class DriverOutlet {
  const DriverOutlet({
    required this.id,
    required this.name,
    required this.phone,
    required this.defaultMaxConcurrentOrders,
    this.membershipStatus,
    this.maxConcurrentOrders,
  });

  final int id;
  final String name;
  final String phone;
  final int defaultMaxConcurrentOrders;
  final String? membershipStatus;
  final int? maxConcurrentOrders;

  bool get isApproved => membershipStatus?.toLowerCase() == 'approved';
  bool get hasRequestedMembership =>
      membershipStatus != null && membershipStatus!.trim().isNotEmpty;

  factory DriverOutlet.fromJson(Map<String, dynamic> json) {
    return DriverOutlet(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      defaultMaxConcurrentOrders:
          _toInt(json['default_max_concurrent_orders']),
      membershipStatus: json['membership_status']?.toString(),
      maxConcurrentOrders: json['max_concurrent_orders'] == null
          ? null
          : _toInt(json['max_concurrent_orders']),
    );
  }
}

class DriverOutletBinOrder {
  const DriverOutletBinOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.outletStatus,
    required this.outletId,
    required this.quantity,
    required this.totalPay,
    required this.productName,
    required this.productImage,
    required this.pickupAddress,
    required this.vendorName,
    required this.dropoffAddress,
    required this.buyerName,
    required this.buyerPhone,
  });

  final int id;
  final String orderNumber;
  final String status;
  final String outletStatus;
  final int outletId;
  final int quantity;
  final String totalPay;
  final String productName;
  final String productImage;
  final String pickupAddress;
  final String vendorName;
  final String dropoffAddress;
  final String buyerName;
  final String buyerPhone;

  factory DriverOutletBinOrder.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map<String, dynamic>
        ? json['product'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final pickup = json['pickup'] is Map<String, dynamic>
        ? json['pickup'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final dropoff = json['dropoff'] is Map<String, dynamic>
        ? json['dropoff'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final vendor = json['vendor'] is Map<String, dynamic>
        ? json['vendor'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return DriverOutletBinOrder(
      id: _toInt(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      outletStatus: json['outlet_status']?.toString() ?? '',
      outletId: _toInt(json['outlet_id']),
      quantity: _toInt(json['quantity'], fallback: 1),
      totalPay: json['total_pay']?.toString() ?? '0',
      productName: product['name']?.toString() ?? '',
      productImage: product['image']?.toString() ?? '',
      pickupAddress: pickup['address']?.toString() ?? '',
      vendorName:
          pickup['vendor_name']?.toString() ??
          vendor['business_name']?.toString() ??
          '',
      dropoffAddress: dropoff['address']?.toString() ?? '',
      buyerName: dropoff['buyer_name']?.toString() ?? '',
      buyerPhone: dropoff['buyer_phone']?.toString() ?? '',
    );
  }
}

class DriverOutletBinPage {
  const DriverOutletBinPage({
    required this.currentPage,
    required this.lastPage,
    required this.orders,
  });

  final int currentPage;
  final int lastPage;
  final List<DriverOutletBinOrder> orders;

  factory DriverOutletBinPage.fromJson(Map<String, dynamic> json) {
    final rows = json['data'] is List ? json['data'] as List : const [];
    return DriverOutletBinPage(
      currentPage: _toInt(json['current_page'], fallback: 1),
      lastPage: _toInt(json['last_page'], fallback: 1),
      orders: rows
          .whereType<Map<String, dynamic>>()
          .map(DriverOutletBinOrder.fromJson)
          .toList(),
    );
  }
}

class DriverOutletsApi {
  DriverOutletsApi._();
  static final DriverOutletsApi instance = DriverOutletsApi._();

  Future<Map<String, String>> _headers() async {
    final storage = AuthLocalStorage();
    final token = (await storage.getToken())?.trim();
    final id = await storage.getUserId();
    final userType = await storage.getUserType();
    final bearer = token == null || token.isEmpty
        ? null
        : token.toLowerCase().startsWith('bearer ')
        ? token
        : 'Bearer $token';
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
      if (bearer != null) 'Authorization': bearer,
      if (id != null && id.isNotEmpty) 'id': id,
      if (userType != null && userType.isNotEmpty) 'user_type': userType,
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response');
    }
    final status = decoded['status']?.toString().toLowerCase();
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        status == 'error' ||
        status == 'fail' ||
        status == 'failed') {
      throw Exception(
        decoded['message']?.toString() ?? 'HTTP ${response.statusCode}',
      );
    }
    return decoded;
  }

  Future<List<DriverOutlet>> fetchOutlets() async {
    final response = await http.get(
      Uri.parse(DriverAPIController.driverOutlets),
      headers: await _headers(),
    );
    final top = _decode(response);
    final rows = top['data'] is List ? top['data'] as List : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(DriverOutlet.fromJson)
        .toList();
  }

  Future<String> joinOutlet(int outletId) async {
    final response = await http.post(
      Uri.parse(DriverAPIController.driverOutletJoin(outletId)),
      headers: await _headers(),
      body: jsonEncode(const <String, dynamic>{}),
    );
    final top = _decode(response);
    return top['message']?.toString() ?? 'Join request submitted';
  }

  Future<DriverOutletBinPage> fetchBinOrders({
    required int outletId,
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse(
        DriverAPIController.driverOutletBinOrders(outletId, page: page),
      ),
      headers: await _headers(),
    );
    final top = _decode(response);
    final data = top['data'];
    return DriverOutletBinPage.fromJson(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
    );
  }

  Future<String> claimOrder(int orderItemId) async {
    final response = await http.post(
      Uri.parse(DriverAPIController.driverOutletBinClaim(orderItemId)),
      headers: await _headers(),
      body: jsonEncode(const <String, dynamic>{}),
    );
    final top = _decode(response);
    return top['message']?.toString() ?? 'Order claimed successfully';
  }
}

final driverOutletsProvider =
    FutureProvider.autoDispose<List<DriverOutlet>>((ref) {
      return DriverOutletsApi.instance.fetchOutlets();
    });

class DriverOutletBinQuery {
  const DriverOutletBinQuery({required this.outletId, required this.page});
  final int outletId;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is DriverOutletBinQuery &&
      other.outletId == outletId &&
      other.page == page;

  @override
  int get hashCode => Object.hash(outletId, page);
}

final driverOutletBinOrdersProvider = FutureProvider.autoDispose
    .family<DriverOutletBinPage, DriverOutletBinQuery>((ref, query) {
      return DriverOutletsApi.instance.fetchBinOrders(
        outletId: query.outletId,
        page: query.page,
      );
    });
