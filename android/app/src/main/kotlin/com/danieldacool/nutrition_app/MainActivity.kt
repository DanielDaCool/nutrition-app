package com.danieldacool.nutrition_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the `health` plugin to request
// Health Connect permissions on Android 14+.
class MainActivity : FlutterFragmentActivity() {
  private val lockScreenNotificationChannel = "nutrition/lockscreen_notification"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, lockScreenNotificationChannel)
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "update" -> {
              LockScreenNotification.show(
                  context = applicationContext,
                  steps = call.argument<Int>("steps") ?: 0,
                  stepGoal = call.argument<Int>("stepGoal") ?: 0,
                  kcalLeftText = call.argument<String>("kcalLeftText") ?: "",
                  goalReached = call.argument<Boolean>("goalReached") ?: false,
              )
              result.success(null)
            }
            "cancel" -> {
              LockScreenNotification.cancel(applicationContext)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        }
  }
}
