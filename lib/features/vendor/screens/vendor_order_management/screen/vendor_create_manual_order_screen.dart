import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/localization/Keys/vendor_kay.dart';
import 'package:market_jango/core/localization/tr.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/image_controller.dart';
import 'package:market_jango/core/widget/global_search_bar.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/offline_sync/data/connectivity_providers.dart';
import 'package:market_jango/features/vendor/offline_sync/data/offline_sale_queue_store.dart';
import 'package:market_jango/features/vendor/offline_sync/provider/offline_sync_providers.dart';
import 'package:market_jango/features/vendor/offline_sync/widget/offline_sync_banner.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/data/vendor_barcode_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/model/vendor_barcode_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/walk_in_barcode_search_riverpod.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_pos_display_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/provider/vendor_pos_display_provider.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/screen/vendor_pos_customer_display_screen.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/pos_scan_sounds.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_walk_in_bill_print_flow.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_walk_in_bill_text.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_walk_in_bill_preview_dialog.dart';
import 'package:market_jango/features/vendor/widgets/custom_back_button.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Walk-in / POS manual order — `POST /vendor/manual-orders` ([doc/details.md]).
class VendorCreateManualOrderScreen extends ConsumerStatefulWidget {
  const VendorCreateManualOrderScreen({super.key, this.presetProductId});

  final int? presetProductId;

  static const routeName = '/vendor/manual-order/create';

  @override
  ConsumerState<VendorCreateManualOrderScreen> createState() =>
      _VendorCreateManualOrderScreenState();
}

int _toInt(dynamic v, {int d = 0}) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

double _toDouble(dynamic v, {double d = 0}) {
  if (v == null) return d;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '')) ?? d;
}

class _PosProduct {
  _PosProduct({
    required this.id,
    required this.name,
    required this.sellPrice,
    required this.stock,
    this.sizeLabel,
    this.colorLabel,
  });

  final int id;
  final String name;
  final double sellPrice;
  final int stock;
  final String? sizeLabel;
  final String? colorLabel;
}

class _CartLine {
  _CartLine({required this.product}) : qty = TextEditingController(text: '1');

  final _PosProduct product;
  final TextEditingController qty;

  void dispose() => qty.dispose();
}

