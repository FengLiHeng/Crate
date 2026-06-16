## Context

Crate 当前有两个队列概念：`ctx` 表示当前视图生成的播放上下文，`manualQueue` 表示通过右键“下一首播放/添加到待播清单”加入的插播队列。待播清单面板同时展示两者。问题是 `playFrom` 重建 `ctx` 时没有清空 `manualQueue`，导致切换视图播放后旧插播仍会优先播放。

## Goals / Non-Goals

**Goals:**

- 从当前视图发起播放时，形成新的播放会话并清空旧插播队列。
- 保持右键插播能力，允许其他分组歌曲插到当前待播清单最前面。
- 不改变上一首/下一首、循环、随机和失效曲目跳过语义。

**Non-Goals:**

- 不把 `manualQueue` 和 `ctx` 合并为一个新模型。
- 不新增拖拽排序、持久化队列或多选添加能力。

## Decisions

- 在 `PlayerStore.playFrom` 开始处清空 `manualQueue`，因为该方法就是【歌曲】或分组视图播放入口的统一通道。
- 保持 `playNextSong` 使用 `manualQueue.insert(..., at: 0)`，让跨分组插播仍优先于当前上下文的“接下来”列表。
- 将右键菜单文案改为“添加到下一首播放”，和用户描述一致。

## Risks / Trade-offs

- [Risk] 用户如果误点当前视图播放，会丢失旧插播队列。 → Mitigation：这是本次需求定义的行为；右键插播仍可重新加入。
