package fr.rvier.planova

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
        Log.d("WidgetUpdateReceiver", "onReceive: action=${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_TIME_TICK -> {
                // Ignore TIME_TICK (every minute) - we use our own alarm
                return
            }
            Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED, "fr.rvier.planova.WIDGET_UPDATE",
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Reload widget on these events
                checkAndUpdateWidget(context)
            }
        }
    }

    companion object {
        private const val SHARED_PREFERENCES_NAME = "group.fr.rvier.planova"
        private const val UPDATE_INTERVAL_MILLIS = 30L * 60L * 1000L // 30 minutes
        
        /**
         * Check and update widget with data from files
         */
        fun checkAndUpdateWidget(context: Context) {
            try {
                Log.d("WidgetUpdateReceiver", "Checking and updating widget")
                
                // Load data from files and update widget
                WidgetDataManager.loadAndUpdateWidget(context)
                
                // Schedule next update (30 minutes from now)
                schedulePeriodicUpdates(context)
                
                Log.d("WidgetUpdateReceiver", "Widget update completed, next scheduled")
            } catch (e: Exception) {
                Log.e("WidgetUpdateReceiver", "Error updating widget", e)
                
                // Still schedule next update even on error
                schedulePeriodicUpdates(context)
            }
        }

        /**
         * Schedule periodic widget updates every 30 minutes
         */
        fun schedulePeriodicUpdates(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val updateIntent = Intent(context, WidgetUpdateReceiver::class.java).apply {
                    action = "fr.rvier.planova.WIDGET_UPDATE"
                }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    updateIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val triggerAt = System.currentTimeMillis() + UPDATE_INTERVAL_MILLIS
                
                // Cancel any existing alarm
                alarmManager.cancel(pendingIntent)
                
                // Schedule new alarm (single-shot, will reschedule after firing)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
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
                
                Log.d("WidgetUpdateReceiver", "Next widget update scheduled at ${Date(triggerAt)}")
            } catch (e: Exception) {
                Log.e("WidgetUpdateReceiver", "Failed to schedule widget update", e)
            }
        }
    }
}
