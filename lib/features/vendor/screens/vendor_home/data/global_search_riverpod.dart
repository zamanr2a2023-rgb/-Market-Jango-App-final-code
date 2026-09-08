import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/get_user_type.dart';
import 'package:market_jango/core/models/global_search_model.dart';
import '../../../../../core/utils/get_token_sharedpefarens.dart';


final searchProvider =
FutureProvider.autoDispose.family<GlobalSearchResponse, String>((ref, query) async {
  // 1) খালি কুয়েরি: সোজা empty() রেসপন্স দিন
  if (query.trim().isEmpty) return GlobalSearchResponse.empty();

  // 2) Token optional for guest buyer browse; vendor search still prefers auth.
  final token = await ref.read(authTokenProvider.future);
  final userType = await ref.read(getUserTypeProvider.future);

  final vendorUrl = VendorAPIController.search_by_vendor(query);
  final buyerUrl = BuyerAPIController.buyer_search_product(query);
  final url = (userType == 'vendor') ? vendorUrl : buyerUrl;

  final resp = await http.get(
    Uri.parse(url),
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
    },
  );

  if (resp.statusCode == 200) {
    final decoded = jsonDecode(resp.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    return GlobalSearchResponse.fromJson(body);
  }

  // Guest-friendly: empty results instead of raw token errors.
  return GlobalSearchResponse.empty();
});