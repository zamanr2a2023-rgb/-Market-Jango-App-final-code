import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/common_api.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/features/affiliate/model/affiliate_model.dart';

// ---------------------------------------------------------------------------
// Get all affiliate links: GET /api/affiliate/links
// ---------------------------------------------------------------------------

final affiliateLinksProvider =
    AsyncNotifierProvider<AffiliateLinksNotifier, List<AffiliateLinkModel>>(
      AffiliateLinksNotifier.new,
    );

class AffiliateLinksNotifier extends AsyncNotifier<List<AffiliateLinkModel>> {
  @override
  Future<List<AffiliateLinkModel>> build() async => _fetch();

  Future<List<AffiliateLinkModel>> _fetch() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.affiliateLinks);
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString() ?? 'Failed to load links';
      throw Exception(msg);
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final data = map['data'];
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(AffiliateLinkModel.fromJson)
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

// ---------------------------------------------------------------------------
// Get statistics: GET /api/affiliate/statistics
// ---------------------------------------------------------------------------

final affiliateStatisticsProvider =
    AsyncNotifierProvider<
      AffiliateStatisticsNotifier,
      AffiliateStatisticsModel?
    >(AffiliateStatisticsNotifier.new);

class AffiliateStatisticsNotifier
    extends AsyncNotifier<AffiliateStatisticsModel?> {
  @override
  Future<AffiliateStatisticsModel?> build() async => _fetch();

  Future<AffiliateStatisticsModel?> _fetch() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.affiliateStatistics);
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString() ?? 'Failed to load statistics';
      throw Exception(msg);
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final data = map['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    return AffiliateStatisticsModel.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }
}

// ---------------------------------------------------------------------------
// GET influencer referral links: /api/vendor-dashboard/influencer-referral-links
// ---------------------------------------------------------------------------

/// Interface for vendor/driver influencer link notifiers (refresh, approve, delete).
abstract class InfluencerReferralLinksNotifierInterface {
  Future<void> refresh();
  Future<void> approveLink(int id);
  Future<void> deleteLink(int id);
}

final influencerReferralLinksProvider =
    AsyncNotifierProvider<
      InfluencerReferralLinksNotifier,
      List<InfluencerReferralLinkModel>
    >(InfluencerReferralLinksNotifier.new);

class InfluencerReferralLinksNotifier
    extends AsyncNotifier<List<InfluencerReferralLinkModel>>
    implements InfluencerReferralLinksNotifierInterface {
  @override
  Future<List<InfluencerReferralLinkModel>> build() async => _fetch();

  Future<List<InfluencerReferralLinkModel>> _fetch() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.influencerReferralLinks);
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg =
          map?['message']?.toString() ?? 'Failed to load influencer links';
      throw Exception(msg);
    }

    final body = jsonDecode(res.body);
    List<dynamic> list = [];
    if (body is List) {
      list = body;
    } else if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        list = data['items'] as List;
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(InfluencerReferralLinkModel.fromJson)
        .toList();
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  /// POST approve influencer referral link
  @override
  Future<void> approveLink(int id) async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.influencerApproveLink(id));
    final res = await http.post(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString() ?? 'Failed to approve link';
      throw Exception(msg);
    }
    await refresh();
  }

  /// DELETE influencer referral link
  @override
  Future<void> deleteLink(int id) async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.influencerDeleteLink(id));
    final res = await http.delete(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString() ?? 'Failed to delete link';
      throw Exception(msg);
    }
    await refresh();
  }

}

// ---------------------------------------------------------------------------
// GET influencer referral links (driver): /api/driver-dashboard/influencer-referral-links
// ---------------------------------------------------------------------------

final driverInfluencerReferralLinksProvider =
    AsyncNotifierProvider<
      DriverInfluencerReferralLinksNotifier,
      List<InfluencerReferralLinkModel>>(DriverInfluencerReferralLinksNotifier.new);

