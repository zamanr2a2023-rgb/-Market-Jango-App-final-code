import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_jango/core/constants/api_control/vendor_api.dart';
import 'package:market_jango/core/utils/auth_local_storage.dart';

/// `POST /api/vendor/ai/chat-reply`
///
/// - `conversation_id`: same id as `GET /api/chat/history/{id}` (partner id)
/// - `message`: last partner message text
class GenerateChatReplyApi {
  GenerateChatReplyApi._();

  static Future<String> generate({
    required int conversationId,
    required String message,
    String? tone,
    String? language,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw Exception('No message to reply to');
    }
    if (conversationId <= 0) {
      throw Exception('Invalid conversation id');
    }

    final token = await AuthLocalStorage().getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token not found');
    }

    final uri = Uri.parse(VendorAPIController.generateChatReply);
    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'message': trimmed,
      if (tone != null && tone.trim().isNotEmpty) 'tone': tone.trim(),
      if (language != null && language.trim().isNotEmpty)
        'language': language.trim(),
    };

    final response = await http.post(
      uri,
      headers: {
        'token': token,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 404) {
      throw Exception(
        'AI chat reply is not available on this server. Please enable it on the backend.',
      );
    }

    dynamic decoded;
    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        throw Exception(
          response.statusCode >= 400
              ? 'AI reply failed (${response.statusCode})'
              : 'Invalid AI reply response',
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = decoded is Map
          ? (decoded['message'] ?? decoded['error'])
          : null;
      throw Exception(
        (msg?.toString().trim().isNotEmpty ?? false)
            ? msg.toString()
            : 'AI reply failed (${response.statusCode})',
      );
    }

    if (decoded is! Map) {
      throw Exception('Invalid response from chat-reply');
    }

    if (decoded['success'] == false) {
      final msg = decoded['message']?.toString().trim();
      throw Exception(
        (msg != null && msg.isNotEmpty) ? msg : 'AI reply failed',
      );
    }

    final data = decoded['data'];
    final reply = data is Map
        ? data['reply']?.toString()
        : decoded['reply']?.toString();

    if (reply == null || reply.trim().isEmpty) {
      throw Exception('No reply returned');
    }
    return reply.trim();
  }
}
