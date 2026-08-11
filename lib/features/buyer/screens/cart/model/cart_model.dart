// cart_models.dart
import 'dart:convert';

class CartResponse {
  final String status;
  final String message;
  final Map<String, List<CartItem>> groups; // e.g. {"0":[...]}
  /// Ledger total in UGX.
  final double total;

  /// Buyer-facing total from API (`total_display`).
  final double totalDisplay;
  final String currency;
  final String displayCurrency;
  final double exchangeRate;

  CartResponse({
    required this.status,
    required this.message,
    required this.groups,
    required this.total,
    this.totalDisplay = 0,
    this.currency = 'UGX',
    this.displayCurrency = 'UGX',
    this.exchangeRate = 1,
  });

  List<CartItem> get items => groups.values.expand((e) => e).toList();

  factory CartResponse.fromRaw(String str) =>
      CartResponse.fromJson(json.decode(str));

  static const _metaKeys = {
    'total',
    'total_display',
    'currency',
    'display_currency',
    'exchange_rate',
    'cart_merchandise_subtotal',
    'cart_merchandise_subtotal_display',
    'cart_total_delivery_charge',
    'cart_total_delivery_charge_display',
    'cart_total_with_delivery_and_fees',
    'cart_total_with_delivery_and_fees_display',
  };

  factory CartResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final Map<String, List<CartItem>> parsed = {};
    double total = 0.0;
    double totalDisplay = 0.0;
    String currency = 'UGX';
    String displayCurrency = 'UGX';
    double exchangeRate = 1;

    num? toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    if (data is Map<String, dynamic>) {
      total = toNum(data['total'])?.toDouble() ?? 0.0;
      totalDisplay = toNum(data['total_display'])?.toDouble() ?? total;
      currency = data['currency']?.toString().trim().isNotEmpty == true
          ? data['currency'].toString().trim()
          : 'UGX';
      displayCurrency =
          data['display_currency']?.toString().trim().isNotEmpty == true
          ? data['display_currency'].toString().trim()
          : currency;
      exchangeRate = toNum(data['exchange_rate'])?.toDouble() ?? 1;

      data.forEach((k, v) {
        if (_metaKeys.contains(k)) return;
        if (v is List) {
          parsed[k] = v
              .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      });
    } else if (data is List) {
      parsed['0'] = data
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return CartResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      groups: parsed,
      total: total,
      totalDisplay: totalDisplay,
      currency: currency,
      displayCurrency: displayCurrency,
      exchangeRate: exchangeRate,
    );
  }
}

class CartItem {
  final int quantity;
  final String deliveryCharge;
  final String deliveryChargeDisplay;
  final String color;
  final String size;
  final String price;
  final String priceDisplay;
  final String currency;
  final String displayCurrency;
  final double exchangeRate;
  final int productId;
  final int buyerId;
  final int vendorId;
  final String status;

  final int? id;
  final String createdAt;
  final String updatedAt;

  final CardProduct product;
  final Vendor vendor;
  final Buyer buyer;

  CartItem({
    required this.quantity,
    required this.deliveryCharge,
    this.deliveryChargeDisplay = '',
    required this.color,
    required this.size,
    required this.price,
    this.priceDisplay = '',
    this.currency = 'UGX',
    this.displayCurrency = 'UGX',
    this.exchangeRate = 1,
    required this.productId,
    required this.buyerId,
    required this.vendorId,
    required this.status,
    required this.product,
    required this.vendor,
    required this.buyer,
    this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String s(dynamic v) => v?.toString() ?? '';

    num? toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    final price = s(json['price']);
    final currency = s(json['currency']).trim().isNotEmpty
        ? s(json['currency']).trim()
        : 'UGX';
    final displayCurrency = s(json['display_currency']).trim().isNotEmpty
        ? s(json['display_currency']).trim()
        : currency;

    return CartItem(
      id: json['id'] == null ? null : i(json['id']),
      quantity: i(json['quantity']),
      deliveryCharge: s(json['delivery_charge']),
      deliveryChargeDisplay: s(
        json['delivery_charge_display'] ?? json['delivery_charge'],
      ),
      color: s(json['color']),
      size: s(json['size']),
      price: price,
      priceDisplay: s(json['price_display'] ?? json['price']),
      currency: currency,
      displayCurrency: displayCurrency,
      exchangeRate: toNum(json['exchange_rate'])?.toDouble() ?? 1,
      productId: i(json['product_id']),
      buyerId: i(json['buyer_id']),
      vendorId: i(json['vendor_id']),
      status: s(json['status']),
      product: CardProduct.fromJson(json['product'] ?? {}),
      vendor: Vendor.fromJson(json['vendor'] ?? {}),
      buyer: Buyer.fromJson(json['buyer'] ?? {}),
      createdAt: s(json['created_at']),
      updatedAt: s(json['updated_at']),
    );
  }
}

class CardProduct {
  final int id;
  final String name;
  final String description;
  final String regularPrice;
  final String sellPrice;
  final int discount;
  final String? publicId;
  final int star;
  final String image;
  final List<String> color;
  final List<String> size;
  final String remark;
  final int isActive;
  final int vendorId;
  final int categoryId;
  final String createdAt;
  final String updatedAt;

  CardProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.regularPrice,
    required this.sellPrice,
    required this.discount,
    required this.publicId,
    required this.star,
    required this.image,
    required this.color,
    required this.size,
    required this.remark,
    required this.isActive,
    required this.vendorId,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CardProduct.fromJson(Map<String, dynamic> json) {
    List<String> list(dynamic data) {
      if (data == null) return [];
      if (data is List) {
        return data
            .expand((e) => e.toString().split(','))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (data is String) {
        return data
            .replaceAll('"', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    int i(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String s(dynamic v) => v?.toString() ?? '';

    return CardProduct(
      id: i(json['id']),
      name: s(json['name']),
      description: s(json['description']),
      regularPrice: s(json['regular_price']),
      sellPrice: s(json['sell_price']),
      discount: i(json['discount']),
      publicId: json['public_id']?.toString(),
      star: i(json['star']),
      image: s(json['image']),
      color: list(json['color']),
      size: list(json['size']),
      remark: s(json['remark']),
      isActive: i(json['is_active']),
      vendorId: i(json['vendor_id']),
      categoryId: i(json['category_id']),
      createdAt: s(json['created_at']),
      updatedAt: s(json['updated_at']),
    );
  }
}

class Vendor {
  final int id;
  final String country;
  final String address;
  final String businessName;
  final String businessType;
  final int userId;
  final String createdAt;
  final String updatedAt;

  Vendor({
    required this.id,
    required this.country,
    required this.address,
    required this.businessName,
    required this.businessType,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    int i(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);

    return Vendor(
      id: i(json['id']),
      country: s(json['country']),
      address: s(json['address']),
      businessName: s(json['business_name']),
      businessType: s(json['business_type']),
      userId: i(json['user_id']),
      createdAt: s(json['created_at']),
      updatedAt: s(json['updated_at']),
    );
  }
}

class Buyer {
  final int id;
  final String gender;
  final String? age;

  // billing/basic
  final String address;
  final String? state;
  final String? postcode;
  final String? country;

  // shipping
  final String? shipName;
  final String? shipEmail;
  final String? shipAddress;
  final String? shipCity;
  final String? shipState;
  final String? shipZone;
  final String? shipTown;
  final String? shipCountry;
  final String? shipPhone;
  final String? shipLocation;

  // misc
  final String? description;
  final String? location;
  final int userId;
  final String createdAt;
  final String updatedAt;

  Buyer({
    required this.id,
    required this.gender,
    required this.age,
    required this.address,
    required this.state,
    required this.postcode,
    required this.country,
    required this.shipName,
    required this.shipEmail,
    required this.shipAddress,
    required this.shipCity,
    required this.shipState,
    required this.shipZone,
    required this.shipTown,
    required this.shipCountry,
    required this.shipPhone,
    required this.shipLocation,
    required this.description,
    required this.location,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Buyer.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    int i(dynamic v) => v is int ? v : (int.tryParse('$v') ?? 0);

    return Buyer(
      id: i(json['id']),
      gender: s(json['gender']),
      age: s(json['age']),
      address: s(json['address']),
      state: s(json['state']),
      postcode: s(json['postcode']),
      country: s(json['country']),

      shipName: s(json['ship_name']),
      shipEmail: s(json['ship_email']),
      shipAddress: s(json['ship_address']),
      shipCity: s(json['ship_city']),
      shipState: s(json['ship_state']),
      shipZone: s(json['ship_zone']),
      shipTown: s(json['ship_town']),
      shipCountry: s(json['ship_country']),
      shipPhone: s(json['ship_phone']),
      shipLocation: s(json['ship_location']),

      description: s(json['description']),
      location: s(json['location']),
      userId: i(json['user_id']),
      createdAt: s(json['created_at']),
      updatedAt: s(json['updated_at']),
    );
  }
}
