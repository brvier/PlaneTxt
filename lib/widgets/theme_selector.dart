import 'package:flutter/material.dart';
import 'package:planetxt/providers/theme_provider.dart';
import 'package:planetxt/themes/app_themes.dart';
import 'package:provider/provider.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ListTile(
          leading: const Icon(Icons.palette),
          title: const Text('Color Theme'),
          subtitle: Text(AppThemes.getTheme(themeProvider.appTheme).name),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showThemeDialog(context, themeProvider),
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Color Theme'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppTheme.values.length,
            itemBuilder: (context, index) {
              final theme = AppTheme.values[index];
              final themeData = AppThemes.getTheme(theme);
              final isSelected = themeProvider.appTheme == theme;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: _buildThemePreview(themeData.lightTheme),
                  title: Text(themeData.name),
                  subtitle: Text(themeData.description),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    themeProvider.setAppTheme(theme);
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
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

  Widget _buildThemePreview(ThemeData theme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
            theme.colorScheme.tertiary,
          ],
        ),
      ),
      child: Icon(
        Icons.palette,
        color: theme.colorScheme.onPrimary,
        size: 20,
      ),
    );
  }
}
