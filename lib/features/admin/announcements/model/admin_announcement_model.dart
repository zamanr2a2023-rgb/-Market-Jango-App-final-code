/// STEP_11 — body for `POST /api/admin/announcements`.
class AdminAnnouncementRequest {
  final String title;
  final bool channelSms;
  final bool channelWhatsapp;
  final bool channelInApp;
  final String zone;

  const AdminAnnouncementRequest({
    required this.title,
    required this.channelSms,
    required this.channelWhatsapp,
    required this.channelInApp,
    required this.zone,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'channel_sms': channelSms,
        'channel_whatsapp': channelWhatsapp,
        'channel_in_app': channelInApp,
        'zone': zone,
      };
}
