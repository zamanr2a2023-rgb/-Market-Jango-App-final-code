import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/common_api.dart';
import 'package:market_jango/core/localization/translation_repository.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';

Future<AppTranslations> _fetchTranslations(Ref ref) async {
  try {
    final token = await ref.read(authTokenProvider.future) ?? '';

    final uri = Uri.parse(CommonAPIController.translations);

    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token.isNotEmpty) 'token': token,
      },
    );

    if (res.statusCode != 200) {
      // Guest / unauthenticated: use English fallbacks instead of raw keys.
      return AppTranslations.empty();
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return AppTranslations.fromJson(map);
  } catch (_) {
    return AppTranslations.empty();
  }
}

/// AsyncNotifier যেন refresh করতে পারি
class AppTranslationsNotifier extends AsyncNotifier<AppTranslations> {
  @override
  Future<AppTranslations> build() async {
    return _fetchTranslations(ref);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchTranslations(ref));
  }

  /// helper – state এর উপরে safe get
  String t(String key, {String? fallback}) {
    final current = state;
    return current.maybeWhen(
      data: (tr) => tr.get(key, fallback: fallback),
      orElse: () => AppTranslations.empty().get(key, fallback: fallback),
    );
  }
}

/// main provider
final appTranslationsProvider =
    AsyncNotifierProvider<AppTranslationsNotifier, AppTranslations>(
      AppTranslationsNotifier.new,
    );
