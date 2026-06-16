## Context

macOS 原生大数据表格的成熟方案是 `NSTableView`。它由 AppKit 管理滚动、行复用、可见区域更新和滚动条；SwiftUI 侧只需要通过 `NSViewRepresentable` 提供桥接。

本应用的歌曲行已经包含较多交互：封面、当前播放标识、悬停播放按钮、单击选中、双击播放和右键菜单。为了降低迁移风险，本次不重写行 UI，而是在 `NSTableView` 的单列 cell 内承载现有 SwiftUI `SongRow`。

## Goals / Non-Goals

**Goals:**

- 大量歌曲时使用 AppKit 行复用，不再让 SwiftUI 持有完整滚动视图树。
- 保留现有歌曲行视觉和交互。
- 保证空列表、245 首以上歌曲、滚轮滚动和拖动滚动条场景稳定。

**Non-Goals:**

- 不改变歌曲行视觉设计。
- 不引入第三方虚拟列表库。
- 不用手写滚动偏移计算。

## Decisions

- 使用单列 `NSTableView`，隐藏原生 header，继续使用现有 SwiftUI `TableHeader`。
- 每个可见行使用可复用的 `NSTableCellView`，内部持有 `NSHostingView<AnyView>`。
- `NSTableViewDelegate`/`NSTableViewDataSource` 由 `Coordinator` 提供，行高固定为 52pt。
- `updateNSView` 只在歌曲 id 集合变化时重载表格；其他状态变化只刷新可见行。

## Risks / Trade-offs

- [Risk] SwiftUI 行内手势和 AppKit 选择事件可能重叠。 → Mitigation：保留 `SongRow` 手势，同时在 `NSTableView` 选择和双击事件中同步选中/播放，确保基础交互可靠。
- [Risk] 原生滚动条视觉与 SwiftUI `ScrollView` 略有差异。 → Mitigation：表格使用透明背景并保留现有 SwiftUI 表头和行内容。
