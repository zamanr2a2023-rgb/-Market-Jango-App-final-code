import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

/// Zone option for registration / guest banner filter (STEP_05).
class VisibilityZoneOption {
  final int? id;
  final String name;

  const VisibilityZoneOption({this.id, required this.name});

  String get label => name;
}

List<VisibilityZoneOption> parseVisibilityZoneOptions(dynamic body) {
  if (body is! Map) return const [];
  final map = Map<String, dynamic>.from(body);
  dynamic raw = map['data'];
  if (raw is Map && raw['items'] is List) {
    raw = raw['items'];
  } else if (raw is Map && raw['zones'] is List) {
    raw = raw['zones'];
  } else if (map['items'] is List) {
    raw = map['items'];
  } else if (map['zones'] is List) {
    raw = map['zones'];
  }

  if (raw is! List) return const [];

  final out = <VisibilityZoneOption>[];
  for (final e in raw) {
    if (e is String) {
      final n = e.trim();
      if (n.isNotEmpty && n != 'null') {
        out.add(VisibilityZoneOption(name: n));
      }
      continue;
    }
    if (e is Map) {
      final m = Map<String, dynamic>.from(e);
      final name = (m['name'] ?? m['zone'] ?? m['zone_name'] ?? m['title'])
              ?.toString()
              .trim() ??
          '';
      if (name.isEmpty || name == 'null') continue;
      final idRaw = m['id'] ?? m['zone_id'];
      int? id;
      if (idRaw is int) {
        id = idRaw;
      } else if (idRaw != null) {
        id = int.tryParse(idRaw.toString());
      }
      out.add(VisibilityZoneOption(id: id, name: name));
    }
  }
  return out;
}

/// STEP_05 — `GET /api/buyer/visibility-locations/zones` (register / guest).
final visibilityLocationsZonesProvider =
    FutureProvider.autoDispose<List<VisibilityZoneOption>>((ref) async {
  final token = await AuthLocalStorage().getToken();
  final uri = Uri.parse(BuyerAPIController.visibilityLocationsZones);
  final res = await http.get(
    uri,
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
    },
  );

  final rawBody = res.body.trimLeft();
  if (rawBody.startsWith('<')) {
    // HTML error page — treat as empty so UI shows manual zone entry.
    return const [];
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(res.body);
  } catch (_) {
    return const [];
  }

  if (res.statusCode != 200) {
    return const [];
  }

  return parseVisibilityZoneOptions(decoded);
});
