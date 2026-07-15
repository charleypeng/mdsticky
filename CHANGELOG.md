# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.2] — 2026-07-01

### Fixed
- Tray menu "New Note" now uses explicit shared context, fixing note persistence after app restart

## [1.2.1] — 2026-06-22

### Fixed
- Sticky note window: removed title text from title bar

## [1.2.0] — 2026-06-22

### Added
- Note list: multi-select with click-and-drag, Cmd+A, Shift+click
- Note list: NSTableView backend for native macOS list behavior
- Delete key and context menu delete with confirmation dialog
- Prominent "Set as Primary" button with confirmation before switching
- Immediate sync after setting a service as primary
- Primary service toggle tinted with accent color

### Changed
- Two-way sync established immediately on setting primary service
- Source code language migrated from zh-Hans to English

### Fixed
- macOS "developer cannot be verified" prompt fixed by building unsigned
- Settings window centered on screen
- Manager window hidden on first launch
- `activateIgnoringOtherApps` deprecation on macOS 14+

## [1.1.0] — 2026-06-22

### Added
- i18n: runtime language switching (10 languages) via `tr()` + per-language bundle lookup
- Color scheme: System / Light / Dark display modes
- Settings window: General, Sync, Language & Appearance tabs
- Sync services: WebDAV, local folder, SMB backends with per-service config
- Single-instance enforcement with macOS 14+ deprecation fix
- Author info in About panel with localized label

### Changed
- Source language migrated from zh-Hans to English; all hardcoded Chinese text replaced
- String catalog (.xcstrings) rebuilt with English keys and zh-Hans translations
- Manager window opened on-demand (no initial window) for unobtrusive startup
- `environment(\.locale)` replaced with manual `.lproj` bundle lookup for reliable macOS i18n

### Fixed
- App icon padding for proper macOS display
- Settings tab bar style (toolbar-style HStack replacing TabView)

## [1.0.0] — 2026-06-21

### Added
- Toolbar: heading-level dropdown (H1–H6) replaces the single heading button. Selecting a level inserts the matching prefix and places the cursor at the end of the prefix.
- Toolbar: code-block button inserts a fenced code block and leaves the cursor on the blank middle line.
- Management window: live Markdown preview for the selected note (powered by MarkdownUI).
- Sync targets: WebDAV, local folder, and SMB share backends with a 2-second file-system debounce.
- "New note" / "Manage notes" / "Sync now" / "Quit" menu-bar items.

### Changed
- Markdown rendering engine swapped from native `AttributedString(markdown:)` to MarkdownUI, restoring full GFM support: headings, lists (bullet / numbered / task), tables, fenced code blocks, blockquotes, horizontal rules, links, images, emphasis, strikethrough.
- Code (inline and block) now renders with a translucent dark background and white text so it reads on any note color.
- Toolbar callback rewritten as a single enum action (`.inline`, `.heading`, `.block`) so call sites and tests share one type.
- Management window: detail panel is preview-only; editing happens in the floating note window. Switching notes uses `.id(note.id)` to force a view rebuild so the preview refreshes.

### Fixed
- Toolbar buttons (bold, italic, etc.) correctly wrap the user's current selection instead of no-oping.
- Heading menu items render in the same dark gray as the rest of the toolbar (was using the system accent color).
- The note-window editor no longer drops the `NSTextView` reference during the first view-body evaluation, which had been leaving the toolbar ineffective until the next mode switch.

## [0.1.0] — 2026-06-21

### Added
- Initial release: floating color-coded Markdown notes, SwiftData metadata store, files in `~/Library/Application Support/mdsticky/notes/`, menu-bar extra, app-sandbox + hardened-runtime build.
