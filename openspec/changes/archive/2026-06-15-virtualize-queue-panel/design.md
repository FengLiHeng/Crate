## Context

待播清单当前使用 `ScrollView` 包裹普通 `VStack`。在 SwiftUI 中，普通 `VStack` 会在布局时创建全部子视图；当播放上下文包含大量后续曲目时，打开面板会同步构造所有 `QueueRow`，导致明显卡顿。

## Goals / Non-Goals

**Goals:**

- 使用 SwiftUI 原生懒加载容器减少面板打开时的同步视图创建量。
- 保持待播清单现有分区、操作和视觉样式不变。
- 避免为长“接下来”列表额外复制完整歌曲数组。

**Non-Goals:**

- 不改变 `PlayerStore` 的队列语义。
- 不引入 AppKit table view 或第三方虚拟列表库。
- 不新增队列持久化或分页能力。

## Decisions

- 使用 `LazyVStack` 替换滚动内容中的普通 `VStack`，让 SwiftUI 只创建可见区域附近的行视图。
- 插播分区按 `manualQueue` 索引懒解析歌曲；接下来分区直接遍历播放上下文的索引范围，避免调用会复制后续 id 的 `upcomingIds` 数组。

## Risks / Trade-offs

- [Risk] 通过索引访问队列时，闭包触发前队列可能变化。 → Mitigation：闭包调用现有 `playManualAt`、`removeManualAt`、`playContextAt`，这些方法内部已有边界检查。
