package com.danieldacool.nutrition_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * An ongoing notification, muted via its channel (no sound/vibration), that
 * Android renders on the lock screen: today's steps out of the goal (big)
 * and calories left (smaller), with a custom RemoteViews layout (see
 * res/layout/lockscreen_notification_{expanded,collapsed}.xml) since
 * flutter_local_notifications' Dart API has no custom-layout support.
 *
 * Driven from Dart via the `nutrition/lockscreen_notification` MethodChannel
 * registered in [MainActivity] — see
 * lib/features/widget_home/lockscreen_notification_sync.dart.
 */
object LockScreenNotification {
  // v2: IMPORTANCE_LOW channels are "silent" notifications, and Android's
  // lock-screen setting "hide silent notifications" (on by default on some
  // OEM skins, e.g. HyperOS) hides them from the lock screen even though
  // they still show in the shade — which is exactly what this looked like.
  // Importance can't be changed on an existing channel, hence the new id;
  // sound/vibration are disabled on the channel itself to stay silent in
  // practice while counting as a non-silent (DEFAULT) notification.
  private const val CHANNEL_ID = "steps_lockscreen_v2"
  private const val CHANNEL_NAME = "Steps & calories"
  private const val NOTIFICATION_ID = 2001

  fun show(
      context: Context,
      steps: Int,
      stepGoal: Int,
      kcalLeftText: String,
      goalReached: Boolean,
  ) {
    ensureChannel(context)

    val goalMet = goalReached || (stepGoal > 0 && steps >= stepGoal)
    val progressMax = 1000
    val progress =
        if (stepGoal > 0) {
          ((steps.toLong() * progressMax) / stepGoal).toInt().coerceIn(0, progressMax)
        } else {
          0
        }

    val expanded =
        RemoteViews(context.packageName, R.layout.lockscreen_notification_expanded).apply {
          setTextViewText(R.id.lockscreen_steps_big, "%,d".format(steps))
          setTextViewText(
              R.id.lockscreen_steps_goal,
              "/ %,d steps".format(stepGoal),
          )
          setTextViewText(R.id.lockscreen_kcal_left, kcalLeftText)
          setProgressBar(R.id.lockscreen_progress_bar, progressMax, progress, false)
          setProgressBar(R.id.lockscreen_progress_bar_teal, progressMax, progress, false)
          val progressPercent = if (stepGoal > 0) ((steps.toLong() * 100) / stepGoal).toInt().coerceIn(0, 100) else 0
          setTextViewText(R.id.lockscreen_progress_percent, "$progressPercent%")
          setViewVisibility(
              R.id.lockscreen_progress_bar,
              if (goalMet) android.view.View.GONE else android.view.View.VISIBLE,
          )
          setViewVisibility(
              R.id.lockscreen_progress_bar_teal,
              if (goalMet) android.view.View.VISIBLE else android.view.View.GONE,
          )
          setViewVisibility(
              R.id.lockscreen_goal_pill,
              if (goalMet) android.view.View.VISIBLE else android.view.View.GONE,
          )
        }

    val collapsed =
        RemoteViews(context.packageName, R.layout.lockscreen_notification_collapsed).apply {
          setTextViewText(
              R.id.lockscreen_collapsed_line,
              "%,d / %,d steps · %s".format(steps, stepGoal, kcalLeftText),
          )
        }

    val contentIntent =
        PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )

    val notification =
        NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(ContextCompat.getColor(context, R.color.lockscreen_accent_periwinkle))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setContentIntent(contentIntent)
            .build()

    NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
  }

  fun cancel(context: Context) {
    NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
  }

  private fun ensureChannel(context: Context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.deleteNotificationChannel("steps_lockscreen")
    val channel =
        NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT)
            .apply {
              setShowBadge(false)
              setSound(null, null)
              enableVibration(false)
            }
    manager.createNotificationChannel(channel)
  }
}
