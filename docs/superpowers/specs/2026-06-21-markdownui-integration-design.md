# MarkdownUI Integration Design

**Date**: 2026-06-21
**Status**: Approved (awaiting spec review by user)
**Project**: mdsticky (macOS sticky notes)

## Problem

The current Markdown display uses SwiftUI's native `AttributedString(markdown:)` with `interpretedSyntax: .full`. This handles only a subset of inline markup (bold, italic, strikethrough, links, code). It does **not** render any of the following GFM constructs:

- Heading levels (`#`–`######`): no font-size change, no weight change
- Bullet lists (`- item`): no bullet point
- Numbered lists (`1. item`): no number
- Task lists (`- [ ]` / `- [x]`): no checkbox
- Horizontal rules (`---`): ignored
- Tables: ignored
- Code fences (` ``` `): not styled
- Blockquotes (`>`): not indented

A user note like:

```markdown
- **范德萨范德萨范德萨**
———
分为惹我惹我去惹我惹我去人
##### 范德萨分为惹范德萨范德萨
- 范德萨惹我
- 分为惹我去
# 额外加入可怜我去节日快乐为
```

currently renders as flat left-aligned text — the user reported it as "a single line, no list bullets, no heading scaling" (and was right).

The work-around committed in `155c444` (per-line `AttributedString` parsing joined with `+ Text("\n")`) was a partial fix for the newlines issue but **does not** recover any of the GFM block-level rendering listed above. Per-line parsing in fact *fragments* multi-line constructs (a code fence split across two lines, a list with continuation paragraphs) and would only compound the problem once the renderer tried to handle them.

`AGENTS.md` already documented the path forward: install `MarkdownUI` (`https://github.com/gonzalezreal/swift-markdown-ui`) via Xcode's package manager.

## Goal

- All Markdown display surfaces in the app render the full GitHub-Flavored Markdown feature set: headings, lists (bullet, numbered, task), horizontal rules, tables, code blocks (fenced and inline), blockquotes, links, images, emphasis, strikethrough.
- The `MarkdownContentView` line-by-line parser and `Text + Text("\n")` workaround are **deleted**.
- The management window's `NoteDetailView` gains a live preview pane below the editor, rendered by the same Markdown view.
- No new external dependencies besides `MarkdownUI`.
- The `StickyNoteView` editor side is unaffected — it continues to use the `MarkdownEditorView` NSTextView wrapper.

## Non-Goals

- Replacing the editor (NSTextView) with a MarkdownUI-based live editor. The editor remains an NSTextView; MarkdownUI is display-only.
- Theme customization UI. A single sensible default theme is provided; users cannot change it from the UI.
- Rendering of MathJax, Mermaid, custom containers, or any non-GFM extension.
- Syncing rendered preview with the editor in real time on a per-keystroke basis when the editor is the in-note `MarkdownEditorView`. Preview is provided only in the management window (`NoteDetailView`), where editor and preview share a single `TextEditor` and `@State`.

## Architecture

```
mdsticky (app target)
├── MarkdownUI  ← Swift Package dependency (new)
│
├── StickyNoteView (SwiftUI)
│   ├── MarkdownEditorView (NSTextView wrapper) — editor, unchanged
│   └── MarkdownContentView (MarkdownUI) — display, replaced
│
└── ContentView (SwiftUI)
    └── NoteDetailView (SwiftUI)
        ├── TextEditor (editor) — unchanged
        └── MarkdownContentView (MarkdownUI) — preview pane, new
```

**Layering rules**

- `MarkdownContentView` is the only Markdown-display component. It wraps `MarkdownUI.Markdown` with a small theme adapter. Any view that wants to render Markdown composes this struct.
- The old line-by-line `AttributedString` parser in `MarkdownContentView` is removed entirely.
- The `MarkdownUI` package is added at the project level (in `project.pbxproj`) so any target can use it.

## Components

### 1. `project.pbxproj` — Swift Package integration

Add to `mdsticky/mdsticky/mdsticky.xcodeproj/project.pbxproj`:

- An `XCRemoteSwiftPackageReference` object for `swift-markdown-ui` (URL: `https://github.com/gonzalezreal/swift-markdown-ui`, version requirement: `from: 2.0.0`).
- An `XCSwiftPackageProductDependency` object that ties the `MarkdownUI` product to the package reference.
- The product is added to the `mdsticky` target's `PBXFrameworksBuildPhase` and `PBXNativeTarget` `packageProductDependencies` list.
- `packageProductDependencies` is added to the `XCRemoteSwiftPackageReference` group.

The pbxproj edit is done by hand on the existing file. The risk is the GUID system — every object has a 24-char hex ID and any collision will break the project. The strategy: pick IDs that don't clash with existing ones (a simple regex over the file will confirm), and verify the build with `xcodebuild -resolvePackageDependencies` after the edit.

### 2. `MarkdownContentView` — rewrite

The struct shrinks dramatically. It no longer needs `textColor` and `secondaryColor` parameters (MarkdownUI handles theming internally), but we keep them for API compatibility with current call sites and forward them to a `MarkdownTheme` for the empty-state placeholder.

```swift
import SwiftUI
import MarkdownUI

struct MarkdownContentView: View {
    let text: String
    let textColor: Color
    let secondaryColor: Color

    var body: some View {
        if text.isEmpty {
            Text("双击编辑...")
                .font(.system(size: 13))
                .foregroundStyle(secondaryColor)
        } else {
            Markdown(text)
                .markdownTheme(.mdsticky(textColor: textColor, secondaryColor: secondaryColor))
        }
    }
}

extension MarkdownTheme {
    static func mdsticky(textColor: Color, secondaryColor: Color) -> MarkdownTheme {
        MarkdownTheme(
            text: {
                FontSize(13)
                ForegroundColor(textColor)
            }
        )
    }
}
```

Notes:
- The `mdsticky` theme is a function (not a static constant) so call sites can pass their own `textColor` / `secondaryColor`. The note's dark text on a colored background is the common case; the management page's detail view uses `.primary` / `.secondary`.
- We can extend the theme later to customize heading sizes, code block backgrounds, list bullet styles, etc. without changing the call API.

### 3. `NoteDetailView` — split into editor + preview

The management window's `NoteDetailView` (in `ContentView.swift`) currently is a single `TextEditor` filling the available space. We split it into an editor and a live preview using `VSplitView` (so the user can drag the divider).

```swift
struct NoteDetailView: View {
    @Bindable var note: StickyNote
    @Environment(\.modelContext) private var modelContext
    @State private var content: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(note.title)
                    .font(.title2)
                Spacer()
                Button(note.isVisible ? "隐藏" : "显示") {
                    toggleVisibility()
                }
            }

            VSplitView {
                TextEditor(text: $content)
                    .font(.system(size: 13))
                    .border(Color.secondary.opacity(0.2), width: 1)

                MarkdownContentView(
                    text: content,
                    textColor: .primary,
                    secondaryColor: .secondary
                )
                .frame(minHeight: 80)
                .padding(8)
                .background(Color.secondary.opacity(0.04))
            }
        }
        .padding()
        .onAppear {
            content = (try? NoteStorageService.shared.load(for: note)) ?? ""
        }
        .onChange(of: content) { _, newValue in
            try? NoteStorageService.shared.save(content: newValue, for: note)
            try? modelContext.save()
        }
    }
}
```

Notes:
- The `VSplitView` initial split is roughly 60/40. SwiftUI's `VSplitView` does not expose a programmatic `fraction` parameter, but it does respect child `frame(minHeight:)` hints. Setting `.frame(minHeight: 80)` on the preview pane ensures it doesn't get squashed to zero.
- The preview re-renders on every `content` change. MarkdownUI is fast enough that this is not a performance concern for typical note sizes.

### 4. `AGENTS.md` — update Key Conventions

Change the two relevant lines:

```diff
- Markdown rendering uses native `AttributedString(markdown:)` — no external dependencies required.
- To add enhanced Markdown rendering (GFM tables, task lists), install `MarkdownUI` via Xcode: File → Add Package Dependencies → `https://github.com/gonzalezreal/swift-markdown-ui`.
+ Markdown rendering uses `MarkdownUI` (`https://github.com/gonzalezreal/swift-markdown-ui`), integrated as a Swift Package dependency in `project.pbxproj`. Provides full GFM support: headings, lists (bullet/numbered/task), tables, code fences, blockquotes, horizontal rules, links, images, emphasis, strikethrough.
```

## Data Flow

**Note display (sticky note window)**:

```
content: String (already loaded by StickyNoteView.onAppear)
  → MarkdownContentView
  → MarkdownUI.Markdown(text)
  → GFM parse → render
```

**Note editor (sticky note window)**:

```
NSTextView user input
  → Coordinator.textDidChange
  → @State content
  → onChange → NoteStorageService.save
  → next render of display mode (after user toggles) shows new content
```

The two views share a single `content` source. The display path is independent of the editor path until the user toggles back from edit to display.

**Management page**:

```
TextEditor user input
  → @Binding content
  → onChange → NoteStorageService.save
  → MarkdownContentView re-renders preview in the same frame
```

Same `@State`, two views, one save. Preview updates on every keystroke.

## Error Handling

| Condition | Behavior |
|---|---|
| MarkdownUI parse error on a single construct (e.g., malformed table) | MarkdownUI falls back to rendering the unparsable slice as plain text. No crash. |
| `content` is empty | `MarkdownContentView` shows the "双击编辑..." placeholder, same as today. |
| pbxproj edit corrupts the project | `xcodebuild` reports a specific error. Restore from git, retry with a different GUID set. |
| `xcodebuild -resolvePackageDependencies` fails (network) | Re-run with network available. If it persistently fails, the spec fails the build but is recoverable by deleting the pbxproj additions. |
| `VSplitView` collapses to 0 height for preview | `.frame(minHeight: 80)` on the preview pane prevents this. |
| MarkdownUI is missing at compile time | `xcodebuild` fails on `import MarkdownUI`. The pbxproj edit is incomplete; re-check. |

## Testing

Manual test plan (Xcode build → Cmd+R):

1. **Heading rendering**: paste a note with `# H1` through `###### H6`. All six headings render with decreasing font sizes and bold weight.
2. **Bullet list**: paste `- one\n- two\n- three`. Three lines with bullet points (•).
3. **Numbered list**: paste `1. one\n2. two`. Numbered 1, 2.
4. **Task list**: paste `- [ ] todo\n- [x] done`. Two checkboxes; the second is checked.
5. **Horizontal rule**: paste `---`. A horizontal line is drawn.
6. **Inline + list**: paste `- **bold item**`. Bullet plus bold text inside.
7. **Code fence**: paste ` ```\ncode\n``` `. Monospaced block with background tint.
8. **Blockquote**: paste `> quote`. Indented block.
9. **Regression — sticky note display**: open a note, switch to display mode, verify all of the above render. (The user's pasted example should now show proper bullets, headings, and the `———` horizontal rule.)
10. **Regression — sticky note editor**: switch a note to edit mode, type "hello", select and bold. Editing is unaffected.
11. **Management page preview**: open the management window, select a note. The right pane shows the editor on top and a live preview on the bottom.
12. **Management page live update**: edit text in the upper editor. The preview updates immediately.
13. **Management page split drag**: drag the divider in the management page. Both panes remain visible.
14. **Persistence**: edit any note, quit, relaunch. Edits are preserved.
15. **No line-by-line parser**: search the source for `parseLine` or `components(separatedBy: "\n")` in `MarkdownContentView` — neither is present.

## File Changes

1. **`mdsticky/mdsticky/mdsticky.xcodeproj/project.pbxproj`** (modify)
   - Add `XCRemoteSwiftPackageReference` for `swift-markdown-ui`.
   - Add `XCSwiftPackageProductDependency` for the `MarkdownUI` product.
   - Add the product to the `mdsticky` target's `PBXFrameworksBuildPhase` and `packageProductDependencies`.
   - All new IDs hand-picked to avoid collision with existing ones.

2. **`mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift`** (modify)
   - Rewrite `MarkdownContentView` body to use `MarkdownUI.Markdown`.
   - Add a small `MarkdownTheme` extension for the `mdsticky` theme.
   - Remove the per-line parser (`parseLine`), the `rendered` computed property, and the `+ Text("\n")` joining.
   - The struct's public properties (`text`, `textColor`, `secondaryColor`) and call sites in `StickyNoteView` are unchanged.

3. **`mdsticky/mdsticky/mdsticky/ContentView.swift`** (modify)
   - Rewrite `NoteDetailView` body to use `VSplitView { TextEditor; MarkdownContentView }`.
   - Keep the title bar and visibility-toggle button as-is.

4. **`/Volumes/Doc/dev/AGENTS.md`** (modify)
   - Replace the "Markdown rendering" line and the "To add enhanced Markdown" line with a single statement that MarkdownUI is now integrated.

5. **Other files** — unchanged.

## Future Work (Out of Scope)

- Custom MarkdownUI theme picker in the settings window.
- Live preview in the sticky note editor (split editor / preview inside the floating note).
- Code-syntax highlighting in code blocks (MarkdownUI supports `CodeSyntaxHighlighter`).
- Table of contents extraction and rendering.
- Math/Mermaid extensions.
- Replace the management page's `TextEditor` with a MarkdownUI-based live editor that still allows source editing.

## Open Questions

None at spec time. All clarifying questions resolved during brainstorming.
