/// Model for one subscription plan from GET /api/subscription/plans
class SubscriptionPlanModel {
  final int id;
  final String name;
  final String description;
  final String price;
  final String currency;
  final String billingPeriod;
  final int categoryLimit;
  final int imageLimit;
  final int visibilityLimit;
  final bool hasAffiliate;
  final bool hasPriorityRanking;
  final int priorityBoost;
  final String forUserType;
  final String status;
  final int sortOrder;

  /// Zone Management zone name; `null` / empty = global plan (STEP_06).
  final String? region;

  /// Driver delivery zone name; `null` / empty = global plan (STEP_06).
  final String? deliveryZone;

  final bool hasMarketplace;
  final bool hasWalkIn;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.billingPeriod,
    required this.categoryLimit,
    required this.imageLimit,
    required this.visibilityLimit,
    required this.hasAffiliate,
    required this.hasPriorityRanking,
    required this.priorityBoost,
    required this.forUserType,
    required this.status,
    required this.sortOrder,
    this.region,
    this.deliveryZone,
    this.hasMarketplace = false,
    this.hasWalkIn = false,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    String? nullableString(dynamic v) {
      final s = v?.toString().trim();
      if (s == null || s.isEmpty || s.toLowerCase() == 'null') return null;
      return s;
    }

    bool asBool(dynamic v) {
      if (v == true || v == 1 || v == '1') return true;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    return SubscriptionPlanModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'USD',
      billingPeriod: json['billing_period']?.toString() ?? 'monthly',
      categoryLimit: (json['category_limit'] as num?)?.toInt() ?? 0,
      imageLimit: (json['image_limit'] as num?)?.toInt() ?? 0,
      visibilityLimit: (json['visibility_limit'] as num?)?.toInt() ?? 0,
      hasAffiliate: asBool(json['has_affiliate']),
      hasPriorityRanking: asBool(json['has_priority_ranking']),
      priorityBoost: (json['priority_boost'] as num?)?.toInt() ?? 0,
      forUserType: json['for_user_type']?.toString() ?? 'vendor',
      status: json['status']?.toString() ?? 'active',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      region: nullableString(json['region']),
      deliveryZone: nullableString(
        json['delivery_zone'] ?? json['deliveryZone'],
      ),
      hasMarketplace: asBool(json['has_marketplace'] ?? json['hasMarketplace']),
      hasWalkIn: asBool(json['has_walk_in'] ?? json['hasWalkIn']),
    );
  }

  bool get isGlobalForVendor => region == null || region!.trim().isEmpty;

  bool get isGlobalForDriver =>
      deliveryZone == null || deliveryZone!.trim().isEmpty;

  String get priceLabel =>
      '$currency $price/${billingPeriod == 'monthly' ? 'mo' : 'yr'}';
}
