/// Resolves the **other user's id** for chat history / send APIs.
///
/// Backend list items may expose `partner_id`, `user_id`, or sender/receiver
/// pairs. When `partner_id` equals the logged-in user (common vendor-side bug),
/// fall back to the other participant.
int resolveChatPartnerUserId(
  Map<String, dynamic> json, {
  int? currentUserId,
}) {
  int read(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  bool isOther(int id) =>
      id > 0 && (currentUserId == null || currentUserId <= 0 || id != currentUserId);

  for (final key in ['partner_user_id', 'other_user_id']) {
    final id = read(json[key]);
    if (isOther(id)) return id;
  }

  final partnerId = read(json['partner_id']);
  final userId = read(json['user_id']);
  final senderId = read(json['sender_id']);
  final receiverId = read(json['receiver_id']);

  if (currentUserId != null && currentUserId > 0) {
    if (isOther(partnerId)) return partnerId;
    if (isOther(userId)) return userId;
    if (senderId == currentUserId && isOther(receiverId)) return receiverId;
    if (receiverId == currentUserId && isOther(senderId)) return senderId;
    return 0;
  }

  if (partnerId > 0) return partnerId;
  if (userId > 0) return userId;
  return 0;
}
