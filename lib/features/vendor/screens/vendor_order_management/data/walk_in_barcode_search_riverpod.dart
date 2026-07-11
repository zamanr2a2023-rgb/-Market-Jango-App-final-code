import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/data/vendor_barcode_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/model/vendor_barcode_models.dart';

/// Walk-in order product search — `GET /vendor/products/barcodes?search=`.
final walkInBarcodeSearchProvider = FutureProvider.autoDispose
    .family<VendorBarcodeListPage, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return VendorBarcodeListPage.empty();
  return VendorBarcodeApi.instance.fetchBarcodeList(search: trimmed);
});
