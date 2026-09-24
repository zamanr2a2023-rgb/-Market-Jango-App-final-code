import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/notification_api.dart';
import 'package:market_jango/core/screen/notification_preferences/model/notification_preferences_model.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

Future<Map<String, String>> _headers() async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final id = await storage.getUserId();
  final userType = await storage.getUserType();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (token != null && token.isNotEmpty)
      'Authorization': token.toLowerCase().startsWith('bearer ')
          ? token
          : 'Bearer $token',
    // STEP_11 Postman: `id` header required.
    if (id != null && id.isNotEmpty) 'id': id,
    if (userType != null && userType.isNotEmpty) 'user_type': userType,
  };
}

String _errorMessage(String body, int code) {
  try {
    final top = jsonDecode(body);
    if (top is Map<String, dynamic>) {
      final msg = top['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
  } catch (_) {}
  return 'HTTP $code';
}

class NotificationPreferencesApi {
  NotificationPreferencesApi._();
  static final NotificationPreferencesApi instance =
      NotificationPreferencesApi._();

  /// Seed from logged-in user JSON (`notify_*` when present). No GET in STEP_11.
  Future<NotificationPreferences> loadCurrent() async {
    final user = await AuthLocalStorage().getUserJson();
    return NotificationPreferences.fromMap(user);
  }

  /// `PUT /api/notification/preferences`
  Future<String> update(NotificationPreferences prefs) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse(NotificationAPIController.notificationPreferences),
      headers: headers,
      body: jsonEncode(prefs.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res.body, res.statusCode));
    }

    String message = 'Preferences saved';
    try {
      final top = jsonDecode(res.body);
      if (top is Map<String, dynamic>) {
        final st = top['status']?.toString().toLowerCase();
        if (st == 'error' || st == 'fail' || st == 'failed') {
          throw Exception(top['message']?.toString() ?? 'Request failed');
        }
        final msg = top['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) message = msg;

        // Prefer returned data fields when present; otherwise keep request values.
        final data = top['data'];
        if (data is Map<String, dynamic>) {
          final parsed = NotificationPreferences.fromMap(data, fallback: prefs);
          await AuthLocalStorage().mergeUserJson(parsed.toJson());
          return message;
        }
      }
    } on FormatException {
      // non-JSON success
    }

    await AuthLocalStorage().mergeUserJson(prefs.toJson());
    return message;
  }
}

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
  return NotificationPreferencesApi.instance.loadCurrent();
});
