# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
