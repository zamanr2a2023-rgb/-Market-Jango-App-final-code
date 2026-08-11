import 'dart:convert';

/// ---------- Pagination link ----------
class PageLink {
  final String? url;
  final String label;
  final int? page;
  final bool active;

  const PageLink({
    required this.url,
    required this.label,
    required this.page,
    required this.active,
  });

  factory PageLink.fromJson(Map<String, dynamic> json) {
    // Safely convert to Map<String, dynamic> to handle Map<dynamic, dynamic>
    final safeJson = Map<String, dynamic>.from(json);
    return PageLink(
      url: safeJson['url'],
      label: safeJson['label']?.toString() ?? '',
      page: safeJson['page'] is int ? safeJson['page'] as int : int.tryParse('${safeJson['page'] ?? ''}'),
      active: safeJson['active'] == true,
    );
  }
}

/// ---------- Top-level response (status + message + products + vendors) ----------
class GlobalSearchResponse {
  final String status;
  final String message;

  // Pagination meta (from products page)
  final int currentPage;
  final String? firstPageUrl;
  final int? from;
  final int lastPage;
  final String? lastPageUrl;
  final List<PageLink> links;
  final String? nextPageUrl;
  final String path;
  final int perPage;
  final String? prevPageUrl;
  final int? to;
  final int total;

  // Actual items
  final List<GlobalSearchProduct> products;
  final List<GlobalSearchVendorHit> vendors;

  GlobalSearchResponse({
    required this.status,
    required this.message,
    required this.currentPage,
    required this.firstPageUrl,
    required this.from,
    required this.lastPage,
    required this.lastPageUrl,
    required this.links,
    required this.nextPageUrl,
    required this.path,
    required this.perPage,
    required this.prevPageUrl,
    required this.to,
    required this.total,
    required this.products,
    this.vendors = const [],
  });

  factory GlobalSearchResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeMap(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }

    final data = safeMap(json['data']);

    // New shape: data.products = { paginated }, data.vendors = [...]
    // Legacy shape: data = { paginated with data[] }
    final productsPage = data['products'] is Map
        ? safeMap(data['products'])
        : data;
    final list = (productsPage['data'] is List)
        ? productsPage['data'] as List
        : (data['data'] is List && data['products'] == null)
            ? data['data'] as List
            : const [];

    final vendorsRaw = data['vendors'];
    final vendors = (vendorsRaw is List)
        ? vendorsRaw
            .whereType<Map>()
            .map((e) => GlobalSearchVendorHit.fromJson(safeMap(e)))
            .toList()
        : const <GlobalSearchVendorHit>[];

    int parsePerPage(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    int parseint(dynamic v, int fallback) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return GlobalSearchResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      currentPage: parseint(productsPage['current_page'], 1),
      firstPageUrl: productsPage['first_page_url']?.toString(),
      from: parseint(productsPage['from'], 0),
      lastPage: parseint(productsPage['last_page'], 1),
      lastPageUrl: productsPage['last_page_url']?.toString(),
      links: (productsPage['links'] is List)
          ? (productsPage['links'] as List)
              .map((e) => PageLink.fromJson(safeMap(e)))
              .toList()
          : const [],
      nextPageUrl: productsPage['next_page_url']?.toString(),
      path: productsPage['path']?.toString() ?? '',
      perPage: parsePerPage(productsPage['per_page']),
      prevPageUrl: productsPage['prev_page_url']?.toString(),
      to: parseint(productsPage['to'], 0),
      total: parseint(productsPage['total'], 0),
      products: List<GlobalSearchProduct>.from(
        list.map((x) => GlobalSearchProduct.fromJson(safeMap(x))),
      ),
      vendors: vendors,
    );
  }

  factory GlobalSearchResponse.empty() => GlobalSearchResponse(
        status: 'success',
        message: '',
        currentPage: 1,
        firstPageUrl: null,
        from: 0,
        lastPage: 1,
        lastPageUrl: null,
        links: const [],
        nextPageUrl: null,
        path: '',
        perPage: 0,
        prevPageUrl: null,
        to: 0,
        total: 0,
        products: const [],
        vendors: const [],
      );

  /// Flat list for search overlay: Vendors section then Products section.
  List<GlobalSearchSuggestion> get suggestions {
    final out = <GlobalSearchSuggestion>[];
    if (vendors.isNotEmpty) {
      out.add(const GlobalSearchSuggestion.header('Vendors'));
      for (final v in vendors) {
        out.add(GlobalSearchSuggestion.vendor(v));
      }
    }
    if (products.isNotEmpty) {
      out.add(const GlobalSearchSuggestion.header('Products'));
      for (final p in products) {
        out.add(GlobalSearchSuggestion.product(p));
      }
    }
    return out;
  }
}

