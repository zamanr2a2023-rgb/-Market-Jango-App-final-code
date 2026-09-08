class PaginatedBanners {
  final int currentPage;
  final int lastPage;
  final int total;
  final List<BannerItem> banners;

  PaginatedBanners({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.banners,
  });

  factory PaginatedBanners.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final banners = <BannerItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          banners.add(BannerItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return PaginatedBanners(
      currentPage: json['current_page'] is int
          ? json['current_page'] as int
          : int.tryParse('${json['current_page'] ?? ''}') ?? 1,
      lastPage: json['last_page'] is int
          ? json['last_page'] as int
          : int.tryParse('${json['last_page'] ?? ''}') ?? 1,
      total: json['total'] is int
          ? json['total'] as int
          : int.tryParse('${json['total'] ?? ''}') ?? 0,
      banners: banners,
    );
  }
}

class BannerItem {
  final int id;
  final String name;
  final String description;
  final String discount;
  final String image;
  final String publicId;
  final int productId;
  final String createdAt;
  final String updatedAt;
  final BenarProduct? product;

  BannerItem({
    required this.id,
    required this.name,
    required this.description,
    required this.discount,
    required this.image,
    required this.publicId,
    required this.productId,
    required this.createdAt,
    required this.updatedAt,
    required this.product,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? productMap;
    final rawProduct = json['product'];
    if (rawProduct is Map) {
      productMap = Map<String, dynamic>.from(rawProduct);
    }

    return BannerItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}') ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discount: json['discount']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      publicId: json['public_id']?.toString() ?? '',
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse('${json['product_id'] ?? ''}') ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      product: productMap != null ? BenarProduct.fromJson(productMap) : null,
    );
  }
}

class BenarProduct {
  final int id;
  final String name;
  final String description;
  final String regularPrice;
  final String sellPrice;
  final int discount;
  final String publicId;
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

  BenarProduct({
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

  factory BenarProduct.fromJson(Map<String, dynamic> json) {
    // color এবং size কখনো array, কখনো string — তাই normalize করা হয়েছে
    List<String> parseDynamicList(dynamic data) {
      if (data == null) return <String>[];
      if (data is List) {
        return data
            .expand((e) => e.toString().split(','))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .map((e) => e.toString())
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
      return <String>[];
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return BenarProduct(
      id: toInt(json['id']),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      regularPrice: json['regular_price']?.toString() ?? '',
      sellPrice: json['sell_price']?.toString() ?? '',
      discount: toInt(json['discount']),
      publicId: json['public_id']?.toString() ?? '',
      star: toInt(json['star']),
      image: json['image']?.toString() ?? '',
      color: parseDynamicList(json['color']),
      size: parseDynamicList(json['size']),
      remark: json['remark']?.toString() ?? '',
      isActive: toInt(json['is_active']),
      vendorId: toInt(json['vendor_id']),
      categoryId: toInt(json['category_id']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}
