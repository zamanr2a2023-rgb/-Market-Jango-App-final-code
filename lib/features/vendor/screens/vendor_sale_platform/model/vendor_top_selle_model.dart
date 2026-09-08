// vendor_top_products_model.dart
import 'dart:convert';

VendorTopProductsResponse vendorTopProductsResponseFromJson(String s) =>
    VendorTopProductsResponse.fromJson(jsonDecode(s) as Map<String, dynamic>);

class VendorTopProductsResponse {
  final String status;
  final String? message;
  final VendorTopSelleData data;

  VendorTopProductsResponse({
    required this.status,
    this.message,
    required this.data,
  });

  factory VendorTopProductsResponse.fromJson(Map<String, dynamic> j) {
    // API: { status, message, data: { products: [ ... ] } }
    final dataMap = j['data'] as Map<String, dynamic>? ?? {};
    return VendorTopProductsResponse(
      status: (j['status'] ?? '').toString(),
      message: j['message']?.toString(),
      data: VendorTopSelleData.fromJson(dataMap),
    );
  }
}

class VendorTopSelleData {
  final List<TopProductItem> products;

  VendorTopSelleData({required this.products});

  factory VendorTopSelleData.fromJson(Map<String, dynamic> j) {
    final list = (j['products'] as List? ?? [])
        .map((e) => TopProductItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return VendorTopSelleData(products: list);
  }
}

class TopProductItem {
  final int? productId;
  final String name;
  final int totalQuantity;
  final double totalRevenue;

  /// Historical / sale-time unit buying cost from API (never current product cost).
  final double? buyingPrice;

  /// Prefer API profit when present (already uses old cost).
  final double? profit;

  TopProductItem({
    required this.productId,
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
    this.buyingPrice,
    this.profit,
  });

  /// Total cost for sold qty when unit buying price is known.
  double? get totalCost {
    if (buyingPrice == null) return null;
    return buyingPrice! * totalQuantity;
  }

  /// Historical-safe profit:
  /// 1) API `profit` / `total_profit`
  /// 2) else revenue − (unitCost × qty)
  double? get displayProfit {
    if (profit != null) return profit;
    final cost = totalCost;
    if (cost == null) return null;
    return totalRevenue - cost;
  }

  factory TopProductItem.fromJson(Map<String, dynamic> j) {
    final buy = _firstDouble(j, const [
      'buying_price',
      'unit_buying_price',
      'historical_buying_price',
      'cost',
      'unit_cost',
    ]);
    final profitVal = _firstDouble(j, const [
      'profit',
      'total_profit',
    ]);

    return TopProductItem(
      productId: j['product_id'] == null ? null : _toInt(j['product_id']),
      name: (j['name'] ?? '').toString(),
      totalQuantity: _toInt(j['total_quantity']),
      totalRevenue: _toDouble(j['total_revenue']),
      buyingPrice: buy,
      profit: profitVal,
    );
  }
}

double? _firstDouble(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (!j.containsKey(k) || j[k] == null) continue;
    return _toDouble(j[k]);
  }
  return null;
}

int _toInt(dynamic v) =>
    v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

double _toDouble(dynamic v) => v == null
    ? 0.0
    : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
