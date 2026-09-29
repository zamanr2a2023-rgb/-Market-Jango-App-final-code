import 'package:market_jango/core/utils/auth_local_storage.dart';

/// Multipart register requests (`vendor` / `driver`) — no fixed `Content-Type`.
Future<Map<String, String>> registerMultipartHeaders({
  required String userType,
}) async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final userId = await storage.getUserId();
  final userJson = await storage.getUserJson();
  final email = userJson?['email']?.toString() ?? '';

  return {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (userId != null && userId.isNotEmpty) 'id': userId,
    'user_type': userType,
    if (email.isNotEmpty) 'email': email,
  };
}
