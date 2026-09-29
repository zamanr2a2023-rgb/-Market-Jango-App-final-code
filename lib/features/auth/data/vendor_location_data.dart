import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/auth_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

/// Location lists for vendor Create Store & driver register (zone → state → town).
/// `GET /api/buyer/visibility-locations/*`
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

Future<List<String>> _getLocationList(String url) async {
  final token = await AuthLocalStorage().getToken();
  final res = await http.get(
    Uri.parse(url),
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
    },
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

/// Zone + state key for town list provider.
class VendorRegisterTownParams {
  const VendorRegisterTownParams({required this.zone, required this.state});

  final String zone;
  final String state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VendorRegisterTownParams &&
          other.zone == zone &&
          other.state == state;

  @override
  int get hashCode => Object.hash(zone, state);
}

/// `GET /api/buyer/visibility-locations/zones`
final vendorRegisterZonesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  return _getLocationList(AuthAPIController.registerLocationZones);
});

/// `GET /api/buyer/visibility-locations/states?zone=`
final vendorRegisterStatesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, zone) async {
  final z = zone.trim();
  if (z.isEmpty) return const [];
  return _getLocationList(AuthAPIController.registerLocationStates(zone: z));
});

/// `GET /api/buyer/visibility-locations/towns?zone=&state=`
final vendorRegisterTownsProvider = FutureProvider.autoDispose
    .family<List<String>, VendorRegisterTownParams>((ref, params) async {
  final z = params.zone.trim();
  final s = params.state.trim();
  if (z.isEmpty || s.isEmpty) return const [];
  return _getLocationList(
    AuthAPIController.registerLocationTowns(zone: z, state: s),
  );
});

final selectedVendorZoneProvider = StateProvider<String?>((ref) => null);
final selectedVendorStateProvider = StateProvider<String?>((ref) => null);
final selectedVendorTownProvider = StateProvider<String?>((ref) => null);
