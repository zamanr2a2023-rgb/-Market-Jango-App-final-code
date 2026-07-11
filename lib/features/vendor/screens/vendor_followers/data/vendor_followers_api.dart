import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_followers/model/vendor_followers_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

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

class VendorFollowersApi {
  VendorFollowersApi._();
  static final VendorFollowersApi instance = VendorFollowersApi._();

  Future<VendorFollowersResult> fetchFollowers({int page = 1}) async {
    final headers = await vendorOrderApiHeaders();
    final uri = Uri.parse(VendorAPIController.vendorFollowers(page: page));
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

final vendorFollowersProvider =
    FutureProvider.autoDispose<VendorFollowersResult>((ref) async {
  return VendorFollowersApi.instance.fetchFollowers();
});

final vendorFollowersCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final result = await ref.watch(vendorFollowersProvider.future);
  return result.followersCount;
});
