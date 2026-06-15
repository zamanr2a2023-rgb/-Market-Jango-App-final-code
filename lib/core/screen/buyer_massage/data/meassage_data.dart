import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/chat_api.dart';
import 'package:market_jango/core/screen/buyer_massage/data/chat_read_data.dart';
import 'package:market_jango/core/screen/buyer_massage/model/massage_list_model.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

class ChatListController extends AsyncNotifier<List<ChatThread>> {
  final http.Client _client = http.Client();

  @override
  Future<List<ChatThread>> build() async {
    return _fetch();
  }

  Future<List<ChatThread>> _fetch() async {
    final authStorage = AuthLocalStorage();
    final token = await authStorage.getToken();
    final myUserId = int.tryParse(await authStorage.getUserId() ?? '');

    final uri = Uri.parse(
      ChatAPIController.massage_list,
    ); // e.g. /api/chat/user
    final res = await _client.get(
      uri,
      headers: {
        if (token != null) 'token': token,
        'Accept': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed: ${res.statusCode} ${res.reasonPhrase}');
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (map['data'] as List? ?? [])
        .map(
          (e) => ChatThread.fromJson(
            e as Map<String, dynamic>,
            currentUserId: myUserId,
          ),
        )
        .toList();
    return list;
  }

  /// pull-to-refresh / ম্যানুয়াল রিফেচ
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  void applyConversationReadLocally(int partnerId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final c in current)
        if (c.partnerId == partnerId)
          ChatThread(
            chatId: c.chatId,
            partnerId: c.partnerId,
            partnerName: c.partnerName,
            partnerImage: c.partnerImage,
            lastMessage: c.lastMessage,
            lastMessageTime: c.lastMessageTime,
            isRead: 1,
            unreadCount: 0,
            hasUnread: false,
          )
        else
          c,
    ]);
  }

  /// `PUT /api/chat/read/{partner_id}` + local inbox update.
  Future<void> markConversationRead(int partnerId) async {
    if (partnerId <= 0) return;
    applyConversationReadLocally(partnerId);
    try {
      await ChatReadApi.markConversationRead(partnerId);
    } catch (_) {
      await refresh();
    }
  }

  /// `PUT /api/chat/read` — mark all conversations read.
  Future<void> markAllRead() async {
    await ChatReadApi.markAllRead();
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final c in current)
        ChatThread(
          chatId: c.chatId,
          partnerId: c.partnerId,
          partnerName: c.partnerName,
          partnerImage: c.partnerImage,
          lastMessage: c.lastMessage,
          lastMessageTime: c.lastMessageTime,
          isRead: 1,
          unreadCount: 0,
          hasUnread: false,
        ),
    ]);
  }
}

/// একটাই প্রোভাইডার ব্যবহার করবেন UI-তে
final chatListProvider =
    AsyncNotifierProvider<ChatListController, List<ChatThread>>(
      ChatListController.new,
    );

/// Refresh inbox list + unread totals (`doc/details.md`).
Future<void> refreshChatInbox(WidgetRef ref) async {
  ref.invalidate(chatUnreadCountProvider);
  await ref.read(chatListProvider.notifier).refresh();
  try {
    await ref.read(chatUnreadCountProvider.future);
  } catch (_) {}
}
