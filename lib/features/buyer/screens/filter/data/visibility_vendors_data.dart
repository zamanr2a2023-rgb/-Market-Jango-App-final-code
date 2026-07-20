import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

class VisibilityVendorsParams {
  final String zone;
  final String? state;
  final String? town;
  final int perPage;

  const VisibilityVendorsParams({
    required this.zone,
    this.state,
    this.town,
    this.perPage = 20,
  });

  bool get isValid => zone.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibilityVendorsParams &&
          zone == other.zone &&
          state == other.state &&
          town == other.town &&
          perPage == other.perPage;

  @override
  int get hashCode => Object.hash(zone, state, town, perPage);
}

class CategoryVendorsParams {
  final int categoryId;
  final String? categoryName;
  final String? zone;
  final String? state;
  final String? town;
  final int perPage;

  const CategoryVendorsParams({
    required this.categoryId,
    this.categoryName,
    this.zone,
    this.state,
    this.town,
    this.perPage = 20,
  });

  bool get isValid => categoryId > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryVendorsParams &&
          categoryId == other.categoryId &&
          categoryName == other.categoryName &&
          zone == other.zone &&
          state == other.state &&
          town == other.town &&
          perPage == other.perPage;

  @override
  int get hashCode =>
      Object.hash(categoryId, categoryName, zone, state, town, perPage);
}

enum VendorFilterType { location, category }

class AvailableVendorsScreenArgs {
  final VendorFilterType type;
  final VisibilityVendorsParams? locationParams;
  final CategoryVendorsParams? categoryParams;

  const AvailableVendorsScreenArgs._({
    required this.type,
    this.locationParams,
    this.categoryParams,
  });

  factory AvailableVendorsScreenArgs.location(VisibilityVendorsParams params) {
    return AvailableVendorsScreenArgs._(
      type: VendorFilterType.location,
      locationParams: params,
    );
  }

  factory AvailableVendorsScreenArgs.category(CategoryVendorsParams params) {
    return AvailableVendorsScreenArgs._(
      type: VendorFilterType.category,
      categoryParams: params,
    );
  }
}

class VisibilityVendorItem {
  final int vendorId;
  final int userId;
  final String name;
  final String? image;
  final String? country;
  final String? businessType;
  final double? avgRating;
  final String? address;
  final String? visibilityLocation;

  const VisibilityVendorItem({
    required this.vendorId,
    required this.userId,
    required this.name,
    this.image,
    this.country,
    this.businessType,
    this.avgRating,
    this.address,
    this.visibilityLocation,
  });

  factory VisibilityVendorItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    String asString(dynamic v) => v?.toString() ?? '';

    final vendorId = asInt(json['vendor_id'] ?? json['vendorId'] ?? json['id']);
    final userJson = json['user'];
    final userId = userJson is Map<String, dynamic>
        ? asInt(userJson['id'])
        : asInt(json['user_id'] ?? json['userId']);

    final businessName = asString(json['business_name']);
    final userName =
        userJson is Map<String, dynamic> ? asString(userJson['name']) : '';
    final name = businessName.isNotEmpty
        ? businessName
        : (userName.isNotEmpty ? userName : 'Vendor');

    final coverImage = asString(json['cover_image']);
    final userImage =
        userJson is Map<String, dynamic> ? asString(userJson['image']) : '';
    final legacyImage = asString(json['image']);
    final image = coverImage.isNotEmpty
        ? coverImage
        : (userImage.isNotEmpty ? userImage : legacyImage);

    String? visibilityLocation;
    final visibility = json['visibility'];
    if (visibility is Map<String, dynamic>) {
      final parts = [
        visibility['town'],
        visibility['state'],
        visibility['zone'],
      ]
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) visibilityLocation = parts.join(', ');
    }

    return VisibilityVendorItem(
      vendorId: vendorId,
      userId: userId,
      name: name,
      image: image.isNotEmpty ? image : null,
      country: json['country']?.toString(),
      businessType: json['business_type']?.toString(),
      avgRating: double.tryParse('${json['avg_rating'] ?? ''}'),
      address: json['address']?.toString(),
      visibilityLocation: visibilityLocation,
    );
  }
}

Future<List<VisibilityVendorItem>> _fetchVisibilityVendors(String url) async {
  final authStorage = AuthLocalStorage();
  final t = await authStorage.getToken();

  final res = await http.get(
    Uri.parse(url),
    headers: {
      'Accept': 'application/json',
      if (t != null && t.isNotEmpty) 'token': t,
    },
  );

  final map = jsonDecode(res.body);
  if (res.statusCode != 200) {
    final msg = (map is Map<String, dynamic>)
        ? (map['message']?.toString() ?? 'Failed to load vendors')
        : 'Failed to load vendors';
    throw Exception(msg);
  }

  if (map is! Map<String, dynamic>) return [];
  final data = map['data'];
  if (data is! Map<String, dynamic>) return [];
  final items = data['items'];
  if (items is! List) return [];

  return items
      .whereType<Map<String, dynamic>>()
      .map(VisibilityVendorItem.fromJson)
      .toList();
}

final visibilityVendorsProvider = FutureProvider.autoDispose
    .family<List<VisibilityVendorItem>, VisibilityVendorsParams>((ref, params) async {
  if (!params.isValid) return [];

  final url = BuyerAPIController.visibilityVendors(
    zone: params.zone,
    state: params.state,
    town: params.town,
    perPage: params.perPage,
  );

  return _fetchVisibilityVendors(url);
});

final categoryVendorsProvider = FutureProvider.autoDispose
    .family<List<VisibilityVendorItem>, CategoryVendorsParams>((ref, params) async {
  if (!params.isValid) return [];

  final url = BuyerAPIController.visibilityVendorsByCategory(
    categoryId: params.categoryId,
    zone: params.zone,
    state: params.state,
    town: params.town,
    perPage: params.perPage,
  );

  return _fetchVisibilityVendors(url);
});
