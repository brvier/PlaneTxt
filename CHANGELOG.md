# Changelog

## [1.3.1] - 2026-07-04

### Changed
- Add builtInKotlin and newDsl Gradle flags (Flutter migrator)

## [1.3.0] - 2026-07-04

### Added
- Today-priority startup load with per-file parse caching
- Adaptive launcher icons (Android)
- Native file-system watching for daily files (inotify), with polling fallback

### Changed
- Faster startup: notification init and permission request deferred after first paint
- Theme and settings load synchronously (no more loading spinner)
- Disk cache JSON encoding/decoding moved off the UI isolate
- File scanning uses async I/O instead of blocking sync calls
- Event notifications are only scheduled for today and future dates
- Refactor daily content helpers
- Upgrade Flutter plugins (file_picker 12, flutter_local_notifications 21, flutter_timezone 5, device_info_plus 13, home_widget 0.9, timezone 0.11, package_info_plus 10)

## [1.2.0] - 2026-04-27

### Added
- Android widget with auto-refresh via boot receiver
- ICS intent sharing
- Event notifications
- Themes, styles and application icon
- Auto-indent in text editor and quick-add modal
- Sort notes by modification date (most recent first)
- Linux platform support

### Changed
- Extract preferences screen into dedicated sections (debug, header patterns, storage)
- Introduce base repository shared by daily and note repositories
- Improve daily loading and ensure file is loaded before use
- Refactor text editor, file provider and preferences screen
- Improve notifications

### Fixed
- Remove duplicate bullet on android widget tasks
- Widget refresh and android alarm updates
- Todo handling in editor
- Custom storage path loading timing issue

### Removed
- PlanovaSAAS backend + frontend prototype
