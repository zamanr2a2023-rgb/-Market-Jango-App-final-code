import 'package:market_jango/features/vendor/screens/vendor_barcode/model/vendor_barcode_models.dart';
import 'package:print_bluetooth_thermal/post_code.dart';

/// ESC/POS helpers for 58mm Bluetooth (plain text, barcode labels, bills).
class VendorEscPosUtil {
  VendorEscPosUtil._();

  static const int _chars58 = 32;

  static List<int> buildPlainText58mm(String text) {
    final out = <int>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        out.addAll(PostCode.text(text: ' ', align: AlignPos.left));
        continue;
      }
      for (final part in _wrap(line, _chars58)) {
        out.addAll(PostCode.text(text: part, align: AlignPos.left));
      }
    }
    out.addAll(PostCode.cut());
    return out;
  }

  static List<int> buildBarcodeLabel58mm(
    VendorBarcodeLabelsResult result, {
    int? copies,
  }) {
    final d = result.printData;
    final p = result.product;
    final n = copies ?? d.copies;
    final barcodeValue = (d.barcode.isNotEmpty ? d.barcode : d.barcodeText).trim();
    final out = <int>[];

    void line(
      String text, {
      AlignPos align = AlignPos.left,
      bool bold = false,
      FontSize size = FontSize.normal,
    }) {
      out.addAll(
        PostCode.text(
          text: _fit(text, _chars58),
          align: align,
          bold: bold,
          fontSize: size,
        ),
      );
    }

    for (var c = 0; c < n; c++) {
      if (c > 0) line('---');
      line('MARKET JANGO', align: AlignPos.center, bold: true);
      line(
        _fit(p.name.isEmpty ? 'Product #${p.id}' : p.name, _chars58),
        align: AlignPos.center,
        bold: true,
      );
      if (p.regularPrice > 0) {
        line('Price: ${p.regularPrice}', align: AlignPos.center);
      }
      if (barcodeValue.isNotEmpty) {
        out.addAll(_barcodeEscPos(barcodeValue));
        line(barcodeValue, align: AlignPos.center, size: FontSize.compressed);
      }
      out.addAll(PostCode.enter(nEnter: 4));
    }

    return out;
  }

  /// ESC/POS barcode bytes — fixes broken length in [PostCode.barcode].
  static List<int> _barcodeEscPos(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return [];

    final upper = trimmed.toUpperCase();
    if (_isCode39Safe(upper)) {
      return _code39(upper);
    }
    return _code128(trimmed);
  }

  static bool _isCode39Safe(String value) {
    return RegExp(r'^[0-9A-Z\-\.\ \$\/\+\%]+$').hasMatch(value);
  }

  static List<int> _code128(String data) {
    final payload = data.codeUnits;
    if (payload.length > 255) {
      throw Exception('Barcode is too long to print (${payload.length} chars).');
    }
    final out = <int>[];
    _addCmd(out, '\x1B@');
    _addCmd(out, '\x1Ba\x01');
    _addCmd(out, '\x1D\x68\x50');
    _addCmd(out, '\x1D\x77\x02');
    _addCmd(out, '\x1D\x48\x02');
    out
      ..add(0x1D)
      ..add(0x6B)
      ..add(0x49)
      ..add(payload.length)
      ..addAll(payload)
      ..add(0x0A);
    return out;
  }

  static List<int> _code39(String data) {
    final payload = data.codeUnits;
    if (payload.length > 255) {
      throw Exception('Barcode is too long to print (${payload.length} chars).');
    }
    final out = <int>[];
    _addCmd(out, '\x1B@');
    _addCmd(out, '\x1Ba\x01');
    _addCmd(out, '\x1D\x68\x50');
    _addCmd(out, '\x1D\x77\x02');
    _addCmd(out, '\x1D\x48\x02');
    out
      ..add(0x1D)
      ..add(0x6B)
      ..add(0x04)
      ..add(payload.length)
      ..addAll(payload)
      ..add(0x00)
      ..add(0x0A);
    return out;
  }

  static void _addCmd(List<int> out, String cmd) {
    out.addAll(cmd.codeUnits);
  }

  static VendorBarcodeLabelsResult labelsFromProduct(
    VendorBarcodeProduct p, {
    int labelCount = 1,
  }) {
    return VendorBarcodeLabelsResult(
      product: p,
      labelCount: labelCount,
      printData: VendorBarcodeLabelPrintData(
        barcode: p.barcode,
        barcodeText: p.barcodeText.isNotEmpty ? p.barcodeText : p.barcode,
        productName: p.name,
        price: p.regularPrice,
        vendorName: p.vendorName,
        sku: p.sku,
        expiryDate: p.expiryDate,
        brandLogoUrl: p.brandLogoUrl,
        variant: p.variant,
        copies: labelCount,
      ),
    );
  }

  static String _fit(String s, int max) {
    final t = s.replaceAll('\n', ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static List<String> _wrap(String text, int width) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var buf = '';
    for (final w in words) {
      if (w.isEmpty) continue;
      if (buf.isEmpty) {
        buf = w;
      } else if (buf.length + 1 + w.length <= width) {
        buf = '$buf $w';
      } else {
        lines.add(buf);
        buf = w;
      }
    }
    if (buf.isNotEmpty) lines.add(buf);
    return lines.isEmpty ? [text] : lines;
  }
}
