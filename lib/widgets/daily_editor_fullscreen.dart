import 'package:flutter/material.dart';
import 'package:planova/widgets/markdown_editor.dart';

class DailyEditorFullscreen extends StatefulWidget {
  final String date;
  final String initialContent;
  final Future<void> Function(String) onSave;
  final Future<void> Function(String)? onAutoSave;

  const DailyEditorFullscreen({
    super.key,
    required this.date,
    required this.initialContent,
    required this.onSave,
    this.onAutoSave,
  });

  @override
  State<DailyEditorFullscreen> createState() => DailyEditorFullscreenState();
}

class DailyEditorFullscreenState extends State<DailyEditorFullscreen> {
  @override
  Widget build(BuildContext context) {
    return MarkdownEditor(
      initialContent: widget.initialContent,
      onSave: widget.onSave,
      onAutoSave: widget.onAutoSave,
      title: 'Daily Notes - ${_formatDate(widget.date)}',
      hintText:
          'Write your daily notes here...\\n\\nYou can use Markdown syntax:\\n# Header\\n**bold** *italic*\\n- bullet list\\n1. numbered list\\n[ ] todo item',
      mode: EditorMode.fullscreen,
      showHeaderButton: true,
      showCodeButton: true,
      showToggleTodo: true,
      showSaveButton: true,
      saveSuccessMessage: 'Daily notes saved',
    );
  }

  void saveBeforeSwitch() {
    // This will be handled by the parent widget
  }

  String _formatDate(String dateString) {
    if (dateString.length == 8) {
      final year = dateString.substring(0, 4);
      final month = dateString.substring(4, 6);
      final day = dateString.substring(6, 8);
      return '$day/$month/$year';
    }
    return dateString;
  }
}
