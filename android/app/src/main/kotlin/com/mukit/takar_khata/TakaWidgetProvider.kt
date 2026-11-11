package com.mukit.takar_khata

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** হোম স্ক্রিন উইজেট: আজকের খরচ আর দ্রুত যোগের বাটন */
class TakaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.taka_widget).apply {
                setTextViewText(R.id.widget_today, widgetData.getString("today_expense", "৳০"))
                setTextViewText(
                    R.id.widget_month,
                    "এ মাসে খরচ " + widgetData.getString("month_expense", "৳০"),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(
                    R.id.widget_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("takarkhata://add"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
