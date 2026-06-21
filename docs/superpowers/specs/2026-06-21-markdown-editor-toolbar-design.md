# Markdown Editor & Toolbar Improvements

**Date**: 2026-06-21
**Status**: Approved (awaiting spec review by user)
**Project**: mdsticky (macOS sticky notes)

## Problem

Two related issues in the sticky-note editor:

1. **Toolbar buttons don't apply to selected text.** When the user selects text in the editor and clicks a toolbar button (e.g., bold), the selection is not wrapped with Markdown syntax. The previous attempt to fix this by globally searching `NSApp.keyWindow` for an `NSTextView` is unreliable — multi-window setups (multiple notes open) make the search return the wrong textView, and the keyWindow can be `nil` during transient UI states (menu open, etc.).

2. **Display-mode Markdown list rendering looks broken to the user.** The example `- xxx - xxfr` (single line, no newline) does not render as a list. Investigation confirmed this is expected: standard Markdown requires each list item on its own line. The user accepts strict standard Markdown — the fix is to make sure the toolbar list button always emits a newline, and the standard renderer handles the rest. The current `AttributedString(markdown:)` with `interpretedSyntax: .full` correctly renders standard GFM lists; no Markdown library swap is needed.

The toolbar also currently has font-size and color buttons added in a previous attempt. These are out of scope for a Markdown editor (Markdown is plain-text semantics; per-text color/font has no representation in the file format). They are being removed.

## Goal

- Toolbar buttons reliably wrap or insert Markdown syntax around the current selection in the active note.
- Toolbar list button always produces valid Markdown (newlines between items).
- A heading-level dropdown (`H1`–`H6`) replaces the single `#` button so the user can pick the heading level.
- No font-size, no text-color, no rich-text persistence, no custom file format. Editor stays close to native SwiftUI on the input side; renderer stays native `AttributedString(markdown:)` on the display side.
- Each floating note's editor operates in isolation; opening multiple notes does not cause cross-window contamination.

## Non-Goals

- Adding a third-party Markdown rendering library (e.g., `MarkdownUI`).
- Per-text font size or color formatting.
- Rich-text persistence (e.g., RTF sidecar files).
- Live preview side-by-side.
- Syntax highlighting inside the editor.

## Architecture

```
StickyNoteView (SwiftUI)
├── MarkdownToolbar       — Markdown syntax buttons + heading-level dropdown
└── MarkdownEditorView    — NSViewRepresentable wrapping NSScrollView + NSTextView
       └── Coordinator     — NSTextViewDelegate bridging NSTextView ↔ SwiftUI @State
```

**Layering rules**

- `MarkdownEditorView` does not know about `StickyNote`, storage, or Markdown semantics. It is a pure text-input component.
- `StickyNoteView` owns the `content` `@State`, file IO, toolbar dispatch, and the cached `NSTextView` reference.
- `Coordinator` is the only place that mutates `content` from NSTextView, and the only place that calls NSTextView APIs on behalf of the view.
- `MarkdownToolbar` is dumb UI: it emits actions, never mutates state.

## Components

### `MarkdownToolbar` (modified)

Reverts to a single-action callback. The font-size buttons, color menu, `ToolbarAction` enum, and `textColors` array are **removed**. The existing `MarkdownToolbarAction` struct (with `prefix`/`suffix`/`placeholder` fields) is **also removed** and replaced by a new enum (see below).

```swift
struct MarkdownToolbar: View {
    let onAction: (MarkdownToolbarAction) -> Void
}
```

**`MarkdownToolbarAction`** is now a Swift enum with three cases:

```swift
enum MarkdownToolbarAction {
    case inline(prefix: String, suffix: String, placeholder: String)  // bold, italic, strikethrough, code, link
    case heading(level: Int)                                            // 1...6, dispatched by the dropdown
    case block(prefix: String)                                          // list, numbered, checklist, divider
}
```

The toolbar's data-driven action list:

```swift
private let actions: [MarkdownToolbarAction] = [
    .inline(prefix: "**",  suffix: "**",   placeholder: "粗体文字"),
    .inline(prefix: "*",   suffix: "*",    placeholder: "斜体文字"),
    .inline(prefix: "~~",  suffix: "~~",   placeholder: "删除线文字"),
    .inline(prefix: "`",   suffix: "`",    placeholder: "代码"),
    .inline(prefix: "[",   suffix: "](url)", placeholder: "链接文字"),
    .block(prefix: "\n- "),
    .block(prefix: "\n1. "),
    .block(prefix: "\n- [ ] "),
    .block(prefix: "\n```\n", placeholder: "\n```\n"),  // code block — see note below
    .block(prefix: "\n---\n"),
]
```

