import 'package:market_jango/features/buyer/screens/billing/model/invoice_details_model.dart';

/// Mode / fulfillment summary for order details (My Orders entry).
String buyerInvoiceFulfillmentModeLabel(List<InvoiceItemDetail> items) {
  if (items.isEmpty) return '—';

  final awaiting = items.where((i) => i.canMarkReceived).length;
  if (awaiting > 0) return 'delivered';

  if (items.every((i) => i.isReceived)) return 'received';

  final statuses = items
      .map((i) => i.status.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  if (statuses.length == 1) return statuses.first;

  return items.first.status.trim().isNotEmpty ? items.first.status.trim() : '—';
}

List<InvoiceItemDetail> buyerLinesAwaitingReceipt(List<InvoiceItemDetail> items) =>
    items.where((i) => i.canMarkReceived).toList();
