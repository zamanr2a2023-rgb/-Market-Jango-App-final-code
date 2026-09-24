import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/common_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/core/utils/get_user_type.dart';
import 'package:market_jango/features/buyer/data/visibility_zones_register_data.dart';
import 'package:market_jango/features/buyer/screens/cart/data/visibility_locations_data.dart';
import 'package:market_jango/features/subscription/model/current_subscription_model.dart';
import 'package:market_jango/features/subscription/model/subscription_plan_model.dart';
import 'package:market_jango/features/vendor/screens/vendor_delivery_setting/data/vendor_route_points_data.dart';

/// STEP_06 — who is loading plans and which zone filter applies.
class SubscriptionPlansContext {
  final String userType;
  final String? region;
  final String? deliveryZone;

  const SubscriptionPlansContext({
    required this.userType,
    this.region,
    this.deliveryZone,
  });

  bool get isVendor => userType == 'vendor';
  bool get isDriver => userType == 'driver';

  String? get activeZoneLabel {
    if (isVendor) return region;
    if (isDriver) return deliveryZone;
    return null;
  }
}

String? _normalizeZoneName(String? raw, List<String> knownZones) {
  final v = raw?.trim();
  if (v == null || v.isEmpty || v.toLowerCase() == 'null') return null;
  for (final z in knownZones) {
    if (z.trim().toLowerCase() == v.toLowerCase()) return z.trim();
  }
  // Prefer exact Zone Management names when list is empty / unavailable.
  if (knownZones.isEmpty) return v;
  return null;
}

Future<List<String>> _loadKnownZoneNames(Ref ref) async {
  final names = <String>{};
  try {
    final zones = await ref.read(visibilityLocationsZonesProvider.future);
    for (final z in zones) {
      if (z.name.trim().isNotEmpty) names.add(z.name.trim());
    }
  } catch (_) {}
  try {
    final zones = await ref.read(visibilityZonesProvider.future);
    for (final z in zones) {
      if (z.trim().isNotEmpty) names.add(z.trim());
    }
  } catch (_) {}
  return names.toList();
}

/// Vendor region = Zone Management `zone_name` from opted-in delivery routes.
Future<String?> _resolveVendorRegion(Ref ref, List<String> known) async {
  try {
    final routes = await ref.read(routePointsProvider.future);
    final items = routes?.items ?? const [];
    final selected = items
        .where((e) => e.isSelected)
        .map((e) => e.zoneName.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final z in selected) {
      final n = _normalizeZoneName(z, known);
      if (n != null) return n;
      if (known.isEmpty) return z;
    }
    for (final e in items) {
      final z = e.zoneName.trim();
      if (z.isEmpty) continue;
      final n = _normalizeZoneName(z, known);
      if (n != null) return n;
      if (known.isEmpty) return z;
    }
  } catch (_) {}

  final storage = AuthLocalStorage();
  final ship = await storage.getShipZone();
  final fromShip = _normalizeZoneName(ship, known);
  if (fromShip != null) return fromShip;

  final uj = await storage.getUserJson();
  for (final key in ['region', 'ship_zone', 'zone', 'delivery_zone']) {
    final n = _normalizeZoneName(uj?[key]?.toString(), known);
    if (n != null) return n;
  }
  final vendor = uj?['vendor'];
  if (vendor is Map) {
    for (final key in ['region', 'zone', 'ship_zone', 'delivery_zone']) {
      final n = _normalizeZoneName(vendor[key]?.toString(), known);
      if (n != null) return n;
    }
  }
  return null;
}

/// Driver delivery zone from profile / session (Zone Management name).
Future<String?> _resolveDriverDeliveryZone(
  Ref ref,
  List<String> known,
) async {
  final storage = AuthLocalStorage();
  final uj = await storage.getUserJson();
  for (final key in [
    'delivery_zone',
    'ship_zone',
    'zone',
    'region',
  ]) {
    final n = _normalizeZoneName(uj?[key]?.toString(), known);
    if (n != null) return n;
  }
  final driver = uj?['driver'];
  if (driver is Map) {
    for (final key in [
      'delivery_zone',
      'ship_zone',
      'zone',
      'region',
      'location',
    ]) {
      final n = _normalizeZoneName(driver[key]?.toString(), known);
      if (n != null) return n;
    }
  }

  final ship = await storage.getShipZone();
  return _normalizeZoneName(ship, known);
}

