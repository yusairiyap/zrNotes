package dev.zr.zrnotes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** A single button that opens the app on a fresh note. It shows no data. */
class QuickAddWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)
            views.setOnClickPendingIntent(
                R.id.quick_add_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("zrnotes://new")),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
