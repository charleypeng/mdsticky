# Markdown Editor & Toolbar Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the sticky-note editor so toolbar buttons correctly wrap selected text with Markdown syntax, replace the single `#` button with a heading-level dropdown (H1–H6), and remove the out-of-scope font-size and text-color buttons.

**Architecture:** Introduce a new `MarkdownEditorView` (`NSViewRepresentable` wrapping `NSScrollView` + `NSTextView`) that owns the editing surface. The parent `StickyNoteView` caches the `NSTextView` reference via callback and dispatches toolbar actions directly against it (no global `NSApp.keyWindow` search). The toolbar's action type becomes a single `MarkdownToolbarAction` enum with `.inline`, `.heading`, and `.block` cases. No rich text, no RTF, no third-party Markdown library.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, AppKit (`NSTextView`, `NSScrollView`, `NSMenu`), Xcode 15+, macOS 15.7+.

**Spec:** `docs/superpowers/specs/2026-06-21-markdown-editor-toolbar-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mdsticky/mdsticky/mdsticky/Views/MarkdownEditorView.swift` | **Create** | `NSViewRepresentable` wrapping `NSScrollView` + `NSTextView` with `Coordinator` bridging to a `@Binding<String>`. Pure input component; no Markdown semantics. |
| `mdsticky/mdsticky/mdsticky/Views/MarkdownToolbar.swift` | **Modify** | Replace the `MarkdownToolbarAction` struct and `ToolbarAction` enum with a new `MarkdownToolbarAction` enum (`.inline`, `.heading`, `.block`). Replace the `h.square` button with a `Menu` offering `H1`–`H6`. Remove font-size buttons, paintbrush color menu, and the `textColors` array. |
| `mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift` | **Modify** | Replace `TextEditor` with `MarkdownEditorView`; add `@State activeTextView: NSTextView?`; rewrite toolbar dispatch to use the cached `NSTextView` via `insertAtCursor`; remove font/color state and the global `findTextView` helper. |
| `mdsticky/mdsticky/mdsticky/ContentView.swift` | Unchanged | — |
| `mdsticky/mdsticky/mdsticky/Services/NoteStorageService.swift` | Unchanged | — |
| Other files | Unchanged | — |

---

## Task 1: Create `MarkdownEditorView` (NSViewRepresentable wrapper)

**Files:**
- Create: `mdsticky/mdsticky/mdsticky/Views/MarkdownEditorView.swift`

- [ ] **Step 1: Create the file with the representable skeleton**

Create `mdsticky/mdsticky/mdsticky/Views/MarkdownEditorView.swift` with the following content:

```swift
//
//  MarkdownEditorView.swift
//  mdsticky
//
//  NSViewRepresentable wrapping NSScrollView + NSTextView for the
//  sticky-note Markdown editor. Pure input component — knows nothing
//  about Note, storage, or Markdown syntax.
//

import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var content: String
    var onTextViewReady: (NSTextView) -> Void
    var autoFocus: Bool
    var textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content)
    }

    func makeNSView(context: Context) -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.delegate = context.coordinator
        textView.string = content

        scrollView.documentView = textView
        onTextViewReady(textView)

        if autoFocus {
            DispatchQueue.main.async { [weak textView] in
                guard let tv = textView else { return }
                tv.window?.makeFirstResponder(tv)
            }
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Intentionally a no-op. The NSTextView is the single source of truth;
        // Coordinator pushes NSTextView -> content (one-way).
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var content: Binding<String>

        init(content: Binding<String>) {
            self.content = content
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            content.wrappedValue = tv.string
        }
    }
}
```

- [ ] **Step 2: Verify the project still builds**

Run: `xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | tail -5`
Workdir: `mdsticky/mdsticky`
Expected: `** BUILD SUCCEEDED **`. The new file is referenced nowhere yet, but must compile on its own.

- [ ] **Step 3: Commit**

