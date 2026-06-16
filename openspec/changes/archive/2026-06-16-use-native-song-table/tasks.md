## 1. 原生歌曲表格

- [x] 1.1 用 `NSViewRepresentable` 包装 `NSTableView` 承载非空歌曲列表。
- [x] 1.2 用可复用 `NSTableCellView + NSHostingView` 渲染现有 SwiftUI `SongRow`。
- [x] 1.3 保留单击选中、双击播放、右键菜单、悬停播放和当前播放状态。
- [x] 1.4 保持空列表布局撑满内容区，避免顶部 UI 错位。

## 2. 验证

- [x] 2.1 运行 `openspec validate use-native-song-table` 验证变更通过。
- [x] 2.2 运行 `swift build` 验证编译通过。
- [x] 2.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
