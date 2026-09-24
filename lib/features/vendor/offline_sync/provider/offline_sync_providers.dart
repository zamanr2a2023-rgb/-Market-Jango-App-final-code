import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sale_queue_store.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sync_manager.dart';
import 'package:market_jango/features/vendor/offline_sync/model/offline_sale_queue_item.dart';

/// Bumps when queue changes so UI refreshes pending count.
final offlineQueueTickProvider = StateProvider<int>((ref) => 0);

void bumpOfflineQueue(WidgetRef ref) {
  ref.read(offlineQueueTickProvider.notifier).state++;
}

final offlinePendingCountProvider = Provider<int>((ref) {
  ref.watch(offlineQueueTickProvider);
  return OfflineSaleQueueStore.instance.pendingCount;
});

final offlineQueueItemsProvider = Provider<List<OfflineSaleQueueItem>>((ref) {
  ref.watch(offlineQueueTickProvider);
  return OfflineSaleQueueStore.instance.all();
});

final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  return OfflineSyncManager.instance;
});
