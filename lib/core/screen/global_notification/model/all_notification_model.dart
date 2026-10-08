import 'package:intl/intl.dart';

/// Supported push / inbox event types (STEP_05).
enum NotificationEventType {
  promotion,
  newProduct,
  follow,
  review,
  announcement,
  autoLineRefund,
  unknown,
}

NotificationEventType parseNotificationEventType(dynamic raw) {
  final s = raw?.toString().trim().toLowerCase() ?? '';
  switch (s) {
    case 'promotion':
    case 'promo':
      return NotificationEventType.promotion;
    case 'new_product':
    case 'new-product':
    case 'product':
      return NotificationEventType.newProduct;
    case 'follow':
    case 'follower':
      return NotificationEventType.follow;
    case 'review':
      return NotificationEventType.review;
    case 'announcement':
    case 'announce':
      return NotificationEventType.announcement;
    case 'auto_line_refund':
    case 'auto-line-refund':
      return NotificationEventType.autoLineRefund;
    default:
      return NotificationEventType.unknown;
  }
}

class NotificationModel {
  final int id;
  final String name;
  final String message;
  final bool isRead;
  final int senderId;
  final int receiverId;
  final DateTime? createdAt;
  final Sender sender;
  final NotificationEventType eventType;
  final String? eventTypeRaw;
  final int? productId;
  final int? vendorId;
  final int? promotionId;
  final String? deepLink;

  /// `auto_line_refund`: `cancel` or `quantity_reduce`.
  final String? changeType;
  final double? amount;
  final int? orderId;
  final int? refundId;

  NotificationModel({
    required this.id,
    required this.name,
    required this.message,
    required this.isRead,
    required this.senderId,
    required this.receiverId,
    this.createdAt,
    required this.sender,
    this.eventType = NotificationEventType.unknown,
    this.eventTypeRaw,
    this.productId,
    this.vendorId,
    this.promotionId,
    this.deepLink,
    this.changeType,
    this.amount,
    this.orderId,
    this.refundId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final senderRaw = json['sender'];
    final nested = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final eventRaw =
        json['event_type'] ??
        json['eventType'] ??
        json['type'] ??
        json['notification_type'] ??
        nested['event_type'] ??
        nested['type'] ??
        nested['notification_type'];

    int? toId(dynamic v) {
      if (v == null) return null;
      if (v is int) return v > 0 ? v : null;
      if (v is num) return v.toInt() > 0 ? v.toInt() : null;
      return int.tryParse(v.toString());
    }

    double? toAmount(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', ''));
    }

    dynamic pick(String key) => json[key] ?? nested[key];

    return NotificationModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      isRead:
          json['is_read'] == 1 ||
          json['is_read'] == true ||
          json['is_read'] == '1' ||
          json['read'] == true ||
          json['read'] == 1,
      senderId: json['sender_id'] is int
          ? json['sender_id'] as int
          : int.tryParse('${json['sender_id'] ?? 0}') ?? 0,
      receiverId: json['receiver_id'] is int
          ? json['receiver_id'] as int
          : int.tryParse('${json['receiver_id'] ?? 0}') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      sender: senderRaw is Map<String, dynamic>
          ? Sender.fromJson(senderRaw)
          : Sender(id: 0, name: '', email: ''),
      eventType: parseNotificationEventType(eventRaw),
      eventTypeRaw: eventRaw?.toString(),
      productId: toId(json['product_id'] ?? json['productId']),
      vendorId: toId(json['vendor_id'] ?? json['vendorId']),
      promotionId: toId(json['promotion_id'] ?? json['promo_id']),
      deepLink:
          json['deep_link']?.toString() ??
          json['deeplink']?.toString() ??
          json['link']?.toString() ??
          nested['deep_link']?.toString(),
      changeType: pick('change_type')?.toString(),
      amount: toAmount(pick('amount')),
      orderId: toId(pick('order_id') ?? pick('orderId')),
      refundId: toId(pick('refund_id') ?? pick('refundId')),
    );
  }

  String get walletRefundText {
    final n = amount;
    final shown = n == null
        ? null
        : (n == n.roundToDouble()
              ? n.toStringAsFixed(0)
              : n.toStringAsFixed(2));
    if (shown != null && shown.isNotEmpty) {
      return '$shown has been returned to your wallet';
    }
    if (message.trim().isNotEmpty) return message.trim();
    return 'A refund has been returned to your wallet';
  }

  String get formattedTime {
    if (createdAt == null) return '';
    return DateFormat('hh:mm a').format(createdAt!);
  }

  String get formattedDate {
    if (createdAt == null) return '';
    return DateFormat('yyyy-MM-dd').format(createdAt!);
  }
}

class Sender {
  final int id;
  final String name;
  final String email;

  Sender({required this.id, required this.name, required this.email});

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}
