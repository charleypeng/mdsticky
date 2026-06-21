# mdsticky

一款 macOS 便利贴应用：每个便利贴都是一个独立的悬浮彩色窗口，自带 Markdown 编辑与渲染。笔记以纯 `.md` 文件保存在本地，并可同步到自己的 WebDAV / 本地目录 / SMB 共享。

## 功能

- **彩色悬浮便利贴**。每个便利贴都是一个独立窗口。从调色板选色，拖到屏幕任意位置，可置顶保持可见，可自由缩放。
- **Markdown 编辑器 + 工具栏**。自研的 `NSViewRepresentable` 包装 `NSTextView`；工具栏可在光标处或选中文本上插入语法（粗体、斜体、删除线、代码、链接、列表、复选框、代码块、分割线），并提供 H1–H6 标题级别下拉。
- **完整 GFM 渲染**。基于 [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)：标题、有序/无序/任务列表、表格、围栏代码块、引用、水平线、链接、图片、强调、删除线全部支持。代码块用半透明深色背景，在任何便利贴底色上都清晰可读。
- **管理页实时预览**。"管理便利贴"窗口列出全部笔记，并在右侧显示当前选中笔记的 Markdown 实时预览。编辑在悬浮便利贴窗口内进行。
- **文件即笔记**。笔记以 `yyyy-MM-dd HH.mm.md` 命名，存储于 `~/Library/Application Support/mdsticky/notes/`。任何文本编辑器都能打开，无格式锁定。
- **多端同步**。可配置一个或多个同步目标：WebDAV、本地目录、SMB 共享。系统文件事件触发同步，2 秒防抖。
- **登录自启**。在设置里打开"自启动"，应用通过 `SMAppService` 注册为登录项。
- **窗口持久化**。关闭最后一个窗口不会退出应用——菜单栏图标保持运行；下次启动时，之前可见的便利贴会自动恢复。

## 系统要求

- macOS 15.7 或更高版本
- Xcode 16 / 26（Swift 5 工具链）

## 构建

```bash
xcodebuild -project mdsticky/mdsticky/mdsticky.xcodeproj \
           -scheme mdsticky \
           -destination 'platform=macOS' \
           build
```

`MarkdownUI` Swift Package 已在 `mdsticky.xcodeproj` 中声明，Xcode 首次构建时自动解析。

## 项目结构

```
mdsticky/
├── mdstickyApp.swift              — @main 入口；Window(.manager) + MenuBarExtra
├── ContentView.swift               — 笔记管理列表 + 预览详情面板
├── Models/
│   ├── StickyNote.swift            — SwiftData @Model（id、标题、颜色、位置、…）
│   └── AppSettings.swift           — UserDefaults 封装（同步目标、自启动）
├── Views/
│   ├── StickyNoteView.swift        — 单个悬浮便利贴：标题栏 + Markdown 编辑 + 渲染
│   ├── MarkdownEditorView.swift    — NSViewRepresentable 包装 NSScrollView + NSTextView
│   ├── MarkdownToolbar.swift       — Markdown 语法工具栏 + 标题级别下拉
│   └── SettingsView.swift          — 自启动 + 同步配置
├── Services/
│   ├── NoteStorageService.swift    — 应用支持目录下 .md 文件的读写
│   ├── WindowManager.swift         — 每个便利贴的 NSWindow 生命周期、焦点、颜色、置顶
│   ├── AutoStartService.swift      — SMAppService 登录项
│   ├── SettingsWindowController.swift — 设置窗口宿主
│   └── Sync/                       — SyncServiceProtocol + 各后端实现
│       ├── SyncServiceProtocol.swift
│       ├── SyncServiceProvider.swift
│       ├── WebDAVSyncService.swift
│       ├── LocalFolderSyncService.swift
│       └── SambaSyncService.swift
└── Utilities/
    └── Color+Hex.swift             — 颜色十六进制解析 + NoteColor 调色板
```

## Markdown 约定

每个便利贴就是一个 `.md` 文件。元数据（颜色、位置、尺寸、置顶、可见）保存在 SwiftData 里；正文只在文件中。工具栏插入的语法跟手写完全一致，所以文件可以无缝迁移到任何其他 Markdown 阅读器。

## 许可协议

TBD。
