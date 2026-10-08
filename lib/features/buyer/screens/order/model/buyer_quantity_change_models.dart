import 'package:market_jango/features/buyer/screens/wallet/model/buyer_wallet_models.dart';

int _toInt(dynamic v, {int d = 0}) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

double _toDouble(dynamic v, {double d = 0}) {
  if (v == null) return d;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? d;
}

String _s(dynamic v) => v?.toString().trim() ?? '';

class BuyerPendingQuantityChangesPayload {
  final BuyerWalletPage<BuyerQuantityChangeRequestItem> page;

  BuyerPendingQuantityChangesPayload({required this.page});

  static BuyerPendingQuantityChangesPayload parse(Map<String, dynamic>? data) {
    if (data == null) {
      return BuyerPendingQuantityChangesPayload(
        page: const BuyerWalletPage(
          currentPage: 1,
          lastPage: 1,
          perPage: 15,
          total: 0,
          items: [],
        ),
      );
    }
    Map<String, dynamic>? pageMap;
    if (data['data'] is List || data['current_page'] != null) {
      pageMap = data;
    }
    final page = BuyerWalletPage.parse(
      pageMap,
      BuyerQuantityChangeRequestItem.fromJson,
    );
    return BuyerPendingQuantityChangesPayload(page: page);
  }
}

class BuyerQuantityChangeRequestItem {
  final int id;
  final String status;
  final int currentQuantity;
  final int proposedQuantity;
  final String reason;
  final double? refundPreview;
  final int invoiceItemId;
  final String orderNumber;
  final String productName;
  final String? productImage;
  final String? requestedByName;

  const BuyerQuantityChangeRequestItem({
    required this.id,
    required this.status,
    required this.currentQuantity,
    required this.proposedQuantity,
    required this.reason,
    this.refundPreview,
    required this.invoiceItemId,
    required this.orderNumber,
    required this.productName,
    this.productImage,
    this.requestedByName,
  });

  factory BuyerQuantityChangeRequestItem.fromJson(Map<String, dynamic> j) {
    final item = j['invoice_item'] is Map<String, dynamic>
        ? j['invoice_item'] as Map<String, dynamic>
        : null;
    final invoice = item?['invoice'] is Map<String, dynamic>
        ? item!['invoice'] as Map<String, dynamic>
        : null;
    final product = item?['product'] is Map<String, dynamic>
        ? item!['product'] as Map<String, dynamic>
        : null;
    final requestedBy = j['requested_by'] is Map<String, dynamic>
        ? j['requested_by'] as Map<String, dynamic>
        : null;

    final lineQty = item != null ? _toInt(item['quantity']) : 0;
    final current = j['current_quantity'] != null
        ? _toInt(j['current_quantity'])
        : lineQty;

    return BuyerQuantityChangeRequestItem(
      id: _toInt(j['id']),
      status: _s(j['status']),
      currentQuantity: current,
      proposedQuantity: _toInt(j['proposed_quantity']),
      reason: _s(j['reason']),
      refundPreview: j['refund_amount_preview'] == null
          ? null
          : _toDouble(j['refund_amount_preview']),
      invoiceItemId: _toInt(item?['id']),
      orderNumber: _s(invoice?['order_number']),
      productName: _s(product?['name']),
      productImage: product?['image']?.toString(),
      requestedByName: _s(requestedBy?['name']).isEmpty
          ? null
          : _s(requestedBy?['name']),
    );
  }
}
