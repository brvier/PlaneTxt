package fr.rvier.planova

import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object MarkdownParser {
    private const val TAG = "MarkdownParser"
    
    private val EVENT_REGEX = Regex("""@(\d{1,2}):(\d{2})""")
    private val TODO_REGEX = Regex("""^\s*[-*+]\s*\[\s*([x\s])\s*\]\s+(.+)$""")
    
    private const val MAX_EVENTS = 3
    private const val MAX_TODOS = 5
    
    /**
     * Parse events from content (limit to MAX_EVENTS)
     */
    fun parseEvents(content: String): List<String> {
        val events = mutableListOf<String>()
        
        for (line in content.lines()) {
            if (events.size >= MAX_EVENTS) break
            
            val match = EVENT_REGEX.find(line)
            if (match != null) {
                try {
                    val hour = match.groupValues[1].toIntOrNull()
                    val minute = match.groupValues[2]
                    
                    if (hour != null) {
                        val time = String.format(Locale.US, "%02d:%s", hour, minute)
                        val eventTitle = line.replace(EVENT_REGEX, "").trim()
                        
                        if (eventTitle.isNotEmpty()) {
                            val event = "$time $eventTitle"
                            events.add(event)
                            Log.d(TAG, "Parsed event: $event")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing event line: $line", e)
                }
            }
        }
        
        Log.d(TAG, "Parsed ${events.size} events")
        return events
    }
    
    /**
     * Parse todos from content (limit to MAX_TODOS)
     */
    fun parseTodos(content: String): List<String> {
        val todos = mutableListOf<String>()
        
        for (line in content.lines()) {
            if (todos.size >= MAX_TODOS) break
            
            val match = TODO_REGEX.find(line.trim())
            if (match != null) {
                val isCompleted = match.groupValues[1].trim().equals("x", ignoreCase = true)
                val text = match.groupValues[2].trim()
                
                if (text.isNotEmpty()) {
                    val status = if (isCompleted) "✓" else "○"
                    val todo = "$status $text"
                    todos.add(todo)
                    Log.d(TAG, "Parsed todo: $todo")
                }
            }
        }
        
        Log.d(TAG, "Parsed ${todos.size} todos")
        return todos
    }
    
    /**
     * Format widget content with structured layout
     */
    fun formatWidgetContent(events: List<String>, todos: List<String>): String {
        val buffer = StringBuilder()
        
        // Events section with icon and styling
        if (events.isNotEmpty()) {
            buffer.appendLine("📅 Events")
            for (event in events) {
                buffer.appendLine("  ◦ $event")
            }
            buffer.appendLine()
        }
        
        // Tasks section with icon and styling
        if (todos.isNotEmpty()) {
            buffer.appendLine("✓ Tasks")
            for (task in todos) {
                buffer.appendLine("  ◦ $task")
            }
        }
        
        val result = if (buffer.isEmpty()) {
            Log.d(TAG, "No events or tasks found")
            "No events or tasks for today"
        } else {
            buffer.toString().trimEnd()
        }
        
        Log.d(TAG, "Formatted widget content: ${result.length} characters")
        return result
    }
}
