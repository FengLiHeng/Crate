## Why

内容区头部的“播放”和“随机播放”与歌曲行播放、右键播放和底部播放控制重复，持续占用各分组的首屏空间。移除这些重复入口能让资料库和分组视图更聚焦于浏览与选择歌曲。

## What Changes

- 移除歌曲资料库与所有分组内容区头部的“播放”和“随机播放”按钮。
- 保留歌曲行悬停播放、双击播放、右键播放和底部播放条，作为开始播放与控制播放的入口。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `music-library`: 更新内容区头部与视图级播放入口的要求，移除重复的全量播放操作。

## Impact

- 修改 `src/Views/LibraryContentView.swift` 的内容区头部布局。
- 移除仅供头部按钮使用的播放集合读取与调用路径；不影响 `PlayerStore` 的播放能力及歌曲表格、右键菜单和播放条。
