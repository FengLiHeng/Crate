## Why

歌曲列表或分组列表数据量较大时，用户拖动滚动条会出现明显卡顿。当前歌曲列表使用 `LazyVStack`，但行内封面会在 SwiftUI 重新计算视图时反复从 `Data` 同步解码 `NSImage`；分组列表则使用普通 `VStack`，会一次性创建所有分组行。

## What Changes

- 为歌曲与专辑封面缩略图增加进程内 `NSImage` 缓存，避免滚动时重复解码同一封面数据。
- 将侧边栏分组滚动内容改为懒加载容器，减少大量分组时的初始视图创建量。
- 保持歌曲表格、分组点击、右键菜单、拖动排序、播放入口和视觉样式不变。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-library`: 歌曲表格在大量歌曲下应避免滚动期间重复同步解码同一封面缩略图。
- `music-groups`: 侧边栏分组列表在大量分组下应使用懒加载渲染，避免一次性创建全部分组行。

## Impact

- 影响 `src/Views/Components.swift`、`src/Views/SongTableView.swift`、`src/Views/SidebarView.swift`。
- 不改变曲库数据结构、分组数据结构、播放语义或持久化格式。
