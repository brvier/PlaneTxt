package fr.rvier.planetxt

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class WidgetRefreshWorker(appContext: Context, params: androidx.work.WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        return try {
            Log.d(TAG, "WorkManager: refreshing widget")
            WidgetUpdateReceiver.checkAndUpdateWidget(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "WorkManager refresh failed", e)
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "WidgetRefreshWorker"
        private const val UNIQUE_WORK_NAME = "planetxt_widget_refresh"

        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .addTag(UNIQUE_WORK_NAME)
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
            Log.d(TAG, "Scheduled WorkManager widget refresh")
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
            Log.d(TAG, "Cancelled WorkManager widget refresh")
        }
    }
}