class DriverInfluencerReferralLinksNotifier
    extends AsyncNotifier<List<InfluencerReferralLinkModel>>
    implements InfluencerReferralLinksNotifierInterface {
  @override
  Future<List<InfluencerReferralLinkModel>> build() async => _fetch();

  Future<List<InfluencerReferralLinkModel>> _fetch() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.driverDashboardInfluencerReferralLinks);
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg =
          map?['message']?.toString() ?? 'Failed to load influencer links';
      throw Exception(msg);
    }

    final body = jsonDecode(res.body);
    List<dynamic> list = [];
    if (body is List) {
      list = body;
    } else if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        list = data['items'] as List;
      }
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(InfluencerReferralLinkModel.fromJson)
        .toList();
  }

  @override
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  @override
  Future<void> approveLink(int id) async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.driverInfluencerApproveLink(id));
    final res = await http.post(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString() ?? 'Failed to approve link';
      throw Exception(msg);
    }
    await refresh();
  }

  @override
  Future<void> deleteLink(int id) async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) throw Exception('Not logged in');

    final uri = Uri.parse(CommonAPIController.driverInfluencerDeleteLink(id));
    final res = await http.delete(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString() ?? 'Failed to delete link';
      throw Exception(msg);
    }
    await refresh();
  }

}

// ---------------------------------------------------------------------------
// Get link details: GET /api/affiliate/link/{id}
// ---------------------------------------------------------------------------

final affiliateLinkDetailProvider = FutureProvider.autoDispose
    .family<AffiliateLinkDetailModel?, int>((ref, id) async {
      final token = await ref.watch(authTokenProvider.future);
      if (token == null || token.isEmpty) throw Exception('Not logged in');

      final uri = Uri.parse(CommonAPIController.affiliateLink(id));
      final res = await http.get(
        uri,
        headers: {'Accept': 'application/json', 'token': token},
      );

      if (res.statusCode != 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>?;
        final msg = map?['message']?.toString() ?? 'Failed to load link';
        throw Exception(msg);
      }

      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      return AffiliateLinkDetailModel.fromJson(data);
    });

// ---------------------------------------------------------------------------
// Affiliate API errors
// ---------------------------------------------------------------------------

class AffiliateApiException implements Exception {
  AffiliateApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

String _formatAffiliateApiError(Map<String, dynamic> json, int statusCode) {
  if (statusCode == 403) {
    final msg = json['message']?.toString();
    if (msg != null && msg.isNotEmpty) {
      return 'Affiliate is not available on your plan.\n$msg';
    }
    return 'Affiliate is not available on your subscription plan.';
  }

  final parts = <String>[];
  final msg = json['message']?.toString();
  if (msg != null && msg.isNotEmpty) parts.add(msg);
  final errors = json['errors'];
  if (errors is Map) {
    for (final e in errors.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v is List) {
        for (final item in v) {
          parts.add('• $k: $item');
        }
      } else if (v != null) {
        parts.add('• $k: $v');
      }
    }
  }
  final data = json['data'];
  if (data is Map) {
    for (final e in data.entries) {
      final v = e.value;
      if (v is List) {
        for (final item in v) {
          parts.add('• ${e.key}: $item');
        }
      }
    }
  }
  if (parts.isEmpty) return 'Request failed (HTTP $statusCode)';
  return parts.join('\n');
}

Map<String, dynamic> _decodeAffiliateJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  return {'message': body};
}

// ---------------------------------------------------------------------------
// Generate: POST /api/affiliate/generate
// ---------------------------------------------------------------------------

/// Result of creating an affiliate link; includes the link and the full URL to share.
class AffiliateGenerateResult {
  final AffiliateLinkModel link;
  final String fullUrl;

  const AffiliateGenerateResult({required this.link, required this.fullUrl});
}

