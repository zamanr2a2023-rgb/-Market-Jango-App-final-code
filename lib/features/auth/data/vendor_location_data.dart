import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/auth_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

/// Location lists for vendor Create Store (zone → state → town).
/// Uses existing delivery-charge location GET APIs.
List<String> _parseLocationItems(dynamic body) {
  if (body is! Map) return const [];
  final map = Map<String, dynamic>.from(body);
  dynamic raw = map['data'];
  if (raw is Map && raw['items'] is List) {
    raw = raw['items'];
  } else if (raw is List) {
    // data is already a list
  } else if (map['items'] is List) {
    raw = map['items'];
  } else {
    return const [];
  }
  if (raw is! List) return const [];
  return raw
      .map((e) {
        if (e is String) return e.trim();
        if (e is Map) {
          return (e['name'] ?? e['title'] ?? e['zone'] ?? e['state'] ?? e['town'])
              ?.toString()
              .trim() ??
              '';
        }
        return e?.toString().trim() ?? '';
      })
      .where((e) => e.isNotEmpty && e != 'null')
      .toList();
}

Future<String> _authToken() async {
  final token = await AuthLocalStorage().getToken();
  if (token == null || token.isEmpty) {
    throw Exception('Not authenticated');
  }
  return token;
}

Future<List<String>> _getLocationList(String url) async {
  final token = await _authToken();
  final res = await http.get(
    Uri.parse(url),
    headers: {'Accept': 'application/json', 'token': token},
  );
  final decoded = jsonDecode(res.body);
  if (res.statusCode != 200) {
    final msg = decoded is Map
        ? (decoded['message']?.toString() ?? 'Failed to load locations')
        : 'Failed to load locations (${res.statusCode})';
    throw Exception(msg);
  }
  return _parseLocationItems(decoded);
}

/// `GET /api/buyer/delivery-charge-locations/zones`
final vendorRegisterZonesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return _getLocationList(AuthAPIController.registerLocationZones);
});

/// `GET /api/buyer/delivery-charge-locations/states?zone=`
final vendorRegisterStatesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, zone) async {
  final z = zone.trim();
  if (z.isEmpty) return const [];
  return _getLocationList(AuthAPIController.registerLocationStates(zone: z));
});

/// `GET /api/buyer/delivery-charge-locations/towns?zone_name=`
final vendorRegisterTownsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, zone) async {
  final z = zone.trim();
  if (z.isEmpty) return const [];
  return _getLocationList(
    AuthAPIController.registerLocationTowns(zoneName: z),
  );
});

final selectedVendorZoneProvider = StateProvider<String?>((ref) => null);
final selectedVendorStateProvider = StateProvider<String?>((ref) => null);
final selectedVendorTownProvider = StateProvider<String?>((ref) => null);
