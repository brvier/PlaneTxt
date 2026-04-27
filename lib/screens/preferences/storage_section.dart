import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:planova/providers/directory_provider.dart';
import 'package:planova/providers/theme_provider.dart';
import 'package:planova/utils/permission_helper.dart';
import 'package:provider/provider.dart';

class StorageSection extends StatelessWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('Storage Location'),
          subtitle: Text(themeProvider.getDisplayStoragePath()),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (themeProvider.customStoragePath != null)
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Storage Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select where you want to store your Planova files:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder_special),
              title: const Text('Default Location'),
              subtitle: const Text('Documents/Org (Recommended)'),
              trailing: themeProvider.customStoragePath == null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                themeProvider.setStoragePath(null);
                Navigator.of(context).pop();
                _reinitializeDirectoryProvider(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Custom Location'),
              subtitle: const Text('Choose a custom folder'),
              trailing: themeProvider.customStoragePath != null
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
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 30) {
          if (!context.mounted) return;
          final shouldProceed =
              await _showPermissionExplanationDialog(context);
          if (!shouldProceed) return;
        }
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final hasPermission = await PermissionHelper.requestStoragePermission();
        if (!hasPermission) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  'Storage permission is required to select a custom location.\n\n'
                  'Please go to Settings > Apps > Planova > Permissions and enable "All files access" or "Storage" permission.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      final String? selectedDirectory =
          await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null && context.mounted) {
        final selectedDir = Directory(selectedDirectory);
        try {
          final testFile = File('${selectedDir.path}/.test_write');
          await testFile.writeAsString('test');
          await testFile.delete();

          themeProvider.setStoragePath(selectedDir.path);

          if (!context.mounted) return;
          Navigator.of(context).pop();

          if (!context.mounted) return;
          _reinitializeDirectoryProvider(context);

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

  Future<bool> _showPermissionExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Storage Permission Required'),
            content: const Text(
              'To select a custom storage location, Planova needs permission to access all files on your device. '
              'This is required for Android 11 and later versions.\n\n'
              'You will be redirected to system settings to grant this permission.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _resetStorageLocation(
      BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Storage Location'),
        content: const Text(
          'Are you sure you want to reset the storage location to the default Documents/Org folder?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              themeProvider.setStoragePath(null);
              Navigator.of(context).pop();
              _reinitializeDirectoryProvider(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Storage location reset to default')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _reinitializeDirectoryProvider(BuildContext context) {
    context.read<DirectoryProvider>().initializeDirectories(context);
  }
}
