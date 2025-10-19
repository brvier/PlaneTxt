# Planova - Flutter Implementation

A future proof opinionated software written with Flutter to manage your life in plaintext: todo, agenda, journal and notes.

## Features Implemented

### ✅ Main View
- **Month Calendar**: Interactive calendar view with scrollable months
- **Daily Content Display**: Shows markdown content for selected days
- **Editable Content**: Rich text editor with markdown support
- **Todo Management**: Check/uncheck todos with double-tap functionality

### ✅ Notes View
- **Note List**: Browse all notes with search functionality
- **Add Notes**: Create new notes with optional folder organization
- **Note Management**: Rename and delete notes
- **Folder Support**: Organize notes in subfolders
- **Search**: Real-time search through note titles and content

### ✅ Preferences Screen
- **Theme Selection**: Choose between System, Light, and Dark themes
- **Settings**: App version and about information

### ✅ File Structure
- **Dailies**: Daily markdown files (YYYYMMDD.md format)
- **Notes**: Organized notes with folder support
- **Archives**: Placeholder for archived content

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── daily_file.dart      # Daily file model
│   └── note_file.dart       # Note file model
├── providers/
│   ├── file_provider.dart   # File management provider
│   └── theme_provider.dart  # Theme management provider
├── screens/
│   ├── main_screen.dart     # Main navigation screen
│   ├── calendar_view.dart   # Calendar and daily view
│   ├── notes_view.dart      # Notes list and management
│   └── preferences_screen.dart # Settings screen
└── widgets/
    ├── daily_editor.dart    # Daily content editor
    ├── note_editor.dart     # Note content editor
    └── note_list_item.dart  # Note list item widget
```

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Planova
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For Linux desktop
   flutter run -d linux
   
   # For Android (requires Android SDK)
   flutter run -d android
   
   # For iOS (requires Xcode on macOS)
   flutter run -d ios
   ```

### Building for Production

```bash
# Build APK for Android
flutter build apk --release

# Build for Linux desktop
flutter build linux --release

# Build for iOS (macOS only)
flutter build ios --release
```

## Usage

### Daily Management
1. **Calendar View**: Select any date on the calendar to view or edit daily content
2. **Edit Mode**: Tap the edit button to enter edit mode for the selected day
3. **Markdown Support**: Use markdown syntax for formatting:
   - `**bold**` for bold text
   - `*italic*` for italic text
   - `- item` for bullet lists
   - `1. item` for numbered lists
   - `[ ] task` for todo items
4. **Todo Management**: Double-tap todo items to check/uncheck them

### Notes Management
1. **Browse Notes**: View all notes organized by folders
2. **Search**: Use the search bar to find specific notes
3. **Add Note**: Tap the "+" button to create a new note
4. **Organize**: Create folders to organize your notes
5. **Edit**: Tap any note to open the editor

### Settings
1. **Theme**: Choose your preferred theme (System/Light/Dark)
2. **About**: View app information and version

## File Organization

The app creates the following directory structure in your documents folder:

```
Documents/
└── Org/
    ├── dailies/
    │   ├── 20250128.md
    │   ├── 20250129.md
    │   └── ...
    ├── archives/
    └── notes/
        ├── Work/
        │   └── project_1.md
        ├── Personal/
        │   └── project_2.md
        └── OtherSubFolder/
            └── notes_can_be_stored_in_subfolder.md
```

## Dependencies

- `table_calendar`: Calendar widget
- `flutter_markdown`: Markdown rendering
- `path_provider`: File system access
- `shared_preferences`: Settings storage
- `provider`: State management
- `intl`: Internationalization

## Development

### Code Style
The project follows Flutter's recommended code style. Run `flutter analyze` to check for issues.

### Testing
```bash
# Run tests
flutter test

# Run integration tests
flutter drive --target=test_driver/app.dart
```

## Roadmap

### Completed Features
- [x] Main View with calendar and daily content
- [x] Editable markdown content
- [x] Todo check/uncheck functionality
- [x] Notes View with search
- [x] Note management (add, rename, delete)
- [x] Folder organization
- [x] Preferences screen with theme selection
- [x] File structure setup

### Future Enhancements
- [ ] Android intent handling
- [ ] Note sharing functionality
- [ ] Advanced search filters
- [ ] Export/import functionality
- [ ] Cloud sync support
- [ ] Widget support for quick access
- [ ] Dark mode improvements
- [ ] Accessibility improvements

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by MOrg and other plaintext productivity tools
- Built with Flutter and Material Design
- Uses markdown for content formatting