import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_gate.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/buyer/model/buyer_home_model.dart';

/// `GET /api/buyer/home` — guest (no token) or logged-in (login token).
final buyerHomeProvider =
    FutureProvider.autoDispose<BuyerHomeResponse>((ref) async {
  final loggedIn = await AuthGate.isLoggedIn();
  String? token;
  if (loggedIn) {
    token = await AuthLocalStorage().getLoginToken();
  }

  final res = await http.get(
    Uri.parse(BuyerAPIController.buyerHome),
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to load home (${res.statusCode})');
  }

  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw Exception('Invalid home response');
  }
  final st = decoded['status']?.toString().toLowerCase();
  if (st == 'failed' || st == 'error') {
    throw Exception(decoded['message']?.toString() ?? 'Failed to load home');
  }
  return BuyerHomeResponse.fromJson(decoded);
});
