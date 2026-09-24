import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_gate.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/buyer/model/buyer_home_model.dart';

/// Resolved numeric `zone_id` for guest home filtering (STEP_05).
/// Logged-in buyers rely on backend `ship_zone` via auth headers.
final buyerHomeZoneIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  final storage = AuthLocalStorage();
  final loggedIn = await AuthGate.isLoggedIn();
  if (loggedIn) {
    // Logged-in: backend uses ship_zone from profile; optional guest id unused.
    return null;
  }
  return storage.getGuestZoneId();
});

/// `GET /api/buyer/home` — guest (optional zone_id) or logged-in (token + id + user_type).
final buyerHomeProvider =
    FutureProvider.autoDispose<BuyerHomeResponse>((ref) async {
  final zoneId = await ref.watch(buyerHomeZoneIdProvider.future);
  final loggedIn = await AuthGate.isLoggedIn();
  final storage = AuthLocalStorage();

  String? token;
  String? userId;
  String? userType;
  if (loggedIn) {
    token = await storage.getLoginToken();
    userId = await storage.getUserId();
    userType = await storage.getUserType();
  }

  final res = await http.get(
    Uri.parse(BuyerAPIController.buyerHome(zoneId: zoneId)),
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
      if (userId != null && userId.isNotEmpty) 'id': userId,
      if (userType != null && userType.isNotEmpty) 'user_type': userType,
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