class _VendorCreateManualOrderScreenState
    extends ConsumerState<VendorCreateManualOrderScreen> {
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerPaid = TextEditingController();
  final _customerNameFocus = FocusNode();
  final _customerPhoneFocus = FocusNode();
  final _customerPaidFocus = FocusNode();
  String _vendorDisplayName = 'Store';

  /// `true` = Cash; `false` = Card / Mobile / Debt (see [_payMode]).
  bool _payCash = true;
  /// When not cash: `Card`, `Mobile`, or `Debt`.
  String _nonCashMethod = 'Card';

  final List<_CartLine> _lines = [];
  List<_PosProduct> _catalog = [];
  bool _loadingCatalog = false;

  bool _submitting = false;

  /// Continuous camera scanner (stays open on POS).
  bool _continuousScan = false;
  MobileScannerController? _scanController;
  bool _scanBusy = false;
  DateTime? _lastScanAt;
  String? _lastScanLabel;
  String? _lastAcceptedCode;
  final List<String> _pendingScans = [];

  /// USB / Bluetooth keyboard-wedge barcode input.
  final _wedgeCtl = TextEditingController();
  final _wedgeFocus = FocusNode();
  Timer? _wedgeIdleTimer;
  bool _searchFocused = false;
  bool _persistReady = false;

  @override
  void initState() {
    super.initState();
    _customerName.addListener(_onCartDraftChanged);
    _customerPhone.addListener(_onCartDraftChanged);
    _customerPaid.addListener(_onCartDraftChanged);
    _customerNameFocus.addListener(_onProtectedFocusChanged);
    _customerPhoneFocus.addListener(_onProtectedFocusChanged);
    _customerPaidFocus.addListener(_onProtectedFocusChanged);
    FocusManager.instance.addListener(_onGlobalFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await OfflineSaleQueueStore.instance.init();
      await _loadVendorName();
      await _loadCatalog();
      if (!mounted) return;
      await _restorePosCartDraft();
      if (!mounted) return;
      _persistReady = true;
      _syncPosCustomerSession();
      final preset = widget.presetProductId;
      if (preset != null) {
        await _addProductById(preset);
      }
      // HID wedge needs focus without soft keyboard (TextInputType.none).
      _requestWedgeFocus(force: true);
    });
  }

  Future<void> _loadVendorName() async {
    try {
      final storage = AuthLocalStorage();
      final user = await storage.getUserJson();
      final name = (user?['name'] ??
              user?['shop_name'] ??
              user?['store_name'] ??
              user?['business_name'] ??
              '')
          .toString()
          .trim();
      if (name.isNotEmpty && mounted) {
        setState(() => _vendorDisplayName = name);
      }
    } catch (_) {}
  }

  void _syncPosCustomerSession() {
    final items = <VendorPosDisplayLine>[];
    for (final l in _lines) {
      final q = int.tryParse(l.qty.text.trim()) ?? 0;
      if (q <= 0) continue;
      items.add(
        VendorPosDisplayLine(
          productId: l.product.id,
          name: l.product.name,
          quantity: q,
          unitPrice: l.product.sellPrice,
        ),
      );
    }
    final prev = ref.read(vendorPosCartSessionProvider);
    ref.read(vendorPosCartSessionProvider.notifier).state = prev.copyWith(
      vendorName: _vendorDisplayName,
      items: items,
    );
  }

  Future<void> _openCustomerDisplay() async {
    _syncPosCustomerSession();
    if (!mounted) return;
    await context.push(VendorPosCustomerDisplayScreen.routeName);
  }

  @override
  void dispose() {
    _persistReady = false;
    _wedgeIdleTimer?.cancel();
    _customerName.removeListener(_onCartDraftChanged);
    _customerPhone.removeListener(_onCartDraftChanged);
    _customerPaid.removeListener(_onCartDraftChanged);
    _customerNameFocus.removeListener(_onProtectedFocusChanged);
    _customerPhoneFocus.removeListener(_onProtectedFocusChanged);
    _customerPaidFocus.removeListener(_onProtectedFocusChanged);
    FocusManager.instance.removeListener(_onGlobalFocusChanged);
    _scanController?.dispose();
    _wedgeCtl.dispose();
    _wedgeFocus.dispose();
    _customerNameFocus.dispose();
    _customerPhoneFocus.dispose();
    _customerPaidFocus.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _customerPaid.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _onCartDraftChanged() {
    if (!_persistReady) return;
    _persistPosCartDraft();
  }

  bool _isProtectedFieldFocused() {
    return _searchFocused ||
        _customerNameFocus.hasFocus ||
        _customerPhoneFocus.hasFocus ||
        _customerPaidFocus.hasFocus;
  }

  void _onProtectedFocusChanged() {
    if (!_isProtectedFieldFocused()) {
      _requestWedgeFocus();
    }
  }

  void _onGlobalFocusChanged() {
    if (!mounted || _isProtectedFieldFocused() || _wedgeFocus.hasFocus) return;
    final primary = FocusManager.instance.primaryFocus;
    // Leave focus alone while qty / other editable fields are active.
    if (primary != null &&
        primary != _wedgeFocus &&
        primary.context != null &&
        primary.context!.widget is EditableText) {
      return;
    }
    _requestWedgeFocus();
  }

  void _requestWedgeFocus({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!force && _isProtectedFieldFocused()) return;
      if (!_wedgeFocus.hasFocus) {
        _wedgeFocus.requestFocus();
      }
      // TextInputType.none avoids soft keyboard; hide is a safety net.
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  Future<void> _persistPosCartDraft() async {
    if (!_persistReady) return;
    final items = <Map<String, dynamic>>[];
    for (final l in _lines) {
      final q = int.tryParse(l.qty.text.trim()) ?? 0;
      items.add({
        'id': l.product.id,
        'name': l.product.name,
        'sell_price': l.product.sellPrice,
        'stock': l.product.stock,
        'size': l.product.sizeLabel,
        'color': l.product.colorLabel,
        'quantity': q <= 0 ? 1 : q,
      });
    }
    await OfflineSaleQueueStore.instance.savePosCartDraft({
      'customer_name': _customerName.text,
      'customer_phone': _customerPhone.text,
      'customer_paid': _customerPaid.text,
      'pay_cash': _payCash,
      'non_cash_method': _nonCashMethod,
      'items': items,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _restorePosCartDraft() async {
    final draft = OfflineSaleQueueStore.instance.loadPosCartDraft();
    if (draft == null) return;
    final items = draft['items'];
    if (items is! List || items.isEmpty) {
      final name = draft['customer_name']?.toString() ?? '';
      final phone = draft['customer_phone']?.toString() ?? '';
      final paid = draft['customer_paid']?.toString() ?? '';
      if (name.isEmpty && phone.isEmpty && paid.isEmpty) return;
    }
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
    if (items is List) {
      for (final raw in items.whereType<Map>()) {
        final e = Map<String, dynamic>.from(raw);
        final id = _toInt(e['id']);
        if (id <= 0) continue;
        final p = _PosProduct(
          id: id,
          name: e['name']?.toString() ?? 'Product $id',
          sellPrice: _toDouble(e['sell_price'] ?? e['price']),
          stock: _toInt(e['stock']),
          sizeLabel: e['size']?.toString(),
          colorLabel: e['color']?.toString(),
        );
        _cacheProduct(p);
        final line = _CartLine(product: p);
        final q = _toInt(e['quantity'], d: 1);
        line.qty.text = '${q < 1 ? 1 : q}';
        line.qty.addListener(_onCartDraftChanged);
        _lines.add(line);
      }
    }
    _customerName.text = draft['customer_name']?.toString() ?? '';
    _customerPhone.text = draft['customer_phone']?.toString() ?? '';
    _customerPaid.text = draft['customer_paid']?.toString() ?? '';
    _payCash = draft['pay_cash'] != false;
    final method = draft['non_cash_method']?.toString();
    if (method == 'Card' || method == 'Mobile' || method == 'Debt') {
      _nonCashMethod = method!;
    }
    if (mounted) setState(() {});
  }

  Future<void> _clearPosCartDraft() async {
    await OfflineSaleQueueStore.instance.clearPosCartDraft();
  }

  bool get _isDebt => !_payCash && _nonCashMethod == 'Debt';

  /// API expects `Cash`, `Card`, `Mobile`, or `Debt` (STEP_03).
  String _paymentMethodApi() {
    if (_payCash) return 'Cash';
    return _nonCashMethod;
  }

  double get _cartTotal {
    var sum = 0.0;
    for (final l in _lines) {
      final q = int.tryParse(l.qty.text.trim()) ?? 0;
      if (q > 0) sum += l.product.sellPrice * q;
    }
    return sum;
  }

  double? get _tenderAmount {
    if (!_payCash) return null;
    final t = _customerPaid.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  double? get _changeDue {
    final tender = _tenderAmount;
    if (tender == null) return null;
    final due = tender - _cartTotal;
    if (due < 0) return null;
    return due;
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    try {
      final headers = await vendorOrderApiHeaders();
      final uri = Uri.parse('${VendorAPIController.vendor_product}?page=1');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) {
        throw Exception('Products HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'];
      final list = data is Map && data['data'] is List
          ? (data['data'] as List)
          : data is List
              ? data
              : <dynamic>[];
      final mapped = <_PosProduct>[];
      final cacheById = <int, Map<String, dynamic>>{};
      for (final e in list.whereType<Map<String, dynamic>>()) {
        final id = _toInt(e['id']);
        if (id <= 0) continue;
        final name = e['name']?.toString() ?? 'Product $id';
        final price = _toDouble(e['sell_price'] ?? e['price'] ?? e['regular_price']);
        final stock = _toInt(e['stock'] ?? e['quantity']);
        String? size;
        String? color;
        final pv = e['product_variation'];
        if (pv is Map<String, dynamic>) {
          size ??= pv['size']?.toString();
          color ??= pv['color']?.toString();
        }
        final attrs = e['attributes'];
        if (attrs is List) {
          for (final a in attrs.whereType<Map<String, dynamic>>()) {
            final n = a['name']?.toString().toLowerCase() ?? '';
            final val = a['value']?.toString() ?? a['attribute_value']?.toString();
            if (val == null || val.isEmpty) continue;
            if (n.contains('size')) size = val;
            if (n.contains('color') || n.contains('colour')) color = val;
          }
        }
        final barcode = (e['barcode'] ?? e['barcode_text'] ?? '').toString().trim();
        mapped.add(
          _PosProduct(
            id: id,
            name: name,
            sellPrice: price,
            stock: stock,
            sizeLabel: size,
            colorLabel: color,
          ),
        );
        cacheById[id] = {
          'id': id,
          'name': name,
          'sell_price': price,
          'stock': stock,
          'size': size,
          'color': color,
          'barcode': barcode,
        };
      }

      // Enrich barcodes from dedicated barcode list (paginated).
      try {
        var page = 1;
        var lastPage = 1;
        do {
          final bp = await VendorBarcodeApi.instance.fetchBarcodeList(page: page);
          lastPage = bp.lastPage < 1 ? 1 : bp.lastPage;
          for (final p in bp.items) {
            final existing = cacheById[p.id];
            final code = p.barcode.trim().isNotEmpty
                ? p.barcode.trim()
                : p.barcodeText.trim();
            if (existing != null) {
              if (code.isNotEmpty) existing['barcode'] = code;
              existing['name'] = p.name;
              existing['sell_price'] = p.sellPrice;
              existing['stock'] = p.stock;
            } else {
              cacheById[p.id] = {
                'id': p.id,
                'name': p.name,
                'sell_price': p.sellPrice,
                'stock': p.stock,
                'size': p.variant.size,
                'color': p.variant.color,
                'barcode': code,
              };
              mapped.add(
                _PosProduct(
                  id: p.id,
                  name: p.name,
                  sellPrice: p.sellPrice,
                  stock: p.stock,
                  sizeLabel: p.variant.size,
                  colorLabel: p.variant.color,
                ),
              );
            }
          }
          page++;
        } while (page <= lastPage && page <= 25);
      } catch (_) {}

      await OfflineSaleQueueStore.instance
          .saveCatalogCache(cacheById.values.toList());
      if (mounted) setState(() => _catalog = mapped);
    } catch (_) {
      // Offline / API failure — use last cached catalog (real data only).
      final cached = OfflineSaleQueueStore.instance.loadCatalogCache();
      final mapped = <_PosProduct>[];
      for (final e in cached) {
        final id = _toInt(e['id']);
        if (id <= 0) continue;
        mapped.add(
          _PosProduct(
            id: id,
            name: e['name']?.toString() ?? 'Product $id',
            sellPrice: _toDouble(e['sell_price'] ?? e['price']),
            stock: _toInt(e['stock']),
            sizeLabel: e['size']?.toString(),
            colorLabel: e['color']?.toString(),
          ),
        );
      }
      if (mounted) setState(() => _catalog = mapped);
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  _PosProduct? _findInCatalog(int id) {
    for (final p in _catalog) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<_PosProduct?> _resolveProduct(int id) async {
    final local = _findInCatalog(id);
    if (local != null) return local;
    try {
      final b = await VendorBarcodeApi.instance.fetchProductBarcode(id);
      return _PosProduct(
        id: b.id,
        name: b.name,
        sellPrice: b.sellPrice,
        stock: b.stock,
        sizeLabel: null,
        colorLabel: null,
      );
    } catch (_) {
      return null;
    }
  }

  _PosProduct _posFromBarcode(VendorBarcodeProduct b) => _PosProduct(
        id: b.id,
        name: b.name,
        sellPrice: b.sellPrice,
        stock: b.stock,
      );

  _PosProduct _posFromCacheRow(Map<String, dynamic> e) {
    final id = _toInt(e['id']);
    return _PosProduct(
      id: id,
      name: e['name']?.toString() ?? 'Product $id',
      sellPrice: _toDouble(e['sell_price'] ?? e['price']),
      stock: _toInt(e['stock']),
      sizeLabel: e['size']?.toString(),
      colorLabel: e['color']?.toString(),
    );
  }

  void _cacheProduct(_PosProduct p) {
    if (_findInCatalog(p.id) != null) return;
    _catalog = [..._catalog, p];
  }

  /// Adds product to cart. Returns `true` if a new line was created.
  bool _addProductFromBarcode(VendorBarcodeProduct b) {
    final p = _posFromBarcode(b);
    _cacheProduct(p);
    final isNew = _addOrIncrementLine(p);
    final code = b.barcode.trim().isNotEmpty ? b.barcode.trim() : b.barcodeText.trim();
    OfflineSaleQueueStore.instance.upsertCatalogProduct({
      'id': b.id,
      'name': b.name,
      'sell_price': b.sellPrice,
      'stock': b.stock,
      'size': b.variant.size,
      'color': b.variant.color,
      'barcode': code,
    });
    return isNew;
  }

  Future<void> _addProductById(int id) async {
    final p = await _resolveProduct(id);
    if (!mounted) return;
    if (p == null) {
      GlobalSnackbar.show(
        context,
        title: 'Product',
        message: 'Could not load product #$id',
        type: CustomSnackType.error,
      );
      return;
    }
    _addOrIncrementLine(p);
  }

  /// Returns `true` when a new cart line was created; `false` when qty++.
  bool _addOrIncrementLine(_PosProduct p) {
    for (final l in _lines) {
      if (l.product.id == p.id) {
        final q = int.tryParse(l.qty.text.trim()) ?? 0;
        l.qty.text = '${q + 1}';
        setState(() {});
        _syncPosCustomerSession();
        _persistPosCartDraft();
        return false;
      }
    }
    final line = _CartLine(product: p);
    line.qty.addListener(_onCartDraftChanged);
    setState(() => _lines.add(line));
    _syncPosCustomerSession();
    _persistPosCartDraft();
    return true;
  }

  void _playCartScanSound({required bool isNewLine}) {
    if (isNewLine) {
      PosScanSounds.instance.productAddedNew();
    } else {
      PosScanSounds.instance.productQtyIncreased();
    }
  }

  bool _scanDebounced(String code) {
    final now = DateTime.now();
    // Same code within 800ms = duplicate (camera re-detect / double Enter).
    // Different codes are allowed immediately for continuous HID scanning.
    if (_lastAcceptedCode == code &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(milliseconds: 800)) {
      return true;
    }
    _lastScanAt = now;
    _lastAcceptedCode = code;
    return false;
  }

  void _enqueueOrHandleScan(String raw) {
    final code = OfflineSaleQueueStore.normalizeBarcode(raw);
    if (code.isEmpty) return;
    if (_scanBusy) {
      if (_pendingScans.length < 30 &&
          (_pendingScans.isEmpty || _pendingScans.last != code)) {
        _pendingScans.add(code);
      }
      return;
    }
    _handleScannedBarcode(code);
  }

  /// Shared pipeline for camera + hardware wedge scans.
  Future<void> _handleScannedBarcode(String raw) async {
    final code = OfflineSaleQueueStore.normalizeBarcode(raw);
    if (code.isEmpty || _scanBusy) return;
    if (_scanDebounced(code)) return;

    setState(() => _scanBusy = true);
    try {
      List<ConnectivityResult> net;
      try {
        net = await Connectivity().checkConnectivity();
      } catch (_) {
        net = const [];
      }
      final online = await resolveIsOnline(net);

      if (online) {
        try {
          final product = await VendorBarcodeApi.instance.scanBarcode(code);
          if (!mounted) return;
          final isNew = _addProductFromBarcode(product);
          _playCartScanSound(isNewLine: isNew);
          setState(() => _lastScanLabel = product.name);
          // Continuous camera stays open; skip snackbar spam while scanning.
          if (!_continuousScan) {
            GlobalSnackbar.show(
              context,
              title: 'Added',
              message: product.name,
              type: CustomSnackType.success,
            );
          }
        } catch (e) {
          if (!mounted) return;
          GlobalSnackbar.show(
            context,
            title: 'Scan',
            message: e.toString().replaceFirst('Exception: ', ''),
            type: CustomSnackType.error,
          );
        }
      } else {
        final row = OfflineSaleQueueStore.instance.findByBarcode(code);
        if (!mounted) return;
        if (row == null) {
          GlobalSnackbar.show(
            context,
            title: 'Offline',
            message:
                'Product unavailable offline. Connect once to refresh catalog.',
            type: CustomSnackType.error,
          );
          return;
        }
        final p = _posFromCacheRow(row);
        _cacheProduct(p);
        final isNew = _addOrIncrementLine(p);
        _playCartScanSound(isNewLine: isNew);
        setState(() => _lastScanLabel = p.name);
        if (!_continuousScan) {
          GlobalSnackbar.show(
            context,
            title: 'Added offline',
            message: p.name,
            type: CustomSnackType.success,
          );
        }
      }
    } finally {
      if (mounted) {
        // Keep MobileScanner running — never stop/dispose here.
        setState(() => _scanBusy = false);
        _requestWedgeFocus();
        if (_pendingScans.isNotEmpty) {
          final next = _pendingScans.removeAt(0);
          // ignore: unawaited_futures
          _handleScannedBarcode(next);
        }
      }
    }
  }

  Future<void> _toggleContinuousScanner() async {
    if (_continuousScan) {
      await _scanController?.stop();
      _scanController?.dispose();
      _scanController = null;
      if (mounted) setState(() => _continuousScan = false);
      _requestWedgeFocus(force: true);
      return;
    }
    _scanController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() => _continuousScan = true);
    PosScanSounds.instance.scannerOpened();
    // Keep HID wedge live while camera continuous mode is open.
    _requestWedgeFocus(force: true);
  }

  void _onCameraDetect(BarcodeCapture capture) {
    if (_scanBusy || !_continuousScan) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final b = codes.first;
    final v = b.rawValue ?? b.displayValue;
    if (v == null || v.isEmpty) return;
    _enqueueOrHandleScan(v);
  }

  void _flushWedgeBuffer() {
    _wedgeIdleTimer?.cancel();
    final code = _wedgeCtl.text.trim();
    _wedgeCtl.clear();
    if (code.isEmpty) return;
    _enqueueOrHandleScan(code);
  }

  void _onWedgeChanged(String value) {
    // Scanners that end with CR/LF may land as characters before onSubmitted.
    if (value.contains('\n') || value.contains('\r')) {
      _flushWedgeBuffer();
      return;
    }
    _wedgeIdleTimer?.cancel();
    if (value.trim().isEmpty) return;
    // Many USB/BT wedges fire Enter; idle flush covers scanners with no suffix.
    _wedgeIdleTimer = Timer(const Duration(milliseconds: 120), _flushWedgeBuffer);
  }

  void _onWedgeSubmitted(String value) {
    _wedgeIdleTimer?.cancel();
    final code = value.trim().isNotEmpty ? value.trim() : _wedgeCtl.text.trim();
    _wedgeCtl.clear();
    if (code.isEmpty) return;
    _enqueueOrHandleScan(code);
  }

  void _removeLine(int i) {
    setState(() {
      _lines[i].qty.removeListener(_onCartDraftChanged);
      _lines[i].dispose();
      _lines.removeAt(i);
    });
    _syncPosCustomerSession();
    _persistPosCartDraft();
  }

  Future<void> _submit({required bool showBill}) async {
    final name = _customerName.text.trim();
    if (name.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Required',
        message: 'Customer name is required',
        type: CustomSnackType.error,
      );
      return;
    }
    if (name.length > 100) {
      GlobalSnackbar.show(
        context,
        title: 'Name',
        message: 'Customer name must be at most 100 characters',
        type: CustomSnackType.error,
      );
      return;
    }
    final items = <Map<String, int>>[];
    for (final l in _lines) {
      final q = int.tryParse(l.qty.text.trim()) ?? 0;
      if (q <= 0) continue;
      if (q > l.product.stock) {
        GlobalSnackbar.show(
          context,
          title: 'Stock',
          message: '${l.product.name}: max ${l.product.stock}',
          type: CustomSnackType.error,
        );
        return;
      }
      items.add({'product_id': l.product.id, 'quantity': q});
    }
    if (items.isEmpty) {
      GlobalSnackbar.show(
        context,
        title: 'Cart',
        message: 'Add at least one product',
        type: CustomSnackType.error,
      );
      return;
    }

    double? paidApi;
    if (_payCash) {
      final t = _customerPaid.text.trim();
      paidApi = t.isEmpty ? null : double.tryParse(t.replaceAll(',', ''));
      if (paidApi != null) {
        if (paidApi < 0) {
          GlobalSnackbar.show(
            context,
            title: 'Cash',
            message: 'Customer paid must be zero or greater',
            type: CustomSnackType.error,
          );
          return;
        }
        if (paidApi < _cartTotal) {
          GlobalSnackbar.show(
            context,
            title: 'Cash',
            message: 'Customer amount is less than total',
            type: CustomSnackType.error,
          );
          return;
        }
      }
    }
    // Debt: no tender — full cart total is recorded as outstanding debt.

    final phone = _customerPhone.text.trim();
    if (phone.length > 30) {
      GlobalSnackbar.show(
        context,
        title: 'Phone',
        message: 'Phone must be at most 30 characters',
        type: CustomSnackType.error,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      List<ConnectivityResult> net;
      try {
        net = await Connectivity().checkConnectivity();
      } catch (_) {
        net = const [];
      }
      final online = await resolveIsOnline(net);

      if (!online) {
        final queued =
            await OfflineSaleQueueStore.instance.enqueueSales(items);
        bumpOfflineQueue(ref);
        if (!mounted) return;
        for (final l in _lines) {
          l.qty.removeListener(_onCartDraftChanged);
          l.dispose();
        }
        _lines.clear();
        _customerName.clear();
        _customerPhone.clear();
        _customerPaid.clear();
        await _clearPosCartDraft();
        if (!mounted) return;
        _syncPosCustomerSession();
        setState(() {});
        GlobalSnackbar.show(
          context,
          title: 'Saved offline',
          message:
              '${queued.length} sale line(s) queued. Will sync when online.',
          type: CustomSnackType.success,
        );
        return;
      }

      final inv = await VendorOrderApi.instance.createManualOrder(
        customerName: name,
        customerPhone: phone.isEmpty ? null : phone,
        paymentMethod: _paymentMethodApi(),
        customerPaid: paidApi,
        items: items,
      );
      if (!mounted) return;
      for (final l in _lines) {
        l.qty.removeListener(_onCartDraftChanged);
        l.dispose();
      }
      _lines.clear();
      _customerName.clear();
      _customerPhone.clear();
      _customerPaid.clear();
      await _clearPosCartDraft();
      _syncPosCustomerSession();
      ref.read(vendorPosCartSessionProvider.notifier).state =
          ref.read(vendorPosCartSessionProvider).copyWith(
                invoiceId: inv.id,
                orderNumber: inv.orderNumber,
                vendorName: _vendorDisplayName,
              );
      if (showBill) {
        await _showBillSheet(inv);
      }
      if (mounted) context.pop(inv.id);
    } catch (e) {
      if (mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showBillSheet(VendorManualOrderInvoice inv) async {
    final text = formatWalkInBillText(inv);
    if (!mounted) return;
    await VendorWalkInBillPreviewDialog.show(
      context,
      invoice: inv,
      billText: text,
      onPrint: () => _openBillPrint(inv, text),
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          GlobalSnackbar.show(
            context,
            title: 'Copied',
            message: 'Bill text copied to clipboard',
            type: CustomSnackType.success,
          );
        }
      },
    );
  }

  Future<void> _openBillPrint(VendorManualOrderInvoice inv, String billText) async {
    if (!mounted) return;
    await VendorWalkInBillPrintFlow.openPrinterSheet(
      context,
      invoice: inv,
      billText: billText,
    );
  }

  /// Full border/label overrides so this screen matches itself — global
  /// [ThemeData.inputDecorationTheme] uses pill radius (50) and gold borders.
  InputDecoration _fieldDeco(String label, {String? hint}) {
    final radius = BorderRadius.circular(10.r);
    final idle = BorderSide(color: AllColor.grey200, width: 1);
    final focus = BorderSide(color: AllColor.loginButtomColor, width: 1.5);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: AllColor.grey500,
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        color: AllColor.grey500,
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: TextStyle(
        color: AllColor.black87,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: AllColor.white,
      isDense: true,
      border: OutlineInputBorder(borderRadius: radius, borderSide: idle),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: idle),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: focus),
      disabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: idle),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AllColor.red200, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AllColor.red200, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalStr = _cartTotal.toStringAsFixed(2);
    final tender = _tenderAmount;
    final changeStr = _changeDue != null
        ? _changeDue!.toStringAsFixed(2)
        : (tender != null && tender < _cartTotal ? '—' : '—');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AllColor.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: const CustomBackButton(),
        ),
        title: Text(
          'New walk-in order',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AllColor.black,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Customer display',
            onPressed: _openCustomerDisplay,
            icon: Icon(
              Icons.tv_outlined,
              color: AllColor.loginButtomColor,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
        children: [
          const OfflineSyncBanner(),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 14.w),
            decoration: BoxDecoration(
              color: AllColor.orange50.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AllColor.orange200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  color: AllColor.loginButtomColor,
                  size: 22.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Scan or search products, then enter customer & payment.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AllColor.black87,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          /// 1) Add products first (POS flow)
          Text(
            'Add products',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AllColor.black,
            ),
          ),
          SizedBox(height: 8.h),
          // Hidden USB/BT wedge capture — must not paint focus border.
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _wedgeCtl,
                focusNode: _wedgeFocus,
                autofocus: false,
                showCursor: false,
                enableSuggestions: false,
                autocorrect: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.none,
                textInputAction: TextInputAction.done,
                onChanged: _onWedgeChanged,
                onSubmitted: _onWedgeSubmitted,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GlobalSearchBar<VendorBarcodeListPage,
                        VendorBarcodeProduct>(
                      provider: walkInBarcodeSearchProvider,
                      itemsSelector: (res) => res.items,
                      itemBuilder: (context, p) =>
                          _WalkInBarcodeSuggestionTile(product: p),
                      onItemSelected: (p) {
                        _addProductFromBarcode(p);
                        _requestWedgeFocus(force: true);
                      },
                      onFocusChange: (hasFocus) {
                        _searchFocused = hasFocus;
                        if (!hasFocus) _requestWedgeFocus();
                      },
                      hintText: ref.t(VKeys.searchProducts),
                      debounce: const Duration(milliseconds: 400),
                      minChars: 1,
                      showResults: true,
                      resultsMaxHeight: 380,
                      autofocus: false,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton.filled(
                    onPressed: _loadingCatalog ? null : _toggleContinuousScanner,
                    style: IconButton.styleFrom(
                      backgroundColor: _continuousScan
                          ? AllColor.red
                          : AllColor.loginButtomColor,
                      foregroundColor: AllColor.white,
                      fixedSize: Size(48.r, 48.r),
                    ),
                    icon: Icon(
                      _continuousScan
                          ? Icons.close_rounded
                          : Icons.qr_code_scanner_rounded,
                    ),
                    tooltip: _continuousScan
                        ? 'Stop continuous scan'
                        : 'Continuous barcode scan',
                  ),
                ],
              );
            },
          ),
          if (_continuousScan && _scanController != null) ...[
            SizedBox(height: 10.h),
            _PosContinuousScannerPanel(
              controller: _scanController!,
              busy: _scanBusy,
              lastLabel: _lastScanLabel,
              onDetect: _onCameraDetect,
              onClose: _toggleContinuousScanner,
            ),
          ],
          Padding(
            padding: EdgeInsets.only(top: 6.h, bottom: 4.h),
            child: Text(
              'USB/BT scanner always ready · Camera optional for continuous scan',
              style: TextStyle(
                fontSize: 11.sp,
                color: AllColor.grey500,
                height: 1.3,
              ),
            ),
          ),
          if (_loadingCatalog)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: const Center(child: CircularProgressIndicator()),
            ),

          SizedBox(height: 14.h),

          /// 2) Cart
          Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                color: AllColor.loginButtomColor,
                size: 20.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'Cart',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp),
              ),
              if (_lines.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AllColor.orange50,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${_lines.length}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: AllColor.loginButtomColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: _loadCatalog,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AllColor.loginButtomColor,
                ),
                child: const Text('Refresh'),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _linesTableCard(),

          SizedBox(height: 12.h),

          Container(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AllColor.loginButtomColor.withValues(alpha: 0.12),
                  AllColor.orange50,
                ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AllColor.orange200),
            ),
            child: Row(
              children: [
                Text(
                  'Cart total',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AllColor.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  'USD $totalStr',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: AllColor.loginButtomColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          Text(
            'Customer',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AllColor.black,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AllColor.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AllColor.grey200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _customerName,
                  focusNode: _customerNameFocus,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      const SizedBox.shrink(),
                  decoration: _fieldDeco('Customer name', hint: 'Required'),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _customerPhone,
                  focusNode: _customerPhoneFocus,
                  keyboardType: TextInputType.phone,
                  maxLength: 30,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      const SizedBox.shrink(),
                  decoration: _fieldDeco('Phone', hint: 'Optional'),
                ),
              ],
            ),
          ),

          SizedBox(height: 18.h),

          Text(
            'Payment',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AllColor.black,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AllColor.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AllColor.grey200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _payOptionTile(
                        label: 'Cash',
                        icon: Icons.payments_outlined,
                        selected: _payCash,
                        onTap: () {
                          setState(() => _payCash = true);
                          _persistPosCartDraft();
                          FocusScope.of(context).unfocus();
                          _requestWedgeFocus(force: true);
                        },
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _payOptionTile(
                        label: 'Other',
                        icon: Icons.credit_card_outlined,
                        selected: !_payCash,
                        onTap: () {
                          setState(() => _payCash = false);
                          _persistPosCartDraft();
                          FocusScope.of(context).unfocus();
                          _requestWedgeFocus(force: true);
                        },
                      ),
                    ),
                  ],
                ),
                if (!_payCash) ...[
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    initialValue: _nonCashMethod,
                    decoration: _fieldDeco('Method'),
                    items: const [
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(
                        value: 'Mobile',
                        child: Text('Mobile money'),
                      ),
                      DropdownMenuItem(value: 'Debt', child: Text('Debt')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _nonCashMethod = v);
                        _persistPosCartDraft();
                      }
                    },
                  ),
                  if (_isDebt) ...[
                    SizedBox(height: 10.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AllColor.loginButtomColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        'Debt: USD ${_cartTotal.toStringAsFixed(2)} — pay later from order detail.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          height: 1.35,
                          color: AllColor.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
                if (_payCash) ...[
                  SizedBox(height: 14.h),
                  _cashTenderCard(
                    totalStr: totalStr,
                    tender: tender,
                    changeStr: changeStr,
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 22.h),
          FilledButton(
            onPressed: _submitting ? null : () => _submit(showBill: false),
            style: FilledButton.styleFrom(
              backgroundColor: AllColor.loginButtomColor,
              foregroundColor: AllColor.white,
              elevation: 0,
              minimumSize: Size(double.infinity, 52.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Text(
              'Create order',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(height: 10.h),
          OutlinedButton.icon(
            onPressed: _submitting ? null : () => _submit(showBill: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AllColor.loginButtomColor,
              side: BorderSide(color: AllColor.orange200, width: 1.4),
              minimumSize: Size(double.infinity, 50.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            icon: Icon(Icons.receipt_long_outlined, size: 20.sp),
            label: Text(
              'Create & preview bill',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Invoice saves as pending until marked delivered.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              color: AllColor.grey500,
              height: 1.35,
            ),
          ),
          if (_submitting)
            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _cashTenderCard({
    required String totalStr,
    required double? tender,
    required String changeStr,
  }) {
    final changeText =
        tender != null && tender >= _cartTotal ? changeStr : '—';
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.grey200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Customer pays',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AllColor.grey500,
                  ),
                ),
              ),
              SizedBox(
                width: 120.w,
                child: TextField(
                  controller: _customerPaid,
                  focusNode: _customerPaidFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0.00',
                    filled: true,
                    fillColor: AllColor.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: AllColor.grey200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(color: AllColor.grey200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide(
                        color: AllColor.loginButtomColor,
                        width: 1.4,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Text(
                'Order total',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AllColor.grey500,
                ),
              ),
              const Spacer(),
              Text(
                totalStr,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(
                'Change due',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AllColor.grey500,
                ),
              ),
              const Spacer(),
              Text(
                changeText,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AllColor.loginButtomColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payOptionTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData icon = Icons.radio_button_off,
  }) {
    return Material(
      color: selected
          ? AllColor.loginButtomColor.withValues(alpha: 0.08)
          : AllColor.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected ? AllColor.loginButtomColor : AllColor.grey200,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : icon,
                color: selected ? AllColor.loginButtomColor : AllColor.grey500,
                size: 20,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? AllColor.loginButtomColor : AllColor.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linesTableCard() {
    if (_lines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AllColor.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AllColor.grey200),
        ),
        child: Text(
          'Cart is empty — search or scan to add products.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AllColor.grey500, fontSize: 13.sp),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AllColor.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.grey200),
      ),
      child: Column(
        children: List.generate(_lines.length, (i) {
          final line = _lines[i];
          final q = int.tryParse(line.qty.text.trim()) ?? 0;
          final amt =
              (q > 0 ? line.product.sellPrice * q : 0).toStringAsFixed(2);
          final meta = <String>[
            if (line.product.sizeLabel?.isNotEmpty == true)
              'Size ${line.product.sizeLabel}',
            if (line.product.colorLabel?.isNotEmpty == true)
              'Colour ${line.product.colorLabel}',
          ].join(' · ');
          return Column(
            children: [
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              meta,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AllColor.grey500,
                              ),
                            ),
                          ],
                          SizedBox(height: 2.h),
                          Text(
                            'USD ${line.product.sellPrice.toStringAsFixed(2)} each',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AllColor.grey500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _qtyStepper(
                      quantity: q < 1 ? 1 : q,
                      onMinus: () {
                        final cur = int.tryParse(line.qty.text.trim()) ?? 1;
                        if (cur <= 1) {
                          _removeLine(i);
                          return;
                        }
                        line.qty.text = '${cur - 1}';
                        setState(() {});
                        _syncPosCustomerSession();
                        _persistPosCartDraft();
                      },
                      onPlus: () {
                        final cur = int.tryParse(line.qty.text.trim()) ?? 0;
                        line.qty.text = '${cur + 1}';
                        setState(() {});
                        _syncPosCustomerSession();
                        _persistPosCartDraft();
                      },
                    ),
                    SizedBox(width: 10.w),
                    SizedBox(
                      width: 64.w,
                      child: Text(
                        amt,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                          color: AllColor.loginButtomColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeLine(i),
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AllColor.red,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _qtyStepper({
    required int quantity,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AllColor.orange50,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AllColor.orange200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onMinus,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Icon(Icons.remove, size: 16.sp, color: AllColor.black87),
            ),
          ),
          Text(
            '$quantity',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AllColor.loginButtomColor,
            ),
          ),
          InkWell(
            onTap: onPlus,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Icon(Icons.add, size: 16.sp, color: AllColor.black87),
            ),
          ),
        ],
      ),
    );
  }
}
class _PosContinuousScannerPanel extends StatelessWidget {
  const _PosContinuousScannerPanel({
    required this.controller,
    required this.busy,
    required this.lastLabel,
    required this.onDetect,
    required this.onClose,
  });

  final MobileScannerController controller;
  final bool busy;
  final String? lastLabel;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220.h,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AllColor.orange200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
          ),
          Positioned(
            left: 10.w,
            right: 10.w,
            top: 10.h,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    busy
                        ? 'Looking up…'
                        : (lastLabel == null
                            ? 'Continuous scan — keep scanning'
                            : 'Last: $lastLabel'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black45,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          if (busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalkInBarcodeSuggestionTile extends StatelessWidget {
  const _WalkInBarcodeSuggestionTile({required this.product});

  final VendorBarcodeProduct product;

  @override
  Widget build(BuildContext context) {
    final sell = product.sellPrice.toStringAsFixed(2);
    final regular = product.regularPrice.toStringAsFixed(2);
    final showRegular = product.regularPrice > 0 && regular != sell;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: FirstTimeShimmerImage(
              imageUrl: product.image,
              height: 56.h,
              width: 56.w,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (product.barcode.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    product.barcode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AllColor.grey500,
                    ),
                  ),
                ],
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Text(
                      'USD $sell',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showRegular) ...[
                      SizedBox(width: 8.w),
                      Text(
                        'USD $regular',
                        style: TextStyle(
                          fontSize: 12.sp,
                          decoration: TextDecoration.lineThrough,
                          color: AllColor.grey500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'Stock ${product.stock}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AllColor.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade500),
        ],
      ),
    );
  }
}
