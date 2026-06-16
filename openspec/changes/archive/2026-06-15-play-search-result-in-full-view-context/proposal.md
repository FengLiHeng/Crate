## Why

用户在分组中搜索某首歌并双击播放时，待播清单被搜索结果缩小成单首歌曲。搜索应只帮助定位歌曲，不应改变当前【歌曲】或分组的播放上下文。

## What Changes

- 新增未经过搜索过滤的当前视图歌曲集合，供播放入口构建待播清单。
- 表格仍按搜索词显示过滤结果；双击过滤结果中的歌曲时，从完整当前视图中定位该歌曲并重建待播清单。
- 顶部【播放】和【随机播放】也使用完整当前视图歌曲集合，不受搜索词缩小。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-library`: 搜索过滤不改变播放上下文范围；播放入口基于未过滤的当前视图歌曲重建待播清单。
- `play-queue`: 从搜索结果双击播放时，待播清单仍按完整当前视图歌曲重建。

## Impact

- 影响 `src/AppState.swift` 的当前视图歌曲派生数据。
- 影响 `src/Views/SongTableView.swift` 和 `src/Views/LibraryContentView.swift` 的播放入口。
- 不改变队列数据结构、导入逻辑或播放引擎。
