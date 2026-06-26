## Why

歌词页当前使用 macOS 系统 `.help` 为每行歌词显示时间提示。系统 help tag 本身带有显示延迟，并且在滚动后的 `LazyVStack` 新行上需要重新进入系统 tooltip 流程，导致用户悬停下方歌词时明显迟钝。

## What Changes

- 将歌词行时间提示从系统 `.help` 改为歌词页内部 hover 浮层。
- 时间提示在鼠标进入歌词行时即时显示，在离开时即时隐藏。
- 保持点击歌词行跳转播放时间的既有行为。

## Impact

- 受影响源码：`src/Views/LyricsPlaybackView.swift`、`src/Views/LyricLineView.swift`。
- 受影响规格：`lyrics-playback`。
- 无数据模型、歌词解析、播放引擎或外部依赖变更。