/// One row in buyer search overlay (section header / product / vendor).
class GlobalSearchSuggestion {
  final String? header;
  final GlobalSearchProduct? product;
  final GlobalSearchVendorHit? vendor;

  const GlobalSearchSuggestion._({this.header, this.product, this.vendor});

  const GlobalSearchSuggestion.header(String title)
      : this._(header: title);

  factory GlobalSearchSuggestion.product(GlobalSearchProduct p) =>
      GlobalSearchSuggestion._(product: p);

  factory GlobalSearchSuggestion.vendor(GlobalSearchVendorHit v) =>
      GlobalSearchSuggestion._(vendor: v);

  bool get isHeader => header != null;
  bool get isProduct => product != null;
  bool get isVendor => vendor != null;
}

/// Top-level vendor hit from search `data.vendors[]`.
class GlobalSearchVendorHit {
  final int id;
  final int userId;
  final String businessName;
  final String country;
  final String address;
  final String coverImage;
  final SearchVendorUser? user;
  final List<SearchVendorReview> reviews;

  const GlobalSearchVendorHit({
    required this.id,
    required this.userId,
    required this.businessName,
    this.country = '',
    this.address = '',
    this.coverImage = '',
    this.user,
    this.reviews = const [],
  });

  String get displayName {
    if (businessName.trim().isNotEmpty) return businessName.trim();
    final n = user?.name.trim() ?? '';
    return n.isNotEmpty ? n : 'Vendor';
  }

  String get avatarUrl {
    final u = user?.image.trim() ?? '';
    if (u.isNotEmpty) return u;
    return coverImage;
  }

  factory GlobalSearchVendorHit.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeMap(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return GlobalSearchVendorHit(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      businessName: json['business_name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      coverImage: json['cover_image']?.toString() ?? '',
      user: (json['user'] is Map)
          ? SearchVendorUser.fromJson(safeMap(json['user']))
          : null,
      reviews: (json['reviews'] is List)
          ? (json['reviews'] as List)
              .map((e) => SearchVendorReview.fromJson(safeMap(e)))
              .toList()
          : const [],
    );
  }
}

/// ---------- Product + nested objects ----------
class GlobalSearchProduct {
  final int id;
  final String name;
  final String description;
  final String image;
  final String regularPrice;
  final String sellPrice;

  // Newly added (from sample JSON)
  final List<String> size; // ["L,XL"] → normalize করে ["L","XL"]
  final List<String> color; // ["yellow,blue"] → ["yellow","blue"]
  final int? vendorId;
  final int? categoryId;
  final SearchCategory? category;
  final SearchVendor? vendor;
  final List<SearchProductImage> images;

  GlobalSearchProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.regularPrice,
    required this.sellPrice,
    this.size = const [],
    this.color = const [],
    this.vendorId,
    this.categoryId,
    this.category,
    this.vendor,
    this.images = const [],
  });

  factory GlobalSearchProduct.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeMap(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }
    return GlobalSearchProduct(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      regularPrice: json['regular_price']?.toString() ?? '',
      sellPrice: (json['sell_price'] ?? json['regular_price'] ?? '').toString(),
      size: _parseFlexibleStringList(json['size']),
      color: _parseFlexibleStringList(json['color']),
      vendorId: json['vendor_id'],
      categoryId: json['category_id'],
      category: (json['category'] is Map) ? SearchCategory.fromJson(safeMap(json['category'])) : null,
      vendor: (json['vendor'] is Map) ? SearchVendor.fromJson(safeMap(json['vendor'])) : null,
      images: (json['images'] is List)
          ? (json['images'] as List).map((e) => SearchProductImage.fromJson(safeMap(e))).toList()
          : const [],
    );
  }
}

class SearchCategory {
  final int id;
  final String name;

  const SearchCategory({required this.id, required this.name});

  factory SearchCategory.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    return SearchCategory(
      id: safeJson['id'] ?? 0,
      name: safeJson['name']?.toString() ?? '',
    );
  }
}

class SearchProductImage {
  final int id;
  final String imagePath;
  final String? publicId;
  final int? productId;

  const SearchProductImage({
    required this.id,
    required this.imagePath,
    this.publicId,
    this.productId,
  });

  factory SearchProductImage.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    return SearchProductImage(
      id: safeJson['id'] ?? 0,
      imagePath: safeJson['image_path']?.toString() ?? '',
      publicId: safeJson['public_id']?.toString(),
      productId: safeJson['product_id'],
    );
  }
}

class SearchVendor {
  final int id;
  final int? userId;
  final SearchVendorUser? user;
  final List<SearchVendorReview> reviews;

  const SearchVendor({
    required this.id,
    this.userId,
    this.user,
    this.reviews = const [],
  });

  factory SearchVendor.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> safeMap(dynamic value) {
      if (value == null) return {};
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }
    return SearchVendor(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      user: (json['user'] is Map) ? SearchVendorUser.fromJson(safeMap(json['user'])) : null,
      reviews: (json['reviews'] is List)
          ? (json['reviews'] as List).map((e) => SearchVendorReview.fromJson(safeMap(e))).toList()
          : const [],
    );
  }
}

class SearchVendorUser {
  final int id;
  final String name;
  final String image;
  final String email;
  final String phone;

  const SearchVendorUser({
    required this.id,
    required this.name,
    this.image = '',
    this.email = '',
    this.phone = '',
  });

  factory SearchVendorUser.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    return SearchVendorUser(
      id: safeJson['id'] ?? 0,
      name: safeJson['name']?.toString() ?? '',
      image: safeJson['image']?.toString() ?? '',
      email: safeJson['email']?.toString() ?? '',
      phone: safeJson['phone']?.toString() ?? '',
    );
  }
}

class SearchVendorReview {
  final int id;
  final int? vendorId;
  final String? description;
  final num? rating;

  const SearchVendorReview({
    required this.id,
    this.vendorId,
    this.description,
    this.rating,
  });

  factory SearchVendorReview.fromJson(Map<String, dynamic> json) {
    final safeJson = Map<String, dynamic>.from(json);
    return SearchVendorReview(
      id: safeJson['id'] ?? 0,
      vendorId: safeJson['vendor_id'],
      description: safeJson['description']?.toString(),
      rating: (safeJson['rating'] is num) ? safeJson['rating'] as num : num.tryParse('${safeJson['rating'] ?? ''}'),
    );
  }
}

/// --- helper: ["L,XL"] / "L,XL" / ["L","XL"] / '["L","XL"]' → ["L","XL"]
List<String> _parseFlexibleStringList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .expand((e) => e.toString().split(','))
        .map((e) => e.replaceAll(RegExp(r'[\[\]\"]'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (raw is String) {
    try {
      final j = jsonDecode(raw);
      if (j is List) return j.map((e) => e.toString()).toList();
    } catch (_) {
      // not JSON → CSV fallback
    }
    return raw
        .split(',')
        .map((e) => e.replaceAll(RegExp(r'[\[\]\"]'), '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}
