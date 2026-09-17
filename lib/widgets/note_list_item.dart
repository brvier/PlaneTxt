import 'package:flutter/material.dart';
import 'package:planetxt/models/note_file.dart';

class NoteListItem extends StatelessWidget {
  final NoteFile note;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.note,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          note.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.folderPath.isNotEmpty)
              Text(
                note.folderPath,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            Text(
              _getPreview(note.content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _getPreview(String content) {
    if (content.isEmpty) {
      return 'Empty note';
    }

    // Remove markdown syntax for preview
    final String preview = content
        .replaceAll(RegExp(r'#+\s*'), '') // Remove headers
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove italic
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove code
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // Remove links
        .replaceAll(
            RegExp(r'^\s*[-*+]\s*', multiLine: true), '') // Remove list markers
        .replaceAll(RegExp(r'^\s*\d+\.\s*', multiLine: true),
            '') // Remove numbered list markers
        .trim();

    return preview.isEmpty ? 'Empty note' : preview;
  }
}
