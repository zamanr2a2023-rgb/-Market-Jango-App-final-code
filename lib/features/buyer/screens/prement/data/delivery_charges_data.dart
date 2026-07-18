import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

class DeliveryChargeItem {
  final int cartId;
  final int productId;
  final String productName;
  final int vendorId;
  final String vendorName;
  final int quantity;
  /// Pricing / routing zone from API (`charge_zone`).
  final String chargeZone;
  final String buyerZone;
  final String buyerTown;
  final String vendorTown;
  final int? routeId;
  final Map<String, num> chargesApplied;
  final num effectiveWeightKg;
  /// Per-line delivery from API: `allocated_delivery_charge` (or legacy `final_delivery_charge`).
  final num finalDeliveryCharge;
  /// Buyer-facing per-line delivery (`allocated_delivery_charge_display`).
  final num finalDeliveryChargeDisplay;
  /// When charge is zero, API may set e.g. `no_matching_route`.
  final String skipReason;

  const DeliveryChargeItem({
    required this.cartId,
    required this.productId,
    required this.productName,
    required this.vendorId,
    required this.vendorName,
    required this.quantity,
    required this.chargeZone,
    required this.buyerZone,
    required this.buyerTown,
    required this.vendorTown,
    required this.routeId,
    required this.chargesApplied,
    required this.effectiveWeightKg,
    required this.finalDeliveryCharge,
    required this.finalDeliveryChargeDisplay,
    required this.skipReason,
  });

  factory DeliveryChargeItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    num asNum(dynamic v) {
      if (v is num) return v;
      return num.tryParse('${v ?? ''}') ?? 0;
    }

    final rawCharges = json['charges_applied'];
    final charges = <String, num>{};
    if (rawCharges is Map<String, dynamic>) {
      rawCharges.forEach((k, v) {
        charges[k] = asNum(v);
      });
    }

    final allocated = json['allocated_delivery_charge'];
    final legacyFinal = json['final_delivery_charge'];
    final lineCharge = allocated != null ? asNum(allocated) : asNum(legacyFinal);
    final allocatedDisplay = json['allocated_delivery_charge_display'];
    final lineChargeDisplay =
        allocatedDisplay != null ? asNum(allocatedDisplay) : lineCharge;

    return DeliveryChargeItem(
      cartId: asInt(json['cart_id']),
      productId: asInt(json['product_id']),
      productName: (json['product_name'] ?? '').toString(),
      vendorId: asInt(json['vendor_id']),
      vendorName: (json['vendor_name'] ?? '').toString(),
      quantity: asInt(json['quantity']),
      chargeZone: (json['charge_zone'] ?? '').toString(),
      buyerZone: (json['buyer_zone'] ?? '').toString(),
      buyerTown: (json['buyer_town'] ?? '').toString(),
      vendorTown: (json['vendor_town'] ?? '').toString(),
      routeId: json['route_id'] == null ? null : asInt(json['route_id']),
      chargesApplied: charges,
      effectiveWeightKg: asNum(json['effective_weight_kg']),
      finalDeliveryCharge: lineCharge,
      finalDeliveryChargeDisplay: lineChargeDisplay,
      skipReason: (json['skip_reason'] ?? '').toString(),
    );
  }
}

/// One row in the delivery “Route” table from `data.zones[].per_town_breakdown`
/// (or legacy equivalents), one entry per vendor town.
class DeliveryRouteSummary {
  final String vendorTown;
  final String buyerTown;
  final num townTotal;
  final num flat;
  final num weightBased;

  const DeliveryRouteSummary({
    required this.vendorTown,
    required this.buyerTown,
    required this.townTotal,
    this.flat = 0,
    this.weightBased = 0,
  });
}

class DeliveryChargesResponse {
  final List<DeliveryChargeItem> items;
  final num cartTotalDeliveryCharge;
  /// `cart_merchandise_subtotal` — product subtotal before delivery & fees.
  final num merchandiseSubtotal;
  final num platformFee;
  final num tax;
  /// `cart_total_with_delivery_and_fees` — amount customer pays (when provided).
  final num grandTotal;