Note: the code-block entry needs both an opening and a closing line, so the `block` case is extended slightly to support `prefix + optional middle + suffix`. The implementation can either (a) make the `block` case carry a `middle: String?` field, or (b) treat code-block as a special inline case with empty inner placeholder. The chosen shape is decided during implementation; the design intent is that code-block inserts `prefix="\`\`\`\n"`, `middle="\n"`, `suffix="\`\`\`\n"` with the cursor placed on the blank middle line.

**New: heading-level dropdown.** A `Menu` placed at the **leftmost** position of the toolbar, before the inline-formatting buttons. Visually it is a small button labeled `H? ▾` (placeholder label "标题" until smart detection is implemented — see Future Work).

The menu has 6 entries (`H1`–`H6`). Selecting an entry dispatches `.heading(level: 1...6)`.

**Dropdown UI sketch:**

```
┌─────────────────────────────────────────────────────────────┐
│ [ H? ▾ ] │ B  I  S  |  •  1.  ☑  🔗  </>  { }  ─            │
└─────────────────────────────────────────────────────────────┘
```

The `Menu` uses `pickerStyle(.menu)` semantics: it shows the current "value" in the label and the options on click. The `|` is a thin `Divider()` separator between the heading group and the inline-formatting group.

### `MarkdownEditorView` (new file: `Views/MarkdownEditorView.swift`)

```swift
struct MarkdownEditorView: NSViewRepresentable {
    @Binding var content: String
    var onTextViewReady: (NSTextView) -> Void
    var autoFocus: Bool
    var textColor: NSColor
}
```

**`makeNSView`**

