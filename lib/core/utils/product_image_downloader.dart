import 'dart:convert';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

class ProductImageDownloadResult {
  final int saved;
  final int failed;
  final int total;

  const ProductImageDownloadResult({
    required this.saved,
    required this.failed,
    required this.total,
  });

  bool get allSaved => saved > 0 && failed == 0;
  bool get noneSaved => saved == 0;
}

class ProductImageDownloader {
  ProductImageDownloader._();

  static Future<bool> _ensureAccess() async {
    final hasAccess = await Gal.hasAccess();
    if (hasAccess) return true;
    return Gal.requestAccess();
  }

  static Future<Uint8List?> _bytesFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('data:image')) {
      final comma = trimmed.indexOf(',');
      if (comma < 0) return null;
      final b64 = trimmed.substring(comma + 1);
      try {
        return base64Decode(b64);
      } catch (_) {
        return null;
      }
    }

    if (!(trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
      return null;
    }

    final res = await http.get(Uri.parse(trimmed));
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    if (res.bodyBytes.isEmpty) return null;
    return res.bodyBytes;
  }

  /// Downloads every product image URL into the device gallery.
  static Future<ProductImageDownloadResult> downloadAll(
    List<String> imageUrls, {
    String album = 'Jango Market',
  }) async {
    final urls = imageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (urls.isEmpty) {
      return const ProductImageDownloadResult(saved: 0, failed: 0, total: 0);
    }

    final allowed = await _ensureAccess();
    if (!allowed) {
      throw Exception('Photo library permission denied');
    }

    var saved = 0;
    var failed = 0;

    for (var i = 0; i < urls.length; i++) {
      try {
        final bytes = await _bytesFromUrl(urls[i]);
        if (bytes == null) {
          failed++;
          continue;
        }
        await Gal.putImageBytes(
          bytes,
          album: album,
          name: 'product_${DateTime.now().millisecondsSinceEpoch}_$i',
        );
        saved++;
      } catch (_) {
        failed++;
      }
    }

    return ProductImageDownloadResult(
      saved: saved,
      failed: failed,
      total: urls.length,
    );
  }
}
