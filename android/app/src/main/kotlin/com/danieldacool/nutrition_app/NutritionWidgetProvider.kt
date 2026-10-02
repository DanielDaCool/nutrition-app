package com.danieldacool.nutrition_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: today's remaining calories and step count.
 *
 * The Flutter side (lib/features/widget_home/) writes the display strings via
 * `HomeWidget.saveWidgetData` whenever today's intake, targets or steps
 * change; this just binds whatever was last saved into the layout each time
 * Android asks for a redraw.
 */
class NutritionWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.nutrition_widget_layout).apply {
            setTextViewText(
                R.id.nutrition_widget_kcal,
                widgetData.getString("kcalLeftText", null) ?: "Open the app to sync",
            )
            setTextViewText(
                R.id.nutrition_widget_steps,
                widgetData.getString("stepsText", null) ?: "",
            )
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.nutrition_widget_container, pendingIntent)
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
