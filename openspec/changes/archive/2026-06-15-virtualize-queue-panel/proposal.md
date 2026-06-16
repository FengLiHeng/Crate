## Why

待播清单在播放上下文较长时打开会卡顿。当前实现使用普通 `VStack` 一次性创建所有行视图，面板展开时需要同步渲染完整队列。

## What Changes

- 将待播清单滚动内容改为懒加载渲染，只创建可见区域附近的行。
- 避免面板打开时预先把全部队列 id 转换为完整行视图。
- 保持现有分区、双击跳播、插播移除和清空行为不变。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `play-queue`: 待播清单面板在长队列下应使用懒加载渲染，避免打开时因创建全部行而卡顿。

## Impact

- 影响 `src/Views/QueuePanelView.swift` 的列表渲染方式。
- 不改变播放队列数据结构、播放语义或持久化逻辑。
