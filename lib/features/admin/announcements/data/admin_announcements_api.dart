import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/notification_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/admin/announcements/model/admin_announcement_model.dart';

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
    if (id != null && id.isNotEmpty) 'id': id,
    // STEP_11 Postman: `user_type: admin`.
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

class AdminAnnouncementsApi {
  AdminAnnouncementsApi._();
  static final AdminAnnouncementsApi instance = AdminAnnouncementsApi._();

  /// `POST /api/admin/announcements`
  Future<String> create(AdminAnnouncementRequest request) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(NotificationAPIController.adminAnnouncements),
      headers: headers,
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_errorMessage(res.body, res.statusCode));
    }
    try {
      final top = jsonDecode(res.body);
      if (top is Map<String, dynamic>) {
        final st = top['status']?.toString().toLowerCase();
        if (st == 'error' || st == 'fail' || st == 'failed') {
          throw Exception(top['message']?.toString() ?? 'Request failed');
        }
        final msg = top['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) return msg;
      }
    } on FormatException {
      // non-JSON success
    }
    return 'Announcement sent';
  }
}

final adminAnnouncementSubmittingProvider =
    StateProvider.autoDispose<bool>((ref) => false);
