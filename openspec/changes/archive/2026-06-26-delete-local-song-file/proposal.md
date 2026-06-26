## Why

歌曲右键菜单目前只能将曲目从资料库或分组中移除，无法直接处理磁盘上的原始音频文件。用户在整理曲库时需要一个明确的本地文件删除入口，减少在应用和 Finder 之间切换。

## What Changes

- 在歌曲右键菜单中为带真实文件路径的导入歌曲新增“移到废纸篓并移除记录…”操作。
- 操作执行前弹出确认，确认后将本地音频文件移到废纸篓，并从资料库、所有分组、播放队列和播放上下文中移除该歌曲。
- 若文件已不存在，确认后仅清理资料库记录并提示用户。

## Capabilities

### New Capabilities
- 无

### Modified Capabilities
- `music-library`: 扩展歌曲右键菜单的删除能力，区分仅移除资料库记录与移到废纸篓并移除记录。

## Impact

- 受影响源码：`src/AppState.swift`、`src/Views/SongTableView.swift`。
- 受影响规格：`music-library`。
- 无数据模型、第三方依赖或外部 API 变更。