final subscriptionPlansContextProvider =
    FutureProvider.autoDispose<SubscriptionPlansContext>((ref) async {
  final userType =
      (await ref.watch(getUserTypeProvider.future))?.toLowerCase() ?? '';
  final known = await _loadKnownZoneNames(ref);

  if (userType == 'vendor') {
    final region = await _resolveVendorRegion(ref, known);
    return SubscriptionPlansContext(userType: 'vendor', region: region);
  }
  if (userType == 'driver') {
    final deliveryZone = await _resolveDriverDeliveryZone(ref, known);
    return SubscriptionPlansContext(
      userType: 'driver',
      deliveryZone: deliveryZone,
    );
  }
  return SubscriptionPlansContext(userType: userType.isEmpty ? 'vendor' : userType);
});

/// Client-side safety filter (hide other regions / delivery zones).
List<SubscriptionPlanModel> filterSubscriptionPlansForContext(
  List<SubscriptionPlanModel> plans,
  SubscriptionPlansContext ctx,
) {
  return plans.where((p) {
    final forType = p.forUserType.trim().toLowerCase();
    if (forType.isNotEmpty &&
        forType != 'all' &&
        forType != ctx.userType) {
      return false;
    }

    if (ctx.isVendor) {
      if (p.isGlobalForVendor) return true;
      final want = ctx.region?.trim();
      if (want == null || want.isEmpty) {
        // Unknown vendor region → only global plans (hide other regions).
        return false;
      }
      return p.region!.trim().toLowerCase() == want.toLowerCase();
    }

    if (ctx.isDriver) {
      if (p.isGlobalForDriver) return true;
      final want = ctx.deliveryZone?.trim();
      if (want == null || want.isEmpty) {
        return false;
      }
      return p.deliveryZone!.trim().toLowerCase() == want.toLowerCase();
    }

    return true;
  }).toList();
}

/// Response from POST /api/subscription/initiate-payment (Flutterwave flow).
class InitiatePaymentResult {
  final String paymentUrl;
  final String? txRef;
  final int? pendingId;
  final String? amount;
  final String? currency;
  const InitiatePaymentResult({
    required this.paymentUrl,
    this.txRef,
    this.pendingId,
    this.amount,
    this.currency,
  });
}

// ---------------------------------------------------------------------------
// Get subscription plans (GET /api/subscription/plans) — STEP_06 regional
// ---------------------------------------------------------------------------

final subscriptionPlansProvider =
    AsyncNotifierProvider<SubscriptionPlansNotifier, List<SubscriptionPlanModel>>(
  SubscriptionPlansNotifier.new,
);

class SubscriptionPlansNotifier
    extends AsyncNotifier<List<SubscriptionPlanModel>> {
  @override
  Future<List<SubscriptionPlanModel>> build() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in');
    }

    final ctx = await ref.watch(subscriptionPlansContextProvider.future);
    final storage = AuthLocalStorage();
    final userId = await storage.getUserId();

    final uri = Uri.parse(
      CommonAPIController.subscriptionPlans(
        region: ctx.isVendor ? ctx.region : null,
        deliveryZone: ctx.isDriver ? ctx.deliveryZone : null,
      ),
    );

    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'token': token,
        if (ctx.userType.isNotEmpty) 'user_type': ctx.userType,
        if (userId != null && userId.isNotEmpty) 'id': userId,
      },
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to load plans: ${res.statusCode} ${res.reasonPhrase}',
      );
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = map['data'] as List<dynamic>? ?? [];
    final parsed = list
        .map((e) =>
            SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return filterSubscriptionPlansForContext(parsed, ctx);
  }
}

// ---------------------------------------------------------------------------
// Get current subscription (GET /api/subscription/current)
// ---------------------------------------------------------------------------

class CurrentSubscriptionState {
  final CurrentSubscriptionModel? subscription;
  final SubscriptionUsageModel? usage;
  const CurrentSubscriptionState({this.subscription, this.usage});
}

final currentSubscriptionProvider =
    AsyncNotifierProvider<CurrentSubscriptionNotifier, CurrentSubscriptionState>(
  CurrentSubscriptionNotifier.new,
);

