# MarkdownUI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the native `AttributedString(markdown:)`-based rendering with `MarkdownUI` (gonzalezreal/swift-markdown-ui) to provide full GFM rendering in both the floating note display and the management page's preview pane.

**Architecture:** Add `MarkdownUI` as a Swift Package dependency in `project.pbxproj`. Replace the line-by-line `AttributedString` parser in `MarkdownContentView` with `MarkdownUI.Markdown`. Split `NoteDetailView` into a `VSplitView` of editor + live preview, both sharing the same `content` state.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, AppKit, [MarkdownUI 2.x](https://github.com/gonzalezreal/swift-markdown-ui), Xcode 15+, macOS 15.7+.

**Spec:** `docs/superpowers/specs/2026-06-21-markdownui-integration-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mdsticky/mdsticky/mdsticky.xcodeproj/project.pbxproj` | **Modify** | Add `XCRemoteSwiftPackageReference` (markdownui), `XCSwiftPackageProductDependency` (MarkdownUI), and link the product into the `mdsticky` target's `PBXFrameworksBuildPhase` and `packageProductDependencies`. |
| `mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift` | **Modify** | Rewrite `MarkdownContentView` to use `MarkdownUI.Markdown`. Add `MarkdownTheme.mdsticky(...)` extension. Drop the per-line parser. |
| `mdsticky/mdsticky/mdsticky/ContentView.swift` | **Modify** | Restructure `NoteDetailView` to use `VSplitView { TextEditor; MarkdownContentView }`. |
| `AGENTS.md` | **Modify** | Replace the two outdated lines about Markdown rendering. |
| Other files | Unchanged | — |

---

## Task 1: Add MarkdownUI Swift Package to `project.pbxproj`

**Files:**
- Modify: `mdsticky/mdsticky/mdsticky.xcodeproj/project.pbxproj`

The pbxproj file uses 24-character hex IDs for every object. The new IDs below are hand-picked from the `CAFE0000000000000000XXXX` block which is guaranteed not to collide with the existing 37 IDs (which all start with `11B35C...`).

Three new object definitions to insert, plus three existing places to reference them.

- [ ] **Step 1: Add `XCRemoteSwiftPackageReference` for swift-markdown-ui**

Insert the following block right after the `/* End PBXProject section */` marker (around line 208, before `/* Begin PBXResourcesBuildPhase section */`):

```pbxproj
/* Begin XCRemoteSwiftPackageReference section */
		CAFE0001000000000000ABCD /* XCRemoteSwiftPackageReference "swift-markdown-ui" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/gonzalezreal/swift-markdown-ui";
			requirement = {
				kind = upToNextMajorVersion;
				minVersion = 2.0.0;
			};
		};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		CAFE0002000000000000ABCD /* MarkdownUI */ = {
			isa = XCSwiftPackageProductDependency;
			package = CAFE0001000000000000ABCD /* XCRemoteSwiftPackageReference "swift-markdown-ui" */;
			productName = MarkdownUI;
		};
/* End XCSwiftPackageProductDependency section */
```

- [ ] **Step 2: Reference the package from the project object**

In the `PBXProject` object (the block starting with `11B35C2A2FE7D0D300ADA6BE /* Project object */`), add a `packageReferences` entry. Find the line `productRefGroup = 11B35C332FE7D0D300ADA6BE /* Products */;` and add this line right before it:

```pbxproj
			packageReferences = (
				CAFE0001000000000000ABCD /* XCRemoteSwiftPackageReference "swift-markdown-ui" */,
			);
```

- [ ] **Step 3: Add the product to the `mdsticky` target's `packageProductDependencies`**

Find the `mdsticky` target block (`11B35C312FE7D0D300ADA6BE /* mdsticky */`). Its `packageProductDependencies = (` is currently empty:

```pbxproj
			packageProductDependencies = (
			);
```

Change it to:

```pbxproj
			packageProductDependencies = (
				CAFE0002000000000000ABCD /* MarkdownUI */,
			);
```

- [ ] **Step 4: Add a `PBXBuildFile` for the product and reference it in the Frameworks phase**

In `PBXBuildFile section` (insert anywhere within that section, e.g. just after the `/* End PBXContainerItemProxy section */` block), add:

```pbxproj
/* Begin PBXBuildFile section */
		CAFE0003000000000000ABCD /* MarkdownUI in Frameworks */ = {isa = PBXBuildFile; productRef = CAFE0002000000000000ABCD /* MarkdownUI */; };
/* End PBXBuildFile section */
```

Then in the `mdsticky` target's Frameworks phase (`11B35C2F2FE7D0D300ADA6BE /* Frameworks */`), the `files = (` array is currently empty. Change it to:

```pbxproj
			files = (
				CAFE0003000000000000ABCD /* MarkdownUI in Frameworks */,
			);
```

- [ ] **Step 5: Resolve package dependencies**

Run:
```bash
cd /Volumes/Doc/dev/mdsticky/mdsticky
xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -resolvePackageDependencies 2>&1 | tail -10
```

Expected: success. The MarkdownUI package is fetched and resolved to a version `>= 2.0.0, < 3.0.0`. If the build fails, the most likely causes are:
- An ID collision (re-check IDs against `grep -oE "[A-F0-9]{24}" project.pbxproj | sort | uniq -d`)
- Malformed pbxproj syntax (revert via `git checkout -- mdsticky.xcodeproj/project.pbxproj` and retry)

- [ ] **Step 6: Verify the project builds with the dependency**

Run: `xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | tail -5`
Workdir: `mdsticky/mdsticky`
Expected: `** BUILD SUCCEEDED **`. No code uses MarkdownUI yet, but the package must be linked.

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Doc/dev/mdsticky
git add mdsticky/mdsticky/mdsticky.xcodeproj/project.pbxproj
git commit -m "Add MarkdownUI Swift Package dependency"
```

---

## Task 2: Rewrite `MarkdownContentView` to use MarkdownUI

**Files:**
- Modify: `mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift` (lines 185-225)

- [ ] **Step 1: Replace the `MarkdownContentView` struct**

Find the existing `MarkdownContentView` struct in `mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift` (starts around line 185 with `struct MarkdownContentView: View {` and ends around line 225 with the closing `}` after `private func parseLine`). Replace the entire struct with:

```swift
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
                .markdownTheme(.mdsticky(textColor: textColor))
        }
    }
}

