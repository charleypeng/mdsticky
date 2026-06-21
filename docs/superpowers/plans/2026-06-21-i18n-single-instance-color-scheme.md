# i18n + Single Instance + Display Mode + Icon Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 5 features: single instance enforcement, 10-language i18n, display mode (system/light/dark), complete translations, fix oversized app icon.

**Architecture:** AppSettings stores language + colorSchemeMode in UserDefaults; locale + preferredColorScheme injected at SwiftUI root; String Catalog (xcstrings) maps Chinese→English for runtime switch without restart.

**Tech Stack:** SwiftUI, AppKit, NSRunningApplication, Xcode String Catalog (.xcstrings), librsvg (rsvg-convert)

---

### Task 1: AppSettings — Add language & colorSchemeMode

**Files:**
- Modify: `mdsticky/mdsticky/Models/AppSettings.swift`

- [ ] **Step 1: Add ColorSchemeMode enum and new properties**

```swift
import Foundation
import Combine

enum ColorSchemeMode: String, CaseIterable {
    case system
    case light
    case dark
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var autoStart: Bool {
        didSet { defaults.set(autoStart, forKey: Keys.autoStart) }
    }

    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    @Published var colorSchemeMode: ColorSchemeMode {
        didSet { defaults.set(colorSchemeMode.rawValue, forKey: Keys.colorSchemeMode) }
    }

    private struct Keys {
        static let autoStart = "mdsticky.autoStart"
        static let language = "mdsticky.language"
        static let colorSchemeMode = "mdsticky.colorSchemeMode"
    }

    private init() {
        autoStart = defaults.bool(forKey: Keys.autoStart)
        language = defaults.string(forKey: Keys.language) ?? "zh-Hans"
        if let raw = defaults.string(forKey: Keys.colorSchemeMode),
           let mode = ColorSchemeMode(rawValue: raw) {
            colorSchemeMode = mode
        } else {
            colorSchemeMode = .system
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add mdsticky/mdsticky/Models/AppSettings.swift
git commit -m "feat: add language & colorSchemeMode to AppSettings"
```

---

### Task 2: Single Instance Enforcement

**Files:**
- Modify: `mdsticky/mdsticky/mdstickyApp.swift`

- [ ] **Step 1: Add single-instance check before `@main` struct**

Insert at top of `mdstickyApp.swift`, after the imports:

```swift
private func enforceSingleInstance() {
    let bundleID = Bundle.main.bundleIdentifier ?? "charleypeng.mdsticky"
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    if running.count > 1 {
        running.first?.activate(options: .activateIgnoringOtherApps)
        exit(0)
    }
}
```

- [ ] **Step 2: Call it in init()**

Add inside `mdstickyApp`, before any stored property:

```swift
@main
struct mdstickyApp: App {
    init() {
        enforceSingleInstance()
    }
    // ... rest unchanged
```

