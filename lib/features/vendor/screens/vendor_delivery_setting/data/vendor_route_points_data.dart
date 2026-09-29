import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/vendor/screens/vendor_delivery_setting/model/vendor_route_point_model.dart';

/// POST 422 when the driver/vendor is already at `max_routes`.
class RouteLimitException implements Exception {
  const RouteLimitException();

  @override
  String toString() =>
      'Route limit reached. Upgrade subscription to add more routes.';
}

final routePointsProvider =
    AsyncNotifierProvider<RoutePointsNotifier, RoutePointsResponse?>(
  RoutePointsNotifier.new,
);

class RoutePointsNotifier extends AsyncNotifier<RoutePointsResponse?> {
  String _search = '';
  int _page = 1;

  String get search => _search;
  int get page => _page;

  @override
  Future<RoutePointsResponse?> build() async {
    return _fetch();
  }

  Future<void> setSearch(String value) async {
    _search = value.trim();
    _page = 1;
    // Don't set AsyncLoading here – keeps previous data visible and avoids
    // rebuilding the body so the search TextField keeps focus and keyboard stays.
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> changePage(int newPage) async {
    if (newPage < 1) return;
    _page = newPage;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<Map<String, String>> _authHeaders({bool jsonBody = false}) async {
    final storage = AuthLocalStorage();
    final token = await storage.getToken();
    final id = await storage.getUserId();
    final userType = await storage.getUserType();
    if (token == null || token.isEmpty) throw Exception('Token not found');
    if (id == null || id.isEmpty) throw Exception('User id not found');
    if (userType == null || userType.isEmpty) {
      throw Exception('User type not found');
    }
    return {
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      'token': token,
      'id': id,
      'user_type': userType,
    };
  }

  Future<RoutePointsResponse> _fetch() async {
    final url = VendorAPIController.vendorRoutePoints(
      search: _search.isEmpty ? null : _search,
      page: _page,
    );
    final res = await http.get(
      Uri.parse(url),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch route points: ${res.statusCode}');
    }

    try {
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        return RoutePointsResponse(
          items: [],
          pagination: RoutePointsPagination.empty(),
        );
      }

      final data = body['data'];
      if (data == null || data is! Map<String, dynamic>) {
        return RoutePointsResponse(
          items: [],
          pagination: RoutePointsPagination.empty(),
        );
      }

      return RoutePointsResponse.fromJson(data);
    } catch (e) {
      throw Exception('Invalid response: $e');
    }
  }

  bool _isSubscriptionLimit(dynamic body) {
    if (body is! Map) return false;
    final encoded = jsonEncode(body).toLowerCase();
    return encoded.contains('max_routes') ||
        encoded.contains('current_routes') ||
        encoded.contains('selected_route') ||
        encoded.contains('limit') ||
        encoded.contains('subscription');
  }

  String _errorMessage(dynamic body, String fallback) {
    if (body is Map) {
      final msg = body['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return fallback;
  }

  /// Opt-in: add this delivery route. POST then refresh list.
  Future<void> optIn(int deliveryChargeRouteId) async {
    final uri = Uri.parse(VendorAPIController.vendor_route_points);
    final res = await http.post(
      uri,
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({
        'delivery_charge_route_id': deliveryChargeRouteId,
      }),
    );

    if (res.statusCode != 201 && res.statusCode != 200) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = res.body;
      }
      if (res.statusCode == 422 && _isSubscriptionLimit(body)) {
        throw const RouteLimitException();
      }
      throw Exception(_errorMessage(body, 'Failed to add route'));
    }

    await refresh();
  }

  /// Opt-out: remove this delivery route. DELETE then refresh list.
  Future<void> optOut(int routePointId) async {
    final url = VendorAPIController.vendorRoutePointsDelete(routePointId);
    final res = await http.delete(
      Uri.parse(url),
      headers: await _authHeaders(),
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = res.body;
      }
      throw Exception(_errorMessage(body, 'Failed to remove route'));
    }

    await refresh();
  }
}
