package fr.rvier.planova

import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "fr.rvier.planova/intent"
    private var sharedText: String? = null
    private var sharedUri: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedText" -> {
                    result.success(sharedText)
                    sharedText = null
                }
                "getSharedUri" -> {
                    result.success(sharedUri?.toString())
                    sharedUri = null
                }
                "readFileFromUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        try {
                            val uri = Uri.parse(uriString)
                            val content = readFileContent(uri)
                            result.success(content)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error reading file from URI", e)
                            result.error("FILE_READ_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URI", "URI is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate called, handling intent")
        
        // Schedule periodic widget updates
        try {
            WidgetUpdateReceiver.schedulePeriodicUpdates(this)
            Log.d("MainActivity", "Widget auto-refresh scheduled successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to schedule widget updates", e)
        }
        
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent called, handling new intent")
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        Log.d("MainActivity", "Handling intent with action: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_SEND -> {
                Log.d("MainActivity", "ACTION_SEND intent received, type: ${intent.type}")
                
                // Handle EXTRA_STREAM first (file sharing)
                val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (streamUri != null) {
                    Log.d("MainActivity", "EXTRA_STREAM URI received: $streamUri")
                    sharedUri = streamUri
                    return
                }
                
                // Handle text content
                when (intent.type) {
                    "text/plain" -> {
                        sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                        Log.d("MainActivity", "Text/plain content received: ${sharedText?.substring(0, minOf(50, sharedText?.length ?: 0))}")
                    }
                    "text/calendar", "text/x-vcalendar", "application/ics", "application/octet-stream" -> {
                        sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                        Log.d("MainActivity", "Calendar content received: ${sharedText?.substring(0, minOf(50, sharedText?.length ?: 0))}")
                    }
                    else -> {
                        Log.d("MainActivity", "Unknown MIME type: ${intent.type}")
                    }
                }
            }
            Intent.ACTION_VIEW -> {
                sharedUri = intent.data
                Log.d("MainActivity", "ACTION_VIEW URI received: $sharedUri")
            }
            Intent.ACTION_INSERT -> {
                Log.d("MainActivity", "ACTION_INSERT intent received, type: ${intent.type}")
                // Handle calendar event insertion
                when (intent.type) {
                    "vnd.android.cursor.dir/event" -> {
                        // Extract event data from intent extras
                        val eventTitle = intent.getStringExtra(Intent.EXTRA_TITLE)
                        val eventText = intent.getStringExtra(Intent.EXTRA_TEXT)
                        val startTime = intent.getLongExtra("beginTime", 0)
                        val endTime = intent.getLongExtra("endTime", 0)
                        
                        Log.d("MainActivity", "Event insertion requested: title=$eventTitle, text=$eventText")
                        
                        // Create ICS content from the event data
                        sharedText = createIcsFromEventData(eventTitle, eventText, startTime, endTime)
                    }
                    else -> {
                        Log.d("MainActivity", "Unknown INSERT MIME type: ${intent.type}")
                    }
                }
            }
            Intent.ACTION_EDIT -> {
                Log.d("MainActivity", "ACTION_EDIT intent received, type: ${intent.type}")
                // Handle calendar event editing
                when (intent.type) {
                    "vnd.android.cursor.item/event" -> {
                        val eventId = intent.getStringExtra("_id")
                        val eventTitle = intent.getStringExtra(Intent.EXTRA_TITLE)
                        val eventText = intent.getStringExtra(Intent.EXTRA_TEXT)
                        
                        Log.d("MainActivity", "Event edit requested: id=$eventId, title=$eventTitle")
                        
                        // For now, treat edit as insert
                        sharedText = createIcsFromEventData(eventTitle, eventText, 0, 0)
                    }
                }
            }
            else -> {
                Log.d("MainActivity", "Unknown intent action: ${intent.action}")
            }
        }
    }
    
    private fun createIcsFromEventData(title: String?, text: String?, startTime: Long, endTime: Long): String {
        val icsContent = StringBuilder()
        icsContent.append("BEGIN:VCALENDAR\n")
        icsContent.append("VERSION:2.0\n")
        icsContent.append("PRODID:-//Planova//Calendar Event//EN\n")
        icsContent.append("BEGIN:VEVENT\n")
        
        // Add UID
        icsContent.append("UID:").append(System.currentTimeMillis()).append("@planova\n")
        
        // Add start time
        if (startTime > 0) {
            val startDate = java.util.Date(startTime)
            val formatter = java.text.SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", java.util.Locale.US)
            formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
            icsContent.append("DTSTART:").append(formatter.format(startDate)).append("\n")
        } else {
            // Default to current time if not specified
            val now = java.util.Date()
            val formatter = java.text.SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", java.util.Locale.US)
            formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
            icsContent.append("DTSTART:").append(formatter.format(now)).append("\n")
        }
        
        // Add end time (1 hour after start if not specified)
        val actualEndTime = if (endTime > 0) endTime else if (startTime > 0) startTime + 3600000 else System.currentTimeMillis() + 3600000
        val endDate = java.util.Date(actualEndTime)
        val formatter = java.text.SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        icsContent.append("DTEND:").append(formatter.format(endDate)).append("\n")
        
        // Add title
        if (!title.isNullOrEmpty()) {
            icsContent.append("SUMMARY:").append(title.replace("\n", "\\n").replace(",", "\\,")).append("\n")
        }
        
        // Add description
        if (!text.isNullOrEmpty()) {
            icsContent.append("DESCRIPTION:").append(text.replace("\n", "\\n").replace(",", "\\,")).append("\n")
        }
        
        icsContent.append("END:VEVENT\n")
        icsContent.append("END:VCALENDAR")
        
        Log.d("MainActivity", "Created ICS content from event data")
        return icsContent.toString()
    }

    private fun readFileContent(uri: Uri): String {
        Log.d("MainActivity", "Reading file from URI: $uri")
        val content = StringBuilder()
        
        contentResolver.openInputStream(uri)?.use { inputStream ->
            BufferedReader(InputStreamReader(inputStream)).use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    content.append(line).append("\n")
                }
            }
        } ?: throw Exception("Unable to open input stream for URI: $uri")
        
        Log.d("MainActivity", "Successfully read ${content.length} characters from file")
        return content.toString()
    }
}
