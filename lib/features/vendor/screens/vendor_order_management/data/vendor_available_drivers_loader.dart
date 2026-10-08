import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

/// Backend transport types (`TransportShipmentController::TRANSPORT_TYPES`).
const kVendorDriverTransportTypes = [
  'motorcycle',
  'car',
  'air',
  'water',
];

String? normalizeVendorTransportFilter(String? raw) {
  final v = raw?.trim().toLowerCase();
  if (v == null || v.isEmpty || v == 'all') return null;
  if (kVendorDriverTransportTypes.contains(v)) return v;
  return null;
}

/// Loads assignable drivers: server pick/drop/search + optional client transport filter.
class VendorAvailableDriversLoader {
  VendorAvailableDriversLoader._();
  static final VendorAvailableDriversLoader instance =
      VendorAvailableDriversLoader._();

  static Map<int, VendorApprovedDriverMetadata>? _metadataCache;

  Future<List<VendorAvailableDriver>> fetch({
    String? search,
    String? pickLocation,
    String? dropLocation,
    String? transportType,
  }) async {
    var list = await VendorOrderApi.instance.fetchAvailableDrivers(
      search: search,
      pickLocation: pickLocation,
      dropLocation: dropLocation,
    );

    final transport = normalizeVendorTransportFilter(transportType);
    final meta = await _loadApprovedMetadataIndex();
    list = list
        .map((d) {
          final m = meta[d.id];
          return m != null ? d.mergeApprovedMetadata(m) : d;
        })
        .toList();

    if (transport != null) {
      list = list.where((d) {
        final t = d.transportType?.trim().toLowerCase();
        if (t == null || t.isEmpty) return false;
        return t == transport;
      }).toList();
    }

    return list;
  }

  Future<Map<int, VendorApprovedDriverMetadata>> _loadApprovedMetadataIndex({
    int maxPages = 10,
  }) async {
    if (_metadataCache != null) return _metadataCache!;

    final headers = await vendorOrderApiHeaders();
    final index = <int, VendorApprovedDriverMetadata>{};

    for (var page = 1; page <= maxPages; page++) {
      final uri = Uri.parse(VendorAPIController.approvedDriverPage(page));
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) break;

      final top = jsonDecode(res.body);
      if (top is! Map<String, dynamic>) break;
      final data = top['data'];
      if (data is! Map<String, dynamic>) break;

      final rows = data['data'];
      if (rows is! List || rows.isEmpty) break;

      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final meta = VendorApprovedDriverMetadata.fromJson(row);
        if (meta.driverId > 0) {
          index[meta.driverId] = meta;
        }
      }

      final lastPage = data['last_page'];
      final current = data['current_page'];
      if (lastPage is int && current is int && current >= lastPage) break;
      if (lastPage is num && current is num && current >= lastPage) break;
    }

    _metadataCache = index;
    return index;
  }

  void clearMetadataCache() => _metadataCache = null;
}
