import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/screen/following/model/following_model.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/get_user_type.dart';

class FollowingApi {
  FollowingApi._();
  static final FollowingApi instance = FollowingApi._();

  Future<FollowingListResult> fetchMyFollowing({int page = 1}) async {
    final auth = AuthLocalStorage();
    final token = await auth.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in');
    }

    final uri = Uri.parse(BuyerAPIController.myFollowing(page: page));
    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'token': token,
      },
    );

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response');
    }

    if (res.statusCode != 200) {
      throw Exception(
        decoded['message']?.toString() ?? 'Failed to load following list',
      );
    }

    final data = decoded['data'];
    return FollowingListResult.fromJson(
      data is Map<String, dynamic> ? data : null,
    );
  }
}

final myFollowingProvider =
    FutureProvider.autoDispose<FollowingListResult>((ref) async {
  final result = await FollowingApi.instance.fetchMyFollowing();
  final userType = await ref.watch(getUserTypeProvider.future);
  return result.forUserType(userType);
});

final myFollowingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final result = await ref.watch(myFollowingProvider.future);
  return result.total;
});
