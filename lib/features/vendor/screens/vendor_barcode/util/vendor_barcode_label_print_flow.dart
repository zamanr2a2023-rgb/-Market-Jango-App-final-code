import 'package:flutter/material.dart';
import 'package:market_jango/core/constants/color_control/all_color.dart';
import 'package:market_jango/core/widget/global_snackbar.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/data/vendor_barcode_api.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/model/vendor_barcode_models.dart';
import 'package:market_jango/features/vendor/screens/vendor_barcode/util/vendor_barcode_label_pdf.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/util/vendor_esc_pos_util.dart';
import 'package:market_jango/features/vendor/screens/vendor_order_management/widget/vendor_printer_choice_sheet.dart';

/// Label count → `POST /vendor/products/{id}/barcode/labels` → printer choice.
class VendorBarcodeLabelPrintFlow {
  VendorBarcodeLabelPrintFlow._();

  static Future<int?> promptLabelCount(
    BuildContext context, {
    int maxCount = 50,
    String confirmLabel = 'Print',
  }) async {
    final countCtrl = TextEditingController(text: '1');
    final submitted = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Label count'),
        content: TextField(
          controller: countCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '1–$maxCount',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: AllColor.orange50.withValues(alpha: 0.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AllColor.loginButtomColor),
            ),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(countCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx, n);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AllColor.loginButtomColor,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    countCtrl.dispose();
    if (submitted == null || submitted < 1 || submitted > maxCount) return null;
    return submitted;
  }

  static Future<void> printForProduct(
    BuildContext context, {
    required int productId,
    int maxLabelCount = 50,
  }) async {
    final count = await promptLabelCount(
      context,
      maxCount: maxLabelCount,
    );
    if (count == null || !context.mounted) return;
    await printWithLabelCount(
      context,
      productId: productId,
      labelCount: count,
    );
  }

  static Future<void> printWithLabelCount(
    BuildContext context, {
    required int productId,
    required int labelCount,
  }) async {
    if (productId <= 0) {
      GlobalSnackbar.show(
        context,
        title: 'Unavailable',
        message: 'Could not resolve product id for printing.',
        type: CustomSnackType.error,
      );
      return;
    }

    try {
      final result = await VendorBarcodeApi.instance.fetchLabelPayload(
        productId: productId,
        labelCount: labelCount,
      );
      if (!context.mounted) return;
      await openPrinterSheet(context, result);
    } catch (e) {
      if (context.mounted) {
        GlobalSnackbar.show(
          context,
          title: 'Error',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: CustomSnackType.error,
        );
      }
    }
  }

  static Future<void> openPrinterSheet(
    BuildContext context,
    VendorBarcodeLabelsResult result,
  ) async {
    final name = result.product.name.isEmpty
        ? 'Product #${result.product.id}'
        : result.product.name;
    await VendorPrinterChoiceSheet.show(
      context,
      title: 'Print barcode label',
      subtitle: name,
      subtitle80: 'Epson / Star · label PDF template',
      pdfJobName: 'barcode_product_${result.product.id}',
      build58Bytes: () async =>
          VendorEscPosUtil.buildBarcodeLabel58mm(result),
      build80Pdf: () async => buildBarcodeLabelTemplatePdf(result),
    );
  }
}
