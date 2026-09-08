/// Local cart line mirrored to the customer POS display (STEP_04).
class VendorPosDisplayLine {
  const VendorPosDisplayLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String name;
  final int quantity;
  final double unitPrice;

  double get lineTotal => unitPrice * quantity;

  factory VendorPosDisplayLine.fromJson(Map<String, dynamic> j) {
    final product = j['product'] is Map<String, dynamic>
        ? j['product'] as Map<String, dynamic>
        : null;
    final name = (j['name'] ??
            j['product_name'] ??
            product?['name'] ??
            'Item')
        .toString();
    final qty = _toInt(j['quantity'] ?? j['qty'], d: 1);
    final price = _toDouble(
      j['unit_price'] ??
          j['price'] ??
          j['sale_price'] ??
          j['sell_price'] ??
          product?['sell_price'],
    );
    return VendorPosDisplayLine(
      productId: _toInt(j['product_id'] ?? product?['id'] ?? j['id']),
      name: name,
      quantity: qty < 1 ? 1 : qty,
      unitPrice: price,
    );
  }
}

/// Payload for customer-facing POS display.
class VendorPosDisplayData {
  const VendorPosDisplayData({
    required this.vendorName,
    required this.items,
    required this.total,
    this.orderNumber,
    this.invoiceId,
    this.source = 'local',
  });

  final String vendorName;
  final List<VendorPosDisplayLine> items;
  final double total;
  final String? orderNumber;
  final int? invoiceId;

  /// `local` (live cart session) or `api` (polled pos-display).
  final String source;

  factory VendorPosDisplayData.fromJson(Map<String, dynamic> j) {
    List<dynamic> rawItems = const [];
    for (final key in ['items', 'lines', 'products', 'order_items']) {
      final v = j[key];
      if (v is List) {
        rawItems = v;
        break;
      }
    }
    final nested = j['invoice'] ?? j['order'] ?? j['data'];
    Map<String, dynamic>? nestMap =
        nested is Map<String, dynamic> ? nested : null;

    final items = <VendorPosDisplayLine>[
      ...rawItems.whereType<Map>().map(
            (e) => VendorPosDisplayLine.fromJson(Map<String, dynamic>.from(e)),
          ),
    ];

    if (items.isEmpty && nestMap != null) {
      for (final key in ['items', 'lines', 'products']) {
        final v = nestMap[key];
        if (v is List) {
          items.addAll(
            v.whereType<Map>().map(
                  (e) => VendorPosDisplayLine.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                ),
          );
          break;
        }
      }
    }

    final vendorName = (j['vendor_name'] ??
            j['store_name'] ??
            j['shop_name'] ??
            nestMap?['vendor_name'] ??
            '')
        .toString()
        .trim();

    double total = _toDouble(
      j['total'] ??
          j['payable'] ??
          j['grand_total'] ??
          nestMap?['total'] ??
          nestMap?['payable'],
    );
    if (total <= 0 && items.isNotEmpty) {
      total = items.fold<double>(0, (s, e) => s + e.lineTotal);
    }

    final orderNumber = (j['order_number'] ??
            nestMap?['order_number'] ??
            j['invoice_number'])
        ?.toString();
    final invoiceId = _toIntOrNull(j['invoice_id'] ?? j['id'] ?? nestMap?['id']);

    return VendorPosDisplayData(
      vendorName: vendorName.isEmpty ? 'Store' : vendorName,
      items: items,
      total: total,
      orderNumber: orderNumber,
      invoiceId: invoiceId,
      source: 'api',
    );
  }

  static VendorPosDisplayData empty({String vendorName = 'Store'}) =>
      VendorPosDisplayData(
        vendorName: vendorName,
        items: const [],
        total: 0,
      );
}

/// Live walk-in session shared with the customer display route.
class VendorPosCartSession {
  const VendorPosCartSession({
    this.vendorName = 'Store',
    this.items = const [],
    this.invoiceId,
    this.orderNumber,
  });

  final String vendorName;
  final List<VendorPosDisplayLine> items;
  final int? invoiceId;
  final String? orderNumber;

  double get total => items.fold<double>(0, (s, e) => s + e.lineTotal);

  VendorPosDisplayData toDisplayData() => VendorPosDisplayData(
        vendorName: vendorName.isEmpty ? 'Store' : vendorName,
        items: items,
        total: total,
        invoiceId: invoiceId,
        orderNumber: orderNumber,
        source: 'local',
      );

  VendorPosCartSession copyWith({
    String? vendorName,
    List<VendorPosDisplayLine>? items,
    int? invoiceId,
    String? orderNumber,
    bool clearInvoice = false,
  }) {
    return VendorPosCartSession(
      vendorName: vendorName ?? this.vendorName,
      items: items ?? this.items,
      invoiceId: clearInvoice ? null : (invoiceId ?? this.invoiceId),
      orderNumber: orderNumber ?? this.orderNumber,
    );
  }
}

int _toInt(dynamic v, {int d = 0}) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  final n = _toInt(v, d: -1);
  return n < 0 ? null : n;
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '')) ?? 0;
}
