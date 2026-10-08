import 'package:market_jango/core/utils/auth_local_storage.dart';

Future<Map<String, String>> buyerAuthHeaders({
  bool includeJsonContentType = false,
}) async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final id = await storage.getUserId();
  final userType = await storage.getUserType();
  final userJson = await storage.getUserJson();
  final email = userJson?['email']?.toString();
  return {
    'Accept': 'application/json',
    if (includeJsonContentType) 'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (id != null && id.isNotEmpty) 'id': id,
    if (userType != null && userType.isNotEmpty) 'user_type': userType,
    if (email != null && email.isNotEmpty) 'email': email,
  };
}
