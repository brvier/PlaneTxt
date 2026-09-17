import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planetxt/models/calendar_event.dart';
import 'package:planetxt/providers/daily_file_provider.dart';
import 'package:planetxt/providers/theme_provider.dart';
import 'package:planetxt/services/ics_parser_service.dart';
import 'package:planetxt/utils/daily_content_helper.dart';
import 'package:planetxt/utils/logger.dart';
import 'package:provider/provider.dart';

class IntentHandlerService {
  static const String _channelName = 'fr.rvier.planetxt/intent';
  static const MethodChannel _channel = MethodChannel(_channelName);

  /// Check if there's shared intent data and handle it
  /// Returns the date that should be selected after processing, or null if no intent was handled
  static Future<String?> handleSharedIntent(BuildContext context) async {
    try {
      Log.i('📅 IntentHandlerService: Checking for shared intents...');

      // Check for shared text (ICS content)
      final sharedText = await _channel.invokeMethod<String>('getSharedText');
      Log.i(
          '📅 IntentHandlerService: Shared text received: ${sharedText != null ? (sharedText.length > 50 ? '${sharedText.substring(0, 50)}...' : sharedText) : 'null'}');
      Log.i(
          '📅 IntentHandlerService: Shared text from Android: ${sharedText != null ? (sharedText.length > 100 ? sharedText.substring(0, 100) : sharedText) : 'null'}');

      if (sharedText != null && sharedText.isNotEmpty) {
        Log.i('📅 IntentHandlerService: Received shared text intent');
        if (!context.mounted) return null;
        return await _handleIcsContent(context, sharedText);
      }

      // Check for shared URI (ICS file)
      final sharedUri = await _channel.invokeMethod<String>('getSharedUri');
      Log.i('📅 IntentHandlerService: Shared URI from Android: $sharedUri');

      if (sharedUri != null && sharedUri.isNotEmpty) {
        Log.i(
            '📅 IntentHandlerService: Received shared URI intent: $sharedUri');

        // Read file content from URI
        try {
          Log.i('📅 IntentHandlerService: Reading file from URI...');
          final fileContent = await _channel
              .invokeMethod<String>('readFileFromUri', {'uri': sharedUri});

          if (fileContent != null && fileContent.isNotEmpty) {
            Log.i(
                '📅 IntentHandlerService: Successfully read ${fileContent.length} characters from file');
            if (!context.mounted) return null;
            return await _handleIcsContent(context, fileContent);
          } else {
            Log.w('⚠️  IntentHandlerService: File content is empty or null');
            if (!context.mounted) return null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('File is empty or could not be read'),
                  duration: Duration(seconds: 2)),
            );
            return null;
          }
        } catch (e) {
          Log.e('❌ IntentHandlerService: Error reading file from URI',
              error: e);
          if (!context.mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error reading file: ${e.toString()}'),
                duration: Duration(seconds: 2)),
          );
          return null;
        }
      }

      Log.i('📅 IntentHandlerService: No shared intent data found');
      return null;
    } catch (e) {
      Log.e('❌ IntentHandlerService: Error handling shared intent', error: e);
      return null;
    }
  }

  /// Handle ICS content and show confirmation dialog
  /// Returns the date that should be selected after adding events, or null if no events were added
  static Future<String?> _handleIcsContent(
      BuildContext context, String icsContent) async {
    try {
      Log.i(
          '📅 IntentHandlerService: Received ICS content (${icsContent.length} characters)');
      Log.i(
          '📅 IntentHandlerService: First 200 chars: ${icsContent.length > 200 ? icsContent.substring(0, 200) : icsContent}');

      // Validate ICS content
      Log.i('📅 IntentHandlerService: Validating ICS content...');
      final isValid = IcsParserService.isValidIcsContent(icsContent);
      Log.i('📅 IntentHandlerService: ICS validation result: $isValid');

      if (!isValid) {
        Log.w('⚠️  IntentHandlerService: Invalid ICS content format');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid ICS calendar format'),
              duration: Duration(seconds: 2)),
        );
        return null;
      }
      Log.i('📅 IntentHandlerService: ICS content is valid');

      // Parse ICS content
      Log.i('📅 IntentHandlerService: Parsing ICS content...');
      final events = IcsParserService.parseIcsContent(icsContent);
      Log.i(
          '📅 IntentHandlerService: Parsed ${events.length} events from ICS content');

      if (events.isEmpty) {
        Log.w('⚠️  IntentHandlerService: No events found in ICS content');
        Log.d('📅 IntentHandlerService: Full content:\n$icsContent');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No events found in calendar file'),
              duration: Duration(seconds: 2)),
        );
        return null;
      }

      // Log event details
      for (var i = 0; i < events.length && i < 3; i++) {
        final event = events[i];
        Log.i(
            '📅 IntentHandlerService: Event ${i + 1}: ${event.title} at ${event.time} on ${event.date}');
      }

      // Show confirmation dialog
      return await _showConfirmationDialog(context, events);
    } catch (e) {
      Log.e('❌ IntentHandlerService: Error processing ICS content', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error processing calendar: ${e.toString()}'),
            duration: Duration(seconds: 2)),
      );
      return null;
    }
  }

  /// Show confirmation dialog with event details
  /// Returns the date that should be selected after adding events
  static Future<String?> _showConfirmationDialog(
      BuildContext context, List<CalendarEvent> events) async {
    return await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Calendar Events'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Found ${events.length} event(s) to add:'),
                const SizedBox(height: 16),
                ...events.map((event) => _buildEventPreview(event)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text('Add Events'),
              onPressed: () async {
                final firstEventDate =
                    events.isNotEmpty ? events.first.date : null;
                Navigator.of(context).pop(firstEventDate);
                await _addEventsToDailyFiles(context, events);
              },
            ),
          ],
        );
      },
    );
  }

  /// Build event preview widget for confirmation dialog
  static Widget _buildEventPreview(CalendarEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                '${event.formattedTime} - ${event.displayTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 24.0),
              child: Text(
                event.description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }

  /// Add events to daily files
  static Future<void> _addEventsToDailyFiles(
      BuildContext context, List<CalendarEvent> events) async {
    try {
      Log.i(
          '📅 IntentHandlerService: Starting to add ${events.length} events to daily files');
      final dailyFileProvider =
          Provider.of<DailyFileProvider>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      // Group events by date
      final eventsByDate = <String, List<CalendarEvent>>{};
      for (final event in events) {
        eventsByDate.putIfAbsent(event.date, () => []).add(event);
      }

      // Process each date's events
      for (final entry in eventsByDate.entries) {
        final date = entry.key;
        final dateEvents = entry.value;

        // Get existing daily file or create template
        var dailyFile = await dailyFileProvider.getDailyFile(date);
        String content = dailyFile?.content ?? themeProvider.dailyTemplate;

        // Add events to content
        content = _addEventsToContent(
            content, dateEvents, RegExp(themeProvider.eventHeaderRegex));

        // Save the updated content
        if (!context.mounted) return;
        await dailyFileProvider.saveDailyFile(context, date, content);
      }

      // Show success message
      Log.i(
          '📅 IntentHandlerService: Successfully added ${events.length} events to daily files');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added ${events.length} event(s)'),
          duration: const Duration(seconds: 2),
        ),
      );

      Log.i(
          '📅 IntentHandlerService: Successfully added ${events.length} events to daily files');
    } catch (e) {
      Log.e('❌ IntentHandlerService: Error adding events to daily files',
          error: e);
      if (!context.mounted) rethrow;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error adding events: ${e.toString()}'),
            duration: Duration(seconds: 2)),
      );
      rethrow;
    }
  }

  /// Add events to daily content at appropriate positions
  static String _addEventsToContent(
      String content, List<CalendarEvent> events, RegExp eventHeaderRegex) {
    events.sort((a, b) => a.time.compareTo(b.time));

    // Insert events one at a time after the last event
    for (final event in events) {
      final eventLine = '- @${event.formattedTime} ${event.title}';
      content = DailyContentHelper.insertAfterLastEvent(
          content, eventLine, eventHeaderRegex.pattern);

      // Add description if present
      if (event.description.isNotEmpty) {
        final descriptionLines = event.description.split('\n');
        for (final descLine in descriptionLines) {
          if (descLine.trim().isNotEmpty) {
            content = '$content\n  $descLine';
          }
        }
      }
    }

    return content;
  }
}
