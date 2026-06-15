// chat_list_models.dart
import 'package:market_jango/core/screen/buyer_massage/util/chat_partner_utils.dart';

class ChatListResponse {
  final String status;
  final String message;
  final List<ChatThread> data;

  ChatListResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ChatListResponse.fromJson(Map<String, dynamic> json) {
    return ChatListResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: (json['data'] as List? ?? [])
          .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatThread {
  final int chatId;
  final int partnerId;
  final String partnerName;
  final String partnerImage;
  final String lastMessage;
  final String lastMessageTime; // already humanized by backend
  final int isRead;
  final int unreadCount;
  final bool hasUnread;

  ChatThread({
    required this.chatId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isRead,
    this.unreadCount = 0,
    this.hasUnread = false,
  });

  bool get isUnread => hasUnread || unreadCount > 0 || isRead == 0;

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is bool) return v ? 1 : 0;
    return int.tryParse('$v') ?? 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final lower = v.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  factory ChatThread.fromJson(
    Map<String, dynamic> json, {
    int? currentUserId,
  }) {
    final unread = _toInt(json['unread_count']);
    final hasUnread = _toBool(json['has_unread']) || unread > 0;

    // Prefer API `partner_id` (GET /api/chat/user) — only fall back when missing/self.
    var partnerId = _toInt(json['partner_id']);
    if (partnerId <= 0 ||
        (currentUserId != null &&
            currentUserId > 0 &&
            partnerId == currentUserId)) {
      partnerId = resolveChatPartnerUserId(json, currentUserId: currentUserId);
    }

    return ChatThread(
      chatId: _toInt(json['chat_id']),
      partnerId: partnerId,
      partnerName: json['partner_name']?.toString() ?? '',
      partnerImage: json['partner_image']?.toString() ?? '',
      lastMessage: json['last_message']?.toString() ?? '',
      lastMessageTime: json['last_message_time']?.toString() ?? '',
      isRead: _toInt(json['is_read']),
      unreadCount: unread,
      hasUnread: hasUnread,
    );
  }
}
