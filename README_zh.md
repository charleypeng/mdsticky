# mdsticky

macOS 桌面 Markdown 便利贴应用。

## 功能

- **桌面便利贴** — 独立浮动窗口，拖拽移动，自由调整大小
- **置顶** — 一键将便利贴置顶到所有窗口之上
- **Markdown 编辑** — 双击切换编辑/展示模式，内置 Markdown 工具栏（加粗/斜体/标题/列表/链接/代码等 11 项）
- **Markdown 渲染** — 原生 `AttributedString(markdown:)` 渲染，零外部依赖
- **多色主题** — 7 种预设颜色（黄/绿/蓝/粉/橙/紫/灰）
- **统一管理** — 管理页面列表/详情查看，右键菜单操作
- **自动启动** — 设置随系统启动，自动恢复桌面便利贴
- **文件持久化** — 按日期时间命名，保存为 `.md` 文件于 `~/Library/Application Support/mdsticky/notes/`
- **多协议同步** — WebDAV / 本地文件夹 / Samba 三种同步服务
- **文件监听** — 实时监听本地变更，2 秒防抖后自动推送

## 技术栈

- Swift 5 + SwiftUI + SwiftData
- macOS 15.7+
- AppKit 浮动窗口 (NSWindow + NSWindow.Level)
- App Sandbox + Hardened Runtime
- Security-scoped Bookmarks（沙箱文件夹访问权限）
- 零外部依赖，全部使用 macOS 原生框架

## 构建

```bash
xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build
```

## 测试

```bash
xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' test
```

## 同步服务

支持三种同步服务，可同时启用多个：

| 服务 | 协议 | 说明 |
|------|------|------|
| WebDAV | HTTP | PROPFIND / GET / PUT / DELETE |
| 本地文件夹 | 文件复制 | 同步到用户选择的本地目录 |
| Samba | SMB | 通过已挂载的 SMB 共享路径同步 |

### 同步规则

- **主服务**支持双向同步（拉取 + 推送），非主服务仅单向（上传）
- 同步频率可选：实时 / 每天一次 / 手动
- 主服务默认实时同步，其他默认每天一次
- 本地文件夹支持通过 `NSOpenPanel` 选择目标目录，使用安全作用域书签（Security-scoped Bookmark）保留访问权限

## 目录结构

```
mdsticky/
├── Models/
│   ├── StickyNote.swift         — SwiftData 数据模型
│   └── AppSettings.swift        — UserDefaults 应用配置
├── Views/
│   ├── ContentView.swift        — 便利贴管理页面
│   ├── StickyNoteView.swift     — 单张便利贴视图（编辑/展示模式）
│   ├── MarkdownToolbar.swift    — Markdown 编辑工具栏
│   └── SettingsView.swift       — 应用设置（通用/同步）
├── Services/
│   ├── NoteStorageService.swift   — .md 文件读写
│   ├── WindowManager.swift        — 浮动窗口生命周期管理
│   ├── AutoStartService.swift     — SMAppService 登录项
│   ├── SettingsWindowController.swift — 设置窗口
│   └── Sync/
│       ├── SyncServiceProtocol.swift    — 同步服务协议
│       ├── SyncServiceProvider.swift    — 同步管理器
│       ├── WebDAVSyncService.swift      — WebDAV 同步
│       ├── LocalFolderSyncService.swift — 本地文件夹同步
│       └── SambaSyncService.swift       — Samba 同步
├── Utilities/
│   └── Color+Hex.swift          — 颜色工具 + NoteColor 枚举
└── mdstickyApp.swift            — @main 应用入口
```
