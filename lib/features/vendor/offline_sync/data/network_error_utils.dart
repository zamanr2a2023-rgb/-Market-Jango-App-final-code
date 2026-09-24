import 'package:market_jango/features/vendor/offline_sync/data/connectivity_providers.dart';

/// True if [error] looks like a network / socket failure.
bool isNetworkError(Object? error) {
  final s = error?.toString().toLowerCase() ?? '';
  return s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('network is unreachable') ||
      s.contains('failed host lookup') ||
      s.contains('connection failed') ||
      s.contains('connection refused') ||
      s.contains('timed out') ||
      s.contains('network_error');
}

String friendlyNetworkErrorMessage(Object? error, {String? fallback}) {
  if (isNetworkError(error)) {
    return 'You are offline. Connect to the internet to load this data.';
  }
  final raw = error?.toString().replaceFirst('Exception: ', '') ?? '';
  if (raw.isEmpty) return fallback ?? 'Something went wrong';
  if (raw.length > 160) return '${raw.substring(0, 160)}…';
  return raw;
}

Future<bool> checkDeviceOnline() => resolveIsOnline();
