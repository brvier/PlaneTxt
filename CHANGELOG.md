# Changelog

## [Unreleased]

### Fixed
- **Data loss on Android restart**: the startup disk cache is now flushed after every save (debounced) and when the app goes to background, so edits to past days survive a process kill; the editor and day selection re-read files from disk before use, so a stale cache can no longer overwrite newer file content
- Atomic file writes (temp file + rename) — a crash mid-write can no longer truncate a markdown file
- Repository cache revalidates file mtime, so edits made by external tools are picked up instead of being silently overwritten on the next save
- File monitor notifies the UI of external changes and deletions (including past dates), not only the notification scheduler
- "Saved" confirmation is now only shown after the write actually succeeded; save/autosave failures show an error and keep the content marked as unsaved
- ICS import: UTC timestamps (`...Z`) are now correctly converted to local time
- ICS import: merging events into a day no longer drops the day's existing events

### Changed
- Refill dialog now offers undone todos from all previous days (was limited to the last 30), sorted from most recent to oldest
- Calendar cells and daily sections use the provider's memoised parse cache instead of re-parsing markdown on every rebuild
- Event notifications and home-widget updates are debounced after saves instead of running on every 500ms autosave
- Saving a note updates the list in memory instead of re-scanning the whole notes directory

### Added
- Unit tests for markdown parser, ICS parser, daily content helpers and storage service
- GitHub Actions CI (analyze + tests)

### Removed
- Dead code: unused FileProvider, EventProvider and embedded DailyEditor

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
