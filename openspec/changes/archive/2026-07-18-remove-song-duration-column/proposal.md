## Why

歌曲时长在歌曲列表与分组列表中占用一列空间，但当前浏览和操作歌曲时并非必要信息。移除它可以让标题、艺术家和专辑信息获得更宽松的展示空间。

## What Changes

- 从资料库歌曲列表移除“时长”表头和每行的时长值。
- 从分组内歌曲列表移除相同的“时长”列。
- 重新分配表格可用宽度给标题、艺术家和专辑列。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-library`: 歌曲表格不再展示时长列。

## Impact

- 修改 `src/Views/SongTableView.swift` 的列宽计算、表头与歌曲行布局。
- 修改 `openspec/specs/music-library/spec.md` 的歌曲表格要求。