Future<AffiliateGenerateResult> affiliateGenerate(
  String? token, {
  String? name,
  String? description,
  String? destinationUrl,
  double? customRate,
  int? cookieDurationDays,
  String? attributionModel,
  String? expiresAt,
}) async {
  if (token == null || token.isEmpty) throw Exception('Not logged in');

  final uri = Uri.parse(CommonAPIController.affiliateGenerate);
  final body = <String, dynamic>{};
  if (name != null && name.isNotEmpty) body['name'] = name;
  if (description != null && description.isNotEmpty) {
    body['description'] = description;
  }
  if (destinationUrl != null && destinationUrl.isNotEmpty) {
    body['destination_url'] = destinationUrl;
  }
  if (customRate != null) body['custom_rate'] = customRate;
  if (cookieDurationDays != null) {
    body['cookie_duration_days'] = cookieDurationDays;
  }
  if (attributionModel != null && attributionModel.isNotEmpty) {
    body['attribution_model'] = attributionModel;
  }
  if (expiresAt != null && expiresAt.isNotEmpty) body['expires_at'] = expiresAt;

  final res = await http.post(
    uri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'token': token,
    },
    body: jsonEncode(body),
  );

  final map = _decodeAffiliateJson(res.body);
  if (res.statusCode == 201 || res.statusCode == 200) {
    final data = map['data'] as Map<String, dynamic>?;
    if (data != null) {
      final link = data['affiliate_link'];
      final fullUrl = data['full_url']?.toString() ?? '';
      if (link is Map<String, dynamic>) {
        return AffiliateGenerateResult(
          link: AffiliateLinkModel.fromJson(link),
          fullUrl: fullUrl.isNotEmpty ? fullUrl : '',
        );
      }
    }
    throw AffiliateApiException(
      res.statusCode,
      _formatAffiliateApiError(map, res.statusCode),
    );
  }
  throw AffiliateApiException(
    res.statusCode,
    _formatAffiliateApiError(map, res.statusCode),
  );
}

// ---------------------------------------------------------------------------
// Update: PUT /api/affiliate/link/{id}
// ---------------------------------------------------------------------------

Future<void> affiliateUpdate(
  String? token, {
  required int id,
  String? name,
  String? description,
  String? status,
  String? destinationUrl,
  double? customRate,
  int? cookieDurationDays,
  String? attributionModel,
  String? expiresAt,
}) async {
  if (token == null || token.isEmpty) throw Exception('Not logged in');

  final uri = Uri.parse(CommonAPIController.affiliateLink(id));
  final body = <String, dynamic>{};
  if (name != null) body['name'] = name;
  if (description != null) body['description'] = description;
  if (status != null) body['status'] = status;
  if (destinationUrl != null) body['destination_url'] = destinationUrl;
  if (customRate != null) body['custom_rate'] = customRate;
  if (cookieDurationDays != null) {
    body['cookie_duration_days'] = cookieDurationDays;
  }
  if (attributionModel != null && attributionModel.isNotEmpty) {
    body['attribution_model'] = attributionModel;
  }
  if (expiresAt != null && expiresAt.isNotEmpty) {
    body['expires_at'] = expiresAt;
  }

  final res = await http.put(
    uri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'token': token,
    },
    body: jsonEncode(body),
  );

  final map = _decodeAffiliateJson(res.body);
  if (res.statusCode == 200) return;
  throw AffiliateApiException(
    res.statusCode,
    _formatAffiliateApiError(map, res.statusCode),
  );
}

// ---------------------------------------------------------------------------
// Delete: DELETE /api/affiliate/link/{id}
// ---------------------------------------------------------------------------

Future<void> affiliateDelete(String? token, {required int id}) async {
  if (token == null || token.isEmpty) throw Exception('Not logged in');

  final uri = Uri.parse(CommonAPIController.affiliateLink(id));
  final res = await http.delete(
    uri,
    headers: {'Accept': 'application/json', 'token': token},
  );

  final map = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 200) return;
  final msg = map['message']?.toString() ?? 'Failed to delete link';
  throw Exception(msg);
}
