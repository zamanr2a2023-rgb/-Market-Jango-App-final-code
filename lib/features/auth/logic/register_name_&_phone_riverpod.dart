import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/phone_e164_utils.dart';
import 'package:market_jango/features/auth/logic/otp_screen_snack_provider.dart';

/// StateNotifier for POST actions that use token
class PostNotifier extends StateNotifier<AsyncValue<bool>> {
  PostNotifier(this._ref) : super(const AsyncData(false));

  final Ref _ref;

  static bool _isRegisterPhoneUrl(String url) =>
      url.contains('register-phone');

  static String? _extractOtp(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map) return null;
    final otp = data['otp'];
    if (otp == null) return null;
    return otp.toString();
  }

  Future<void> send({
    required String keyname,
    required String value,
    required String url,
    required BuildContext context,
  }) async {
    state = const AsyncLoading();

    try {
      final authStorage = AuthLocalStorage();
      final token = await authStorage.getToken();
      if (token == null || token.isEmpty) throw 'Missing auth token';

      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'token': token,
        },
        body: jsonEncode({keyname: value}),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw parseApiErrorMessage(res.body, res.statusCode);
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw 'Invalid response';
      }

      final j = decoded;
      final status = (j['status'] ?? '').toString().toLowerCase();
      final message = (j['message'] ?? '').toString();
      final msgLower = message.toLowerCase();

      Logger().i('✅ POST Response: $j');

      if (status != 'success') {
        throw message.isNotEmpty ? message : 'Request failed';
      }

      if (_isRegisterPhoneUrl(url)) {
        _ref.read(otpScreenSnackProvider.notifier).state = null;

        if (msgLower.contains('debug mode') && msgLower.contains('otp')) {
          final otp = _extractOtp(j);
          _ref.read(otpScreenSnackProvider.notifier).state = OtpScreenSnack(
            title: 'Verification code',
            message: otp != null
                ? 'Your OTP: $otp'
                : message,
          );
        } else if (msgLower == 'otp sent to phone') {
          _ref.read(otpScreenSnackProvider.notifier).state = const OtpScreenSnack(
            title: 'Success',
            message: 'OTP sent to phone',
          );
        }
      }

      state = const AsyncData(true);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

/// Provider
final postProvider =
    StateNotifierProvider<PostNotifier, AsyncValue<bool>>(
  (ref) => PostNotifier(ref),
);
