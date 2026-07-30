## Why

当前主窗口的默认尺寸偏宽，配合固定侧边栏和底部播放条后，整体容易显得被横向压扁。调整为更均衡的默认比例，让首次启动和宣传截图的视觉重心更自然。

## What Changes

- 将主窗口默认内容尺寸调整为更接近 3:2 的比例。
- 让自动化截图窗口使用同一尺寸，保持应用内外展示一致。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `app-shell`: 调整应用启动时的默认窗口比例。

## Impact

- `src/CrateApp.swift` 的默认窗口尺寸。
- `src/ScreenshotMode.swift` 的固定截图窗口尺寸。
