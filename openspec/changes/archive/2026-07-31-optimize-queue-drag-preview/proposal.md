## Why

待播队列使用 SwiftUI 默认整行拖动预览，侧边栏分组则直接移动原行。两处排序反馈不一致：待播预览会与原行叠出残影，侧边栏拖动行会覆盖相邻内容且目标位置不够清晰。

## What Changes

- 使用尺寸固定、背景不透明的紧凑拖动预览替代系统默认整行快照。
- 拖动期间隐藏原行内容，同时保留稳定的占位轮廓，避免列表跳动。
- 让侧边栏普通分组复用相同的拖动预览、占位、实时换位与释放清理交互。
- 保持现有分区内实时排序、跨分区拒绝、播放顺序和无障碍移动语义不变。
- 保持“我的收藏”固定第一位且不可拖动，并保留歌曲拖入普通分组的能力。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `play-queue`：优化待播分区拖动排序的视觉反馈，避免预览与原行叠加形成残影。
- `music-groups`：统一普通分组排序的拖动预览、占位与实时目标反馈。

## Impact

- `src/Views/QueuePanelView.swift`
- `src/Views/SidebarView.swift`
- `src/Views/Components.swift`
- `src/Models.swift`
- `openspec/specs/play-queue/spec.md`
- `openspec/specs/music-groups/spec.md`
