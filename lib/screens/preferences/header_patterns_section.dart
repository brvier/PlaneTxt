import 'package:flutter/material.dart';
import 'package:planova/providers/theme_provider.dart';

class HeaderPatternTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String regex;
  final VoidCallback onTap;

  const HeaderPatternTile({
    super.key,
    required this.icon,
    required this.title,
    required this.regex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(regex.isEmpty ? 'No pattern set' : 'Pattern: $regex'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}

void showHeaderRegexDialog(
    BuildContext context, ThemeProvider themeProvider,
    {required String title,
    required String currentRegex,
    required String description,
    required String example,
    required String exampleDescription,
    required void Function(String regex) onSave}) {
  final controller = TextEditingController(text: currentRegex);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            const Text('Example patterns:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text('? $example',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            Text('  $exampleDescription',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Regex Pattern',
                hintText: example,
                border: const OutlineInputBorder(),
                helperText: 'Use regex syntax. ^ matches start of line.',
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
            final regex = controller.text.trim();
            try {
              RegExp(regex);
              onSave(regex);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pattern saved successfully')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invalid regex pattern: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
