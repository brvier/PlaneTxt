package fr.rvier.planova

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateFormat
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object WidgetDataManager {
    private const val TAG = "WidgetDataManager"
    private const val DATE_FORMAT = "yyyyMMdd"
    private const val WIDGET_DAILY_CONTENT_KEY = "widget_daily_content"
    private const val WIDGET_DATE_KEY = "widget_date"
    
    /**
     * Main entry point: load data and update widget
     */
    fun loadAndUpdateWidget(context: Context, triggerWidgetUpdate: Boolean = true) {
        try {
            Log.i(TAG, "Loading and updating widget")
            
            // Get today's date string
            val todayDate = getTodayDateString()
            Log.d(TAG, "Today's date: $todayDate")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                if (!alarmManager.canScheduleExactAlarms()) {
                    val message = "Exact alarms disabled - please allow Planova"
                    Log.w(TAG, message)
                    FileHelper.showWidgetError(context, message, triggerWidgetUpdate)
                }
            }
            
            // Read today's daily file: from the SAF tree when the user
            // selected a custom folder, else from the raw storage path
            // (app-private default).
            val treeUri = FileHelper.getStorageTreeUri(context)
            val content: String?
            if (treeUri != null) {
                Log.d(TAG, "Reading daily file from SAF tree: $treeUri")
                content = FileHelper.readDailyContentFromTree(context, treeUri, todayDate)
            } else {
                val storagePath = FileHelper.getStoragePath(context)
                if (storagePath == null) {
                    val message = "Storage path not configured"
                    Log.e(TAG, message)
                    FileHelper.showWidgetError(context, message, triggerWidgetUpdate)
                    return
                }
                val dailyFilePath = FileHelper.getDailyFilePath(storagePath, todayDate)
                Log.d(TAG, "Daily file path: ${dailyFilePath.absolutePath}")
                content = if (FileHelper.fileExists(dailyFilePath)) {
                    FileHelper.readFile(dailyFilePath)
                } else {
                    null
                }
            }

            if (content == null || content.isBlank()) {
                val message = "No content for today"
                Log.i(TAG, message)
                updateWidgetContent(context, message, todayDate, triggerWidgetUpdate)
                return
            }
            
            // Parse events and tasks
            val events = MarkdownParser.parseEvents(content)
            val todos = MarkdownParser.parseTodos(content)
            
            // Format widget content
            val widgetContent = MarkdownParser.formatWidgetContent(events, todos)
            
            // Update SharedPreferences with widget content
            updateWidgetContent(context, widgetContent, todayDate, triggerWidgetUpdate)
            
            Log.i(TAG, "Widget updated successfully")
        } catch (e: Exception) {
            val message = "⚠️ Error: ${e.message ?: "Unknown error"}"
            Log.e(TAG, "Error loading and updating widget", e)
            FileHelper.showWidgetError(context, message, triggerWidgetUpdate)
        }
    }
    
    /**
     * Get today's date in yyyyMMdd format
     */
    fun getTodayDateString(): String {
        val sdf = SimpleDateFormat(DATE_FORMAT, Locale.US)
        return sdf.format(Date())
    }
    
    /**
     * Update SharedPreferences with widget content
     */
    private fun updateWidgetContent(
        context: Context,
        content: String,
        date: String,
        triggerWidgetUpdate: Boolean = true
    ) {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            
            prefs.edit()
                .putString(WIDGET_DAILY_CONTENT_KEY, content)
                .putString(WIDGET_DATE_KEY, date)
                .apply()
            
            Log.d(TAG, "Updated widget content: ${content.length} characters")
            
            if (triggerWidgetUpdate) {
                // Trigger widget UI refresh
                triggerWidgetUpdate(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget content", e)
        }
    }
    
    /**
     * Trigger widget UI refresh
     */
    fun triggerWidgetUpdate(context: Context) {
        try {
            val widgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = widgetManager.getAppWidgetIds(
                android.content.ComponentName(
                    context,
                    PlanovaWidgetProvider::class.java
                )
            )
            
            if (widgetIds.isNotEmpty()) {
                val updateIntent = Intent(context, PlanovaWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                }
                context.sendBroadcast(updateIntent)
                Log.d(TAG, "Triggered widget update for ${widgetIds.size} widget(s)")
            } else {
                Log.w(TAG, "No active widgets to update")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering widget update", e)
        }
    }
}
