## Why

内容区头部的 `+` 菜单与“更多操作”中的音乐文件夹管理入口都能添加文件夹，用户难以判断两者区别。一次性文件导入和持续文件夹来源管理应各自只有一个清晰入口。

## What Changes

- 将内容区头部的 `+` 改为直接打开音乐文件选择面板。
- 移除 `+` 下的“添加音乐文件夹”二级入口和相关 AppKit 菜单桥接。
- 音乐文件夹的添加、移除与重新扫描统一保留在“更多操作 → 音乐文件夹…”管理界面。
- 保持导入进度、取消、文件拖入和文件夹扫描行为不变。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `library-import`：内容区头部的 `+` 从二级导入菜单改为直接导入音乐文件。
- `music-folder-sources`：明确音乐文件夹管理界面是添加和管理来源的统一入口。

## Impact

- `src/Views/LibraryContentView.swift`
- `src/AppState.swift`
- `Tests/CrateTests/AppUpdateServiceTests.swift`（避免运行中的应用阻塞完整测试）
- `openspec/specs/library-import/spec.md`
- `openspec/specs/music-folder-sources/spec.md`
