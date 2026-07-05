package com.jagga.munshi

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the user's "safe to spend today" figure.
 * Data is pushed from Flutter via the home_widget plugin; tapping opens the app.
 */
class MunshiWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.munshi_widget).apply {
                val label = widgetData.getString("widget_label", "Safe to spend today")
                val amount = widgetData.getString("spendable_today", "—")
                val sub = widgetData.getString("widget_sub", "")

                setTextViewText(R.id.widget_label, label)
                setTextViewText(R.id.widget_amount, amount)
                setTextViewText(R.id.widget_sub, sub)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
