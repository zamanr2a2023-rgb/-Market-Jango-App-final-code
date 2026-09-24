import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:market_jango/features/vendor/offline_sync/model/offline_sale_queue_item.dart';

/// Hive-backed offline sale queue + POS catalog/cart draft (STEP_13).
class OfflineSaleQueueStore {
  OfflineSaleQueueStore._();
  static final OfflineSaleQueueStore instance = OfflineSaleQueueStore._();

  static const _boxName = 'offline_sale_queue_v1';
  static const _catalogBoxName = 'offline_pos_catalog_v1';
  static const _cartBoxName = 'offline_pos_cart_v1';
  static const _catalogKey = 'products';
  static const _cartKey = 'draft';

  Box? _box;
  Box? _catalogBox;
  Box? _cartBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _catalogBox = await Hive.openBox(_catalogBoxName);
    _cartBox = await Hive.openBox(_cartBoxName);
    _initialized = true;
  }

  Box get _queue {
    final b = _box;
    if (b == null) {
      throw StateError('OfflineSaleQueueStore not initialized');
    }
    return b;
  }

  String newLocalId() =>
      'local_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

  /// Stable key for a sale — reused on retry (never regenerate).
  String newIdempotencyKey() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(1 << 28);
    return 'sale_${ts}_$r';
  }

  Future<OfflineSaleQueueItem> enqueueSale({
    required int productId,
    required int quantity,
  }) async {
    await init();
    final item = OfflineSaleQueueItem(
      localId: newLocalId(),
      idempotencyKey: newIdempotencyKey(),
      action: 'sale',
      payload: {
        'product_id': productId,
        'quantity': quantity,
      },
      createdAt: DateTime.now(),
      syncStatus: OfflineSyncStatus.pending,
    );
    await _queue.put(item.localId, item.toHiveMap());
    return item;
  }

  Future<List<OfflineSaleQueueItem>> enqueueSales(
    List<Map<String, int>> items,
  ) async {
    final out = <OfflineSaleQueueItem>[];
    for (final row in items) {
      final pid = row['product_id'] ?? 0;
      final qty = row['quantity'] ?? 0;
      if (pid <= 0 || qty <= 0) continue;
      out.add(await enqueueSale(productId: pid, quantity: qty));
    }
    return out;
  }

  List<OfflineSaleQueueItem> all() {
    if (_box == null) return const [];
    return _queue.values
        .whereType<Map>()
        .map((e) => OfflineSaleQueueItem.fromHiveMap(Map.from(e)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<OfflineSaleQueueItem> pendingOrFailed() =>
      all().where((e) => e.isPendingLike).toList();

  int get pendingCount => pendingOrFailed().length;

  Future<void> update(OfflineSaleQueueItem item) async {
    await init();
    await _queue.put(item.localId, item.toHiveMap());
  }

  Future<void> remove(String localId) async {
    await init();
    await _queue.delete(localId);
  }

  /// Cache last online product list for offline POS (real API data only).
  /// Expected keys: id, name, sell_price, stock, barcode, size?, color?
  Future<void> saveCatalogCache(List<Map<String, dynamic>> products) async {
    await init();
    await _catalogBox?.put(_catalogKey, products);
  }

  List<Map<String, dynamic>> loadCatalogCache() {
    final raw = _catalogBox?.get(_catalogKey);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static String normalizeBarcode(String raw) =>
      raw.trim().replaceAll(RegExp(r'[\s\r\n]+'), '');

  /// Upsert one catalog row (keeps barcode when merging online scans).
  Future<void> upsertCatalogProduct(Map<String, dynamic> row) async {
    await init();
    final id = row['id'];
    if (id is! int && id is! num) return;
    final pid = (id as num).toInt();
    if (pid <= 0) return;
    final list = loadCatalogCache().toList();
    final i = list.indexWhere((e) => (e['id'] as num?)?.toInt() == pid);
    if (i >= 0) {
      final merged = Map<String, dynamic>.from(list[i])..addAll(row);
      list[i] = merged;
    } else {
      list.add(Map<String, dynamic>.from(row));
    }
    await saveCatalogCache(list);
  }

  /// Offline barcode → cached product map, or null.
  Map<String, dynamic>? findByBarcode(String barcode) {
    final needle = normalizeBarcode(barcode).toLowerCase();
    if (needle.isEmpty) return null;
    for (final e in loadCatalogCache()) {
      final b = normalizeBarcode(
        (e['barcode'] ?? e['barcode_text'] ?? '').toString(),
      ).toLowerCase();
      if (b.isNotEmpty && b == needle) return e;
      final idStr = (e['id'] ?? '').toString();
      if (idStr.isNotEmpty && idStr == needle) return e;
    }
    return null;
  }

  /// Draft cart for walk-in POS (survives app restart).
  Future<void> savePosCartDraft(Map<String, dynamic> draft) async {
    await init();
    await _cartBox?.put(_cartKey, draft);
  }

  Map<String, dynamic>? loadPosCartDraft() {
    final raw = _cartBox?.get(_cartKey);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  Future<void> clearPosCartDraft() async {
    await init();
    await _cartBox?.delete(_cartKey);
  }
}