extension MarkdownTheme {
    static func mdsticky(textColor: Color) -> MarkdownTheme {
        MarkdownTheme(
            text: {
                FontSize(13)
                ForegroundColor(textColor)
            }
        )
    }
}
```

- [ ] **Step 2: Add the `import MarkdownUI` line**

At the top of `mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift`, after the existing `import AppKit` (line 8), add:

```swift
import MarkdownUI
```

- [ ] **Step 3: Build to verify the integration compiles**

Run: `xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD " | tail -5`
Workdir: `mdsticky/mdsticky`
Expected: `** BUILD SUCCEEDED **`. If a `Cannot find 'MarkdownUI' in scope` or similar error appears, Task 1's pbxproj edit is incomplete.

- [ ] **Step 4: Verify the old parser is gone**

Run: `rg -n "parseLine|components\(separatedBy: \"\\\\n\"\)" mdsticky/mdsticky/Views/StickyNoteView.swift || echo "clean"`
Workdir: `/Volumes/Doc/dev/mdsticky`
Expected: `clean`. The line-by-line parser is fully removed.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Doc/dev/mdsticky
git add mdsticky/mdsticky/mdsticky/Views/StickyNoteView.swift
git commit -m "Render markdown via MarkdownUI for full GFM support"
```

---

## Task 3: Add live preview to `NoteDetailView`

**Files:**
- Modify: `mdsticky/mdsticky/mdsticky/ContentView.swift` (lines 144-181)

- [ ] **Step 1: Replace `NoteDetailView` body**

Find the `NoteDetailView` struct in `mdsticky/mdsticky/mdsticky/ContentView.swift`. Replace the entire struct body (everything inside `var body: some View {` ... the closing `}` of the struct) with:

```swift
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
```

The only change from the original is replacing the single `TextEditor` line with a `VSplitView` containing the editor and the `MarkdownContentView` preview.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | grep -E "error:|BUILD " | tail -5`
Workdir: `mdsticky/mdsticky`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Volumes/Doc/dev/mdsticky
git add mdsticky/mdsticky/mdsticky/ContentView.swift
git commit -m "Add live markdown preview pane to management page"
```

---

## Task 4: Update `AGENTS.md` documentation

**Files:**
- Modify: `AGENTS.md` (line 57-58)

- [ ] **Step 1: Replace the two outdated lines**

In `/Volumes/Doc/dev/AGENTS.md`, find the two adjacent lines:

```markdown
- Markdown rendering uses native `AttributedString(markdown:)` — no external dependencies required.
- To add enhanced Markdown rendering (GFM tables, task lists), install `MarkdownUI` via Xcode: File → Add Package Dependencies → `https://github.com/gonzalezreal/swift-markdown-ui`.
```

Replace them with:

```markdown
- Markdown rendering uses `MarkdownUI` (`https://github.com/gonzalezreal/swift-markdown-ui`), integrated as a Swift Package dependency in `project.pbxproj`. Provides full GFM support: headings, lists (bullet/numbered/task), tables, code fences, blockquotes, horizontal rules, links, images, emphasis, strikethrough.
```

- [ ] **Step 2: Commit**

```bash
cd /Volumes/Doc/dev/mdsticky
git add AGENTS.md
git commit -m "Update AGENTS.md to reflect MarkdownUI integration"
```

---

## Task 5: Launch smoke test (programmatic verification)

**Files:** None — automated launch + log inspection.

- [ ] **Step 1: Build and launch the app, capture system log for 8 seconds**

Run:
```bash
cd /Volumes/Doc/dev/mdsticky/mdsticky
xcodebuild -project mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build 2>&1 | tail -3
APP=/Users/charleypeng/Library/Developer/Xcode/DerivedData/mdsticky-adivfxqsrczdhhgctnzvpyiblmkm/Build/Products/Debug/mdsticky.app
pkill -f "mdsticky.app/Contents/MacOS/mdsticky" 2>/dev/null
open "$APP"
sleep 8
pgrep -lf "mdsticky.app/Contents/MacOS/mdsticky" | head -1
log show --predicate 'process == "mdsticky"' --last 10s --style compact 2>&1 | grep -iE "error|fault|crash|fatal" | head -10
pkill -f "mdsticky.app/Contents/MacOS/mdsticky" 2>/dev/null
echo "smoke test done"
```

Expected:
- `** BUILD SUCCEEDED **` at the end of the build line
- A PID line for mdsticky
- Either no error lines, or only the pre-existing SwiftData XPC warnings (which are documented as benign)

- [ ] **Step 2: If the smoke test surfaces a MarkdownUI-specific crash or load error, capture it and revert to a stub**

If the app crashes on launch with errors mentioning `MarkdownUI` or `swift-markdown-ui`, it likely means the package wasn't resolved correctly (a network issue at install time, or an incompatible version). Revert Task 2's commit (`git revert --no-commit HEAD~2..HEAD` or check out the prior `MarkdownContentView` content), keep the pbxproj change for re-attempt, and notify the user.

---

## Self-Review

**Spec coverage:**

| Spec section | Covered by |
|---|---|
| `project.pbxproj` integration | Task 1 (steps 1-4) |
| `MarkdownContentView` rewrite | Task 2 (steps 1-4) |
| `NoteDetailView` split into editor + preview | Task 3 (steps 1-3) |
| `AGENTS.md` documentation update | Task 4 (steps 1-2) |
| Manual test plan (15 cases) | Task 5 + user's interactive verification |
| Error handling (pbxproj corruption, etc.) | Task 1 step 5 (revert-on-fail) and Task 5 step 2 (revert-on-MarkdownUI-crash) |

**Placeholder scan:** No `TBD` / `TODO` / "implement later" / "fill in details" patterns.

**Type / API consistency:**

- `MarkdownContentView`'s public properties (`text`, `textColor`, `secondaryColor`) are unchanged — call sites in `StickyNoteView` (line 115) and `NoteDetailView` (Task 3) both use the same constructor.
- `MarkdownTheme.mdsticky(textColor:)` is the new function; called exactly once inside `MarkdownContentView.body`.
- `VSplitView` is a SwiftUI built-in, no new type to verify.

No inconsistencies found.
