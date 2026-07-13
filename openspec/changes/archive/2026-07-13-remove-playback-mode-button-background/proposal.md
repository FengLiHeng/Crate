## Why

播放模式按钮在顺序播放和列表循环时共用 `repeat` 图标。目前列表循环额外以浅红色圆角背景标识，容易让用户把背景本身误解为另一个独立控件，且与图标语义形成重复信息。

## What Changes

- 移除播放条中播放模式按钮在随机、列表循环和单曲循环状态下的浅红色圆角背景。
- 保留播放模式图标及强调色，以持续标识非顺序播放状态。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `playback`: 调整播放模式激活状态在播放条中的视觉高亮方式。

## Impact

- 修改 `src/Views/Components.swift` 的共享图标按钮以支持无背景激活态，并仅在 `src/Views/PlayBarView.swift` 的播放模式按钮使用；待播清单按钮保持现有背景反馈。
- 不改变播放模式切换顺序、播放上下文、持久化或快捷键行为。
