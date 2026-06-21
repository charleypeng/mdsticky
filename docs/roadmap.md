# mdsticky 开发路线图

> macOS 桌面 Markdown 便利贴应用

## 项目现状

当前是 Xcode 默认 SwiftUI 模板项目，包含：
- `Item.swift`：模板 SwiftData 模型
- `ContentView.swift`：模板列表视图
- `mdstickyApp.swift`：应用入口

需要重构为完整的便利贴应用。

## 架构总览

```
mdstickyApp (入口)
├── MenuBarExtra           — 菜单栏图标，快速新建/管理
├── NoteManagerWindow      — 统一管理页面（列表/网格）
│   └── NoteManagerView
├── StickyNoteWindows      — 每个便利贴一个独立浮动窗口
│   └── StickyNoteView
│       ├── DisplayMode    — Markdown 渲染展示
│       └── EditMode       — Markdown 编辑 + Toolbar
├── SettingsWindow         — 设置页面
│   └── SettingsView
└── Services
    ├── NoteStorageService — 文件 I/O（.md 文件 + SwiftData 元数据索引）
    ├── WindowManager      — 浮动窗口创建/生命周期/位置记忆
    ├── WebDAVService      — WebDAV 上传/下载/同步
    └── AutoStartService   — SMAppService 登录项 + 启动恢复
```

## 技术选型

| 模块 | 方案 | 说明 |
|------|------|------|
| Markdown 渲染 | 原生 `AttributedString(markdown:)` | macOS 15+ 内置，零依赖 |
| Markdown 编辑 | 自定义 `TextEditor` + Toolbar | 原生行为，支持选中加粗/斜体等 |
| 浮动窗口 | `NSWindow` + `NSWindow.Level.floating` | 真正的置顶便利贴体验 |
| WebDAV | 自定义 `URLSession` 实现 | 避免笨重依赖，WebDAV 协议简单 |
| 自动启动 | `SMAppService.loginItem` | macOS 13+ Login Item API |
| 文件存储 | `FileManager` + Application Support | `.md` 纯文本，用户可直接访问 |
| 密码存储 | UserDefaults 明文 | 简化实现，仅个人使用 |
| 文件监听 | `DispatchSource.makeFileSystemObjectSource` | 监听 notes 目录变更，2 秒防抖 |

> 如需增强 Markdown 渲染（GFM 表格、任务列表等），可通过 Xcode → File → Add Package Dependencies 添加 `https://github.com/gonzalezreal/swift-markdown-ui`

## 数据模型

### `StickyNote`（SwiftData）

```swift
@Model final class StickyNote {
    @Attribute(.unique) var id: UUID
    var title: String             // 自动日期命名
    var contentFileName: String   // 对应的 .md 文件名
    var colorHex: String          // e.g. "#FFEB3B"
    var positionX: Double         // 窗口 X 位置
    var positionY: Double         // 窗口 Y 位置
    var width: Double             // 窗口宽度，默认 300
    var height: Double            // 窗口高度，默认 200
    var isPinned: Bool            // 是否置顶
    var isVisible: Bool           // 是否显示在桌面
    var createdAt: Date
    var updatedAt: Date
}
```

- SwiftData 存元数据（颜色、位置、可见性等）
- 文件系统存实际内容：`~/Library/Application Support/mdsticky/notes/`
- 文件命名格式：`yyyy-MM-dd HH.mm.md`

### `AppSettings`

使用 UserDefaults 存储：
- `autoStart: Bool` — 是否随系统启动
- `webdavURL: String` — WebDAV 服务器地址
- `webdavUsername: String`
- `webdavPassword: String`
- `syncInterval: TimeInterval` — 同步间隔

## 实施阶段

### 阶段 1：数据模型与存储基础

1. 创建 `Models/StickyNote.swift` — SwiftData `@Model`
2. 创建 `Models/AppSettings.swift` — UserDefaults 配置封装
3. 创建 `Services/NoteStorageService.swift`：
   - 目录创建
   - `.md` 文件读写
   - 删除
4. 更新 `mdstickyApp.swift` 的 Schema
5. 删除 `Item.swift`

**验收**：编译通过，启动后自动创建 `Application Support/mdsticky/` 目录

---

### 阶段 2：浮动窗口基础设施

6. 创建 `Services/WindowManager.swift`：
   - 创建/销毁 `NSWindow`
   - 置顶/取消置顶（`.floating` vs `.normal`）
   - 窗口关闭时隐藏不退出
7. 创建 `Views/StickyNoteView.swift`：
   - 默认黄色背景
   - 标题栏：日期标题 + 置顶/颜色/关闭按钮
   - 内容区：纯文本展示（临时）
8. 更新 `mdstickyApp.swift`：
   - `MenuBarExtra` 菜单栏图标
   - 启动时恢复可见便签
9. 实现基本操作：新建、关闭、删除、置顶、改色

**验收**：能新建便签，关闭后不退出 app，支持置顶和改色

---

### 阶段 3：Markdown 编辑与工具栏

10. 添加 Swift Package `MarkdownUI`
11. 创建 `Views/MarkdownToolbar.swift`：
    - 加粗、斜体、标题、无序列表、有序列表、链接、代码块、复选框、分割线
12. 重写 `Views/StickyNoteView.swift` 内容区：
    - 编辑模式：`TextEditor` + `MarkdownToolbar`
    - 展示模式：`Markdown` 渲染
    - 双击切换模式
13. 自动保存 `.md` 文件

**验收**：双击进入编辑，Markdown 正常渲染，工具栏可插入语法

---

### 阶段 4：统一管理页面与设置

14. 重写 `Views/ContentView.swift` → `Views/NoteManagerView.swift`：
    - 列表/网格展示所有便签
    - 显示/隐藏、删除、改色、置顶操作
    - 新建按钮、设置入口
15. 创建 `Views/SettingsView.swift`：
    - 自动启动开关
    - WebDAV 配置（地址、用户名、密码）
    - 立即同步按钮
16. 创建 `Services/AutoStartService.swift`：
    - `SMAppService.loginItem` 注册/取消
    - 启动恢复可见便签

**验收**：管理页可查看/操作所有便签，设置页可配置 WebDAV 和自动启动

---

### 阶段 5：WebDAV 文件监听自动同步

17. 创建 `Services/WebDAVService.swift`：
    - `PROPFIND` 列目录
    - `GET` 下载
    - `PUT` 上传
    - Basic Auth
    - 冲突处理：最后修改时间胜出
18. 文件监听自动同步：
    - 监听 `notes/` 目录变更
    - 防抖 2 秒后触发同步
    - 同步状态提示

**验收**：修改便签后自动同步到 WebDAV，从其他客户端可拉取更新

---

### 阶段 6：打磨与边界处理

19. 窗口位置/尺寸持久化
20. 应用退出时保存窗口可见状态
21. 键盘快捷键：`Cmd+N` 新建、`Cmd+W` 关闭
22. 菜单栏右键菜单：管理页、新建、同步、退出
23. 更新 `AGENTS.md` 添加新的依赖和构建命令

**验收**：快捷键生效，状态正确保存，文档同步

## 外部依赖

无。所有功能使用 macOS 原生框架实现（SwiftUI、SwiftData、AppKit、Foundation）。

> 如需增强 Markdown 渲染，可添加 `MarkdownUI` (https://github.com/gonzalezreal/swift-markdown-ui)。

## 实施状态

所有 6 个阶段已完成实现。

## 构建命令

```bash
xcodebuild -project mdsticky/mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build
```

## 测试命令

```bash
xcodebuild -project mdsticky/mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' test
```
