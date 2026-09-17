package fr.rvier.planetxt

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar
import java.util.Date

class WidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive: action=${intent.action}")

        when (intent.action) {
            Intent.ACTION_TIME_TICK -> {
                // Ignore TIME_TICK (every minute) - we use our own alarm
                return
            }
            Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED, ACTION_WIDGET_UPDATE,
            ACTION_MIDNIGHT_REFRESH,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Reload widget on these events
                checkAndUpdateWidget(context)
            }
            AppWidgetManager.ACTION_APPWIDGET_ENABLED -> {
                // WorkManager is scheduled by the widget provider
                WidgetRefreshWorker.schedule(context)
                scheduleMidnightAlarm(context)
            }
            AppWidgetManager.ACTION_APPWIDGET_DISABLED -> {
                // Stop schedule when last widget is removed
                cancelPeriodicUpdates(context)
                cancelMidnightAlarm(context)
                WidgetRefreshWorker.cancel(context)
                FileHelper.clearWidgetContent(context)
            }
        }
    }

    companion object {
        private const val TAG = "WidgetUpdateReceiver"
        private const val UPDATE_INTERVAL_MILLIS = 30L * 60L * 1000L // 30 minutes
        private const val REQUEST_CODE = 0
        private const val MIDNIGHT_REQUEST_CODE = 42
        private const val ACTION_WIDGET_UPDATE = "fr.rvier.planetxt.WIDGET_UPDATE"
        private const val ACTION_MIDNIGHT_REFRESH = "fr.rvier.planetxt.MIDNIGHT_REFRESH"

        /**
         * Check and update widget with data from files
         */
        fun checkAndUpdateWidget(context: Context) {
            try {
                Log.d(TAG, "Checking and updating widget")

                // Load data from files and update widget
                WidgetDataManager.loadAndUpdateWidget(context)

                // Ensure WorkManager periodic refresh stays scheduled
                WidgetRefreshWorker.schedule(context)

                // Re-schedule midnight alarm for the next day
                scheduleMidnightAlarm(context)

                Log.d(TAG, "Widget update completed, next scheduled")
            } catch (e: Exception) {
                Log.e(TAG, "Error updating widget", e)

                // Still schedule next update even on error
                WidgetRefreshWorker.schedule(context)
                scheduleMidnightAlarm(context)
            }
        }

        /**
         * Schedule an alarm at midnight (00:00) to refresh the widget for the new day.
         * This ensures immediate refresh at day change, complementing WorkManager.
         */
        fun scheduleMidnightAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = ACTION_MIDNIGHT_REFRESH
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    MIDNIGHT_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // Calculate next midnight
                val midnight = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, 1)
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 5) // 5 seconds past midnight to avoid edge cases
                    set(Calendar.MILLISECOND, 0)
                }

                val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }

                if (canScheduleExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        midnight.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        midnight.timeInMillis,
                        pendingIntent
                    )
                }

                Log.d(TAG, "Midnight alarm scheduled at ${Date(midnight.timeInMillis)}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule midnight alarm", e)
            }
        }

        /**
         * Cancel the midnight alarm
         */
        fun cancelMidnightAlarm(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = ACTION_MIDNIGHT_REFRESH
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    MIDNIGHT_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                Log.d(TAG, "Cancelled midnight alarm")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel midnight alarm", e)
            }
        }

        /**
         * Schedule periodic widget updates every 30 minutes (legacy alarm)
         */
        fun schedulePeriodicUpdates(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val updateIntent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = ACTION_WIDGET_UPDATE
                }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    REQUEST_CODE,
                    updateIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val triggerAt = System.currentTimeMillis() + UPDATE_INTERVAL_MILLIS

                // Cancel any existing alarm
                alarmManager.cancel(pendingIntent)

                val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }

                // Schedule new alarm (single-shot, will reschedule after firing)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (canScheduleExact) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    } else {
                        // Fallback: inexact repeating if exact not allowed
                        alarmManager.setRepeating(
                            AlarmManager.RTC_WAKEUP,
                            triggerAt,
                            UPDATE_INTERVAL_MILLIS,
                            pendingIntent
                        )
                        Log.w(
                            TAG,
                            "Exact alarms not permitted; using inexact repeating"
                        )
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
                } else {
                    alarmManager.setRepeating(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        UPDATE_INTERVAL_MILLIS,
                        pendingIntent
                    )
                }

                Log.d(TAG, "Next widget update scheduled at ${Date(triggerAt)}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule widget update", e)
            }
        }

        fun cancelPeriodicUpdates(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val updateIntent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = ACTION_WIDGET_UPDATE
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    REQUEST_CODE,
                    updateIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                Log.d(TAG, "Cancelled widget update alarm")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel widget update alarm", e)
            }
        }
    }
}
