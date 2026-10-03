// Pushes the ongoing lock-screen notification (see
// android/.../LockScreenNotification.kt) with today's steps-vs-goal and
// kcal-left, via a small MethodChannel bridge — flutter_local_notifications'
// Dart API has no custom-RemoteViews support, so this one notification is
// native. Called from HomeWidgetSyncController._syncNow() so one sync pass
// drives both the home-screen widget and the lock-screen notification.
library;

import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('nutrition/lockscreen_notification');

/// Updates the lock-screen notification. No-op (and never throws) off
/// Android, and swallows platform-channel failures the same way the
/// `HomeWidget` calls in `HomeWidgetSyncController` do — no channel
/// implementation (e.g. in tests, or on iOS) just means nothing to show.
Future<void> syncLockScreenNotification({
  required int? steps,
  required int stepGoal,
  required String kcalLeftText,
  required bool goalReached,
}) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('update', {
      'steps': steps ?? 0,
      'stepGoal': stepGoal,
      'kcalLeftText': kcalLeftText,
      'goalReached': goalReached,
    });
  } catch (_) {
    // Platform channel unavailable — not a sync failure.
  }
}
