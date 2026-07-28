class FollowingItem {
  final String followableType;
  final int followableId;
  final int userId;
  final String name;
  final String? businessName;
  final String? image;
  final String? followedAt;

  const FollowingItem({
    required this.followableType,
    required this.followableId,
    required this.userId,
    required this.name,
    this.businessName,
    this.image,
    this.followedAt,
  });

  bool get isVendor => followableType.toLowerCase() == 'vendor';
  bool get isDriver => followableType.toLowerCase() == 'driver';

  String get displayName {
    final business = businessName?.trim() ?? '';
    if (business.isNotEmpty) return business;
    final n = name.trim();
    return n.isNotEmpty ? n : (isVendor ? 'Vendor' : 'Driver');
  }

  String get subtitle {
    if (isVendor) {
      final n = name.trim();
      if (n.isNotEmpty && n != displayName) return n;
      return 'Vendor';
    }
    return 'Driver';
  }

  factory FollowingItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    String asString(dynamic v) => v?.toString() ?? '';

    return FollowingItem(
      followableType: asString(json['followable_type']).toLowerCase(),
      followableId: asInt(json['followable_id']),
      userId: asInt(json['user_id']),
      name: asString(json['name']),
      businessName: json['business_name']?.toString(),
      image: json['image']?.toString(),
      followedAt: json['followed_at']?.toString(),
    );
  }
}

class FollowingListResult {
  final List<FollowingItem> items;
  final int total;
  final int currentPage;
  final int lastPage;
  final int perPage;

  const FollowingListResult({
    required this.items,
    required this.total,
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 15,
  });

  factory FollowingListResult.fromJson(Map<String, dynamic>? data) {
    if (data == null) {
      return const FollowingListResult(items: [], total: 0);
    }

    final raw = data['data'];
    final items = (raw is List)
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(FollowingItem.fromJson)
            .toList()
        : <FollowingItem>[];

    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

    return FollowingListResult(
      items: items,
      total: asInt(data['total']),
      currentPage: asInt(data['current_page'] ?? 1),
      lastPage: asInt(data['last_page'] ?? 1),
      perPage: asInt(data['per_page'] ?? 15),
    );
  }

  /// Buyer → vendors only; transport → drivers only.
  FollowingListResult forUserType(String? userType) {
    final type = (userType ?? '').trim().toLowerCase();
    if (type == 'buyer') {
      final vendors = items.where((e) => e.isVendor).toList();
      return FollowingListResult(
        items: vendors,
        total: vendors.length,
        currentPage: currentPage,
        lastPage: lastPage,
        perPage: perPage,
      );
    }
    if (type == 'transport') {
      final drivers = items.where((e) => e.isDriver).toList();
      return FollowingListResult(
        items: drivers,
        total: drivers.length,
        currentPage: currentPage,
        lastPage: lastPage,
        perPage: perPage,
      );
    }
    return this;
  }
}
