// OWNER: Health Connect agent (C).
// Thin wrapper over flutter_local_notifications for the walk reminder: one
// Android notification channel, shown at most once a day.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _channelId = 'walk_reminder';
const _channelName = 'Walk reminder';
const _channelDescription =
    "Reminds you to take a walk when you haven't moved much today";
const _notificationId = 1001;

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

/// Initializes the notifications plugin; call once at app startup, before
/// [showWalkReminderNotification] can be used.
Future<void> initWalkReminderNotifications() => _plugin.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ),
);

/// Requests the Android 13+ POST_NOTIFICATIONS permission. Returns true when
/// granted (or when the platform doesn't require it).
Future<bool> requestWalkReminderPermission() async {
  final android = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return true;
  return await android.requestNotificationsPermission() ?? true;
}

/// Shows the walk reminder notification. Safe to call from a background
/// isolate (the plugin doesn't need a running Flutter app).
Future<void> showWalkReminderNotification() => _plugin.show(
  id: _notificationId,
  title: 'Time to stretch your legs',
  body: "You're behind on steps today. A short walk would help.",
  notificationDetails: const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  ),
);
