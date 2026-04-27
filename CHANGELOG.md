# Changelog

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