```bash
cd /Volumes/Doc/dev/mdsticky
git add mdsticky/mdsticky/mdsticky/Views/MarkdownEditorView.swift
git commit -m "Add MarkdownEditorView NSViewRepresentable wrapper"
```

---

## Task 2: Replace `MarkdownToolbar` actions (struct → enum, drop font/color)

**Files:**
- Modify: `mdsticky/mdsticky/mdsticky/Views/MarkdownToolbar.swift` (full rewrite)

- [ ] **Step 1: Rewrite `MarkdownToolbar.swift`**

Replace the entire file `mdsticky/mdsticky/mdsticky/Views/MarkdownToolbar.swift` with the following content. The rewrite:
- Removes the `MarkdownToolbarAction` struct and the `ToolbarAction` enum.
- Defines a new `MarkdownToolbarAction` enum with three cases (`.inline`, `.heading`, `.block`).
- Removes font-size buttons, paintbrush menu, and the `textColors` array.
- Replaces the `h.square` button with a `Menu` (H1–H6).
- Calls `onAction` with the new enum.

```swift
import SwiftUI
import AppKit

enum MarkdownToolbarAction {
    case inline(prefix: String, suffix: String, placeholder: String)
    case heading(level: Int)
    case block(prefix: String)
}

struct MarkdownToolbar: View {
    let onAction: (MarkdownToolbarAction) -> Void

    private let inlineActions: [(icon: String, label: String, action: MarkdownToolbarAction)] = [
        ("bold",          "加粗",   .inline(prefix: "**",  suffix: "**",    placeholder: "粗体文字")),
        ("italic",        "斜体",   .inline(prefix: "*",   suffix: "*",     placeholder: "斜体文字")),
        ("strikethrough", "删除线", .inline(prefix: "~~",  suffix: "~~",    placeholder: "删除线文字")),
        ("chevron.left.forwardslash.chevron.right", "代码", .inline(prefix: "`", suffix: "`", placeholder: "代码")),
        ("link",          "链接",   .inline(prefix: "[",   suffix: "](url)", placeholder: "链接文字")),
    ]

    private let blockActions: [(icon: String, label: String, action: MarkdownToolbarAction)] = [
        ("list.bullet", "无序列表", .block(prefix: "\n- ")),
        ("list.number", "有序列表", .block(prefix: "\n1. ")),
        ("checklist",   "复选框",   .block(prefix: "\n- [ ] ")),
        ("curlybraces", "代码块",   .block(prefix: "\n```\n\n```\n")),
        ("minus",       "分割线",   .block(prefix: "\n---\n")),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                headingDropdown

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ForEach(inlineActions.indices, id: \.self) { index in
                    let entry = inlineActions[index]
                    Button {
                        onAction(entry.action)
                    } label: {
                        Image(systemName: entry.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(white: 0.15))
                    .help(entry.label)
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ForEach(blockActions.indices, id: \.self) { index in
                    let entry = blockActions[index]
                    Button {
                        onAction(entry.action)
                    } label: {
                        Image(systemName: entry.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(white: 0.15))
                    .help(entry.label)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 26)
        .background(Color.black.opacity(0.08))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.black.opacity(0.06)), alignment: .bottom)
    }

    private var headingDropdown: some View {
        Menu {
            ForEach(1...6, id: \.self) { level in
                Button {
                    onAction(.heading(level: level))
                } label: {
                    Text("H\(level)")
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(width: 30, height: 22)
            .foregroundStyle(Color(white: 0.15))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 30)
        .help("标题级别")
    }
}
```

- [ ] **Step 2: Build to surface compile errors in `StickyNoteView` (expected)**

Run: `xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD " | head -20`
Workdir: `mdsticky/mdsticky`
Expected: **Multiple `error: cannot convert value of type 'MarkdownToolbarAction' (new enum) to expected argument type 'ToolbarAction'` (old enum)** in `StickyNoteView.swift`. These will be fixed in Task 3.

