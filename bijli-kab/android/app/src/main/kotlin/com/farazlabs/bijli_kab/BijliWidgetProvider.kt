package com.farazlabs.bijli_kab

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the main area's power status. The Flutter side
 * (lib/services/widget_service.dart) writes the texts; this only draws them.
 */
class BijliWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val state = widgetData.getString("bk_state", "unknown")
        val (dot, color) = when (state) {
            "on" -> R.drawable.widget_dot_on to 0xFF22E58B.toInt()
            "off" -> R.drawable.widget_dot_off to 0xFFFF4D5E.toInt()
            else -> R.drawable.widget_dot_unknown to 0xFF9A9BB0.toInt()
        }
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.bijli_widget).apply {
                setOnClickPendingIntent(R.id.widget_root, open)
                setImageViewResource(R.id.widget_dot, dot)
                setTextViewText(R.id.widget_area, widgetData.getString("bk_area", "Bijli Kab?"))
                setTextViewText(
                    R.id.widget_headline,
                    widgetData.getString("bk_headline", context.getString(R.string.widget_open_app)),
                )
                setTextColor(R.id.widget_headline, color)
                setTextViewText(R.id.widget_since, widgetData.getString("bk_since", ""))
                setTextViewText(R.id.widget_hint, widgetData.getString("bk_hint", ""))
                setTextViewText(R.id.widget_updated, widgetData.getString("bk_updated", ""))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
