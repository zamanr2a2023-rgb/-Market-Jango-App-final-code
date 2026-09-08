import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/vendor/screens/vendor_sale_platform/model/vendor_dashboard_analytics_model.dart';

/// Soft-fail provider: null on error so income KPIs stay intact.
final vendorDashboardAnalyticsProvider =
    FutureProvider.autoDispose<VendorDashboardAnalytics?>((ref) async {
  try {
    final token = await AuthLocalStorage().getToken();
    final res = await http.get(
      Uri.parse(VendorAPIController.vendorDashboardAnalytics),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );

    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;

    final st = decoded['status']?.toString().toLowerCase();
    if (st == 'failed' || st == 'error') return null;

    return VendorDashboardAnalytics.fromJson(decoded);
  } catch (_) {
    return null;
  }
});
