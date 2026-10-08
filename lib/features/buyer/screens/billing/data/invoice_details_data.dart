import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/buyer_api.dart';
import 'package:market_jango/features/buyer/screens/billing/model/invoice_details_model.dart';
import 'package:market_jango/features/buyer/screens/order/data/buyer_auth_headers.dart';

final invoiceDetailsProvider =
    FutureProvider.family<InvoiceDetails?, int>((ref, invoiceId) async {
  final headers = await buyerAuthHeaders();

  final uri = Uri.parse(BuyerAPIController.invoiceProductList(invoiceId));
  final res = await http.get(uri, headers: headers);

  if (res.statusCode != 200) {
    throw Exception('Failed to fetch invoice details: ${res.statusCode}');
  }

  final parsed = InvoiceDetailsResponse.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
  return parsed.data;
});
