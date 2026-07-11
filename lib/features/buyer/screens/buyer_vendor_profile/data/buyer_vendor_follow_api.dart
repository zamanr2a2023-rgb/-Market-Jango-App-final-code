import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/features/vendor/screens/vendor_followers/model/vendor_followers_model.dart';

Map<String, dynamic> _decodeMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw Exception('Invalid JSON');
}

Map<String, dynamic>? _data(Map<String, dynamic> top) {
  final d = top['data'];
  if (d is Map<String, dynamic>) return d;
  return null;
}

String _message(Map<String, dynamic> top) =>
    top['message']?.toString() ?? 'Request failed';

Future<Map<String, String>> _headers() async {
  final storage = AuthLocalStorage();
  final token = await storage.getToken();
  final id = await storage.getUserId();
  final userType = await storage.getUserType();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'token': token,
    if (id != null && id.isNotEmpty) 'id': id,
    if (userType != null && userType.isNotEmpty) 'user_type': userType,
  };
}

class BuyerVendorFollowApi {
  BuyerVendorFollowApi._();
  static final BuyerVendorFollowApi instance = BuyerVendorFollowApi._();

  Future<VendorFollowersResult> fetchFollowers(
    int vendorId, {
    int page = 1,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse(
      BuyerAPIController.vendorFollowers(vendorId, page: page),
    );
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      try {
        throw Exception(_message(_decodeMap(res.body)));
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    final top = _decodeMap(res.body);
    return VendorFollowersResult.fromJson(_data(top));
  }

  Future<String> follow(int vendorId) async {
    final headers = await _headers();
    final uri = Uri.parse(BuyerAPIController.followVendor(vendorId));
    final res = await http.post(uri, headers: headers, body: jsonEncode({}));
    if (res.statusCode != 200 && res.statusCode != 201) {
      try {
        throw Exception(_message(_decodeMap(res.body)));
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    try {
      return _message(_decodeMap(res.body));
    } catch (_) {
      return 'Followed successfully';
    }
  }

  Future<String> unfollow(int vendorId) async {
    final headers = await _headers();
    final uri = Uri.parse(BuyerAPIController.unfollowVendor(vendorId));
    final res = await http.delete(uri, headers: headers);
    if (res.statusCode != 200 && res.statusCode != 204) {
      try {
        throw Exception(_message(_decodeMap(res.body)));
      } catch (_) {
        throw Exception('HTTP ${res.statusCode}');
      }
    }
    try {
      if (res.body.trim().isEmpty) return 'Unfollowed successfully';
      return _message(_decodeMap(res.body));
    } catch (_) {
      return 'Unfollowed successfully';
    }
  }
}

class VendorFollowUiState {
  final int count;
  final bool isFollowing;
  final bool loading;
  final bool actionLoading;

  const VendorFollowUiState({
    this.count = 0,
    this.isFollowing = false,
    this.loading = true,
    this.actionLoading = false,
  });

  VendorFollowUiState copyWith({
    int? count,
    bool? isFollowing,
    bool? loading,
    bool? actionLoading,
  }) {
    return VendorFollowUiState(
      count: count ?? this.count,
      isFollowing: isFollowing ?? this.isFollowing,
      loading: loading ?? this.loading,
      actionLoading: actionLoading ?? this.actionLoading,
    );
  }
}

class VendorFollowNotifier extends StateNotifier<VendorFollowUiState> {
  VendorFollowNotifier(this.vendorId) : super(const VendorFollowUiState()) {
    refresh();
  }

  final int vendorId;

  Future<void> refresh() async {
    state = state.copyWith(loading: true);
    try {
      final result = await BuyerVendorFollowApi.instance.fetchFollowers(vendorId);
      final storage = AuthLocalStorage();
      final myId = int.tryParse(await storage.getUserId() ?? '') ?? 0;
      var following = result.isFollowing;
      if (following == null && myId > 0) {
        following = result.followers.items.any((f) => f.id == myId);
      }
      state = VendorFollowUiState(
        count: result.followersCount,
        isFollowing: following ?? false,
        loading: false,
        actionLoading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false, actionLoading: false);
    }
  }

  Future<void> toggle() async {
    if (state.actionLoading) return;
    final wasFollowing = state.isFollowing;
    final prevCount = state.count;
    // Optimistic UI
    state = state.copyWith(
      actionLoading: true,
      isFollowing: !wasFollowing,
      count: wasFollowing
          ? (prevCount > 0 ? prevCount - 1 : 0)
          : prevCount + 1,
    );
    try {
      if (wasFollowing) {
        await BuyerVendorFollowApi.instance.unfollow(vendorId);
      } else {
        await BuyerVendorFollowApi.instance.follow(vendorId);
      }
      state = state.copyWith(actionLoading: false);
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        isFollowing: wasFollowing,
        count: prevCount,
      );
      rethrow;
    }
  }
}

final vendorFollowProvider = StateNotifierProvider.autoDispose
    .family<VendorFollowNotifier, VendorFollowUiState, int>((ref, vendorId) {
  return VendorFollowNotifier(vendorId);
});

final publicVendorFollowersProvider = FutureProvider.autoDispose
    .family<VendorFollowersResult, int>((ref, vendorId) async {
  return BuyerVendorFollowApi.instance.fetchFollowers(vendorId);
});
