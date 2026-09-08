import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/vendor_order_auth.dart';

/// Binary result of `GET /api/vendor/orders/export?format=…` (STEP_04).
class VendorOrdersExportBytes {
  const VendorOrdersExportBytes({
    required this.bytes,
    required this.contentType,
    required this.format,
  });

  final Uint8List bytes;
  final String? contentType;
  final String format;
}

void _throwIfExportBodyIsJsonError(Uint8List bytes) {
  if (bytes.isEmpty || bytes[0] != 0x7B) return;
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map<String, dynamic>) {
      final st = decoded['status']?.toString().toLowerCase();
      final msg = decoded['message']?.toString();
      if (st == 'error' ||
          st == 'fail' ||
          (msg != null && msg.trim().isNotEmpty)) {
        throw Exception(
          msg != null && msg.trim().isNotEmpty ? msg.trim() : 'Export failed',
        );
      }
    }
  } on FormatException {
    // not JSON
  }
}

/// STEP_04 sales/orders export — documented query is `format` only (`xlsx`|`pdf`).
class VendorOrdersExportApi {
  VendorOrdersExportApi._();
  static final instance = VendorOrdersExportApi._();

  Future<VendorOrdersExportBytes> download({required String format}) async {
    final fmt = format.trim().toLowerCase();
    if (fmt != 'xlsx' && fmt != 'pdf') {
      throw Exception('Unsupported export format: $format');
    }
    final headers = await vendorOrderApiHeaders();
    // Binary download — do not force JSON Accept.
    final h = Map<String, String>.from(headers);
    h['Accept'] = '*/*';
    h.remove('Content-Type');

    final uri = Uri.parse(VendorAPIController.vendorOrdersExport(format: fmt));
    final res = await http.get(uri, headers: h);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Export failed (${res.statusCode})';
      try {
        final top = jsonDecode(res.body);
        if (top is Map && top['message'] != null) {
          msg = top['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
    _throwIfExportBodyIsJsonError(res.bodyBytes);
    if (res.bodyBytes.isEmpty) {
      throw Exception('Export returned an empty file');
    }
    return VendorOrdersExportBytes(
      bytes: res.bodyBytes,
      contentType: res.headers['content-type'],
      format: fmt,
    );
  }
}
