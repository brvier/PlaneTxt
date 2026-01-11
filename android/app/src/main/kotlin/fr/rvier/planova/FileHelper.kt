package fr.rvier.planova

import android.content.Context
import android.content.SharedPreferences
import android.os.Environment
import android.util.Log
import java.io.File

object FileHelper {
    private const val TAG = "FileHelper"
    private const val SHARED_PREFERENCES_NAME = "group.fr.rvier.planova"
    private const val STORAGE_PATH_KEY = "storage_path"
    private const val ORG_DIR_NAME = "Org"
    private const val DAILIES_DIR_NAME = "dailies"
    private const val WIDGET_DAILY_CONTENT_KEY = "widget_daily_content"

    /**
     * Get storage path from SharedPreferences or default
     */
    fun getStoragePath(context: Context): String? {
        val prefs = context.getSharedPreferences(
            SHARED_PREFERENCES_NAME,
            Context.MODE_PRIVATE
        )
        val customPath = prefs.getString(STORAGE_PATH_KEY, null)
        
        if (!customPath.isNullOrEmpty()) {
            val dir = File(customPath)
            if (dir.exists() && dir.isDirectory) {
                Log.d(TAG, "Using custom storage path: $customPath")
                return customPath
            }
            Log.w(TAG, "Custom storage path does not exist: $customPath")
        }
        
        val defaultPath = getDefaultStoragePath(context)
        if (defaultPath.exists()) {
            Log.d(TAG, "Using default storage path: ${defaultPath.absolutePath}")
            return defaultPath.absolutePath
        }
        
        Log.e(TAG, "Storage path not configured")
        return null
    }

    /**
     * Get default storage path (Documents/Org)
     */
    fun getDefaultStoragePath(context: Context): File {
        val documentsDir = context.filesDir.resolve("documents")
        val orgDir = documentsDir.resolve(ORG_DIR_NAME)
        return orgDir
    }

    /**
     * Check if MANAGE_EXTERNAL_STORAGE permission is granted
     */
    fun hasManageExternalStoragePermission(context: Context): Boolean {
        return android.os.Environment.isExternalStorageManager()
    }

    /**
     * Read file content with error handling
     */
    fun readFile(path: File): String? {
        return try {
            if (!path.exists()) {
                Log.w(TAG, "File does not exist: ${path.absolutePath}")
                return null
            }
            
            val content = path.readText()
            Log.d(TAG, "Read file: ${path.absolutePath}, ${content.length} bytes")
            content
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied reading file: ${path.absolutePath}", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error reading file: ${path.absolutePath}", e)
            null
        }
    }

    /**
     * Check if file exists
     */
    fun fileExists(path: File): Boolean {
        return try {
            path.exists() && path.isFile
        } catch (e: Exception) {
            Log.e(TAG, "Error checking file existence: ${path.absolutePath}", e)
            false
        }
    }

    /**
     * Construct path to daily file
     */
    fun getDailyFilePath(storagePath: String, date: String): File {
        return File(storagePath, "$DAILIES_DIR_NAME/$date.md")
    }

    /**
     * Show error message on widget
     */
    fun showWidgetError(context: Context, message: String) {
        try {
            Log.w(TAG, "Showing widget error: $message")
            
            val prefs = context.getSharedPreferences(
                SHARED_PREFERENCES_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit().putString(WIDGET_DAILY_CONTENT_KEY, message).apply()
            
            // Trigger widget update to show error
            WidgetDataManager.triggerWidgetUpdate(context)
        } catch (e: Exception) {
            Log.e(TAG, "Error showing widget error", e)
        }
    }
}
