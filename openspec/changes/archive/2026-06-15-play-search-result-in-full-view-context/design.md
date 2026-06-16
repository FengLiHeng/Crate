## Context

`AppState.viewSongs` 同时承担“表格显示数据”和“播放上下文数据”两种职责。由于 `viewSongs` 会应用搜索过滤，搜索后双击播放会把 `PlayerStore.playFrom` 的输入缩小为搜索结果。

## Goals / Non-Goals

**Goals:**

- 将当前视图的完整歌曲集合与搜索过滤后的显示集合分开。
- 保持搜索结果中的双击播放体验：被双击歌曲立即播放。
- 保持待播清单范围为当前【歌曲】或当前分组的完整歌曲集合。

**Non-Goals:**

- 不改变搜索匹配规则。
- 不新增搜索内播放模式。
- 不改变随机播放、循环或插播队列语义。

## Decisions

- 在 `AppState` 增加 `viewPlaybackSongs`，表示当前【歌曲】或分组的完整歌曲集合，不应用搜索过滤。
- `viewSongs` 继续作为表格显示集合，保留现有搜索行为。
- 双击表格行时，用歌曲 id 在 `viewPlaybackSongs` 中查找索引，再调用 `playFrom`。

## Risks / Trade-offs

- [Risk] 用户搜索后点击顶部【播放】可能期望只播放搜索结果。 → Mitigation：本次需求明确待播清单应包含该分组所有歌曲；搜索作为定位工具处理。
