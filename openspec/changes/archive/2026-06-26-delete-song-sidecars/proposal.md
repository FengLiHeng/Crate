## Why

用户通过歌曲右键菜单删除本地音频文件时，歌曲旁边常见的同名专辑图片和歌词文件仍会留在磁盘上，后续整理目录时会产生孤立文件。删除动作应覆盖与歌曲强绑定的 sidecar 文件。

## What Changes

- “移到废纸篓并移除记录…”确认文案说明会同步处理同名 `.jpg` 专辑图片和 `.lrc` 歌词文件。
- 执行删除时，若同目录存在与音频同 basename 的 `.jpg` 或 `.lrc` 文件，一并移到废纸篓。
- 若关联文件删除失败，应用仍移除资料库记录并 toast 提示未删除的关联文件名。

## Capabilities

### New Capabilities
- 无

### Modified Capabilities
- `music-library`: 扩展歌曲右键菜单删除本地文件时的 sidecar 文件处理。

## Impact

- 受影响源码：`src/AppState.swift`。
- 受影响规格：`music-library`。
- 无数据模型、第三方依赖或外部 API 变更。