Make sure `enforceSingleInstance()` is either a free function or a static method (can't be an instance method called from init).

Move the function outside the struct:

```swift
@main
struct mdstickyApp: App {
    init() {
        enforceSingleInstance()
    }
    // ...
}

private func enforceSingleInstance() {
    let bundleID = Bundle.main.bundleIdentifier ?? "charleypeng.mdsticky"
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    if running.count > 1 {
        running.first?.activate(options: .activateIgnoringOtherApps)
        exit(0)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add mdsticky/mdsticky/mdstickyApp.swift
git commit -m "feat: enforce single instance via NSRunningApplication"
```

---

### Task 3: Locale & ColorScheme Injection at App Root

**Files:**
- Modify: `mdsticky/mdsticky/mdstickyApp.swift`

- [ ] **Step 1: Inject `.environment(\.locale, ...)` and `.preferredColorScheme(...)` on both scenes**

```swift
// Inside mdstickyApp.body
Window("便利贴管理", id: "manager") {
    ContentView()
        // ...
}
.modelContainer(sharedModelContainer)
.environment(\.locale, Locale(identifier: AppSettings.shared.language))
.preferredColorScheme(colorScheme(from: AppSettings.shared.colorSchemeMode))
// ... rest of modifiers

MenuBarExtra("mdsticky", systemImage: "note.text") {
    MenuBarView()
        .frame(width: 220)
}
.modelContainer(sharedModelContainer)
.environment(\.locale, Locale(identifier: AppSettings.shared.language))
.preferredColorScheme(colorScheme(from: AppSettings.shared.colorSchemeMode))
```

Add a helper method:

```swift
private func colorScheme(from mode: ColorSchemeMode) -> ColorScheme? {
    switch mode {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add mdsticky/mdsticky/mdstickyApp.swift
git commit -m "feat: inject locale & colorScheme at root for runtime switching"
```

---

### Task 4: SettingsView — Add 语言与外观 Tab

**Files:**
- Modify: `mdsticky/mdsticky/Views/SettingsView.swift`

- [ ] **Step 1: Add language/appearance tab to the TabView**

Insert a third tab after the sync tab:

```swift
TabView {
    generalTab
        .tabItem { Label("通用", systemImage: "gear") }
    syncTab
        .tabItem { Label("同步", systemImage: "arrow.triangle.2.circlepath") }
    languageAppearanceTab
        .tabItem { Label("语言与外观", systemImage: "globe") }
}
```

- [ ] **Step 2: Add the languageAppearanceTab view**

Add after `generalTab`:

```swift
private var languageAppearanceTab: some View {
    Form {
        Section {
            Picker("语言", selection: $settings.language) {
                Text("简体中文").tag("zh-Hans")
                Text("English").tag("en")
                Text("繁體中文").tag("zh-Hant")
                Text("日本語").tag("ja")
                Text("한국어").tag("ko")
                Text("Français").tag("fr")
                Text("Deutsch").tag("de")
                Text("Español").tag("es")
                Text("Português (Brasil)").tag("pt-BR")
                Text("Русский").tag("ru")
            }
            .pickerStyle(.menu)
        } header: {
            Text("语言")
        }

        Section {
            Picker("显示模式", selection: $settings.colorSchemeMode) {
                Text("跟随系统").tag(ColorSchemeMode.system)
                Text("白天").tag(ColorSchemeMode.light)
                Text("夜晚").tag(ColorSchemeMode.dark)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("显示模式")
        }
    }
    .formStyle(.grouped)
    .padding()
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add mdsticky/mdsticky/Views/SettingsView.swift
git commit -m "feat: add language & display mode tab to settings"
```

---

### Task 5: Create String Catalog (.xcstrings)

**Files:**
- Create: `mdsticky/mdsticky/Localizable.xcstrings`

- [ ] **Step 1: Create the xcstrings file with zh-Hans as source + en translations**

Run this script to generate the catalog:

```bash
cat > /Volumes/Doc/dev/mdsticky/mdsticky/mdsticky/Localizable.xcstrings << 'XCSTRINGS_EOF'
{
  "sourceLanguage" : "zh-Hans",
  "strings" : {
    "隐藏" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Hide" } }
      }
    },
    "显示" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Show" } }
      }
    },
    "取消置顶" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Unpin" } }
      }
    },
    "置顶" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Pin" } }
      }
    },
    "删除" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Delete" } }
      }
    },
    "便利贴" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sticky Notes" } }
      }
    },
    "新建便利贴" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "New Note" } }
      }
    },
    "设置" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Settings" } }
      }
    },
    "选择一个便利贴" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Select a Note" } }
      }
    },
    "管理便利贴" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Manage Notes" } }
      }
    },
    "立即同步" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sync Now" } }
      }
    },
    "退出" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Quit" } }
      }
    },
    "关于 mdsticky" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "About mdsticky" } }
      }
    },
    "通用" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "General" } }
      }
    },
    "同步" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sync" } }
      }
    },
    "语言与外观" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Language & Appearance" } }
      }
    },
    "启动" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Startup" } }
      }
    },
    "随系统启动并恢复桌面便利贴" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Launch at login and restore desktop notes" } }
      }
    },
    "同步服务" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sync Services" } }
      }
    },
    "添加服务" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Add Service" } }
      }
    },
    "全部同步" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sync All" } }
      }
    },
    "暂无同步服务，点击「添加服务」开始" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "No sync services yet. Click \"Add Service\" to start." } }
      }
    },
    "服务名称" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Service Name" } }
      }
    },
    "同步频率" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sync Frequency" } }
      }
    },
    "已设为主服务" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Primary Service" } }
      }
    },
    "非主服务" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Not Primary" } }
      }
    },
    "设为主" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Set as Primary" } }
      }
    },
    "测试" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Test" } }
      }
    },
    "选择文件夹..." : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Choose Folder…" } }
      }
    },
    "路径" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Path" } }
      }
    },
    "服务器" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Server" } }
      }
    },
    "用户名" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Username" } }
      }
    },
    "密码" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Password" } }
      }
    },
    "连接成功" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Connection Successful" } }
      }
    },
    "连接失败" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Connection Failed" } }
      }
    },
    "测试中..." : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Testing…" } }
      }
    },
    "选择同步目标文件夹" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Choose sync target folder" } }
      }
    },
    "确定要删除同步服务「%@」吗？此操作不可撤销。" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Are you sure you want to delete the sync service \"%@\"? This action cannot be undone." } }
      }
    },
    "确认删除" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Confirm Delete" } }
      }
    },
    "取消" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Cancel" } }
      }
    },
    "双击编辑..." : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Double-click to edit…" } }
      }
    },
    "加粗" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Bold" } }
      }
    },
    "斜体" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Italic" } }
      }
    },
    "删除线" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Strikethrough" } }
      }
    },
    "代码" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Code" } }
      }
    },
    "链接" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Link" } }
      }
    },
    "无序列表" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Bullet List" } }
      }
    },
    "有序列表" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Numbered List" } }
      }
    },
    "复选框" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Checklist" } }
      }
    },
    "代码块" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Code Block" } }
      }
    },
    "分割线" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Divider" } }
      }
    },
    "标题级别" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Heading Level" } }
      }
    },
    "粗体文字" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "bold text" } }
      }
    },
    "斜体文字" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "italic text" } }
      }
    },
    "删除线文字" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "strikethrough text" } }
      }
    },
    "链接文字" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "link text" } }
      }
    },
    "黄色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Yellow" } }
      }
    },
    "绿色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Green" } }
      }
    },
    "蓝色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Blue" } }
      }
    },
    "粉色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Pink" } }
      }
    },
    "橙色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Orange" } }
      }
    },
    "紫色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Purple" } }
      }
    },
    "灰色" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Gray" } }
      }
    },
    "语言" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Language" } }
      }
    },
    "显示模式" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Appearance" } }
      }
    },
    "跟随系统" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "System" } }
      }
    },
    "白天" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Light" } }
      }
    },
    "夜晚" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Dark" } }
      }
    },
    "上次: %@ %@" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Last: %@ %@" } }
      }
    },
    "暂不同步" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Don't Sync" } }
      }
    }
  },
  "version" : "1.0"
}
XCSTRINGS_EOF
echo "String catalog created"
```

**Note:** The `确定要删除同步服务...` and `上次: %@ %@` keys contain `%@` format specifiers. These match SwiftUI's string interpolation. For the delete confirmation message, the original uses `\(config.displayName)` which generates a `%@` format specifier.

- [ ] **Step 2: Verify file exists and is valid JSON**

```bash
python3 -m json.tool /Volumes/Doc/dev/mdsticky/mdsticky/mdsticky/Localizable.xcstrings > /dev/null && echo "Valid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add mdsticky/mdsticky/Localizable.xcstrings
git commit -m "feat: add string catalog with zh-Hans and en translations"
```

---

### Task 6: Fix App Icon — Redesign SVG with padding, regenerate PNGs

**Files:**
- Modify: `mdsticky/app-icon.svg`
- Modify: `mdsticky/mdsticky/Assets.xcassets/AppIcon.appiconset/` (10 PNG files)

- [ ] **Step 1: Redesign app-icon.svg with internal padding**

Write new SVG:

```bash
cat > /Volumes/Doc/dev/mdsticky/mdsticky/app-icon.svg << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="none">
  <!-- Light background base for the app icon shape -->
  <rect width="1024" height="1024" rx="225" fill="#F0ECE5"/>
  <!-- Subtle shadow behind sticky note -->
  <rect x="82" y="84" width="860" height="860" rx="52" fill="rgba(0,0,0,0.08)"/>
  <!-- Yellow sticky note (scaled down with ~8% padding) -->
  <rect x="82" y="82" width="860" height="860" rx="52" fill="#FFE066"/>
  <!-- Folded corner -->
  <path d="M774 82 L774 146 L838 210 L774 210 L774 82 Z" fill="#EDD055"/>
  <!-- White content area inside the note -->
  <rect x="164" y="168" width="696" height="636" rx="12" fill="#FFFFFF"/>
  <!-- Text lines -->
  <line x1="224" y1="248" x2="760" y2="248" stroke="#3A2E1F" stroke-width="20" stroke-linecap="round"/>
  <line x1="224" y1="316" x2="760" y2="316" stroke="#3A2E1F" stroke-width="20" stroke-linecap="round"/>
  <line x1="224" y1="384" x2="608" y2="384" stroke="#3A2E1F" stroke-width="20" stroke-linecap="round"/>
  <line x1="224" y1="452" x2="760" y2="452" stroke="#3A2E1F" stroke-width="20" stroke-linecap="round"/>
  <line x1="224" y1="520" x2="544" y2="520" stroke="#3A2E1F" stroke-width="20" stroke-linecap="round"/>
</svg>
SVGEOF
echo "SVG updated"
```

This design has:
- Light gray base rounded rect (standard macOS icon shape)
- 8.4% padding around the sticky note (1024→860)
- Subtle shadow behind the note
- Folded corner visual
- White content area with text lines, all proportionally smaller

- [ ] **Step 2: Regenerate all 10 PNG sizes from the SVG**

```bash
cd /Volumes/Doc/dev/mdsticky/mdsticky/mdsticky/Assets.xcassets/AppIcon.appiconset

# Remove old PNGs
rm -f icon_*.png

# Generate each size
rsvg-convert -w 16 -h 16 ../../../app-icon.svg -o icon_16x16.png
rsvg-convert -w 32 -h 32 ../../../app-icon.svg -o icon_16x16@2x.png
rsvg-convert -w 32 -h 32 ../../../app-icon.svg -o icon_32x32.png
rsvg-convert -w 64 -h 64 ../../../app-icon.svg -o icon_32x32@2x.png
rsvg-convert -w 128 -h 128 ../../../app-icon.svg -o icon_128x128.png
rsvg-convert -w 256 -h 256 ../../../app-icon.svg -o icon_128x128@2x.png
rsvg-convert -w 256 -h 256 ../../../app-icon.svg -o icon_256x256.png
rsvg-convert -w 512 -h 512 ../../../app-icon.svg -o icon_256x256@2x.png
rsvg-convert -w 512 -h 512 ../../../app-icon.svg -o icon_512x512.png
rsvg-convert -w 1024 -h 1024 ../../../app-icon.svg -o icon_512x512@2x.png

echo "Icons regenerated"
```

- [ ] **Step 3: Verify all 10 files exist with correct sizes**

```bash
cd /Volumes/Doc/dev/mdsticky/mdsticky/mdsticky/Assets.xcassets/AppIcon.appiconset
echo "=== Icon files ==="
sips -g pixelWidth -g pixelHeight icon_*.png 2>/dev/null | grep -E "pixel|file"
```

Expected: 10 files, all matching their intended pixel dimensions.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -project /Volumes/Doc/dev/mdsticky/mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add mdsticky/app-icon.svg \
       mdsticky/mdsticky/Assets.xcassets/AppIcon.appiconset/
git commit -m "fix: resize app icon with proper padding per macOS HIG"
```

---

### Task 7: Handle the Delete Confirmation Dialog Format String

The delete confirmation in SettingsView uses string interpolation:
```swift
Text("确定要删除同步服务「\(config.displayName)」吗？此操作不可撤销。")
```

SwiftUI generates a format specifier `%@` for the interpolated value. The xcstrings key needs to match the specific format specifier pattern. In Xcode string catalogs, the `%@` in the key is matched differently depending on SwiftUI version.

- [ ] **Step 1: Verify the string catalog entry works correctly**

Build and run the app. Open Settings → try to delete a sync service. If the deletion dialog text is wrong, the format specifier needs adjustment.

**If the text shows correctly**, no action needed.

**If the text doesn't localize**, replace the `Text(...)` with a non-interpolated version:

```swift
// In SettingsView.swift, replace:
Text("确定要删除同步服务「\(config.displayName)」吗？此操作不可撤销。")
// with:
Text("确认删除同步服务 \"\(config.displayName)\" 吗？此操作不可撤销。")
```

And add the corresponding xcstrings entry.

- [ ] **Step 2: Fix if needed, then commit**

```bash
git add -A
git commit -m "fix: adjust localization key for delete confirmation dialog"
```
