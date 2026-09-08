import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

bool _looksLikeZip(Uint8List bytes) {
  // xlsx is a ZIP package (PK..)
  return bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
}

bool _looksLikePdf(Uint8List bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}

String _exportExtension({
  required Uint8List bytes,
  required String? contentType,
  required String preferredFormat,
}) {
  final ct = contentType?.toLowerCase() ?? '';
  final pref = preferredFormat.toLowerCase().trim();
  if (ct.contains('spreadsheet') ||
      ct.contains('excel') ||
      ct.contains('xlsx') ||
      ct.contains('officedocument.spreadsheet')) {
    return 'xlsx';
  }
  if (ct.contains('application/pdf') || _looksLikePdf(bytes)) return 'pdf';
  if (_looksLikeZip(bytes) && (pref == 'xlsx' || pref == 'xls')) return 'xlsx';
  if (pref == 'pdf') return 'pdf';
  if (pref == 'xlsx' || pref == 'xls') return 'xlsx';
  if (_looksLikePdf(bytes)) return 'pdf';
  return pref.isNotEmpty ? pref : 'bin';
}

String _mimeForExportExt(String ext) {
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'xls':
      return 'application/vnd.ms-excel';
    default:
      return 'application/octet-stream';
  }
}

Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  final topLeft = box.localToGlobal(Offset.zero);
  return topLeft & box.size;
}

/// Saves vendor sales/orders export under `MarketJango/downloads` and opens share.
Future<void> saveVendorExportLocallyAndShare({
  required BuildContext context,
  required Uint8List bytes,
  required String? contentType,
  required String preferredFormat,
  String label = 'orders_export',
}) async {
  final shareOrigin = _shareOrigin(context);
  final ext = _exportExtension(
    bytes: bytes,
    contentType: contentType,
    preferredFormat: preferredFormat,
  );
  final safe = label
      .trim()
      .replaceAll(RegExp(r'[^\w\-\.]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final base = safe.isEmpty
      ? 'export'
      : (safe.length > 40 ? safe.substring(0, 40) : safe);
  final ts = DateTime.now().millisecondsSinceEpoch;
  final name = '${base}_$ts.$ext';

  final root = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(root.path, 'MarketJango', 'downloads'));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  final path = p.join(folder.path, name);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  final xf = XFile(
    file.path,
    mimeType: _mimeForExportExt(ext),
    name: name,
  );

  await SharePlus.instance.share(
    ShareParams(
      files: [xf],
      subject: 'Vendor export',
      text: 'Save to Downloads or another folder.',
      sharePositionOrigin: shareOrigin,
    ),
  );
}
