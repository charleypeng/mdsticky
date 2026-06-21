# Changelog

## [1.0.0] — 2026-06-21

### Added
- 桌面浮动便利贴窗口 (NSWindow + NSWindow.Level)
- 置顶/取消置顶功能
- 创建/删除/隐藏便利贴
- 7 种预设颜色主题
- Markdown 编辑模式 + 展示模式（双击切换）
- Markdown 工具栏（11 项快捷插入）
- 统一管理页面（列表 + 详情编辑）
- 菜单栏图标快速操作
- 自动启动（SMAppService）+ 启动恢复可见便签
- 文件持久化：`~/Library/Application Support/mdsticky/notes/*.md`
- Cmd+N 快捷键新建便利贴

### Sync
- 多协议同步架构：WebDAV / 本地文件夹 / Samba
- 主服务双向同步，非主服务单向上传
- 同步频率选择（实时/每天一次/手动）
- DispatchSource 文件监听自动同步（2 秒防抖）
- Security-scoped Bookmark 沙箱文件夹访问
- NSOpenPanel 文件夹选择器
- 测试连接功能

### UI
- 设置面板 TabView 分页（通用/同步）
- 同步服务卡片式 UI（圆角 + 边框）
- 删除确认弹窗
- 浅色背景文字可读性优化（绝对深色值）
- SF Symbol 图标 + 服务类型标识

### Fixed
- NSPanel 失焦消失 → 改用 NSWindow
- 置顶按钮不生效 → isFloatingPanel + orderFront
- Markdown 工具栏按钮失焦失效 → 递归搜索 NSTextView
- Sendable warning → 协议改为传递 String 而非 StickyNote 对象
