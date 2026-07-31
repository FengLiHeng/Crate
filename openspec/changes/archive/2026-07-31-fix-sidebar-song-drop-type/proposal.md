## Why

侧边栏歌曲拖放入口在构建视图时通过 `UTType(identifier)!` 强制解包自定义类型。部分 macOS 版本不会把未声明的动态标识符解析为已注册类型，导致应用窗口首次布局时直接崩溃，用户无法打开应用。

## What Changes

- 使用显式导出的自定义歌曲拖放类型，避免依赖可失败的动态查询。
- 让表格拖放载荷与侧边栏接收端复用同一个类型定义。
- 添加回归测试，确保自定义类型可创建且标识符保持一致。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-groups`：歌曲拖放类型必须能够在应用启动和侧边栏布局时安全构建。

## Impact

- `src/Models.swift`
- `src/Views/SongTableView.swift`
- `src/Views/SidebarView.swift`
- `Tests/CrateTests/AppStateLibraryTests.swift`
