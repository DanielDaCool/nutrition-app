package com.danieldacool.nutrition_app

import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// FlutterFragmentActivity is required by the `health` plugin to request
// Health Connect permissions on Android 14+.
class MainActivity : FlutterFragmentActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    cleanUpOldLockScreenNotification()
  }

  // One-time cleanup for existing installs: the home-screen widget and
  // lock-screen notification features (and the native code that managed
  // their notification channels) were removed. Delete the old channels so
  // the stale "steps & calories" notification doesn't linger forever on
  // lock screens that already have it, and cancel any instance currently
  // showing.
  private fun cleanUpOldLockScreenNotification() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
      manager.deleteNotificationChannel("steps_lockscreen")
      manager.deleteNotificationChannel("steps_lockscreen_v2")
    }
    NotificationManagerCompat.from(this).cancel(2001)
  }
}
