import 'package:market_jango/features/buyer/screens/order/model/buyer_line_receipt_fields.dart';

/// Receipt fields on GET /shipments/{id} are merged at data root; status lives on shipment.
BuyerLineReceiptFields transportShipmentReceiptFields({
  required Map<String, dynamic> shipment,
  Map<String, dynamic>? detailRoot,
}) {
  final merged = <String, dynamic>{
    if (detailRoot != null) ...detailRoot,
    'status': shipment['status'] ?? detailRoot?['status'],
  };
  return BuyerLineReceiptFields.fromJson(merged);
}
