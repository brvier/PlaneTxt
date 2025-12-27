import 'package:planova/utils/logger.dart';

/// Utility functions for working with daily file content
class DailyContentHelper {
  /// Inserts content after the first header matching the given regex pattern.
  /// If no matching header is found, appends the content to the end.
  ///
  /// [content] - The existing daily file content
  /// [newContent] - The new content to insert (e.g., a todo or event)
  /// [headerRegex] - Regex pattern to match the header (e.g., r'^##\s+Tasks?')
  ///
  /// Returns the updated content with newContent inserted after the matching header.
  static String insertAfterHeader(
    String content,
    String newContent,
    String headerRegex,
  ) {
    if (headerRegex.isEmpty) {
      // If no regex is set, append to end
      return content.isEmpty ? newContent : '$content\n\n$newContent';
    }

    try {
      final regex = RegExp(headerRegex, multiLine: true);
      final lines = content.split('\n');

      // Find the first line that matches the header regex
      int? headerIndex;
      for (int i = 0; i < lines.length; i++) {
        if (regex.hasMatch(lines[i])) {
          headerIndex = i;
          break;
        }
      }

      if (headerIndex == null) {
        // No matching header found, append to end
        return content.isEmpty ? newContent : '$content\n\n$newContent';
      }

      // Find the insertion point (after the header and any empty lines)
      int insertIndex = headerIndex + 1;

      // Skip empty lines after the header
      while (insertIndex < lines.length && lines[insertIndex].trim().isEmpty) {
        insertIndex++;
      }

      // Insert the new content
      final beforeInsert = lines.sublist(0, insertIndex).join('\n');
      final afterInsert = lines.sublist(insertIndex).join('\n');

      // Check if the next line after insertion starts with a header (#)
      final nextLineAfterInsert =
          afterInsert.split('\n').firstOrNull?.trim() ?? '';
      final isNextLineHeader = nextLineAfterInsert.startsWith('#');

      // If there's content after, add a newline before it
      if (afterInsert.isNotEmpty) {
        // Add extra newline if next line is a header to separate sections
        if (isNextLineHeader) {
          return '$beforeInsert\n$newContent\n\n$afterInsert';
        } else {
          return '$beforeInsert\n$newContent\n$afterInsert';
        }
      } else {
        // If we're at the end, just append
        return '$beforeInsert\n$newContent';
      }
    } catch (e) {
      // If regex is invalid, fall back to appending
      Log.e('?? DailyContentHelper: Invalid regex pattern "$headerRegex"',
          error: e);
      return content.isEmpty ? newContent : '$content\n\n$newContent';
    }
  }
}
