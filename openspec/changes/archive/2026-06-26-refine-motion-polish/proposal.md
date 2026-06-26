## Why

当前应用的基础播放、曲库、队列和歌词能力已经完整，但界面状态变化偏瞬时，导致整体体验显得生硬。需要引入一套克制、统一、可降级的动效语言，让播放状态、页面切换和列表反馈更有连续性，同时不改变现有播放语义。

## What Changes

- 为界面动效建立统一节奏：短交互反馈、页面转场、面板展开和歌词推进使用一致的时长与曲线。
- 优化歌词页进入/退出、待播清单展开/收起、播放条换歌与播放/暂停反馈。
- 优化歌曲表格、侧边栏、按钮和滑杆的 hover、选中、按压与状态过渡。
- 尊重系统“减少动态效果”设置，必要时降级为淡入淡出或即时状态更新。
- 不新增第三方依赖，不改变播放队列、曲库、歌词解析或持久化行为。

## Capabilities

### New Capabilities
- `interface-motion`: 定义应用界面动效、状态过渡和减少动态效果降级规则。

### Modified Capabilities
- 无

## Impact

- 受影响源码：`src/Theme.swift`、`src/Views/RootView.swift`、`src/Views/PlayBarView.swift`、`src/Views/LyricsPlaybackView.swift`、`src/Views/QueuePanelView.swift`、`src/Views/SongTableView.swift`、`src/Views/SidebarView.swift`、`src/Views/LibraryContentView.swift`、`src/Views/Components.swift`。
- 受影响规格：新增 `interface-motion`。
- 无外部 API、数据模型或依赖变更。
