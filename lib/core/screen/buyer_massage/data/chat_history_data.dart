import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/chat_api.dart';
import 'package:market_jango/core/screen/buyer_massage/model/chat_history_model.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

/// Fetcher
Future<List<ChatMessage>> fetchChatHistory(int partnerId) async {
  final authStorage = AuthLocalStorage();
  final token = await authStorage.getToken();

  final uri = Uri.parse(ChatAPIController.chat_history(partnerId));
  final res = await http.get(uri, headers: {if (token != null) 'token': token});

  if (res.statusCode == 200) {
    final parsed = ChatHistoryResponse.fromBody(res.body);
    return parsed.data;
  }

  throw Exception('Failed to fetch chat history: ${res.statusCode}');
}

/// Polls only while the chat screen is open (autoDispose + cancellable loop).
final chatHistoryStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, partnerId) async* {
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  yield await fetchChatHistory(partnerId);

  while (!cancelled) {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (cancelled) break;
    yield await fetchChatHistory(partnerId);
  }
});
