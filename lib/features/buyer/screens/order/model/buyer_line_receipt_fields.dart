import 'package:intl/intl.dart';

/// Parses receipt fields shared by all-order rows and invoice line items.
class BuyerLineReceiptFields {
  const BuyerLineReceiptFields({
    this.deliveredAt,
    this.receivedAt,
    this.receivedVia,
    this.autoReceiveDeadlineAt,
    required this.canMarkReceived,
    required this.statusRaw,
  });

  final DateTime? deliveredAt;
  final DateTime? receivedAt;
  final String? receivedVia;
  final DateTime? autoReceiveDeadlineAt;
  final bool canMarkReceived;
  final String statusRaw;

  factory BuyerLineReceiptFields.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    final statusLower = status.toLowerCase().trim();

    final actions = json['actions'];
    bool canMark;
    if (actions is Map) {
      final flag = actions['can_mark_received'];
      if (flag is bool) {
        canMark = flag;
      } else {
        canMark = statusLower == 'delivered';
      }
    } else {
      canMark = statusLower == 'delivered';
    }

    return BuyerLineReceiptFields(
      deliveredAt: _parseDate(json['delivered_at']),
      receivedAt: _parseDate(json['received_at']),
      receivedVia: json['received_via']?.toString(),
      autoReceiveDeadlineAt: _parseDate(json['auto_receive_deadline_at']),
      canMarkReceived: canMark,
      statusRaw: status,
    );
  }

  bool get isReceived {
    final s = statusRaw.toLowerCase().trim();
    return s == 'received' || receivedAt != null;
  }

  String get autoReceiveHintLine {
    const fallback =
        'If you don\'t confirm, this will auto-mark received within 24 hours';
    if (autoReceiveDeadlineAt == null) return fallback;
    final local = autoReceiveDeadlineAt!.toLocal();
    final formatted = DateFormat('MMM d, yyyy h:mm a').format(local);
    return 'If you don\'t confirm, this will auto-mark received by $formatted';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
