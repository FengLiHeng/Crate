## Why

导入的本地音乐文件随时可能被移动、删除，或随外接硬盘拔出而不可访问。当前实现只在"试图播放某首歌的那一刻"才发现文件缺失，弹一条短暂 toast 并跳过，列表里失效曲目看起来和正常曲目完全一样，用户既无法预先识别、也无从清理或重新定位。此外播放跳过逻辑存在两个真实缺陷：按"上一首"撞到缺失文件会反向跳到后面的曲目，且防无限跳过的计数边界在混合队列场景下会漂移。本变更系统性加固播放健壮性，让失效曲目可见、可清理、可修复。

## What Changes

- 新增**失效曲目对账**：`AppState` 维护一份运行时派生的 `missingIds: Set<String>`（不持久化，拔/插盘后重扫即自洽）；应用启动时后台批量探测整库并标记，播放撞到缺失文件时即时补入，重新定位或导入后移出。
- 资料库列表中失效曲目 SHALL **置灰并显示警告图标**，与可播曲目视觉区分。
- 新增**重新定位**入口：为失效曲目选择新文件后更新其 `fileURL`，并自动按相对文件名批量修复同一旧目录下的其他失效曲目（整文件夹搬家时一次修好）。
- 新增**清理失效曲目**入口：一键批量移除当前所有失效曲目（复用现有删除路径，同步歌单与播放上下文）。
- 修正 `prev()` 撞缺失文件的**方向 bug**：上一首跳过 SHALL 继续向"前"寻找可用曲目，而非现状的向后跳。
- 修正防无限跳过的**终止条件**：以已访问集合替代会漂移的 `consecutiveSkips` 计数，确保整库不可播时干净停止、不误判。
- 将 `AVAudioPlayer(contentsOf:)` 的同步构造移出主线程，避免大文件或网络卷上加载时阻塞 UI。

## Capabilities

### New Capabilities
- `track-availability`: 失效曲目的运行时探测、列表标记、清理与重新定位。

### Modified Capabilities
- `playback`: 细化"文件缺失"行为，补充上一首/下一首跳过的方向语义与整库不可播时的终止条件。

## Impact

- 代码：`src/AppState.swift`（新增 `missingIds` 与探测/清理/重定位逻辑）、`src/PlayerStore.swift`（带方向的跳过、终止条件、即时标记回调、异步引擎构造）、`src/PlaybackEngine.swift`（`AVAudioPlayerEngine` 异步构造）、`src/Views/SongTableView.swift` 与 `src/Views/Components.swift`（失效行样式与右键/工具栏入口）。
- 数据：`Song` 模型与 `library.json` 持久化格式**不变**——失效是派生状态。
- 依赖与系统：无新增依赖；仍非沙盒、单机自用，不引入 security-scoped bookmark。