- [ ] **Step 3: Commit the toolbar rewrite**

```bash
cd /Volumes/Doc/dev/mdsticky
git add mdsticky/mdsticky/mdsticky/Views/MarkdownToolbar.swift
git commit -m "Refactor MarkdownToolbar: enum action type, add H1-H6 dropdown, drop font/color"
```

---

## Task 3: Rewrite `StickyNoteView` toolbar dispatch and replace `TextEditor`

**Files:**
- Modify: `mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift`

This task is the largest change. Apply each step in order. After all steps, the file should match the "Final file" shown at the end of this task.

- [ ] **Step 1: Replace the `@State` declarations (lines 13–16)**

Change the `@State` block from:

```swift
@State private var isEditing: Bool = false
@State private var content: String = ""
@State private var activeTextView: NSTextView?
@State private var editorFontSize: CGFloat = 13
```

to:

```swift
@State private var isEditing: Bool = false
@State private var content: String = ""
@State private var activeTextView: NSTextView?
```

- [ ] **Step 2: Remove the `onChange(of: isEditing)` modifier (lines 50–56)**

Delete this block from the view body:

```swift
.onChange(of: isEditing) { _, editing in
    if editing {
        DispatchQueue.main.async {
            captureTextView()
        }
    }
}
```

- [ ] **Step 3: Replace `TextEditor` in `contentArea` (lines 113–125)**

Change the `if isEditing` branch of `contentArea` from:

```swift
if isEditing {
    TextEditor(text: $content)
        .font(.system(size: editorFontSize))
        .foregroundStyle(textColor)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
} else {
```

to:

```swift
if isEditing {
    MarkdownEditorView(
        content: $content,
        onTextViewReady: { tv in activeTextView = tv },
        autoFocus: true,
        textColor: NSColor(white: 0.18, alpha: 1.0)
    )
} else {
```

- [ ] **Step 4: Remove the `captureTextView` and `findTextView` methods (lines 153–169)**

Delete both private methods entirely:

```swift
private func captureTextView() {
    guard let contentView = NSApp.keyWindow?.contentView else { return }
    activeTextView = findTextView(in: contentView)
}

private func findTextView(in view: NSView?) -> NSTextView? {
    guard let view else { return nil }
    if let tv = view as? NSTextView, tv.isEditable, tv.isSelectable {
        return tv
    }
    for subview in view.subviews {
        if let found = findTextView(in: subview) {
            return found
        }
    }
    return nil
}
```

- [ ] **Step 5: Replace `handleToolbarAction` + `applyMarkdownAction` + `applyTextColor` (lines 171–217)**

Delete:

```swift
private func handleToolbarAction(_ action: ToolbarAction) {
    switch action {
    case .markdown(let mdAction):
        applyMarkdownAction(mdAction)
    case .increaseFontSize:
        editorFontSize = min(48, editorFontSize + 2)
    case .decreaseFontSize:
        editorFontSize = max(8, editorFontSize - 2)
    case .changeColor(let color):
        applyTextColor(color)
    }
}

private func applyMarkdownAction(_ action: MarkdownToolbarAction) {
    guard let tv = activeTextView else {
        content += action.prefix + action.placeholder + action.suffix
        return
    }

    let selectedRange = tv.selectedRange()
    let text = tv.string

    if selectedRange.length > 0 {
        let selectedText = (text as NSString).substring(with: selectedRange)
        tv.insertText(action.prefix + selectedText + action.suffix, replacementRange: selectedRange)
        content = tv.string
    } else {
        let insertion = action.prefix + action.placeholder + action.suffix
        let safePosition = min(selectedRange.location, (text as NSString).length)
        tv.insertText(insertion, replacementRange: NSRange(location: safePosition, length: 0))
        let selectStart = safePosition + action.prefix.count
        if !action.placeholder.isEmpty {
            tv.setSelectedRange(NSRange(location: selectStart, length: action.placeholder.count))
            tv.scrollRangeToVisible(NSRange(location: selectStart, length: action.placeholder.count))
        }
        content = tv.string
    }
}

private func applyTextColor(_ color: NSColor) {
    guard let tv = activeTextView else { return }
    if tv.selectedRange().length > 0 {
        tv.textStorage?.addAttribute(.foregroundColor, value: color, range: tv.selectedRange())
    } else {
        tv.typingAttributes[.foregroundColor] = color
    }
}
```