class CurrentSubscriptionNotifier
    extends AsyncNotifier<CurrentSubscriptionState> {
  @override
  Future<CurrentSubscriptionState> build() async {
    final token = await ref.read(authTokenProvider.future);
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in');
    }
    final uri = Uri.parse(CommonAPIController.subscriptionCurrent);
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'token': token},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Failed to load current subscription: ${res.statusCode}',
      );
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final data = map['data'];
    if (data == null) {
      return const CurrentSubscriptionState();
    }
    final dataMap = data as Map<String, dynamic>;
    CurrentSubscriptionModel? sub;
    SubscriptionUsageModel? usage;
    if (dataMap['subscription'] != null) {
      sub = CurrentSubscriptionModel.fromJson(
        dataMap['subscription'] as Map<String, dynamic>,
      );
    }
    if (dataMap['usage'] != null) {
      usage = SubscriptionUsageModel.fromJson(
        dataMap['usage'] as Map<String, dynamic>,
      );
    }
    return CurrentSubscriptionState(subscription: sub, usage: usage);
  }
}

// ---------------------------------------------------------------------------
// Initiate Flutterwave payment (POST /api/subscription/initiate-payment)
// ---------------------------------------------------------------------------

/// Gets a Flutterwave payment link for the given plan. Open [result.paymentUrl]
/// in browser or webview; after user pays, backend activates subscription.
Future<InitiatePaymentResult> initiateSubscriptionPayment(
  String? token, {
  required int subscriptionPlanId,
}) async {
  if (token == null || token.isEmpty) {
    throw Exception('Not logged in');
  }
  final uri = Uri.parse(CommonAPIController.subscriptionInitiatePayment);
  final body = <String, dynamic>{
    'subscription_plan_id': subscriptionPlanId,
  };
  final res = await http.post(
    uri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'token': token,
    },
    body: jsonEncode(body),
  );
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    final message =
        map['message']?.toString() ?? 'Failed to create payment link';
    throw Exception(message);
  }
  final data = map['data'] as Map<String, dynamic>?;
  if (data == null) {
    throw Exception('No payment URL in response');
  }
  final paymentUrl = data['payment_url']?.toString();
  if (paymentUrl == null || paymentUrl.isEmpty) {
    throw Exception('Missing payment_url');
  }
  return InitiatePaymentResult(
    paymentUrl: paymentUrl,
    txRef: data['tx_ref']?.toString(),
    pendingId: (data['pending_id'] as num?)?.toInt(),
    amount: data['amount']?.toString(),
    currency: data['currency']?.toString(),
  );
}

// ---------------------------------------------------------------------------
// Confirm payment (POST /api/subscription/confirm-payment) – fallback when
// Flutterwave redirect doesn't update the database; call when user returns.
// ---------------------------------------------------------------------------

/// Call when user returns from Flutterwave payment page. Backend verifies
/// with Flutterwave and activates subscription. Use [txRef] from
/// [InitiatePaymentResult.txRef].
Future<void> confirmSubscriptionPayment(
  String? token, {
  required String txRef,
  void Function()? invalidateCurrentSubscription,
}) async {
  if (token == null || token.isEmpty) {
    throw Exception('Not logged in');
  }
  if (txRef.isEmpty) {
    throw Exception('tx_ref is required');
  }
  final uri = Uri.parse(CommonAPIController.subscriptionConfirmPayment);
  final body = <String, dynamic>{'tx_ref': txRef};
  final res = await http.post(
    uri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'token': token,
    },
    body: jsonEncode(body),
  );
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 200) {
    invalidateCurrentSubscription?.call();
    return;
  }
  final message =
      map['message']?.toString() ?? 'Payment could not be confirmed';
  throw Exception(message);
}

// ---------------------------------------------------------------------------
// Subscribe to plan (POST /api/subscription/subscribe)
// ---------------------------------------------------------------------------

/// Subscribe to a plan. Pass [invalidateCurrentSubscription] so the current
/// subscription provider can be refreshed after success (e.g. ref.invalidate(currentSubscriptionProvider)).
Future<void> subscribeToPlan(
  String? token, {
  required int subscriptionPlanId,
  String? paymentMethod,
  String? transactionId,
  void Function()? invalidateCurrentSubscription,
}) async {
  if (token == null || token.isEmpty) {
    throw Exception('Not logged in');
  }
  final uri = Uri.parse(CommonAPIController.subscriptionSubscribe);
  final body = <String, dynamic>{
    'subscription_plan_id': subscriptionPlanId,
    if (paymentMethod != null && paymentMethod.isNotEmpty)
      'payment_method': paymentMethod,
    if (transactionId != null && transactionId.isNotEmpty)
      'transaction_id': transactionId,
  };
  final res = await http.post(
    uri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'token': token,
    },
    body: jsonEncode(body),
  );
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode == 201 || res.statusCode == 200) {
    invalidateCurrentSubscription?.call();
    return;
  }
  final message = map['message']?.toString() ?? 'Subscription failed';
  throw Exception(message);
}
