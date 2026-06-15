import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/chat_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

class ChatUnreadCount {
  final int totalUnread;
  final Map<int, int> byPartnerId;

  const ChatUnreadCount({
    required this.totalUnread,
    required this.byPartnerId,
  });

  factory ChatUnreadCount.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      return const ChatUnreadCount(totalUnread: 0, byPartnerId: {});
    }
    final total = data['total_unread'];
    final totalUnread = total is int
        ? total
        : (total is num ? total.toInt() : int.tryParse('$total') ?? 0);

    final map = <int, int>{};
    final conversations = data['conversations'];
    if (conversations is List) {
      for (final e in conversations) {
        if (e is! Map<String, dynamic>) continue;
        final pid = e['partner_id'];
        final count = e['unread_count'];
        final partnerId = pid is int
            ? pid
            : (pid is num ? pid.toInt() : int.tryParse('$pid'));
        final unread = count is int
            ? count
            : (count is num ? count.toInt() : int.tryParse('$count') ?? 0);
        if (partnerId != null && partnerId > 0) {
          map[partnerId] = unread;
        }
      }
    }
    return ChatUnreadCount(totalUnread: totalUnread, byPartnerId: map);
  }
}

class ChatReadApi {
  ChatReadApi._();

  static Future<Map<String, String>> _headers() async {
    final token = await AuthLocalStorage().getToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'token': token,
    };
  }

  static String _errorMessage(int status, String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>?;
      final msg = map?['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return 'Request failed ($status)';
  }

  static Future<ChatUnreadCount> fetchUnreadCount() async {
    final uri = Uri.parse(ChatAPIController.chatUnreadCount);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.statusCode, res.body));
    }
    final top = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatUnreadCount.fromJson(top);
  }

  static Future<void> markConversationRead(int partnerId) async {
    if (partnerId <= 0) return;
    final uri = Uri.parse(ChatAPIController.chatMarkRead(partnerId));
    final res = await http.put(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.statusCode, res.body));
    }
  }

  static Future<int> markAllRead() async {
    final uri = Uri.parse(ChatAPIController.chatMarkAllRead);
    final res = await http.put(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res.statusCode, res.body));
    }
    try {
      final top = jsonDecode(res.body) as Map<String, dynamic>;
      final data = top['data'];
      if (data is Map<String, dynamic>) {
        final n = data['marked_read'];
        if (n is int) return n;
        if (n is num) return n.toInt();
        return int.tryParse('$n') ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}

final chatUnreadCountProvider =
    FutureProvider.autoDispose<ChatUnreadCount>((ref) async {
  return ChatReadApi.fetchUnreadCount();
});
