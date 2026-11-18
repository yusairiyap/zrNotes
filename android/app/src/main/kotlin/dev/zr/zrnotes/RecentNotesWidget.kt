package dev.zr.zrnotes

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Lists the latest notes. The Dart side (lib/platform/home_widgets.dart) writes
 * `count`, `id_N`, `title_N` and `desc_N`; this only draws them and wires the taps.
 */
class RecentNotesWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val count = widgetData.getInt("count", 0).coerceIn(0, ROWS)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.recent_notes_widget)
            views.setViewVisibility(R.id.empty, if (count == 0) View.VISIBLE else View.GONE)

            for (i in 0 until ROWS) {
                val row = ROW_IDS[i]
                if (i >= count) {
                    views.setViewVisibility(row[0], View.GONE)
                    continue
                }
                val id = widgetData.getString("id_$i", "") ?: ""
                val title = widgetData.getString("title_$i", "") ?: ""
                val desc = widgetData.getString("desc_$i", "") ?: ""
                views.setViewVisibility(row[0], View.VISIBLE)
                views.setTextViewText(row[1], title.ifEmpty { context.getString(R.string.widget_untitled) })
                views.setTextViewText(row[2], desc)
                views.setViewVisibility(row[2], if (desc.isEmpty()) View.GONE else View.VISIBLE)
                views.setOnClickPendingIntent(
                    row[0],
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("zrnotes://note?id=${Uri.encode(id)}"),
                    ),
                )
            }

            views.setOnClickPendingIntent(
                R.id.add_button,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("zrnotes://new")),
            )
            views.setOnClickPendingIntent(
                R.id.empty,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private companion object {
        const val ROWS = 5

        // Row container, title, description: same order as the ids in recent_notes_widget.xml.
        val ROW_IDS = arrayOf(
            intArrayOf(R.id.row_0, R.id.title_0, R.id.desc_0),
            intArrayOf(R.id.row_1, R.id.title_1, R.id.desc_1),
            intArrayOf(R.id.row_2, R.id.title_2, R.id.desc_2),
            intArrayOf(R.id.row_3, R.id.title_3, R.id.desc_3),
            intArrayOf(R.id.row_4, R.id.title_4, R.id.desc_4),
        )
    }
}
