import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:planova/providers/directory_provider.dart';
import 'package:planova/providers/theme_provider.dart';
import 'package:planova/screens/preferences/debug_section.dart';
import 'package:planova/screens/preferences/header_patterns_section.dart';
import 'package:planova/screens/preferences/storage_section.dart';
import 'package:planova/widgets/theme_selector.dart';
import 'package:provider/provider.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          _buildSection(context, title: 'Appearance', children: [
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme Mode'),
                  subtitle: Text(_getThemeModeText(themeProvider.themeMode)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showThemeDialog(context, themeProvider),
                );
              },
            ),
            const ThemeSelector(),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return SwitchListTile(
                  secondary: const Icon(Icons.widgets),
                  title: const Text('Widget Dark Theme'),
                  subtitle: const Text('Use dark theme for home screen widget'),
                  value: themeProvider.widgetDarkTheme,
                  onChanged: (value) => themeProvider.setWidgetTheme(value),
                );
              },
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.opacity),
                  title: const Text('Widget Transparency'),
                  subtitle: Text(
                      '${(themeProvider.widgetTransparency * 100).round()}% opaque'),
                  trailing: SizedBox(
                    width: 200,
                    child: Slider(
                      value: themeProvider.widgetTransparency,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label:
                          '${(themeProvider.widgetTransparency * 100).round()}%',
                      onChanged: (value) =>
                          themeProvider.setWidgetTransparency(value),
                    ),
                  ),
                );
              },
            ),
          ]),

          const Divider(),

          _buildSection(context, title: 'Storage', children: [
            const StorageSection(),
          ]),

          const Divider(),

          _buildSection(context, title: 'Daily Template', children: [
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
          ]),

          const Divider(),

          _buildSection(context, title: 'Header Preferences', children: [
            Consumer<ThemeProvider>(
              builder: (context, tp, _) => HeaderPatternTile(
                icon: Icons.checklist,
                title: 'Todo Header Pattern',
                regex: tp.todoHeaderRegex,
                onTap: () => showHeaderRegexDialog(context, tp,
                    title: 'Todo Header Pattern',
                    currentRegex: tp.todoHeaderRegex,
                    description:
                        'Set a regex pattern to match the header where todos should be inserted.',
                    example: r'^#{1,2}\s+.*(Todos?|Tasks?)',
                    exampleDescription:
                        'Matches "# Todos", "## Tasks", "# ✅ Todos", etc.',
                    onSave: tp.setTodoHeaderRegex),
              ),
            ),
            Consumer<ThemeProvider>(
              builder: (context, tp, _) => HeaderPatternTile(
                icon: Icons.event,
                title: 'Event Header Pattern',
                regex: tp.eventHeaderRegex,
                onTap: () => showHeaderRegexDialog(context, tp,
                    title: 'Event Header Pattern',
                    currentRegex: tp.eventHeaderRegex,
                    description:
                        'Set a regex pattern to match the header where events should be inserted.',
                    example: r'^#{1,2}\s+.*Events?',
                    exampleDescription:
                        'Matches "# Events", "## Events", "# 📅 Events", etc.',
                    onSave: tp.setEventHeaderRegex),
              ),
            ),
            Consumer<ThemeProvider>(
              builder: (context, tp, _) => HeaderPatternTile(
                icon: Icons.edit_note,
                title: 'Log Header Pattern',
                regex: tp.logHeaderRegex,
                onTap: () => showHeaderRegexDialog(context, tp,
                    title: 'Log Header Pattern',
                    currentRegex: tp.logHeaderRegex,
                    description:
                        'Set a regex pattern to match the header where log entries should be inserted.',
                    example: r'^#{1,2}\s+.*(Journal|Logs?)',
                    exampleDescription:
                        'Matches "# Logs", "## Journal", "# 📝 Logs", etc.',
                    onSave: tp.setLogHeaderRegex),
              ),
            ),
          ]),

          const Divider(),

          _buildSection(context, title: 'Widget Health', children: [
            const WidgetHealthTile(),
          ]),

          const Divider(),

          _buildSection(context, title: 'Debug Info', children: [
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
            Consumer<DirectoryProvider>(
              builder: (context, directoryProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Actual Storage Path'),
                  subtitle: Text(directoryProvider.getCurrentStoragePath()),
                  isThreeLine: true,
                );
              },
            ),
          ]),

          const Divider(),

          _buildSection(context, title: 'Debug', children: [
            const DebugToolsTiles(),
          ]),

          const Divider(),

          _buildSection(context, title: 'About', children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? 'Unknown';
                final buildNumber = snapshot.data?.buildNumber ?? '';
                final versionString = buildNumber.isNotEmpty
                    ? '$version+$buildNumber'
                    : version;
                return ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  subtitle: Text(versionString),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('About Planova'),
              subtitle: const Text(
                  'A future proof opinionated software to manage your life in plaintext'),
              onTap: () => _showAboutDialog(context),
            ),
          ]),
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
        content: RadioGroup<ThemeMode>(
          groupValue: themeProvider.themeMode,
          onChanged: (value) {
            if (value == null) return;
            themeProvider.setThemeMode(value);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in {
                ThemeMode.system: ('System', 'Follow system setting'),
                ThemeMode.light: ('Light', 'Always use light theme'),
                ThemeMode.dark: ('Dark', 'Always use dark theme'),
              }.entries)
                ListTile(
                  title: Text(entry.value.$1),
                  subtitle: Text(entry.value.$2),
                  leading: Radio<ThemeMode>(value: entry.key),
                  onTap: () {
                    themeProvider.setThemeMode(entry.key);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
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
                  hintText:
                      '# 📅 Events\n# ✅ Todos\n# 📝 Logs\n# 🗒️ Notes\n',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

  Future<void> _showAboutDialog(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    final versionString =
        buildNumber.isNotEmpty ? '$version+$buildNumber' : version;

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Planova',
      applicationVersion: versionString,
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
}