Replace with:

```swift
private func handleMarkdownAction(_ action: MarkdownToolbarAction) {
    switch action {
    case .inline(let prefix, let suffix, let placeholder):
        insertAtCursor(prefix: prefix, suffix: suffix, placeholder: placeholder, selectPlaceholder: true)
    case .heading(let level):
        let hashes = String(repeating: "#", count: level)
        insertAtCursor(prefix: "\n\(hashes) ", suffix: "", placeholder: "", selectPlaceholder: false)
    case .block(let prefix):
        // Code-block entry uses the form "\n```\n\n```\n" so we split into
        // opening prefix, blank middle, closing suffix and drop the cursor
        // on the middle line.
        if prefix == "\n```\n\n```\n" {
            insertAtCursor(prefix: "\n```\n", suffix: "\n```\n", placeholder: "", selectPlaceholder: false)
        } else {
            insertAtCursor(prefix: prefix, suffix: "", placeholder: "", selectPlaceholder: false)
        }
    }
}

private func insertAtCursor(prefix: String, suffix: String, placeholder: String, selectPlaceholder: Bool) {
    guard let tv = activeTextView, tv.window != nil else {
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
    // textDidChange will sync content -> save
}
```

- [ ] **Step 6: Update the toolbar callback (line 33–35)**

Change:

```swift
MarkdownToolbar { action in
    handleToolbarAction(action)
}
```

to:

```swift
MarkdownToolbar { action in
    handleMarkdownAction(action)
}
```

- [ ] **Step 7: Build the project**

Run: `xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:|BUILD " | tail -10`
Workdir: `mdsticky/mdsticky`
Expected: `** BUILD SUCCEEDED **`. No remaining references to the old `ToolbarAction` enum, `editorFontSize`, `applyTextColor`, `findTextView`, or `captureTextView`.

If any compile error appears, fix and re-run.

- [ ] **Step 8: Verify the file structure matches expectations**

Run: `rg -n "ToolbarAction|editorFontSize|applyTextColor|captureTextView|findTextView" mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift mdsticky/mdsticky/mdsticky/Views/MarkdownToolbar.swift || echo "clean"`
Workdir: `/Volumes/Doc/dev/mdsticky`
Expected: `clean` — no remaining references to the removed types or methods.

- [ ] **Step 9: Commit**

```bash
cd /Volumes/Doc/dev/mdsticky
git add mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift
git commit -m "Wire MarkdownEditorView into StickyNoteView; fix selection-aware toolbar"
```

---

## Task 4: Manual smoke test (15 cases from spec)

**Files:** None — interactive testing.

- [ ] **Step 1: Open the app in Xcode and build & run**

In Xcode, `Cmd+R` the `mdsticky` scheme. Two notes are created via the menu bar "新建便利贴".

- [ ] **Step 2: Run the manual test checklist**

For each case below, perform the action and confirm the result.

