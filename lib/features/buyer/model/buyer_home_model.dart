/// `GET /api/buyer/home` — guest (no token) or logged-in (token).
class BuyerHomeResponse {
  final bool hidePrices;
  final bool loginRequiredForCart;
  final List<BuyerHomeBanner> banners;
  final List<BuyerHomePopularItem> popular;
  /// Approved vendor promotions when backend includes them on home.
  final List<BuyerHomePromotion> promotions;

  const BuyerHomeResponse({
    required this.hidePrices,
    required this.loginRequiredForCart,
    required this.banners,
    required this.popular,
    this.promotions = const [],
  });

  factory BuyerHomeResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map<String, dynamic>
        ? data
        : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});

    final bannersRaw = map['banners'];
    final popularRaw = map['popular'];
    final promotionsRaw = map['promotions'] ?? map['vendor_promotions'];

    return BuyerHomeResponse(
      hidePrices: map['hide_prices'] == true,
      loginRequiredForCart: map['login_required_for_cart'] != false,
      banners: bannersRaw is List
          ? bannersRaw
              .whereType<Map>()
              .map((e) => BuyerHomeBanner.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      popular: popularRaw is List
          ? popularRaw
              .whereType<Map>()
              .map(
                (e) =>
                    BuyerHomePopularItem.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      promotions: promotionsRaw is List
          ? promotionsRaw
              .whereType<Map>()
              .map(
                (e) =>
                    BuyerHomePromotion.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
    );
  }
}

class BuyerHomeBanner {
  final int id;
  final String image;
  final String? publicId;
  final int? zoneId;
  final String? zone;
  final bool isGlobal;

  const BuyerHomeBanner({
    required this.id,
    required this.image,
    this.publicId,
    this.zoneId,
    this.zone,
    this.isGlobal = true,
  });

  factory BuyerHomeBanner.fromJson(Map<String, dynamic> j) {
    final zoneId = _toIntOrNull(j['zone_id'] ?? j['zoneId']);
    final zone = j['zone']?.toString() ?? j['ship_zone']?.toString();
    final globalFlag = j['is_global'] ?? j['global'];
    final isGlobal = globalFlag == true ||
        globalFlag == 1 ||
        globalFlag == '1' ||
        (zoneId == null && (zone == null || zone.isEmpty));

    return BuyerHomeBanner(
      id: _toInt(j['id']),
      image: j['image']?.toString() ?? '',
      publicId: j['public_id']?.toString(),
      zoneId: zoneId,
      zone: zone,
      isGlobal: isGlobal,
    );
  }
}

/// Vendor marketing promotion surfaced on buyer home (STEP_05).
class BuyerHomePromotion {
  final int id;
  final String title;
  final String content;
  final String? image;
  final String? zone;
  final int? vendorId;
  final String? vendorName;
  final String? status;

  const BuyerHomePromotion({
    required this.id,
    required this.title,
    this.content = '',
    this.image,
    this.zone,
    this.vendorId,
    this.vendorName,
    this.status,
  });

  factory BuyerHomePromotion.fromJson(Map<String, dynamic> j) {
    final vendor = j['vendor'];
    String? vendorName;
    int? vendorId = _toIntOrNull(j['vendor_id']);
    if (vendor is Map) {
      vendorName = vendor['name']?.toString() ?? vendor['shop_name']?.toString();
      vendorId ??= _toIntOrNull(vendor['id']);
    }
    return BuyerHomePromotion(
      id: _toInt(j['id']),
      title: j['title']?.toString() ?? j['name']?.toString() ?? '',
      content: j['content']?.toString() ??
          j['text']?.toString() ??
          j['description']?.toString() ??
          '',
      image: j['image']?.toString(),
      zone: j['zone']?.toString() ?? j['ship_zone']?.toString(),
      vendorId: vendorId,
      vendorName: vendorName,
      status: j['status']?.toString(),
    );
  }
}

class BuyerHomePopularItem {
  final BuyerHomeProduct product;
  final int soldQty;
  final bool outOfStock;

  const BuyerHomePopularItem({
    required this.product,
    required this.soldQty,
    required this.outOfStock,
  });

  factory BuyerHomePopularItem.fromJson(Map<String, dynamic> j) {
    final p = j['product'];
    return BuyerHomePopularItem(
      product: BuyerHomeProduct.fromJson(
        p is Map ? Map<String, dynamic>.from(p) : const {},
      ),
      soldQty: _toInt(j['sold_qty']),
      outOfStock: j['out_of_stock'] == true,
    );
  }
}

class BuyerHomeProduct {
  final int id;
  final String name;
  final String image;
  final int stock;
  final bool outOfStock;
  final bool canOpenDetail;
  final String? sellPrice;
  final String? sellPriceDisplay;
  final String? displayCurrency;
  final String? currency;

  const BuyerHomeProduct({
    required this.id,
    required this.name,
    required this.image,
    required this.stock,
    required this.outOfStock,
    required this.canOpenDetail,
    this.sellPrice,
    this.sellPriceDisplay,
    this.displayCurrency,
    this.currency,
  });

  factory BuyerHomeProduct.fromJson(Map<String, dynamic> j) {
    return BuyerHomeProduct(
      id: _toInt(j['id']),
      name: j['name']?.toString() ?? '',
      image: j['image']?.toString() ?? '',
      stock: _toInt(j['stock']),
      outOfStock: j['out_of_stock'] == true,
      canOpenDetail: j['can_open_detail'] != false,
      sellPrice: j['sell_price']?.toString(),
      sellPriceDisplay: j['sell_price_display']?.toString(),
      displayCurrency: j['display_currency']?.toString(),
      currency: j['currency']?.toString(),
    );
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final p = int.tryParse(v.toString());
  return (p != null && p > 0) ? p : null;
}
