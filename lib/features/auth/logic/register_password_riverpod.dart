import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

final registerPasswordProvider =
    StateNotifierProvider<RegisterPasswordNotifier, AsyncValue<bool>>(
        (ref) => RegisterPasswordNotifier());

class RegisterPasswordNotifier extends StateNotifier<AsyncValue<bool>> {
  RegisterPasswordNotifier() : super(const AsyncValue.data(false));

  Future<void> setPassword({
    required String url,
    required String password,
    required String confirmPassword,
    String? shipZone,
  }) async {
    state = const AsyncValue.loading();

    try {
      final authStorage = AuthLocalStorage();
      final token = await authStorage.getToken();
      final userId = await authStorage.getUserId();
      final userType = await authStorage.getUserType();

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'token': token,
        if (userId != null && userId.isNotEmpty) 'id': userId,
        if (userType != null && userType.isNotEmpty) 'user_type': userType,
      });

      request.fields['password'] = password;
      request.fields['password_confirmation'] = confirmPassword;
      final zone = shipZone?.trim() ?? '';
      if (zone.isNotEmpty) {
        request.fields['ship_zone'] = zone;
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();
      Logger().i("🔐 Password Register Response: $body");

      final json = jsonDecode(body);

      if ((response.statusCode == 200) && json['status'] == 'success') {
        if (zone.isNotEmpty) {
          await authStorage.saveShipZone(zone);
        }
        state = const AsyncValue.data(true);
      } else {
        throw Exception(json['message'] ?? 'Password setup failed');
      }
    } catch (e, st) {
      Logger().e("⛔ Password Error: $e");
      state = AsyncValue.error(e, st);
    }
  }
}
