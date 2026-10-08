import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/auth_api.dart';
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/transport_module_access.dart';

Map<String, dynamic> _decodeObj(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw const FormatException('Invalid JSON');
}

String _formatApiError(Map<String, dynamic> j, int code) {
  final parts = <String>[];
  final msg = j['message']?.toString();
  if (msg != null && msg.isNotEmpty) parts.add(msg);
  final errors = j['errors'];
  if (errors is Map) {
    for (final e in errors.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v is List) {
        for (final item in v) {
          parts.add('• $k: $item');
        }
      } else if (v != null) {
        parts.add('• $k: $v');
      }
    }
  }
  if (parts.isEmpty) return 'Request failed (HTTP $code)';
  return parts.join('\n');
}

Future<Map<String, String>> _buyerAuthHeaders() async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final id = await storage.getUserId();
  final userType = await storage.getUserType();
  final userJson = await storage.getUserJson();
  final email = userJson?['email']?.toString();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (id != null && id.isNotEmpty) 'id': id,
    if (userType != null && userType.isNotEmpty) 'user_type': userType,
    if (email != null && email.isNotEmpty) 'email': email,
  };
}

/// Merges user / modules / transport from API into persisted login JSON.
Future<void> applyUserSessionPatch(Map<String, dynamic> patch) async {
  if (patch.isEmpty) return;
  await AuthLocalStorage().mergeUserJson(patch);
}

void _mergeDetailPayloadIntoPatch(
  Map<String, dynamic> data,
  Map<String, dynamic> patch,
) {
  final user = data['user'];
  if (user is Map<String, dynamic>) {
    patch.addAll(user);
  }
  if (data['modules'] is Map) {
    patch['modules'] = data['modules'];
  }
  if (data.containsKey('transport')) {
    patch['transport'] = data['transport'];
  }
  if (data['transports'] != null) {
    patch['transports'] = data['transports'];
  }
}

/// `GET /api/user/detail` (POLISH) with fallback to `user/show`.
Future<void> refreshLoggedInUserSession() async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final userId = await storage.getUserId();
  if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
    return;
  }

  final headers = {
    'Accept': 'application/json',
    'token': token,
    'id': userId,
  };

  http.Response? res;
  try {
    res = await http.get(
      Uri.parse(AuthAPIController.userDetail(id: userId)),
      headers: headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      res = null;
    }
  } catch (_) {
    res = null;
  }

  if (res == null) {
    res = await http.get(
      Uri.parse('${AuthAPIController.user_show}?id=$userId'),
      headers: headers,
    );
  }

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Could not refresh profile (HTTP ${res.statusCode})');
  }

  final top = _decodeObj(res.body);
  final st = top['status']?.toString().toLowerCase();
  if (st == 'error' || st == 'fail' || st == 'failed') {
    throw Exception(_formatApiError(top, res.statusCode));
  }

  final data = top['data'];
  if (data is! Map<String, dynamic>) return;

  final patch = <String, dynamic>{};
  _mergeDetailPayloadIntoPatch(data, patch);
  await applyUserSessionPatch(patch);
}

/// `POST /api/buyer/transport/enable` then refresh session.
Future<void> enableBuyerTransportModule() async {
  final headers = await _buyerAuthHeaders();
  final res = await http.post(
    Uri.parse(BuyerAPIController.buyerTransportEnable),
    headers: headers,
    body: jsonEncode(<String, dynamic>{}),
  );

  Map<String, dynamic> top;
  try {
    top = _decodeObj(res.body);
  } catch (_) {
    throw Exception('Enable transport failed (HTTP ${res.statusCode})');
  }

  final ok = res.statusCode >= 200 &&
      res.statusCode < 300 &&
      top['status']?.toString().toLowerCase() != 'error' &&
      top['status']?.toString().toLowerCase() != 'fail' &&
      top['status']?.toString().toLowerCase() != 'failed';

  if (!ok) {
    throw Exception(_formatApiError(top, res.statusCode));
  }

  final data = top['data'];
  if (data is Map<String, dynamic>) {
    final patch = <String, dynamic>{};
    _mergeDetailPayloadIntoPatch(data, patch);
    if (data['modules'] is Map) {
      patch['modules'] = data['modules'];
    }
    if (patch.isNotEmpty) {
      await applyUserSessionPatch(patch);
    }
  }

  await refreshLoggedInUserSession();
}

final buyerTransportModuleRefreshProvider = StateProvider<int>((ref) => 0);

/// Whether the logged-in user can open the transport module (buyer w/ module or transport role).
final buyerTransportModuleProvider = FutureProvider<bool>((ref) async {
  ref.watch(buyerTransportModuleRefreshProvider);
  final json = await AuthLocalStorage().getUserJson();
  return canUseTransportModule(json);
});

final buyerMayEnableTransportProvider = FutureProvider<bool>((ref) async {
  ref.watch(buyerTransportModuleRefreshProvider);
  final json = await AuthLocalStorage().getUserJson();
  return buyerMayEnableTransport(json);
});

void invalidateBuyerTransportModule(WidgetRef ref) {
  ref.read(buyerTransportModuleRefreshProvider.notifier).state++;
}
