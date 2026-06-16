## Why

歌曲列表是典型的大数据表格场景。`ScrollView + LazyVStack` 在中等数据量下可用，但在 macOS 上无法提供 `NSTableView` 级别的行复用、滚动条和表格滚动稳定性；手写滚动偏移虚拟化已经证明会破坏布局与滚动范围。

## What Changes

- 将非空歌曲列表的滚动容器迁移为 AppKit `NSTableView`，通过 `NSViewRepresentable` 嵌入 SwiftUI。
- 继续复用现有 SwiftUI 歌曲行内容、右键菜单、悬停播放、双击播放和选中状态。
- 保持空列表布局稳定，头部 UI 不因歌曲列表为空而垂直错位。
- 保留封面 `NSImage` 缓存，降低可见行渲染时的图片解码开销。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-library`: 歌曲表格在大量歌曲下应使用原生可复用表格渲染，确保滚轮与拖动滚动条能浏览完整歌曲集合。

## Impact

- 影响 `src/Views/SongTableView.swift`。
- 不改变曲库数据结构、播放上下文、搜索过滤、分组行为或持久化格式。
