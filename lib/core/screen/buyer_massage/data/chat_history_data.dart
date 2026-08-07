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
  final res = await http.get(
    uri,
    headers: {
      if (token != null) 'token': token,
      'Accept': 'application/json',
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to fetch chat history: ${res.statusCode}');
  }

  final body = res.body;
  if (body.trim().isEmpty) {
    throw Exception('Empty chat history response');
  }

  try {
    final parsed = ChatHistoryResponse.fromBody(body);
    return parsed.data;
  } on FormatException catch (e) {
    throw Exception(
      'Chat history response was incomplete or invalid JSON. Please try again. ($e)',
    );
  } catch (e) {
    // jsonDecode can also throw other errors for truncated payloads
    if (e.toString().contains('FormatException') ||
        e.toString().contains('Unexpected end of input')) {
      throw Exception(
        'Chat history response was incomplete. Please try again.',
      );
    }
    rethrow;
  }
}

/// Polls only while the chat screen is open (autoDispose + cancellable loop).
/// Later poll failures keep the last good messages instead of blanking the UI.
final chatHistoryStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, partnerId) async* {
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  List<ChatMessage> latest = await fetchChatHistory(partnerId);
  yield latest;

  while (!cancelled) {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (cancelled) break;
    try {
      latest = await fetchChatHistory(partnerId);
      yield latest;
    } catch (_) {
      // Keep showing previous messages if a poll fails (e.g. truncated JSON).
      yield latest;
    }
  }
});
