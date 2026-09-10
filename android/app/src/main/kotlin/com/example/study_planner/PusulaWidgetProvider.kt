package com.example.study_planner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Pusula ana ekran widget'ı: sınav geri sayımı + bugünkü görev ilerlemesi.
 * Veriyi Flutter tarafı (WidgetService) SharedPreferences'a yazar, bu provider
 * onu okuyup RemoteViews'a basar. Widget'a dokunmak uygulamayı açar.
 */
class PusulaWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pusula_widget)

            val hasCountdown = widgetData.getBoolean("has_countdown", false)
            val countdown = widgetData.getString("countdown", "") ?: ""
            val tasks = widgetData.getString("tasks", "Bugüne görev eklenmedi")
                ?: "Bugüne görev eklenmedi"

            if (hasCountdown && countdown.isNotEmpty()) {
                views.setTextViewText(R.id.widget_countdown, countdown)
                views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_countdown, View.GONE)
            }
            views.setTextViewText(R.id.widget_tasks, tasks)

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
