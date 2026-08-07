class ChatArgs {
  final int partnerId;
  final String partnerName;
  final String partnerImage;
  final int myUserId;
  /// Backend conversation / chat id used by AI reply (`conversation_id`).
  final int? conversationId;

  ChatArgs({
    required this.partnerId,
    required this.partnerName,
    required this.partnerImage,
    required this.myUserId,
    this.conversationId,
  });
}
