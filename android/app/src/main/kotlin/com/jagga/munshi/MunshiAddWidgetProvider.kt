package com.jagga.munshi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * Compact "+ Add expense" widget. Launches MainActivity with a
 * munshiwidget://quickadd URI; the Flutter side reads it and opens quick-add.
 * Pure AppWidgetProvider — no plugin dependency.
 */
class MunshiAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.munshi_add_widget).apply {
                val launch = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("munshiwidget://quickadd")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val pending = PendingIntent.getActivity(
                    context, 1, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.add_widget_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