  /// Buyer-facing `*_display` amounts (never converted client-side).
  final num cartTotalDeliveryChargeDisplay;
  final num merchandiseSubtotalDisplay;
  final num platformFeeDisplay;
  final num taxDisplay;
  final num grandTotalDisplay;
  /// `display_currency` (falls back to ledger `currency`, then UGX).
  final String displayCurrency;
  /// Merged `charges_applied` from each entry in `data.zones` (zone-level surcharges).
  final Map<String, num> zoneChargesApplied;
  /// Sum of `aggregated_effective_weight_kg` across `data.zones` (informational).
  final num zonesAggregatedWeightKg;
  /// When API sends `per_town_breakdown` (or similar), use this for route rows
  /// instead of one row per cart line (avoids duplicate “KENYA to UAE” @ $0).
  final List<DeliveryRouteSummary> routeSummaries;

  const DeliveryChargesResponse({
    required this.items,
    required this.cartTotalDeliveryCharge,
    this.merchandiseSubtotal = 0,
    this.platformFee = 0,
    this.tax = 0,
    this.grandTotal = 0,
    this.cartTotalDeliveryChargeDisplay = 0,
    this.merchandiseSubtotalDisplay = 0,
    this.platformFeeDisplay = 0,
    this.taxDisplay = 0,
    this.grandTotalDisplay = 0,
    this.displayCurrency = 'UGX',
    this.zoneChargesApplied = const <String, num>{},
    this.zonesAggregatedWeightKg = 0,
    this.routeSummaries = const <DeliveryRouteSummary>[],
  });

  /// Best-effort delivery total when API root field is 0 but breakdown has values.
  num get effectiveDeliveryTotal {
    if (cartTotalDeliveryCharge > 0) return cartTotalDeliveryCharge;

    final fromLines =
        items.fold<num>(0, (sum, it) => sum + it.finalDeliveryCharge);
    if (fromLines > 0) return fromLines;

    final fromRoutes =
        routeSummaries.fold<num>(0, (sum, r) => sum + r.townTotal);
    if (fromRoutes > 0) return fromRoutes;

    return zoneChargesApplied.values.fold<num>(0, (sum, v) => sum + v);
  }

  bool get hasDeliverySkipReason =>
      items.any((it) => it.skipReason.trim().isNotEmpty);

  String get firstDeliverySkipReason {
    for (final it in items) {
      final r = it.skipReason.trim();
      if (r.isNotEmpty) return r;
    }
    return '';
  }

