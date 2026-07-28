class VendorProduct {
  final int id;
  final String name;
  final String description;
  final String regularPrice;
  final String sellPrice;
  final String regularPriceDisplay;
  final String sellPriceDisplay;
  final String currency;
  final String displayCurrency;
  final String image;
  final int vendorId;
  final int categoryId;
  final String categoryName;

  final List<String> sizes;
  final List<String> colors;
  final List<ProductImage> images;
  final int? stock;
  final String? weight; // weight value
  final String weightUnit;
  final String? length;
  final String? width;
  final String? height;
  final String dimensionUnit;
  final String? saleType;
  final String? termsAndConditions;
  final String? barcode;
  final String? attributes; // JSON string: {"color":["red"],"size":["m"]}
  final int? viewCount; // number of views

  VendorProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.regularPrice,
    required this.sellPrice,
    this.regularPriceDisplay = '',
    this.sellPriceDisplay = '',
    this.currency = 'UGX',
    this.displayCurrency = 'UGX',
    required this.image,
    required this.vendorId,
    required this.categoryId,
    required this.categoryName,
    required this.sizes,
    required this.colors,
    required this.images,
    this.stock,
    this.weight,
    this.weightUnit = 'kg',
    this.length,
    this.width,
    this.height,
    this.dimensionUnit = 'cm',
    this.saleType,
    this.termsAndConditions,
    this.barcode,
    this.attributes,
    this.viewCount,
  });

  factory VendorProduct.fromJson(Map<String, dynamic> json) {
    final rawSize = json['measurement'] ?? json['size'];
    final rawColor = json['color'];

    // Helper to safely convert to int
    int toInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is num) return value.toInt();
      return defaultValue;
    }

    List<String> toStringList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.trim().isNotEmpty) return [raw];
      return [];
    }

    String? optString(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return VendorProduct(
      id: toInt(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      regularPrice: json['regular_price']?.toString() ?? '',
      sellPrice: json['sell_price']?.toString() ?? '',
      regularPriceDisplay:
          (json['regular_price_display'] ?? json['regular_price'])
                  ?.toString() ??
              '',
      sellPriceDisplay:
          (json['sell_price_display'] ?? json['sell_price'])?.toString() ?? '',
      currency: json['currency']?.toString().trim().isNotEmpty == true
          ? json['currency'].toString().trim()
          : 'UGX',
      displayCurrency:
          json['display_currency']?.toString().trim().isNotEmpty == true
              ? json['display_currency'].toString().trim()
              : (json['currency']?.toString().trim().isNotEmpty == true
                  ? json['currency'].toString().trim()
                  : 'UGX'),
      image: json['image']?.toString() ?? '',
      vendorId: toInt(json['vendor_id']),
      categoryId: toInt(json['category_id']),
      categoryName: json['category']?['name']?.toString() ?? '',

      /// ✅ Safe list conversion
      sizes: toStringList(rawSize),
      colors: toStringList(rawColor),

      /// ✅ images mapping - ensure it's a List, not a Map
      images: () {
        final imagesField = json['images'];
        if (imagesField is List) {
          return imagesField
              .whereType<Map>()
              .map((e) => ProductImage.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
        return <ProductImage>[];
      }(),
      stock: json['stock'] == null 
          ? null 
          : (json['stock'] is int 
              ? json['stock'] as int 
              : (json['stock'] is num 
                  ? (json['stock'] as num).toInt() 
                  : int.tryParse(json['stock'].toString()))),
      weight: json['weight']?.toString(),
      weightUnit: () {
        final u = json['weight_unit']?.toString().trim();
        return (u == null || u.isEmpty) ? 'kg' : u;
      }(),
      length: optString(json['length']),
      width: optString(json['width']),
      height: optString(json['height']),
      dimensionUnit: () {
        final u = json['dimension_unit']?.toString().trim();
        return (u == null || u.isEmpty) ? 'cm' : u;
      }(),
      saleType: optString(json['sale_type']),
      termsAndConditions: optString(json['terms_and_conditions']),
      barcode: optString(json['barcode']),
      attributes: json['attributes']?.toString(),
      viewCount: () {
        // Try multiple field names that API might use
        final views = json['view_count'] ?? json['views'] ?? json['view'];
        if (views == null) return null;
        if (views is int) return views;
        if (views is num) return views.toInt();
        final parsed = int.tryParse(views.toString());
        return parsed != null && parsed > 0 ? parsed : null;
      }(),
    );
  }
}

class PaginatedProducts {
  final int currentPage;
  final int lastPage;
  final int total;
  final List<VendorProduct> products;

  PaginatedProducts({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.products,
  });

  factory PaginatedProducts.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to int
    int toInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is num) return value.toInt();
      return defaultValue;
    }

    // Safely extract products list
    List<VendorProduct> productsList = [];
    final dataField = json['data'];
    
    if (dataField is List) {
      // If 'data' is a List, map it directly
      productsList = dataField
          .whereType<Map>()
          .map((e) => VendorProduct.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else if (dataField is Map) {
      // If 'data' is a Map, it might contain nested data
      // This shouldn't happen in normal cases, but handle it safely
      productsList = [];
    }

    return PaginatedProducts(
      currentPage: toInt(json['current_page'], defaultValue: 1),
      lastPage: toInt(json['last_page'], defaultValue: 1),
      total: toInt(json['total']),
      products: productsList,
    );
  }
}

//
// class PaginatedProducts {
//   final int currentPage;
//   final int lastPage;
//   final int total;
//   final List<Product> products;
//
//   PaginatedProducts({
//     required this.currentPage,
//     required this.lastPage,
//     required this.total,
//     required this.products,
//   });
//
//   factory PaginatedProducts.fromJson(Map<String, dynamic> json) {
//     final data = json['products'];
//     return PaginatedProducts(
//       currentPage: data['current_page'],
//       lastPage: data['last_page'],
//       total: data['total'],
//       products: (data['data'] as List<dynamic>)
//           .map((e) => Product.fromJson(e as Map<String, dynamic>))
//           .toList(),
//     );
//   }
// }
class ProductImage {
  final int id;
  final String imagePath;
  final int productId;

  ProductImage({
    required this.id,
    required this.imagePath,
    required this.productId,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert to int
    int toInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is num) return value.toInt();
      return defaultValue;
    }

    return ProductImage(
      id: toInt(json['id']),
      imagePath: json['image_path']?.toString() ?? '',
      productId: toInt(json['product_id']),
    );
  }
}