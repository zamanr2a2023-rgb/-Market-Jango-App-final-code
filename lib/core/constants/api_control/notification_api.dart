import 'global_api.dart';

class NotificationAPIController {
  static final String _base_api = "$api/api";

  /// `GET /api/notification/`
  static String notificationList = "$_base_api/notification/";

  /// `PUT /api/notification/read/{id}`
  static String notificationRead(int id) => "$_base_api/notification/read/$id";

  /// `PUT /api/notification/preferences` — STEP_11.
  static String get notificationPreferences =>
      "$_base_api/notification/preferences";

  /// `POST /api/admin/announcements` — STEP_11.
  static String get adminAnnouncements => "$_base_api/admin/announcements";

  /// `POST /api/save-fcm`
  static String saveFcm = "$_base_api/save-fcm";
}