package com.danieldacool.nutrition_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat

/**
 * RESEARCH / PROTOTYPE — NOT SHIPPED. Lives only on the
 * `claude/lockscreen-live-updates-research` branch; never merged, never a PR.
 * Daniel asked for this to be built and researched but explicitly kept out of
 * the current version (lock-screen card + widget are removed there).
 *
 * This is the Android 16 ("Baklava", API 36) "Live Updates" path for the
 * steps/calories lock-screen card: a `Notification.ProgressStyle` notification
 * that opts into system promotion via `setRequestPromotedOngoing(true)`, which
 * is what earns the permanently-expanded placement on the lock screen — the
 * same honest mechanism Google ships for rideshare/delivery progress, with no
 * fake MediaSession and no risk of this app showing up as a phantom
 * "now playing" track on Bluetooth/car/other media surfaces.
 *
 * [LockScreenNotification] (the shipped-today RemoteViews card) is the
 * fallback for every device below API 36, which as of this research is every
 * real device — Android 16 only reached general availability in late 2025
 * and OEM skins (HyperOS included) typically trail AOSP by months on top of
 * that, so Daniel's own Redmi Note 13 Pro (Android 15) cannot use this path
 * yet. [LockScreenNotification.show] is the single entry point MainActivity
 * calls; it branches to this class at runtime via [Build.VERSION.SDK_INT].
 *
 * What's verified vs assumed — see the research report handed back with this
 * branch. In short: this compiles against the documented API 36 surface
 * (`developer.android.com/develop/ui/views/notifications/progress-centric`),
 * but has NOT been run on a real Android 16 device or emulator (none was
 * available in this sandbox), so the actual lock-screen placement, the
 * `setRequestPromotedOngoing` contract, and the `POST_PROMOTED_NOTIFICATIONS`
 * permission behavior are reasoned from documentation and third-party
 * write-ups, not observed.
 */
@RequiresApi(Build.VERSION_CODES.BAKLAVA) // API 36
object LiveUpdatesLockScreenNotification {
  private const val CHANNEL_ID = "steps_lockscreen_live_update_v1"
  private const val CHANNEL_NAME = "Steps & calories (live update)"
  private const val NOTIFICATION_ID = 2002

  /**
   * True once the OS and the user both allow this app to post promoted
   * ("Live Update") notifications. Checked before every [show] call; when
   * false, callers should keep using [LockScreenNotification] instead — the
   * permission can be revoked at any time from system settings, so this is
   * a per-call check, not a one-time capability flag to cache.
   */
  fun isAvailable(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.BAKLAVA) return false
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    // Added in API 36. Reflects both the POST_PROMOTED_NOTIFICATIONS manifest
    // permission and any user-facing toggle the OS exposes for it — unverified
    // against a real device, but this is the documented gate per the proandroiddev
    // / JET write-ups on shipping Live Updates.
    return manager.canPostPromotedNotifications()
  }

  fun show(
      context: Context,
      steps: Int,
      stepGoal: Int,
      kcalLeftText: String,
      goalReached: Boolean,
  ) {
    ensureChannel(context)

    val goalMet = goalReached || (stepGoal > 0 && steps >= stepGoal)
    // ProgressStyle progress is modeled 0..max over the segments' total
    // length, not a 0..100 percent — segment lengths are the "duration"
    // of each leg of the journey. We model it as two segments: "walked so
    // far" (teal, filled) and "remaining to goal" (track color, unfilled),
    // which is the same two-tone bar the shipped RemoteViews card draws by
    // hand. A point marks the goal itself so it's visible even mid-bar.
    val goalForBar = if (stepGoal > 0) stepGoal else maxOf(steps, 1)
    val walked = steps.coerceIn(0, goalForBar)
    val remaining = (goalForBar - walked).coerceAtLeast(0)

    val tealColor = ContextCompat.getColor(context, R.color.lockscreen_accent_teal)
    val trackColor = ContextCompat.getColor(context, R.color.lockscreen_track)
    val coralColor = ContextCompat.getColor(context, R.color.lockscreen_accent_coral)

    val segments =
        listOf(
            Notification.ProgressStyle.Segment(maxOf(walked, 1)).setColor(tealColor),
            Notification.ProgressStyle.Segment(maxOf(remaining, 1)).setColor(trackColor),
        )
    val points =
        if (stepGoal > 0) {
          listOf(Notification.ProgressStyle.Point(stepGoal.coerceIn(0, goalForBar)).setColor(coralColor))
        } else {
          emptyList()
        }

    val progressStyle =
        Notification.ProgressStyle()
            .setStyledByProgress(false) // segments carry the color, not an auto gradient
            .setProgress(walked)
            .setProgressSegments(segments)
            .apply { if (points.isNotEmpty()) setProgressPoints(points) }

    val contentIntent =
        PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )

    val stepsLine =
        if (stepGoal > 0) "%,d / %,d steps".format(steps, stepGoal) else "%,d steps".format(steps)

    val notification =
        Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(ContextCompat.getColor(context, R.color.lockscreen_accent_periwinkle))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentTitle(stepsLine)
            .setContentText(kcalLeftText)
            .setStyle(progressStyle)
            .setContentIntent(contentIntent)
            // This is the actual ask-for-promotion call: without it, this is
            // just an ordinary ProgressStyle notification that sits in the
            // shade like any other, not a permanently-expanded Live Update.
            .setRequestPromotedOngoing(true)
            .build()

    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.notify(NOTIFICATION_ID, notification)
  }

  fun cancel(context: Context) {
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.cancel(NOTIFICATION_ID)
  }

  private fun ensureChannel(context: Context) {
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    // Per the JET write-up on shipping this: IMPORTANCE_MIN does not qualify a
    // notification as a Live Update. IMPORTANCE_DEFAULT (not HIGH) is the
    // documented minimum, same as the v2 RemoteViews channel's own silent
    // IMPORTANCE_DEFAULT approach (sound/vibration disabled on the channel).
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
