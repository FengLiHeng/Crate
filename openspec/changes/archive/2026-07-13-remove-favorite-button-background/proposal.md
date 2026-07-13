## Why

底部收藏按钮在已收藏时用浅红色圆角背景强调，与相邻的播放模式按钮产生重复的视觉层级。收藏状态可由实心心形和强调色清晰表达，无需额外底色。

## What Changes

- 移除播放条收藏按钮在已收藏状态下的浅红色圆角背景。
- 保留实心心形图标、强调色、悬停反馈和收藏切换行为。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-groups`: 调整播放条收藏按钮的已收藏状态视觉标识。

## Impact

- 修改 `src/Views/PlayBarView.swift` 的 `FavoriteButton`。
- 不改变收藏分组、持久化、播放上下文或操作反馈。
