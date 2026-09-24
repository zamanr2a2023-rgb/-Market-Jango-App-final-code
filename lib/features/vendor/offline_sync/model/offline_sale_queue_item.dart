/// Sync status for a queued offline sale (STEP_13).
enum OfflineSyncStatus {
  pending,
  syncing,
  completed,
  failed,
}

extension OfflineSyncStatusX on OfflineSyncStatus {
  String get wire {
    switch (this) {
      case OfflineSyncStatus.pending:
        return 'pending';
      case OfflineSyncStatus.syncing:
        return 'syncing';
      case OfflineSyncStatus.completed:
        return 'completed';
      case OfflineSyncStatus.failed:
        return 'failed';
    }
  }

  static OfflineSyncStatus fromWire(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'syncing':
        return OfflineSyncStatus.syncing;
      case 'completed':
        return OfflineSyncStatus.completed;
      case 'failed':
        return OfflineSyncStatus.failed;
      case 'pending':
      default:
        return OfflineSyncStatus.pending;
    }
  }
}

/// Local queue row for `POST /api/sync/offline`.
class OfflineSaleQueueItem {
  final String localId;
  final String idempotencyKey;
  final String action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final OfflineSyncStatus syncStatus;
  final String? lastError;

  const OfflineSaleQueueItem({
    required this.localId,
    required this.idempotencyKey,
    required this.action,
    required this.payload,
    required this.createdAt,
    required this.syncStatus,
    this.lastError,
  });

  bool get isPendingLike =>
      syncStatus == OfflineSyncStatus.pending ||
      syncStatus == OfflineSyncStatus.failed;

  OfflineSaleQueueItem copyWith({
    OfflineSyncStatus? syncStatus,
    String? lastError,
    bool clearError = false,
  }) {
    return OfflineSaleQueueItem(
      localId: localId,
      idempotencyKey: idempotencyKey,
      action: action,
      payload: payload,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toHiveMap() => {
        'local_id': localId,
        'idempotency_key': idempotencyKey,
        'action': action,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'sync_status': syncStatus.wire,
        'last_error': lastError,
      };

  factory OfflineSaleQueueItem.fromHiveMap(Map map) {
    final payloadRaw = map['payload'];
    final payload = payloadRaw is Map
        ? Map<String, dynamic>.from(payloadRaw)
        : <String, dynamic>{};
    return OfflineSaleQueueItem(
      localId: map['local_id']?.toString() ?? '',
      idempotencyKey: map['idempotency_key']?.toString() ?? '',
      action: map['action']?.toString() ?? 'sale',
      payload: payload,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      syncStatus: OfflineSyncStatusX.fromWire(map['sync_status']?.toString()),
      lastError: map['last_error']?.toString(),
    );
  }

  /// Body for `POST /api/sync/offline`.
  Map<String, dynamic> toSyncRequestJson() => {
        'idempotency_key': idempotencyKey,
        'action': action,
        'payload': payload,
      };
}
