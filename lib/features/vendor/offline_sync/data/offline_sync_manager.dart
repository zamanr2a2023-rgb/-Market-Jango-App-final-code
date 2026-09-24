import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:market_jango/features/vendor/offline_sync/data/connectivity_providers.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sale_queue_store.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sync_api.dart';
import 'package:market_jango/features/vendor/offline_sync/model/offline_sale_queue_item.dart';

typedef OfflineSyncListener = void Function();

/// Flushes pending offline sales one-by-one (STEP_13).
///
/// Triggers: app startup, internet reconnect. One pass per trigger — no
/// infinite retry loop inside a single run.
class OfflineSyncManager {
  OfflineSyncManager._();
  static final OfflineSyncManager instance = OfflineSyncManager._();

  final _store = OfflineSaleQueueStore.instance;
  final _api = OfflineSyncApi.instance;

  bool _running = false;
  bool _started = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final List<OfflineSyncListener> _listeners = [];

  void addListener(OfflineSyncListener l) => _listeners.add(l);
  void removeListener(OfflineSyncListener l) => _listeners.remove(l);
  void _notify() {
    for (final l in List.of(_listeners)) {
      try {
        l();
      } catch (_) {}
    }
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _store.init();

    // Startup sync if online.
    unawaited(_syncIfOnline());

    try {
      _sub = Connectivity().onConnectivityChanged.listen((results) async {
        if (await resolveIsOnline(results)) {
          unawaited(syncPending());
        }
      });
    } catch (e) {
      // MissingPluginException after hot reload — needs full rebuild.
      debugPrint('OfflineSyncManager connectivity listen: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _syncIfOnline() async {
    try {
      if (await resolveIsOnline()) {
        await syncPending();
      }
    } catch (e) {
      debugPrint('OfflineSyncManager startup check: $e');
    }
  }

  /// Process pending/failed items once. Reuses existing idempotency keys.
  Future<void> syncPending() async {
    if (_running) return;
    _running = true;
    try {
      await _store.init();
      final batch = _store.pendingOrFailed();
      for (final item in batch) {
        final marked = item.copyWith(
          syncStatus: OfflineSyncStatus.syncing,
          clearError: true,
        );
        await _store.update(marked);
        _notify();
        try {
          await _api.syncSale(marked);
          await _store.remove(marked.localId);
        } catch (e) {
          await _store.update(
            marked.copyWith(
              syncStatus: OfflineSyncStatus.failed,
              lastError: e.toString().replaceFirst('Exception: ', ''),
            ),
          );
        }
        _notify();
      }
    } finally {
      _running = false;
      _notify();
    }
  }
}
