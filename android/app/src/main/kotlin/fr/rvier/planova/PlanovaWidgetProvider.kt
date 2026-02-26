package fr.rvier.planova

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class PlanovaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val todayDate = WidgetDataManager.getTodayDateString()
        val storedDate = widgetData.getString("widget_date", "")
        Log.d(TAG, "Refreshing widget data (stored: $storedDate, today: $todayDate)")

        WidgetDataManager.loadAndUpdateWidget(context, triggerWidgetUpdate = false)
        val refreshedData = HomeWidgetPlugin.getData(context)

        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, refreshedData)
        }
        // Cancel legacy alarm schedule; rely on WorkManager + midnight alarm
        WidgetUpdateReceiver.cancelPeriodicUpdates(context)
        WidgetRefreshWorker.schedule(context)
        WidgetUpdateReceiver.scheduleMidnightAlarm(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdateReceiver.cancelPeriodicUpdates(context)
        WidgetRefreshWorker.schedule(context)
        WidgetUpdateReceiver.scheduleMidnightAlarm(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetUpdateReceiver.cancelPeriodicUpdates(context)
        WidgetUpdateReceiver.cancelMidnightAlarm(context)
        WidgetRefreshWorker.cancel(context)
    }

    companion object {
        private const val TAG = "PlanovaWidgetProvider"
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            // Construct the RemoteViews object
            val views = RemoteViews(context.packageName, R.layout.planova_widget_layout)
            
            // Get data from SharedPreferences
            val dailyContent = widgetData.getString("widget_daily_content", "No content")
            val date = widgetData.getString("widget_date", "")

            val isDarkTheme = getBooleanCompat(widgetData, "widget_dark_theme", false)

            val transparency = getFloatCompat(widgetData, "widget_transparency", 1.0f)
                .coerceIn(0.0f, 1.0f)

            val textBaseSize = getFloatCompat(widgetData, "widget_text_size", 14.0f)
                .coerceIn(10.0f, 24.0f)
            
            // Maintain 14:12 ratio (7:6) - title is 14sp, content is 12sp
            val titleTextSize = textBaseSize
            val contentTextSize = textBaseSize * 6f / 7f

            val alpha = (transparency * 255).toInt().coerceIn(0, 255)

            val defaultBackgroundColor = if (isDarkTheme) {
                Color.argb(255, 0x1E, 0x1E, 0x1E)
            } else {
                Color.argb(255, 0xFF, 0xFF, 0xFF)
            }

            val baseBackgroundColor = getIntCompat(
                widgetData,
                "widget_background_color",
                defaultBackgroundColor
            )

            val backgroundColor = (baseBackgroundColor and 0x00FFFFFF) or (alpha shl 24)

            val defaultTextColor = if (isDarkTheme) Color.WHITE else Color.BLACK
            val titleColor = getIntCompat(widgetData, "widget_title_color", defaultTextColor)
            val textColor = getIntCompat(widgetData, "widget_text_color", defaultTextColor)

            // Format date for display (convert YYYYMMDD to DD/MM/YYYY)
            val formattedDate = if (!date.isNullOrEmpty() && date.length == 8) {
                "${date.substring(6, 8)}/${date.substring(4, 6)}/${date.substring(0, 4)}"
            } else {
                date ?: ""
            }
            
            // Update widget views
            views.setTextViewText(R.id.widget_title, if (formattedDate.isEmpty()) "Planova" else "Planova - $formattedDate")
            views.setTextViewText(R.id.widget_content, dailyContent)
            views.setTextColor(R.id.widget_title, titleColor)
            views.setTextColor(R.id.widget_content, textColor)
            views.setFloat(R.id.widget_title, "setTextSize", titleTextSize)
            views.setFloat(R.id.widget_content, "setTextSize", contentTextSize)
            views.setInt(R.id.widget_container, "setBackgroundColor", backgroundColor)
            
            // Set click intent to launch the app
            val intent = Intent(context, Class.forName("fr.rvier.planova.MainActivity"))
            intent.action = Intent.ACTION_MAIN
            intent.addCategory(Intent.CATEGORY_LAUNCHER)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_content, pendingIntent)
            
            // Update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun getBooleanCompat(
            prefs: SharedPreferences,
            key: String,
            defaultValue: Boolean
        ): Boolean {
            return try {
                prefs.getBoolean(key, defaultValue)
            } catch (e: ClassCastException) {
                val value = prefs.all[key] ?: return defaultValue
                when (value) {
                    is Boolean -> value
                    is String -> value.toBoolean()
                    is Int -> value != 0
                    is Long -> value != 0L
                    else -> defaultValue
                }
            }
        }

        private fun getIntCompat(
            prefs: SharedPreferences,
            key: String,
            defaultValue: Int
        ): Int {
            return try {
                prefs.getInt(key, defaultValue)
            } catch (e: ClassCastException) {
                val value = prefs.all[key] ?: return defaultValue
                when (value) {
                    is Int -> value
                    is Long -> value.toInt()
                    is Float -> value.toInt()
                    is Double -> value.toInt()
                    is String -> value.toLongOrNull()?.toInt() ?: defaultValue
                    else -> defaultValue
                }
            }
        }

        private fun getFloatCompat(
            prefs: SharedPreferences,
            key: String,
            defaultValue: Float
        ): Float {
            return try {
                prefs.getFloat(key, defaultValue)
            } catch (e: ClassCastException) {
                val value = prefs.all[key] ?: return defaultValue
                when (value) {
                    is Float -> value
                    is Double -> value.toFloat()
                    is Int -> value.toFloat()
                    is Long -> {
                        // Flutter (shared_preferences) stores doubles as raw long bits on Android.
                        if (kotlin.math.abs(value) > 1_000_000_000L) {
                            val decoded = java.lang.Double.longBitsToDouble(value)
                            if (decoded.isFinite()) decoded.toFloat() else defaultValue
                        } else {
                            value.toFloat()
                        }
                    }
                    is String -> value.toFloatOrNull() ?: defaultValue
                    else -> defaultValue
                }
            }
        }
    }
}
