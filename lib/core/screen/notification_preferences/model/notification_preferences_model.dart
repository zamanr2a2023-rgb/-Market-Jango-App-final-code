/// STEP_11 — body for `PUT /api/notification/preferences`.
class NotificationPreferences {
  final bool notifySms;
  final bool notifyWhatsapp;
  final bool notifyInApp;

  const NotificationPreferences({
    required this.notifySms,
    required this.notifyWhatsapp,
    required this.notifyInApp,
  });

  NotificationPreferences copyWith({
    bool? notifySms,
    bool? notifyWhatsapp,
    bool? notifyInApp,
  }) {
    return NotificationPreferences(
      notifySms: notifySms ?? this.notifySms,
      notifyWhatsapp: notifyWhatsapp ?? this.notifyWhatsapp,
      notifyInApp: notifyInApp ?? this.notifyInApp,
    );
  }

  Map<String, dynamic> toJson() => {
        'notify_sms': notifySms,
        'notify_whatsapp': notifyWhatsapp,
        'notify_in_app': notifyInApp,
      };

  /// Parse only known keys from user profile / API maps. Missing → [fallback].
  factory NotificationPreferences.fromMap(
    Map<String, dynamic>? map, {
    NotificationPreferences fallback = const NotificationPreferences(
      notifySms: true,
      notifyWhatsapp: true,
      notifyInApp: true,
    ),
  }) {
    if (map == null) return fallback;
    bool? pick(String key) {
      if (!map.containsKey(key)) return null;
      final v = map[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().trim().toLowerCase();
      if (s == null || s.isEmpty || s == 'null') return null;
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no') return false;
      return null;
    }

    return NotificationPreferences(
      notifySms: pick('notify_sms') ?? fallback.notifySms,
      notifyWhatsapp: pick('notify_whatsapp') ?? fallback.notifyWhatsapp,
      notifyInApp: pick('notify_in_app') ?? fallback.notifyInApp,
    );
  }
}
