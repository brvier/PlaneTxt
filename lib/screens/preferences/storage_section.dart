import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:planetxt/providers/daily_file_provider.dart';
import 'package:planetxt/providers/directory_provider.dart';
import 'package:planetxt/providers/note_file_provider.dart';
import 'package:planetxt/providers/theme_provider.dart';
import 'package:planetxt/services/file_monitor_service.dart';
import 'package:planetxt/services/file_store/saf_file_store.dart';
import 'package:provider/provider.dart';

class StorageSection extends StatelessWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final hasCustom = themeProvider.customStoragePath != null ||
            themeProvider.storageTreeUri != null;
        return ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('Storage Location'),
          subtitle: Text(themeProvider.getDisplayStoragePath()),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCustom)
                IconButton(
                  onPressed: () =>
                      _resetStorageLocation(context, themeProvider),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset to default',
                ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
          onTap: () => _showStorageLocationDialog(context, themeProvider),
        );
      },
    );
  }

  void _showStorageLocationDialog(
      BuildContext context, ThemeProvider themeProvider) {
    final hasCustom = themeProvider.customStoragePath != null ||
        themeProvider.storageTreeUri != null;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Storage Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select where you want to store your PlaneTxt files:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              Platform.isAndroid
                  ? 'Pick a folder synced by Syncthing, Dropbox, etc. to '
                      'access your files from other devices. No special '
                      'permission is required.'
                  : 'Pick any folder to share your files with other tools.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder_special),
              title: const Text('Default Location'),
              subtitle: const Text('App private storage (Recommended)'),
              trailing: !hasCustom
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () async {
                await themeProvider.setStorageTree(null, null);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                await _reinitializeStorage(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Custom Folder'),
              subtitle: const Text('Choose a folder (e.g. a synced one)'),
              trailing: hasCustom
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () =>
                  _selectCustomStorageLocation(context, themeProvider),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomStorageLocation(
      BuildContext context, ThemeProvider themeProvider) async {
    try {
      if (Platform.isAndroid) {
        // System folder picker; the returned document-tree URI carries a
        // persistable read/write grant - no storage permission involved.
        final treeUri = await SafFileStore.pickTree();
        if (treeUri == null) return; // cancelled

        final name = await SafFileStore.treeDisplayName(treeUri);
        await themeProvider.setStorageTree(treeUri, name);

        if (!context.mounted) return;
        Navigator.of(context).pop();
        await _reinitializeStorage(context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Storage location changed to: $name'),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
        return;
      }

      // Desktop / iOS: raw filesystem path.
      final String? selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory == null || !context.mounted) return;

      final selectedDir = Directory(selectedDirectory);
      try {
        final testFile = File('${selectedDir.path}/.test_write');
        await testFile.writeAsString('test');
        await testFile.delete();

        await themeProvider.setStoragePath(selectedDir.path);

        if (!context.mounted) return;
        Navigator.of(context).pop();
        await _reinitializeStorage(context);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Storage location changed to: ${selectedDir.path}'),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cannot write to selected directory: $e\nUsing default location instead.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetStorageLocation(
      BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Storage Location'),
        content: const Text(
          'Are you sure you want to reset the storage location to the default folder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final treeUri = themeProvider.storageTreeUri;
              await themeProvider.setStorageTree(null, null);
              // Release the now-unused grant (best effort).
              if (treeUri != null) {
                try {
                  await SafFileStore.releaseTree(treeUri);
                } catch (_) {}
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
              await _reinitializeStorage(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Storage location reset to default')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _reinitializeStorage(BuildContext context) async {
    await context.read<DirectoryProvider>().initializeDirectories(context);
    // Re-attach the file monitor to the new root (watch vs polling may
    // differ between io and SAF roots).
    await FileMonitorService().reinitialize();
    if (!context.mounted) return;
    // Force-reload from the new root; the in-memory and disk caches still
    // hold the previous folder's content. Runs in the background - the
    // "building cache" banner covers the wait.
    final dailyProvider = context.read<DailyFileProvider>();
    final noteProvider = context.read<NoteFileProvider>();
    unawaited(dailyProvider.loadDailyFiles(forceReload: true));
    unawaited(noteProvider.loadNoteFiles(forceReload: true));
  }
}
