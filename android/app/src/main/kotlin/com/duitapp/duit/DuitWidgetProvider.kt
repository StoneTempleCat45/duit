package com.duitapp.duit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Draws the Duit home screen widget.
 *
 * The Flutter app saves ready-to-show text (see lib/home_widget/widget_sync.dart)
 * every time your spending changes, then asks Android to redraw this widget.
 * Android also redraws it every 30 minutes, which is when a new day is picked up
 * even if the app has not been opened.
 */
class DuitWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = Date()
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
        val thisMonth = SimpleDateFormat("yyyy-MM", Locale.US).format(now)

        val ready = widgetData.getString("ready", "false") == "true"
        val savedDay = widgetData.getString("day", "")
        val savedMonth = widgetData.getString("month", "")
        val zero = widgetData.getString("zero", "RM 0.00") ?: "RM 0.00"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.duit_widget)

            var percent = 0
            var level = 0

            when {
                !ready -> {
                    views.setTextViewText(R.id.today_value, zero)
                    views.setTextViewText(R.id.left_value, "Set up Duit")
                    views.setTextViewText(R.id.left_label, "Tap to set your budget")
                    views.setTextViewText(R.id.caption, "")
                }
                savedMonth != thisMonth -> {
                    // A new month started and the app hasn't been opened yet.
                    views.setTextViewText(R.id.today_value, zero)
                    views.setTextViewText(R.id.left_value, "New month")
                    views.setTextViewText(R.id.left_label, "Open Duit to start this month")
                    views.setTextViewText(R.id.caption, "")
                }
                else -> {
                    // Today's total resets to zero when the day has changed.
                    val todayText = if (savedDay == today) widgetData.getString("today", zero) else zero
                    views.setTextViewText(R.id.today_value, todayText)
                    views.setTextViewText(R.id.left_value, widgetData.getString("left", zero))
                    views.setTextViewText(R.id.left_label, widgetData.getString("left_label", ""))
                    views.setTextViewText(R.id.caption, widgetData.getString("caption", ""))
                    percent = widgetData.getString("percent", "0")?.toIntOrNull() ?: 0
                    level = widgetData.getString("level", "0")?.toIntOrNull() ?: 0
                }
            }

            // One progress bar per colour; show the one that matches the level.
            val bars = listOf(R.id.progress_normal, R.id.progress_warning, R.id.progress_over)
            bars.forEachIndexed { index, barId ->
                views.setViewVisibility(barId, if (index == level) View.VISIBLE else View.GONE)
                views.setProgressBar(barId, 100, percent.coerceIn(0, 100), false)
            }

            // Tap anywhere: open the app. Tap +: open the add expense screen.
            val openApp = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("duit://home"),
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)

            val quickAdd = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("duit://add"),
            )
            views.setOnClickPendingIntent(R.id.add_button, quickAdd)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
