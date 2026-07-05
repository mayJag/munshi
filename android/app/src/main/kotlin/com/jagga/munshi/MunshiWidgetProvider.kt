package com.jagga.munshi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget showing the user's "safe to spend today" figure.
 * Reads data written by MainActivity's MethodChannel; tapping opens the app.
 * Pure AppWidgetProvider — no plugin dependency.
 */
class MunshiWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(
            MainActivity.WIDGET_PREFS, Context.MODE_PRIVATE
        )
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.munshi_widget).apply {
                setTextViewText(
                    R.id.widget_label,
                    prefs.getString("label", "Safe to spend today")
                )
                setTextViewText(
                    R.id.widget_amount,
                    prefs.getString("amount", "Open Munshi")
                )
                setTextViewText(R.id.widget_sub, prefs.getString("sub", ""))

                val launch = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val pending = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
