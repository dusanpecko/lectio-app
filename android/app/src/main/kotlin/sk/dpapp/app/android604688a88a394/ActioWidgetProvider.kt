package sk.dpapp.app.android604688a88a394

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Domovský widget „Actio" — zobrazuje dnešný duchovný impulz.
 * Ťuknutie kdekoľvek na widget otvorí appku s deep-linkom `lectiowidget://actio`,
 * ktorý (cez home_widget) vo Flutteri otvorí dnešné Lectio.
 */
class ActioWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.actio_widget).apply {
                val text = widgetData.getString("actio_text", null)
                    ?: "Otvor dnešné Lectio"
                val reference = widgetData.getString("actio_ref", null) ?: ""

                setTextViewText(R.id.actio_text, text)
                if (reference.isEmpty()) {
                    setViewVisibility(R.id.actio_ref, View.GONE)
                } else {
                    setViewVisibility(R.id.actio_ref, View.VISIBLE)
                    setTextViewText(R.id.actio_ref, reference)
                }

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("lectiowidget://actio")
                )
                setOnClickPendingIntent(R.id.actio_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