1. Create `NSScrollView`, configure: `hasVerticalScroller = true`, `autohidesScrollers = true`, `drawsBackground = false`, `borderType = .noBorder`.
2. Create `NSTextView` with:
   - `isRichText = false` (plain text only — Markdown is plain-text semantics)
   - `isEditable = true`, `isSelectable = true`
   - `isAutomaticQuoteSubstitutionEnabled = false`, `isAutomaticDashSubstitutionEnabled = false`, `isAutomaticTextReplacementEnabled = false` (avoid macOS auto-correct clobbering Markdown syntax like `**` and `--`)
   - `font = NSFont.systemFont(ofSize: 13)`
   - `textColor = textColor` (dark text against the note's colored background)
   - `backgroundColor = .clear` (transparent so the note's color from the parent ZStack shows through; the `backgroundColor` parameter on the representable is reserved for future use and currently unused — see Future Work)
   - `drawsBackground = false` (required when `backgroundColor = .clear`)
   - `textContainerInset = NSSize(width: 4, height: 8)`
   - `textContainer?.widthTracksTextView = true`, `isHorizontallyResizable = false`, `isVerticallyResizable = true`
   - `delegate = context.coordinator`
3. Set the initial text: `textView.string = content`.
4. `scrollView.documentView = textView`.
5. Invoke `onTextViewReady(textView)`.
6. If `autoFocus` is true, dispatch a `DispatchQueue.main.async` block to call `textView.window?.makeFirstResponder(textView)` (the window may not be attached yet at `makeNSView` time).

**`updateNSView`** is **deliberately a no-op**. The single source of truth for text is the NSTextView. The `content` binding flows in one direction (NSTextView → Coordinator → SwiftUI). Doing anything in `updateNSView` would either fight user input or risk a state-change loop.

**`Coordinator`**

```swift
final class Coordinator: NSObject, NSTextViewDelegate {
    var content: Binding<String>

    init(_ content: Binding<String>) { self.content = content }

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        content.wrappedValue = tv.string
    }
}
```

No `textDidBeginEditing` / `textDidEndEditing` hooks needed.

### `StickyNoteView` (modified)

**State changes**:

```swift
@State private var isEditing: Bool = false
@State private var content: String = ""
@State private var activeTextView: NSTextView?   // NEW: cached reference
// REMOVED: editorFontSize, richContent, the global findTextView helper
```

**Body** — replace the TextEditor in `contentArea`:

```swift
if isEditing {
    MarkdownEditorView(
        content: $content,
        onTextViewReady: { tv in activeTextView = tv },
        autoFocus: true,
        textColor: NSColor(white: 0.18, alpha: 1.0)
    )
} else {
    ScrollView { MarkdownContentView(...) }
}
```

**Toolbar callback** — back to a single closure type:

```swift
MarkdownToolbar { action in
    handleMarkdownAction(action)
}
```

**`handleMarkdownAction(_ action: MarkdownToolbarAction)`**

Dispatches on the new enum:

```swift
private func handleMarkdownAction(_ action: MarkdownToolbarAction) {
    switch action {
    case .inline(let prefix, let suffix, let placeholder):
        applyInlineWrapper(prefix: prefix, suffix: suffix, placeholder: placeholder)
    case .heading(let level):
        applyHeadingPrefix(level: level)
    case .block(let prefix):
        applyBlockPrefix(prefix)
    }
}
```

**`applyInlineWrapper`** — wraps the selection with `prefix...suffix`, or inserts `prefix + placeholder + suffix` if nothing is selected, selecting the placeholder range so the user can type to replace it.

**`applyHeadingPrefix(level:)`** — inserts `\n# ` × `level`, with no selection, no placeholder (heading text is whatever the user types next on that line).

**`applyBlockPrefix(_:)`** — used for list, numbered list, checklist, divider. Inserts the prefix at the current cursor location; for list/numbered/checklist the cursor is positioned at the end of the inserted prefix so the user types the item content. For divider, no further action.

All three helpers go through one common primitive that uses `activeTextView`:

```swift
private func insertAtCursor(prefix: String, suffix: String = "", placeholder: String = "", selectPlaceholder: Bool = true) {
    guard let tv = activeTextView, tv.window != nil else {
        // Fallback: append to content. Toolbar clicks before makeNSView completes land here.
        content += prefix + placeholder + suffix
        return
    }
    let selectedRange = tv.selectedRange()
    let nsText = tv.string as NSString
    if selectedRange.length > 0 {
        let selected = nsText.substring(with: selectedRange)
        tv.insertText(prefix + selected + suffix, replacementRange: selectedRange)
    } else {
        let safePos = min(selectedRange.location, nsText.length)
        tv.insertText(prefix + placeholder + suffix, replacementRange: NSRange(location: safePos, length: 0))
        if selectPlaceholder, !placeholder.isEmpty {
            let selectStart = safePos + (prefix as NSString).length
            tv.setSelectedRange(NSRange(location: selectStart, length: (placeholder as NSString).length))
            tv.scrollRangeToVisible(tv.selectedRange())
        }
    }
    // textDidChange will sync content → save
}
```

**Removed code**:

- `applyTextColor(_:)`
- `applyMarkdownAction(_:)` (old free function / old method on the view)
- `findTextView(in:)`, `captureTextView()`
- `editorFontSize` state
- `DispatchQueue.main.async { captureTextView() }` in `.onChange(of: isEditing)`
- All references to `ToolbarAction` (the old enum)

`onChange(of: isEditing)` is no longer needed (no capture step).

`MarkdownContentView` is **unchanged** — display rendering already handles standard Markdown correctly.

## Data Flow

**Typing**:

```
keyboard
  → NSTextView default key handling
  → textDidChange notification
  → Coordinator.content.wrappedValue = tv.string
  → SwiftUI @State content updates
  → onChange(of: content)
  → NoteStorageService.save(.md)
  → modelContext.save()
```

**Toolbar click with selection**:

```
user selects "hello", clicks bold
  → MarkdownToolbar onAction(.inline(prefix: "**", suffix: "**", placeholder: "粗体文字"))
  → StickyNoteView.handleMarkdownAction(...)
  → insertAtCursor(prefix: "**", suffix: "**", placeholder: "")
  → tv.insertText("**hello**", replacementRange: <selectedRange>)
  → textDidChange fires
  → content = "**hello**"
  → save
```

**Toolbar click without selection (inline, with placeholder)**:

```
cursor at end of "abc", clicks bold
  → insertAtCursor(prefix: "**", suffix: "**", placeholder: "粗体文字")
  → tv.insertText("****粗体文字", replacementRange: <cursor>)
  → tv.setSelectedRange(<range of "粗体文字">)
  → user types to replace placeholder
```

**Heading dropdown click**:

```
cursor in middle of line, picks H2
  → applyHeadingPrefix(level: 2)
  → insertAtCursor(prefix: "\n## ", suffix: "", placeholder: "")
  → text becomes "...\n## " with cursor right after "## "
```

**List button click** (existing behavior, retained):

```
cursor at end of line, clicks bullet list
  → insertAtCursor(prefix: "\n- ", suffix: "", placeholder: "")
  → cursor is at the start of a new "- " line
```

The `\n` at the start of every list/checklist/numbered/divider/heading prefix is what guarantees valid Markdown regardless of where the cursor is on the current line.

## Error Handling

| Condition | Behavior |
|---|---|
| `activeTextView == nil` (toolbar clicked before `onTextViewReady` fires) | Fallback: append `prefix + placeholder + suffix` to `content`. The `.md` file gets the text; the user sees it on next render. No crash. |
| `activeTextView.window == nil` (view detached during mode switch) | Same fallback as above. |
| `selectedRange.location > text.length` | `safePos = min(location, length)` clamps the insertion point. |
| `tv.insertText` is called on a non-editable textView (should not happen) | Crash visible immediately — indicates state corruption, not a recoverable error. |
| `AttributedString(markdown:)` throws on display | `MarkdownContentView` already falls back to `Text(text)`. No change. |

## Testing

Manual test plan (Xcode build → Cmd+R):

1. **Selection wrap — bold**: select "hello" in any note → click bold → result "**hello**".
2. **Selection wrap — italic**: select "world" → click italic → "*world*".
3. **No-selection inline — bold**: cursor at end of "abc" → click bold → "abc****" with "粗体文字" selected (placeholder).
4. **No-selection inline — strikethrough**: cursor mid-word → click strikethrough → "~~删除线文字~~" inserted at cursor.
5. **Heading dropdown — H1**: cursor mid-text → pick H1 → "\n# " inserted at cursor.
6. **Heading dropdown — H3**: cursor at end of line → pick H3 → "\n### " inserted.
7. **List button — bullet**: cursor at end of "abc" → click bullet list → "abc\n- " with cursor after "- ".
8. **List button — checklist**: cursor mid-line → click checklist → "\n- [ ] " inserted.
9. **Code block**: cursor anywhere → click code block → "\n```\n\n```\n" with cursor on the blank middle line.
10. **Multi-window isolation**: open two notes. In note A, select "foo" and click bold. Note B is unchanged. Bold is applied only to A.
11. **Mode roundtrip**: edit → switch to display → switch back to edit. Text and cursor position are preserved; no duplication of toolbar-inserted prefixes.
12. **Display rendering — list**: in display mode, content "- a\n- b\n- c" renders as a bulleted list (rounded bullets, indent).
13. **Display rendering — heading**: content "# H1\n## H2" renders with H1 larger than H2.
14. **Persistence**: edit a note, quit app, relaunch. Edited content is still in the note.
15. **Regression — no font/color buttons**: toolbar does not show font-size or text-color buttons. The `ToolbarAction` enum and `textColors` array are gone from the source.

## File Changes

1. **`Views/MarkdownToolbar.swift`** (modify)
   - Change `onAction` callback type to `(MarkdownToolbarAction) -> Void` (where `MarkdownToolbarAction` is the new enum).
   - Replace the 11 inline `MarkdownToolbarAction` struct entries with a mix of `inline`, `heading`, and `block` cases.
   - Add a `Menu` at the leftmost position of the toolbar with 6 heading-level entries.
   - Remove `ToolbarAction` enum, `textColors` array, font-size buttons, paintbrush color menu.
   - Drop unused `import AppKit` references if no longer needed (still needed for `NSColor` type in old code paths being removed).

2. **`Views/StickyNoteView.swift`** (modify)
   - Replace `TextEditor(text: $content)` in `contentArea` with `MarkdownEditorView(...)`.
   - Add `@State private var activeTextView: NSTextView?`.
   - Replace `handleToolbarAction` / `applyMarkdownAction` / `applyTextColor` with `handleMarkdownAction` + the three dispatcher helpers (`applyInlineWrapper`, `applyHeadingPrefix`, `applyBlockPrefix`) and the shared `insertAtCursor` primitive.
   - Remove `editorFontSize`, `captureTextView`, `findTextView`, the `DispatchQueue.main.async` in `onChange(of: isEditing)`, the `onChange(of: isEditing)` itself if nothing else uses it.
   - Keep `MarkdownContentView` unchanged.

3. **`Views/MarkdownEditorView.swift`** (new)
   - `NSViewRepresentable` wrapping `NSScrollView` + `NSTextView` as specified.

4. **Other files** — unchanged. In particular:
   - `NoteStorageService` keeps its original (no-RTF) state.
   - `Models/`, `Services/WindowManager`, `ContentView`, `mdstickyApp`, sync services — no changes.

## Future Work (Out of Scope for This Spec)

- **Smart heading-level display in dropdown**: detect the current line's heading level from the cursor position and show `H1`–`H6` (or "段落" if no heading) in the dropdown label. This requires walking backward from the cursor to the start of the line and counting `#` characters. Defer to a follow-up.
- **Live preview pane** alongside the editor.
- **`MarkdownUI` integration** if `AttributedString(markdown:)` proves insufficient for any specific GFM construct users report.
- **Per-line blockquote, admonition, footnote toolbar buttons**.

## Open Questions

None at spec time. All clarifying questions resolved during brainstorming.
