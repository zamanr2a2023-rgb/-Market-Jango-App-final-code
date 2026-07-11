import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/driver_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/vendor/screens/vendor_followers/model/vendor_followers_model.dart';

Map<String, dynamic> _decodeMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw Exception('Invalid JSON');
}

Map<String, dynamic>? _data(Map<String, dynamic> top) {
  final d = top['data'];
  if (d is Map<String, dynamic>) return d;
  return null;
}

String _message(Map<String, dynamic> top) =>
    top['message']?.toString() ?? 'Request failed';

Future<Map<String, String>> _headers() async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final id = await storage.getUserId();
  final userType = await storage.getUserType();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (id != null && id.isNotEmpty) 'id': id,
    if (userType != null && userType.isNotEmpty) 'user_type': userType,
  };
}

class DriverFollowersApi {
  DriverFollowersApi._();
  static final DriverFollowersApi instance = DriverFollowersApi._();

  Future<VendorFollowersResult> fetchFollowers({int page = 1}) async {
    final headers = await _headers();
    final uri = Uri.parse(DriverAPIController.driverFollowers(page: page));
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      try {
        throw Exception(_message(_decodeMap(res.body)));
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    final top = _decodeMap(res.body);
    return VendorFollowersResult.fromJson(_data(top));
  }
}

final driverFollowersProvider =
    FutureProvider.autoDispose<VendorFollowersResult>((ref) async {
  return DriverFollowersApi.instance.fetchFollowers();
});

final driverFollowersCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final result = await ref.watch(driverFollowersProvider.future);
  return result.followersCount;
});
