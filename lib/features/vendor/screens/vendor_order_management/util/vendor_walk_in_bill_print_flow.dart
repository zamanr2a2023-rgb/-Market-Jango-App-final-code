import 'package:flutter/material.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/data/vendor_order_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_invoice_print_data.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/model/vendor_orders_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_esc_pos_receipt.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_walk_in_bill_text.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_printer_choice_sheet.dart';

/// Walk-in bill → same 58mm Bluetooth / 80mm Wi‑Fi printer sheet as barcode labels.
class VendorWalkInBillPrintFlow {
  VendorWalkInBillPrintFlow._();

  static Future<void> openPrinterSheet(
    BuildContext context, {
    required VendorManualOrderInvoice invoice,
    String? billText,
  }) async {
    final text = billText ?? formatWalkInBillText(invoice);
    final pathId = walkInOrderDocumentPathId(invoice);
    final printData = VendorInvoicePrintData.fromManualInvoice(invoice, pathId);

    await VendorPrinterChoiceSheet.show(
      context,
      title: 'Print bill',
      subtitle: invoice.orderNumber,
      subtitle80: pathId > 0
          ? 'Epson / Star · invoice PDF'
          : 'Epson / Star · bill text PDF',
      pdfJobName: 'bill_${invoice.orderNumber}',
      build58Bytes: () async => VendorEscPosReceipt.build58mm(printData),
      build80Pdf: () async {
        if (pathId > 0) {
          try {
            final doc = await VendorOrderApi.instance
                .fetchVendorAllOrderInvoiceDocument(pathId);
            if (doc.bytes.isNotEmpty) return doc.bytes;
          } catch (_) {}
        }
        return buildWalkInBillTextPdf(text);
      },
    );
  }
}
