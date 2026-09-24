import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/get_token_sharedpefarens.dart';
import 'package:market_jango/features/vendor/screens/vendor_sale_platform/model/vendor_sale_model.dart';

final selectedIncomeDaysProvider = StateProvider<int>((ref) => 7);
final selectedSellingModeProvider = StateProvider<String?>((ref) => null);
final selectedPaymentTypeProvider = StateProvider<String?>((ref) => null);

/// Values accepted by `GET /vendor/income/update`.
const _allowedIncomePaymentTypes = {'online_pay', 'cash_pay', 'debt_pay'};

class VendorIncomeFilter {
  final int days;
  final String? sellingMode;
  final String? paymentType;

  const VendorIncomeFilter({
    required this.days,
    this.sellingMode,
    this.paymentType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VendorIncomeFilter &&
          days == other.days &&
          sellingMode == other.sellingMode &&
          paymentType == other.paymentType;

  @override
  int get hashCode => Object.hash(days, sellingMode, paymentType);
}

final vendorIncomeFilterProvider = Provider<VendorIncomeFilter>((ref) {
  final raw = ref.watch(selectedPaymentTypeProvider);
  final paymentType =
      (raw != null && _allowedIncomePaymentTypes.contains(raw)) ? raw : null;
  return VendorIncomeFilter(
    days: ref.watch(selectedIncomeDaysProvider),
    sellingMode: ref.watch(selectedSellingModeProvider),
    paymentType: paymentType,
  );
});

String _incomeApiErrorMessage(String body, int code) {
  try {
    final top = jsonDecode(body);
    if (top is Map<String, dynamic>) {
      final data = top['data'];
      if (data is Map) {
        final pt = data['payment_type'];
        if (pt is List && pt.isNotEmpty) {
          return pt.first.toString();
        }
        final parts = <String>[];
        for (final e in data.entries) {
          final v = e.value;
          if (v is List && v.isNotEmpty) {
            parts.add(v.first.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
      final msg = top['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
  } catch (_) {}
  return 'Failed to load income (HTTP $code)';
}

final vendorIncomeProvider =
    FutureProvider.family<VendorIncomeData, VendorIncomeFilter>((
  ref,
  filter,
) async {
  final token = await ref.read(authTokenProvider.future);
  if (token == null) throw Exception('Token not found');

  final uri = Uri.parse(
    VendorAPIController.vendor_income_update(
      days: filter.days,
      sellingMode: filter.sellingMode,
      paymentType: filter.paymentType,
    ),
  );

  final res = await http.get(
    uri,
    headers: {'Accept': 'application/json', 'token': token},
  );

  if (res.statusCode != 200) {
    throw Exception(_incomeApiErrorMessage(res.body, res.statusCode));
  }

  final decoded = vendorIncomeResponseFromJson(res.body);
  return decoded.data;
});
