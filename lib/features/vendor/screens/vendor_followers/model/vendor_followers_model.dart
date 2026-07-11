int _toInt(dynamic v, {int d = 0}) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

String _s(dynamic v) => v?.toString() ?? '';

String? _nullableString(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

class VendorFollower {
  final int id;
  final String name;
  final String? image;
  final String userType;
  final String? followedAt;

  const VendorFollower({
    required this.id,
    required this.name,
    this.image,
    required this.userType,
    this.followedAt,
  });

  factory VendorFollower.fromJson(Map<String, dynamic> j) {
    return VendorFollower(
      id: _toInt(j['id']),
      name: _s(j['name']),
      image: _nullableString(j['image']),
      userType: _s(j['user_type']),
      followedAt: _nullableString(j['followed_at']),
    );
  }
}

class VendorFollowersPage {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final String? nextPageUrl;
  final List<VendorFollower> items;

  const VendorFollowersPage({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.nextPageUrl,
    required this.items,
  });

  factory VendorFollowersPage.empty() => const VendorFollowersPage(
        currentPage: 1,
        lastPage: 1,
        perPage: 15,
        total: 0,
        items: [],
      );

  factory VendorFollowersPage.fromJson(Map<String, dynamic>? j) {
    if (j == null) return VendorFollowersPage.empty();
    final list = (j['data'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VendorFollower.fromJson)
        .toList();
    return VendorFollowersPage(
      currentPage: _toInt(j['current_page'], d: 1),
      lastPage: _toInt(j['last_page'], d: 1),
      perPage: _toInt(j['per_page'], d: 15),
      total: _toInt(j['total']),
      nextPageUrl: _nullableString(j['next_page_url']),
      items: list,
    );
  }

  bool get hasMore => nextPageUrl != null && nextPageUrl!.isNotEmpty;
}

class VendorFollowersResult {
  final int followersCount;
  final VendorFollowersPage followers;
  final bool? isFollowing;

  const VendorFollowersResult({
    required this.followersCount,
    required this.followers,
    this.isFollowing,
  });

  factory VendorFollowersResult.empty() => VendorFollowersResult(
        followersCount: 0,
        followers: VendorFollowersPage.empty(),
      );

  factory VendorFollowersResult.fromJson(Map<String, dynamic>? j) {
    if (j == null) return VendorFollowersResult.empty();
    final page = j['followers'];
    bool? following;
    final raw = j['is_following'] ?? j['following'] ?? j['is_followed'];
    if (raw is bool) {
      following = raw;
    } else if (raw != null) {
      final s = raw.toString().toLowerCase();
      if (s == '1' || s == 'true') following = true;
      if (s == '0' || s == 'false') following = false;
    }
    return VendorFollowersResult(
      followersCount: _toInt(j['followers_count']),
      followers: VendorFollowersPage.fromJson(
        page is Map<String, dynamic> ? page : null,
      ),
      isFollowing: following,
    );
  }
}