| # | Action | Expected |
|---|---|---|
| 1 | Edit note A, type "hello", select "hello", click **B** toolbar button. | Text becomes `**hello**`. |
| 2 | Click **I** toolbar button with "world" selected. | Text becomes `*world*`. |
| 3 | Move cursor to end of "abc", click **B**. | Text becomes `abc****` and the placeholder "粗体文字" is selected. Typing replaces it. |
| 4 | Click strikethrough at cursor mid-word. | `~~删除线文字~~` inserted at cursor. |
| 5 | Open the heading dropdown, choose **H1**. | `\n# ` inserted at cursor. |
| 6 | Choose **H3** in the dropdown. | `\n### ` inserted at cursor. |
| 7 | Cursor at end of "abc", click bullet-list button. | Text becomes `abc\n- ` with cursor right after `- `. |
| 8 | Click checklist button mid-line. | `\n- [ ] ` inserted. |
| 9 | Click code-block button. | `\n\`\`\`\n\n\`\`\`\n` inserted; cursor on the blank middle line. |
| 10 | Open two notes. In note A, select "foo" and click **B**. In note B, type "bar". | A becomes `**foo**`. B is unaffected. |
| 11 | Edit a note, switch to display mode (click the eye icon), switch back to edit. | Text and toolbar-inserted prefixes are preserved; no duplication. |
| 12 | In display mode, type `- a\n- b\n- c` (via the bullet button three times). | Display shows a bulleted list with rounded bullets. |
| 13 | In display mode, type `# H1\n## H2` (via dropdown). | H1 line is larger than H2. |
| 14 | Edit a note, quit the app, relaunch. | The edited content is still there. |
| 15 | Look at the toolbar. | No font-size or paintbrush-color buttons. Only the H-dropdown and 10 Markdown syntax buttons. |

- [ ] **Step 3: If any case fails, file a fix**

For each failure, capture the case number, the action, the actual result, and the expected result. Apply targeted fixes in the relevant file (`MarkdownEditorView.swift`, `MarkdownToolbar.swift`, or `StickyNoteView.swift`) and re-run. Common failure modes are pre-documented in the spec's Error Handling section.

- [ ] **Step 4: Commit any fixes**

```bash
cd /Volumes/Doc/dev/mdsticky
git add <modified files>
git commit -m "Fix issues from manual smoke test"
```

(Only run this step if you made changes in Step 3. Skip if all 15 cases passed.)

---

## Self-Review

**Spec coverage check:**

| Spec section | Covered by |
|---|---|
| Toolbar buttons wrap selection | Task 3 Step 5 (insertAtCursor selection branch) |
| List button always emits valid Markdown (newlines) | Task 2 (blockActions have `\n- ` etc.) + Task 3 Step 5 (insertAtCursor applies prefix at cursor) |
| Heading dropdown H1–H6 | Task 2 (headingDropdown + `inlineActions`/`blockActions` split) + Task 3 Step 5 (`.heading` case builds the `#` prefix) |
| No font-size, no text-color, no RTF, no third-party lib | Task 2 (removes font-size buttons, color menu, `ToolbarAction` enum) + Task 3 Step 1 (removes `editorFontSize` state) + Task 1 (`isRichText = false`) |
| Each note's editor isolated from others | Task 1 (each StickyNoteView instance creates its own NSTextView via `onTextViewReady`; `activeTextView` is per-view @State) |
| `MarkdownContentView` unchanged | (no task touches it) |
| `NoteStorageService` unchanged | (no task touches it) |
| All 15 manual test cases | Task 4 |

**Placeholder scan:** No `TBD`/`TODO`/`"implement later"`/`"add appropriate error handling"` patterns.

**Type / API consistency:**

- `MarkdownToolbarAction` is defined in `MarkdownToolbar.swift` (Task 2 Step 1) as the new enum and used as the `onAction` parameter type — matches Task 3 Step 5 usage.
- `MarkdownEditorView` is defined in `MarkdownEditorView.swift` (Task 1 Step 1) with the four properties `{@Binding content, onTextViewReady, autoFocus, textColor}` — matches the call site in Task 3 Step 3.
- `insertAtCursor(prefix:suffix:placeholder:selectPlaceholder:)` signature in Task 3 Step 5 is consistent with the call sites in the same step.
- `activeTextView: NSTextView?` state added in Task 3 Step 1 is read in `insertAtCursor` in Task 3 Step 5.

No inconsistencies found.
