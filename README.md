# mdsticky

macOS 桌面 Markdown 便利贴应用。

## 功能

- **桌面便利贴** — 独立浮动窗口，拖拽移动，自由调整大小
- **置顶** — 一键将便利贴置顶到所有窗口之上
- **Markdown 编辑** — 双击切换编辑/展示模式，内置 Markdown 工具栏
- **Markdown 渲染** — 原生 `AttributedString(markdown:)` 渲染，零外部依赖
- **多色主题** — 7 种预设颜色（黄/绿/蓝/粉/橙/紫/灰）
- **统一管理** — 管理页面列表/详情查看，右键菜单操作
- **自动启动** — 设置随系统启动，自动恢复桌面便利贴
- **文件持久化** — 按日期时间命名，保存为 `.md` 文件
- **多协议同步** — WebDAV / 本地文件夹 / Samba 自动同步
- **文件监听** — 实时监听本地变更，2 秒防抖后自动推送

## 技术栈

- Swift 5 + SwiftUI + SwiftData
- macOS 15.7+
- AppKit 浮动窗口 (`NSWindow`, `NSWindow.Level`)
- App Sandbox + Hardened Runtime
- Security-scoped Bookmarks (沙箱文件夹访问)
- 零外部依赖，全部使用 macOS 原生框架

## 构建

```bash
xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' build
```

## 测试

```bash
xcodebuild -project mdsticky/mdsticky.xcodeproj -scheme mdsticky -destination 'platform=macOS' test
```

## 存储

便利贴内容存储为 `.md` 文件，位于：
```
~/Library/Application Support/mdsticky/notes/
```

## 同步

支持三种同步服务，可同时启用多个：

| 服务 | 说明 |
|------|------|
| WebDAV | HTTP PROPFIND / GET / PUT / DELETE |
| 本地文件夹 | 文件复制到指定文件夹 |
| Samba | 挂载的 SMB 共享路径 |

- 主服务支持双向同步，非主服务仅单向（上传）
- 同步频率：实时 / 每天一次 / 手动
- 主服务默认实时同步，其他默认每天一次
