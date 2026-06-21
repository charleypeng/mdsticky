# mdsticky: i18n, Single Instance, Color Scheme & Icon Fix

## Overview

Add five user-facing features to mdsticky: enforce single instance, multi-language
support with runtime switching, light/dark mode, complete Chinese+English
translations, and fix app icon sizing.

## 1. Single Instance Enforcement

**Goal:** Prevent two copies of mdsticky from running simultaneously.

**Implementation:**
- In `mdstickyApp.init()`, enumerate running processes with the same bundle
  identifier (`charleypeng.mdsticky`) via `NSRunningApplication`.
- If another instance is found, activate it (`.activate(options: .activateIgnoringOtherApps)`)
  and call `exit(0)`.
- This covers both LaunchServices launches and direct binary invocation.

## 2. Multi-Language Support

**Goal:** Let the user choose the app language from 10 common languages via
Settings, applied at runtime without app restart.

### Langauges

| Code     | Language           |
|----------|--------------------|
| `en`     | English            |
| `zh-Hans`| 简体中文           |
| `zh-Hant`| 繁體中文           |
| `ja`     | 日本語             |
| `ko`     | 한국어             |
| `fr`     | Français           |
| `de`     | Deutsch            |
| `es`     | Español            |
| `pt-BR`  | Português (Brasil) |
| `ru`     | Русский            |

### Architecture

- **String Catalog:** Xcode `.xcstrings` (standard modern format, supported by
  macOS 15.7). All user-facing strings are moved from hardcoded Chinese to
  `Text("key")` / `String(localized:)` calls referencing the catalog.
- **Locale injection:** Root view gets `.environment(\.locale, Locale(identifier: language))`.
  `Text()` views re-render automatically when the locale changes.
  `String(localized:)` calls use the injected locale.
- **AppSettings.language:** stored in UserDefaults (`mdsticky.language`), default `"zh-Hans"`.
  The initial read happens before `ContentView` to ensure the right locale on
  first launch.

### Settings UI

A new **语言与外观** tab in `SettingsView` replaces the 通用 + 同步 two-tab layout
with a three-tab layout. This tab contains:

- **语言选择:** `Picker` listing 10 languages with their native display names
  (e.g. "English", "简体中文", "日本語", "Français").
- **显示模式:** segmented `Picker` (跟随系统 / 白天 / 夜晚).

## 3. Dark / Light Mode

**Goal:** Let the user choose between follow-system, force light, or force dark.

### AppSettings.colorSchemeMode

```swift
enum ColorSchemeMode: String, CaseIterable {
    case system
    case light
    case dark
}
```

Stored in UserDefaults (`mdsticky.colorSchemeMode`), default `.system`.

### Root injection

```swift
.preferredColorScheme(settings.colorSchemeMode == .system
    ? nil
    : (settings.colorSchemeMode == .light ? .light : .dark))
```

## 4. Translation Scope

All user-facing strings in these files must use `Text("key")` / `String(localized:)`:

- `mdstickyApp.swift` – menu items, about panel, MenuBarView
- `ContentView.swift` – sidebar strings, context menu, detail view
- `SettingsView.swift` – tab labels, form labels, button text
- `StickyNoteView.swift` – title bar, toolbar items (paint palette pin), empty state "双击编辑..."
- `MarkdownToolbar.swift` – action labels (加粗/斜体/删除线 etc.) and `.help()` tooltips
- `Color+Hex.swift` – NoteColor names (黄色/绿色 etc.)

Strings that are data (note titles, file names, Markdown content) are NOT
translated.

The `.xcstrings` file will contain entries for all keys. For the initial pass,
`en` and `zh-Hans` get full translations; the other 8 languages receive
English as fallback with a comment flagging them as machine-translatable.

## 5. App Icon Sizing

**Problem:** The sticky-note graphic fills the entire 1024×1024 canvas edge-to-
edge, making the icon appear visually larger than macOS system icons (which
have generous internal padding).

**Fix:** Revise `app-icon.svg`:
- Add a minimal light-gray base background that fills the app icon shape.
- Shrink the yellow sticky note into the center with ~8-10 % padding on each side.
- Add a subtle drop shadow behind the note for depth.
- Keep the existing note content (white area, text lines) proportionally scaled.
- Regenerate all PNGs from the revised SVG using `librsvg` (`rsvg-convert`) or
  other available tool.

### Icon sizes to regenerate

| File                | Size  |
|---------------------|-------|
| `icon_16x16.png`    | 16×16  |
| `icon_16x16@2x.png` | 32×32  |
| `icon_32x32.png`    | 32×32  |
| `icon_32x32@2x.png` | 64×64  |
| `icon_128x128.png`  | 128×128 |
| `icon_128x128@2x.png`| 256×256 |
| `icon_256x256.png`  | 256×256 |
| `icon_256x256@2x.png`| 512×512 |
| `icon_512x512.png`  | 512×512 |
| `icon_512x512@2x.png`| 1024×1024 |

## Files Changed

| File | Change |
|------|--------|
| `mdstickyApp.swift` | Single-instance check; inject locale + colorScheme at root |
| `AppSettings.swift` | Add `language`, `colorSchemeMode` properties |
| `SettingsView.swift` | Add third tab (语言与外观), language picker, display mode picker |
| `mdsticky/Assets.xcassets/AppIcon.appiconset/*.png` | Regenerated from revised SVG |
| `app-icon.svg` | Redesigned with padding + light background |
| `Localizable.xcstrings` | **New** – string catalog for 10 languages |

Strings marked in the following files move to the catalog:

| File | Strings to translate |
|------|---------------------|
| `ContentView.swift` | 隐藏/显示/置顶/取消置顶/删除/便利贴/新建便利贴/设置/选择一个便利贴 |
| `StickyNoteView.swift` | 双击编辑... |
| `mdstickyApp.swift` | 关于 mdsticky/新建便利贴/管理便利贴/立即同步/退出 |
| `SettingsView.swift` | 通用/同步/语言与外观/启动/随系统启动并恢复桌面便利贴/同步服务/添加服务/全部同步/暂无同步服务.../切换语言/显示模式/跟随系统/白天/夜晚 |
| `MarkdownToolbar.swift` | 加粗/斜体/删除线/代码/链接/无序列表/有序列表/复选框/代码块/分割线/标题级别 |
| `Color+Hex.swift` | 黄色/绿色/蓝色/粉色/橙色/紫色/灰色 |
