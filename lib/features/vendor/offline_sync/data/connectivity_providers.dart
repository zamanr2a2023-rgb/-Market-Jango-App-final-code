import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/core/constants/api_control/global_api.dart';

/// True when any non-none connectivity result is present.
/// Empty list = unknown → treat as online (avoid false "Offline" banners).
bool connectivityResultsOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) return true;
  return results.any((r) => r != ConnectivityResult.none);
}

/// TCP probe to configured API host — used when connectivity_plus is unsure.
Future<bool> probeApiReachable({
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    final uri = Uri.parse(api);
    final host = uri.host;
    if (host.isEmpty) return true;
    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' ? 443 : 80);
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// Final online decision: interface online → online; if interface says offline,
/// confirm with API host probe (fixes Wi‑Fi-on but banner-offline bugs).
Future<bool> resolveIsOnline([List<ConnectivityResult>? results]) async {
  List<ConnectivityResult> r;
  try {
    r = results ?? await Connectivity().checkConnectivity();
  } catch (_) {
    return probeApiReachable();
  }
  if (connectivityResultsOnline(r)) return true;
  return probeApiReachable();
}

final connectivityResultsProvider =
    StreamProvider.autoDispose<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();
  try {
    yield await connectivity.checkConnectivity();
  } catch (_) {
    yield const <ConnectivityResult>[];
  }
  await for (final results in connectivity.onConnectivityChanged) {
    yield results;
  }
});

/// Stream of reliable online flags (connectivity + API probe when needed).
final isOnlineStreamProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final connectivity = Connectivity();

  Future<bool> emitFor(List<ConnectivityResult> results) =>
      resolveIsOnline(results);

  try {
    yield await emitFor(await connectivity.checkConnectivity());
  } catch (_) {
    yield await probeApiReachable();
  }

  await for (final results in connectivity.onConnectivityChanged) {
    yield await emitFor(results);
  }
});

/// UI helper — defaults to **online** while loading / on error.
final isOnlineProvider = Provider.autoDispose<bool>((ref) {
  final async = ref.watch(isOnlineStreamProvider);
  return async.when(
    data: (v) => v,
    loading: () => true,
    error: (_, __) => true,
  );
});
