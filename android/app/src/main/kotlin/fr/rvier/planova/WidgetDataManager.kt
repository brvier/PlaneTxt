package fr.rvier.planova

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.text.format.DateFormat
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

object WidgetDataManager {
    private const val TAG = "WidgetDataManager"
    private const val SHARED_PREFERENCES_NAME = "group.fr.rvier.planova"
    private const val DATE_FORMAT = "yyyyMMdd"
    private const val WIDGET_DAILY_CONTENT_KEY = "widget_daily_content"
    private const val WIDGET_DATE_KEY = "widget_date"
    
    /**
     * Main entry point: load data and update widget
     */
    fun loadAndUpdateWidget(context: Context) {
        try {
            Log.i(TAG, "Loading and updating widget")
            
            // Get today's date string
            val todayDate = getTodayDateString()
            Log.d(TAG, "Today's date: $todayDate")
            
            // Check for MANAGE_EXTERNAL_STORAGE permission
            if (!FileHelper.hasManageExternalStoragePermission(context)) {
                val message = "Permission denied - Cannot access storage files"
                Log.e(TAG, message)
                FileHelper.showWidgetError(context, message)
                return
            }
            
            // Get storage path
            val storagePath = FileHelper.getStoragePath(context)
            if (storagePath == null) {
                val message = "Storage path not configured"
                Log.e(TAG, message)
                FileHelper.showWidgetError(context, message)
                return
            }
            
            // Construct path to daily file
            val dailyFilePath = FileHelper.getDailyFilePath(storagePath, todayDate)
            Log.d(TAG, "Daily file path: ${dailyFilePath.absolutePath}")
            
            // Check if file exists
            if (!FileHelper.fileExists(dailyFilePath)) {
                val message = "No content for today"
                Log.i(TAG, message)
                updateWidgetContent(context, message, todayDate)
                return
            }
            
            // Read file content
            val content = FileHelper.readFile(dailyFilePath)
            if (content == null) {
                val message = "⚠️ Error: Failed to read file"
                Log.e(TAG, message)
                FileHelper.showWidgetError(context, message)
                return
            }
            
            if (content.isBlank()) {
                val message = "No content for today"
                Log.i(TAG, message)
                updateWidgetContent(context, message, todayDate)
                return
            }
            
            // Parse events and tasks
            val events = MarkdownParser.parseEvents(content)
            val todos = MarkdownParser.parseTodos(content)
            
            // Format widget content
            val widgetContent = MarkdownParser.formatWidgetContent(events, todos)
            
            // Update SharedPreferences with widget content
            updateWidgetContent(context, widgetContent, todayDate)
            
            Log.i(TAG, "Widget updated successfully")
        } catch (e: Exception) {
            val message = "⚠️ Error: ${e.message ?: "Unknown error"}"
            Log.e(TAG, "Error loading and updating widget", e)
            FileHelper.showWidgetError(context, message)
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
    private fun updateWidgetContent(context: Context, content: String, date: String) {
        try {
            val prefs = context.getSharedPreferences(
                SHARED_PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )
            
            prefs.edit()
                .putString(WIDGET_DAILY_CONTENT_KEY, content)
                .putString(WIDGET_DATE_KEY, date)
                .apply()
            
            Log.d(TAG, "Updated widget content: ${content.length} characters")
            
            // Trigger widget UI refresh
            triggerWidgetUpdate(context)
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
