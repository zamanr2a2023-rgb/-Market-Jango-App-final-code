import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_invoice_print_data.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_esc_pos_receipt.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_printer_prefs.dart';
import 'package:pdf/pdf.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

/// 58mm Bluetooth (OEM) + 80mm Wi‑Fi/Ethernet (Epson/Star via system print).
class VendorInvoicePrinterService {
  VendorInvoicePrinterService._();

  static Future<String?> ensureBluetoothReady() async {
    if (kIsWeb) {
      return 'Bluetooth printing is not supported in the browser. Use the mobile app.';
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      return '58mm Bluetooth printing is only supported on Android and iOS.';
    }
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      return 'Turn on Bluetooth on this device.';
    }
    final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!granted) {
      return 'Allow Bluetooth permission for Market Jango in system settings.';
    }
    return null;
  }

  static Future<List<BluetoothInfo>> listPairedPrinters() {
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static bool _macEquals(String a, String b) =>
      a.trim().toUpperCase() == b.trim().toUpperCase();

  /// Finds a paired device by saved MAC or display name.
  static Future<BluetoothInfo?> findPairedPrinter({
    String? mac,
    String? name,
  }) async {
    final devices = await listPairedPrinters();
    if (mac != null && mac.trim().isNotEmpty) {
      for (final d in devices) {
        if (_macEquals(d.macAdress, mac)) return d;
      }
    }
    if (name != null && name.trim().isNotEmpty) {
      final target = name.trim().toLowerCase();
      BluetoothInfo? partial;
      for (final d in devices) {
        final dn = d.name.trim().toLowerCase();
        if (dn == target) return d;
        if (partial == null &&
            (dn.contains(target) || target.contains(dn))) {
          partial = d;
        }
      }
      if (partial != null) return partial;
    }
    return null;
  }

  static bool looksLikeScanner(BluetoothInfo device) {
    final n = device.name.trim().toLowerCase();
    if (n.isEmpty) return false;
    const keys = ['scanner', 'barcode scan', 'scan gun', 'scan'];
    if (keys.any(n.contains) && !n.contains('print')) return true;
    return false;
  }

  /// Heuristic for 58mm thermal / label printers among paired devices.
  static bool looksLikePrinter(BluetoothInfo device) {
    if (looksLikeScanner(device)) return false;
    final n = device.name.trim().toLowerCase();
    if (n.isEmpty) return false;
    const keys = [
      'print',
      'pos',
      'thermal',
      'label',
      'xprinter',
      'goojprt',
      'hspos',
      'innerprinter',
      'mtp-',
      'rp-',
      'b1-',
      'jk-',
      'mp-',
      '58mm',
      '80mm',
      'h828',
      'ticket',
      'receipt',
      'rongta',
      'gainscha',
      'niimbot',
      'nimbot',
    ];
    return keys.any(n.contains);
  }

  static List<BluetoothInfo> likelyPrinters(List<BluetoothInfo> paired) {
    return paired.where(looksLikePrinter).toList();
  }

  /// Saved printer when still paired — never guesses another device.
  static Future<BluetoothInfo?> resolveActivePrinter() async {
    final saved = await VendorPrinterPrefs.saved58Printer();
    return findPairedPrinter(mac: saved.mac, name: saved.name);
  }

  static Future<bool> connectPrinter(String macAddress) async {
    final mac = macAddress.trim();
    if (mac.isEmpty) return false;

    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        try {
          await PrintBluetoothThermal.disconnect;
        } catch (_) {}
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }

      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!ok) continue;

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await PrintBluetoothThermal.connectionStatus) return true;
    }
    return false;
  }

  static Future<void> print58mmBluetooth({
    required VendorInvoicePrintData data,
    required String macAddress,
    required String printerName,
  }) async {
    await print58RawBytes(
      bytes: VendorEscPosReceipt.build58mm(data),
      macAddress: macAddress,
      printerName: printerName,
    );
  }

  static Future<void> print58RawBytes({
    required List<int> bytes,
    required String macAddress,
    required String printerName,
  }) async {
    final block = await ensureBluetoothReady();
    if (block != null) throw Exception(block);

    final paired = await findPairedPrinter(mac: macAddress, name: printerName);
    if (paired == null) {
      throw Exception(
        '$printerName is not paired on this phone. Tap "Change Bluetooth printer" and select it in phone Bluetooth settings first.',
      );
    }

    final mac = paired.macAdress.trim();
    final connected = await connectPrinter(mac);
    if (!connected) {
      throw Exception(
        'Could not connect to ${paired.name}. Turn the printer on, open phone Bluetooth settings and confirm it is paired, then tap "Change Bluetooth printer" to try again.',
      );
    }

    await VendorPrinterPrefs.save58Printer(mac: mac, name: paired.name);

    await _writeBytesChunked(bytes);

    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  static Future<void> _writeBytesChunked(List<int> bytes) async {
    if (bytes.isEmpty) {
      throw Exception('Nothing to print.');
    }
    const chunkSize = 512;
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      final end = offset + chunkSize > bytes.length
          ? bytes.length
          : offset + chunkSize;
      final ok = await PrintBluetoothThermal.writeBytes(
        bytes.sublist(offset, end),
      );
      if (!ok) {
        throw Exception('Print failed. Check paper and that the printer is ready.');
      }
      if (end < bytes.length) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
  }

  /// Server invoice PDF on 80mm roll — Epson / Star on Wi‑Fi or Ethernet.
  static Future<void> print80mmInvoicePdf({
    required VendorInvoicePrintData data,
  }) async {
    final doc = await VendorOrderApi.instance.fetchVendorAllOrderInvoiceDocument(
      data.orderDocumentPathId,
    );
    if (doc.bytes.isEmpty) {
      throw Exception('Invoice PDF is empty.');
    }
    await print80RawPdf(
      pdfBytes: doc.bytes,
      jobName: 'invoice_${data.orderNumber}',
    );
  }

  static Future<void> print80RawPdf({
    required Uint8List pdfBytes,
    required String jobName,
  }) async {
    if (pdfBytes.isEmpty) {
      throw Exception('PDF is empty.');
    }
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      format: PdfPageFormat.roll80,
      name: jobName,
    );
  }
}
