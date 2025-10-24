import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../providers/theme_provider.dart';
import '../providers/file_provider.dart';
import '../utils/permission_helper.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // Theme section
          _buildSection(
            context,
            title: 'Appearance',
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Theme'),
                    subtitle: Text(_getThemeModeText(themeProvider.themeMode)),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showThemeDialog(context, themeProvider),
                  );
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return SwitchListTile(
                    secondary: const Icon(Icons.widgets),
                    title: const Text('Widget Dark Theme'),
                    subtitle: const Text('Use dark theme for home screen widget'),
                    value: themeProvider.widgetDarkTheme,
                    onChanged: (value) {
                      themeProvider.setWidgetTheme(value);
                    },
                  );
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.opacity),
                    title: const Text('Widget Transparency'),
                    subtitle: Text('${(themeProvider.widgetTransparency * 100).round()}% opaque'),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: themeProvider.widgetTransparency,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: '${(themeProvider.widgetTransparency * 100).round()}%',
                        onChanged: (value) {
                          themeProvider.setWidgetTransparency(value);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const Divider(),

          // Storage section
          _buildSection(
            context,
            title: 'Storage',
            children: [
              Consumer<ThemeProvider>(
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
                    onTap: () =>
                        _showStorageLocationDialog(context, themeProvider),
                  );
                },
              ),
            ],
          ),

          const Divider(),

          // Template section
          _buildSection(
            context,
            title: 'Daily Template',
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Daily File Template'),
                    subtitle: Text(themeProvider.dailyTemplate.isEmpty
                        ? 'No template set'
                        : 'Template configured'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showTemplateDialog(context, themeProvider),
                  );
                },
              ),
            ],
          ),

          const Divider(),

          // Debug section
          _buildSection(
            context,
            title: 'Debug Info',
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Configured Storage Path'),
                    subtitle: Text(themeProvider.getDisplayStoragePath()),
                    isThreeLine: true,
                  );
                },
              ),
              Consumer<FileProvider>(
                builder: (context, fileProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Actual Storage Path'),
                    subtitle: Text(fileProvider.getCurrentStoragePath()),
                    isThreeLine: true,
                  );
                },
              ),
            ],
          ),

          const Divider(),

          // About section
          _buildSection(
            context,
            title: 'About',
            children: [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('About Planova'),
                subtitle: const Text(
                    'A future proof opinionated software to manage your life in plaintext'),
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System'),
              subtitle: const Text('Follow system setting'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Light'),
              subtitle: const Text('Always use light theme'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Dark'),
              subtitle: const Text('Always use dark theme'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
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
                _reinitializeFileProvider(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Custom Location'),
              subtitle: const Text('Choose a custom folder'),
              trailing: themeProvider.customStoragePath != null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => _selectCustomStorageLocation(context, themeProvider),
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
      // Show a dialog explaining permissions for Android 11+
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 30) {
          final shouldProceed = await _showPermissionExplanationDialog(context);
          if (!shouldProceed) return;
        }
      }

      // Request storage permissions first
      final hasPermission = await PermissionHelper.requestStoragePermission();
      if (!hasPermission) {
        if (context.mounted) {
          // Show a dialog with instructions to enable permission
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

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null && context.mounted) {
        // Use the selected directory directly without creating an Org subfolder
        final selectedDir = Directory(selectedDirectory);

        // Test if the directory is writable
        try {
          final testFile = File('${selectedDir.path}/.test_write');
          await testFile.writeAsString('test');
          await testFile.delete();
          
          // Set the storage path
          themeProvider.setStoragePath(selectedDir.path);
          Navigator.of(context).pop();

          // Reinitialize file provider with new location
          _reinitializeFileProvider(context);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Storage location changed to: ${selectedDir.path}'),
                action: SnackBarAction(
                  label: 'OK',
                  onPressed: () {},
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot write to selected directory: $e\nUsing default location instead.'),
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
    ) ?? false;
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
              _reinitializeFileProvider(context);
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

  void _reinitializeFileProvider(BuildContext context) {
    // Reinitialize the file provider with the new storage location
    context.read<FileProvider>().initializeDirectories(context);
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Planova',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.calendar_today, size: 48),
      children: [
        const Text(
          'A future proof opinionated software written with Flutter to manage your life in plaintext: todo, agenda, journal and notes.',
        ),
        const SizedBox(height: 16),
        const Text(
          'By using a more structured yet flexible approach with dailies Markdown files instead of a calendar.txt and todo.txt, Planova provides a more efficient, scalable, and user-friendly experience.',
        ),
      ],
    );
  }

  void _showTemplateDialog(BuildContext context, ThemeProvider themeProvider) {
    final controller = TextEditingController(text: themeProvider.dailyTemplate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily File Template'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set a template that will be used when creating new daily files. You can use Markdown syntax.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '## Events\n\n## Tasks\n\n## Journal\n\n## Notes\n',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              themeProvider.setDailyTemplate(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

