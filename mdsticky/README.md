# mdsticky

A macOS sticky-notes app where each note is a floating, color-coded window with built-in Markdown editing and rendering. Notes are stored as plain `.md` files on disk and synced to your own WebDAV / local folder / SMB share.

## Features

- **Floating color-coded notes.** Each note is its own window. Pick a color from the palette, drag the note anywhere on screen, pin it to stay on top, and resize freely.
- **Markdown editor with toolbar.** A purpose-built `NSViewRepresentable` wraps `NSTextView`; the toolbar inserts syntax (bold, italic, strikethrough, code, link, list, checklist, code block, divider) and a heading-level dropdown (H1–H6) right at the cursor or around the selection.
- **Full GFM rendering.** Powered by [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui): headings, bullet / numbered / task lists, tables, fenced code blocks, blockquotes, horizontal rules, links, images, emphasis, strikethrough. Code blocks get a translucent dark background so they read on any note color.
- **Live preview in the management window.** The "Manage notes" window shows a list of all notes and a live Markdown preview for the selected one. Editing happens in the floating note window.
- **Filesystem-backed notes.** Notes are saved as `yyyy-MM-dd HH.mm.md` under `~/Library/Application Support/mdsticky/notes/`. Open them in any text editor; no lock-in.
- **Multi-target sync.** Configure one or more sync targets — WebDAV, local folder, or SMB share. File-system events on the notes directory trigger sync with a 2-second debounce.
- **Auto-start at login.** Toggle "auto-start" in Settings; the app registers itself via `SMAppService`.
- **Persistent windows.** Closing the last window does not quit the app — the menu-bar item keeps it alive and the previously visible notes are restored on next launch.

## Requirements

- macOS 15.7 or later
- Xcode 16 / 26 (Swift 5 toolchain)

## Build

```bash
xcodebuild -project mdsticky/mdsticky/mdsticky.xcodeproj \
           -scheme mdsticky \
           -destination 'platform=macOS' \
           build
```

The MarkdownUI Swift Package is declared in `mdsticky.xcodeproj`; Xcode will resolve it on first build.

## Project Layout

```
mdsticky/
├── mdstickyApp.swift              — @main entry point; Window(.manager) + MenuBarExtra
├── ContentView.swift               — Note management list + preview-only detail panel
├── Models/
│   ├── StickyNote.swift            — SwiftData @Model (id, title, color, position, …)
│   └── AppSettings.swift           — UserDefaults wrapper (sync targets, auto-start)
├── Views/
│   ├── StickyNoteView.swift        — Single floating note: title bar + Markdown editor + display
│   ├── MarkdownEditorView.swift    — NSViewRepresentable wrapping NSScrollView + NSTextView
│   ├── MarkdownToolbar.swift       — Markdown syntax toolbar + heading-level dropdown
│   └── SettingsView.swift          — Auto-start + sync configuration
├── Services/
│   ├── NoteStorageService.swift    — Read / write .md files in app-support directory
│   ├── WindowManager.swift         — Per-note NSWindow lifecycle, focus, color, pin
│   ├── AutoStartService.swift      — SMAppService login item
│   ├── SettingsWindowController.swift — Settings window host
│   └── Sync/                       — SyncServiceProtocol + per-backend implementations
│       ├── SyncServiceProtocol.swift
│       ├── SyncServiceProvider.swift
│       ├── WebDAVSyncService.swift
│       ├── LocalFolderSyncService.swift
│       └── SambaSyncService.swift
└── Utilities/
    └── Color+Hex.swift             — Color hex parsing + NoteColor palette
```

## Markdown conventions

Each note is a single `.md` file. Metadata (color, position, size, pinned, visible) lives in SwiftData; only the body is in the file. The toolbar inserts the same syntax you would write by hand, so the file is portable to any other Markdown reader.

## License

TBD.