  factory DeliveryChargesResponse.fromJson(Map<String, dynamic> json) {
    num asNum(dynamic v) {
      if (v is num) return v;
      return num.tryParse('${v ?? ''}') ?? 0;
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return DeliveryChargesResponse(
        items: [],
        cartTotalDeliveryCharge: 0,
        merchandiseSubtotal: 0,
        platformFee: 0,
        tax: 0,
        grandTotal: 0,
        zoneChargesApplied: const <String, num>{},
        zonesAggregatedWeightKg: 0,
        routeSummaries: const <DeliveryRouteSummary>[],
      );
    }
    // API returns `line_items` (cart delivery breakdown); older shape used `items`.
    final itemsRaw = data['line_items'] ?? data['items'];
    final items = (itemsRaw is List)
        ? itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(DeliveryChargeItem.fromJson)
            .toList()
        : <DeliveryChargeItem>[];

    final zoneCharges = <String, num>{};
    num zonesAggWeight = 0;
    final routeSummaries = <DeliveryRouteSummary>[];
    final zonesRaw = data['zones'];
    if (zonesRaw is List) {
      for (final z in zonesRaw) {
        if (z is! Map<String, dynamic>) continue;
        zonesAggWeight += asNum(z['aggregated_effective_weight_kg']);
        final ca = z['charges_applied'];
        if (ca is Map<String, dynamic>) {
          ca.forEach((k, v) {
            final key = k.toString();
            zoneCharges[key] = (zoneCharges[key] ?? 0) + asNum(v);
          });
        }

        final buyerTown = (z['buyer_town'] ?? '').toString();
        final ptb = z['per_town_breakdown'] ??
            z['per_town'] ??
            z['town_breakdown'] ??
            z['town_totals'];
        if (ptb is Map<String, dynamic> && ptb.isNotEmpty) {
          void addTown(String town, Map<String, dynamic> m) {
            // Prefer buyer-facing display amounts when the API sends them.
            final flat = asNum(m['flat_display'] ?? m['flat']);
            final wb = asNum(m['weight_based_display'] ?? m['weight_based']);
            final explicit = m['town_total_display'] ?? m['town_total'];
            final total = explicit != null ? asNum(explicit) : flat + wb;
            routeSummaries.add(
              DeliveryRouteSummary(
                vendorTown: town,
                buyerTown: buyerTown,
                townTotal: total,
                flat: flat,
                weightBased: wb,
              ),
            );
          }

          final order = z['vendor_towns'];
          if (order is List) {
            final seen = <String>{};
            for (final vt in order) {
              final town = vt.toString();
              seen.add(town);
              final m = ptb[town];
              if (m is Map<String, dynamic>) addTown(town, m);
            }
            for (final e in ptb.entries) {
              if (seen.contains(e.key)) continue;
              if (e.value is Map<String, dynamic>) {
                addTown(e.key, e.value as Map<String, dynamic>);
              }
            }
          } else {
            ptb.forEach((town, v) {
              if (v is Map<String, dynamic>) addTown(town, v);
            });
          }
        }
      }
    }

    num displayOrLedger(dynamic display, num ledger) =>
        display != null ? asNum(display) : ledger;

    num platformFee = 0;
    num tax = 0;
    num platformFeeDisplay = 0;
    num taxDisplay = 0;
    final feesRaw = data['fees'];
    if (feesRaw is Map<String, dynamic>) {
      platformFee = asNum(feesRaw['platform_fee']);
      tax = asNum(feesRaw['tax']);
      platformFeeDisplay =
          displayOrLedger(feesRaw['platform_fee_display'], platformFee);
      taxDisplay = displayOrLedger(feesRaw['tax_display'], tax);
    }

    final delivery = asNum(data['cart_total_delivery_charge']);
    final merchandise = asNum(data['cart_merchandise_subtotal']);
    var grand = asNum(data['cart_total_with_delivery_and_fees']);
    if (grand == 0 &&
        (merchandise != 0 || delivery != 0 || platformFee != 0 || tax != 0)) {
      grand = merchandise + delivery + platformFee + tax;
    }

    final deliveryDisplay =
        displayOrLedger(data['cart_total_delivery_charge_display'], delivery);
    final merchandiseDisplay =
        displayOrLedger(data['cart_merchandise_subtotal_display'], merchandise);
    var grandDisplay = displayOrLedger(
      data['cart_total_with_delivery_and_fees_display'],
      0,
    );
    if (grandDisplay == 0 &&
        (merchandiseDisplay != 0 ||
            deliveryDisplay != 0 ||
            platformFeeDisplay != 0 ||
            taxDisplay != 0)) {
      grandDisplay =
          merchandiseDisplay + deliveryDisplay + platformFeeDisplay + taxDisplay;
    }

    String pickCurrency(dynamic v, String fallback) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? fallback : s.toUpperCase();
    }

    final ledgerCurrency = pickCurrency(data['currency'], 'UGX');
    final displayCurrency =
        pickCurrency(data['display_currency'], ledgerCurrency);

    return DeliveryChargesResponse(
      items: items,
      cartTotalDeliveryCharge: delivery,
      merchandiseSubtotal: merchandise,
      platformFee: platformFee,
      tax: tax,
      grandTotal: grand,
      cartTotalDeliveryChargeDisplay: deliveryDisplay,
      merchandiseSubtotalDisplay: merchandiseDisplay,
      platformFeeDisplay: platformFeeDisplay,
      taxDisplay: taxDisplay,
      grandTotalDisplay: grandDisplay,
      displayCurrency: displayCurrency,
      zoneChargesApplied: zoneCharges,
      zonesAggregatedWeightKg: zonesAggWeight,
      routeSummaries: routeSummaries,
    );
  }
}

final cartDeliveryChargesProvider =
    FutureProvider.autoDispose<DeliveryChargesResponse>((ref) async {
  final auth = AuthLocalStorage();
  final token = await auth.getToken();
  if (token == null || token.isEmpty) throw Exception('Not logged in');

  final res = await http.get(
    Uri.parse(BuyerAPIController.cartDeliveryCharges),
    headers: {'Accept': 'application/json', 'token': token},
  );

  final map = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    final msg = map['message']?.toString() ?? 'Failed to load delivery charges';
    throw Exception(msg);
  }
  return DeliveryChargesResponse.fromJson(map);
});

