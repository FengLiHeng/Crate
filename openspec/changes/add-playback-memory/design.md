## Context

当前应用已将曲库、播放列表持久化到 Application Support 下的 `library.json`，并通过 `CrateApp` 在 `NSApplication.willTerminateNotification` 时调用 `AppState.flushPersistence()` 做退出前落盘。播放状态集中在 `PlayerStore`：当前曲目、上下文、插播队列、随机/循环、播放进度和引擎生命周期都由它管理；音量已使用 `UserDefaults` 单独持久化。

本变更需要在应用重启后恢复播放条的当前歌曲和进度，但恢复后必须保持暂停，不能自动构造并播放音频。由于 `PlayerStore` 通过 `songProvider` 从 `AppState` 查询歌曲，恢复动作应发生在曲库加载、索引重建、回调注入之后。

## Goals / Non-Goals

**Goals:**

- 保存当前播放歌曲、播放进度和足够恢复底部播放条/队列语义的播放状态。
- 启动后恢复到上次歌曲和进度，并保持 `isPlaying == false`。
- 用户手动点击播放按钮后，从恢复进度继续播放。
- 当歌曲无法在当前曲库中匹配，或真实文件缺失时，安全回退到未播放状态。
- 复用现有持久化和播放状态边界，避免引入新依赖。

**Non-Goals:**

- 不恢复为自动播放，也不记住退出前是否正在播放。
- 不改变随机、循环、上一首/下一首、插播队列和歌词入口的既有交互规则。
- 不做跨设备同步、播放历史列表或多用户状态。
- 不迁移曲库 JSON 结构，除非实现阶段确认必须与曲库快照强绑定。

## Decisions

### D1. 播放记忆由 `PlayerStore` 定义并持久化

在 `PlayerStore` 内新增轻量级 `PlaybackMemory`（`Codable`）快照，包含：

- `currentId`
- `progress`
- `isManual`
- `manualQueue`
- `ctx.ids`
- `ctx.originalIds`
- `ctx.pos`
- `shuffle`
- `repeatMode`

保存位置优先使用 Application Support 下独立的 `playback-memory.json`，由 `AppState` 暴露同目录 URL 或调用 `PlayerStore` 配置持久化 URL。这样播放记忆和曲库快照生命周期分离，避免为了频繁进度变更持续重写整个 `library.json`。

替代方案是直接写入 `UserDefaults`。这更简单，但播放上下文和队列是结构化数据，独立 JSON 更容易扩展和调试，也与曲库持久化的文件存储方式一致。

### D2. 保存采用节流写入加退出强制落盘

播放状态在以下时机更新记忆：

- 当前曲目或上下文变化后。
- 用户拖动进度后。
- 进度定时器推进时节流保存，避免每 0.25 秒写盘。
- 暂停、停止、切歌、清空播放会话、删除当前歌曲时。
- 应用退出时强制保存当前快照。

实现上可在 `PlayerStore` 内维护待保存快照和简单节流任务；退出时由 `AppState.flushPersistence()` 同步调用 `player.flushPlaybackMemory()`。如果当前没有 `currentId`，应清除或写入空记忆，确保下次启动显示未播放状态。

替代方案是只在退出时保存。它实现简单，但崩溃、强制退出或系统回收时容易丢失最近进度；节流保存能提高恢复可靠性。

### D3. 恢复只恢复状态，不启动播放引擎

新增 `restorePlaybackMemory(availableSongs:)` 或等价方法，在 `AppState.init()` 完成曲库加载、`songsById` 建立和 `songProvider` 注入后调用。恢复流程：

1. 读取记忆文件并解码。
2. 确认 `currentId` 存在于 `songsById`。
3. 若歌曲有 `fileURL`，先检查文件仍存在；不存在则清理记忆并保持未播放。
4. 恢复 `currentId`、`progress`、`isManual`、`manualQueue`、`ctx`、`shuffle`、`repeatMode`。
5. 将 `progress` clamp 到 `0...song.duration`。
6. 保持 `isPlaying = false`，不创建 `PlaybackEngine`，不启动进度 timer。

用户点击播放按钮时，现有 `togglePlay()` 如果发现有 `currentId` 但 `engine == nil`，需要能从 `progress` 构造引擎并从该位置开始播放。可通过新增 `prepareAndPlayCurrent(from:)` 复用现有真实文件/模拟曲目的引擎构造逻辑，避免把恢复态误判为“已有引擎暂停”。

替代方案是在恢复时预构造引擎并立即暂停。该方案可能触发文件 IO、解码失败 toast 或后台构造竞态，不符合“打开 app 后不自动播放”的低副作用要求。

### D4. 恢复失败使用静默安全回退

恢复失败时应清空播放状态并删除无效记忆，不自动跳到其他歌曲。启动阶段不应因为上次歌曲缺失就触发“已跳过”或“没有可播放的曲目”等播放过程 toast；这些提示应保留给用户主动播放时的行为。

替代方案是复用现有失效跳过逻辑。它会自动寻找下一首，和“恢复上次位置但不自动播放”的用户预期不一致。

## Risks / Trade-offs

- [Risk] 频繁保存进度增加磁盘写入 → 使用节流保存，并在退出时做最终同步保存。
- [Risk] 恢复态没有引擎，现有播放按钮只调用 `engine?.play()` 会无声失败 → 修改 `togglePlay()`，在 `engine == nil` 且 `currentId != nil` 时构造引擎并从恢复进度播放。
- [Risk] 曲库变化后上下文中包含已删除歌曲 → 恢复时过滤 `ctx.ids`、`ctx.originalIds`、`manualQueue` 中不存在的 id，并重新对齐 `ctx.pos` 到当前歌曲。
- [Risk] 真实文件在启动时缺失 → 恢复阶段静默清理记忆；用户后续主动播放其他歌曲时仍沿用现有缺失提示与跳过逻辑。
- [Risk] 示例曲目和真实文件恢复路径不一致 → 统一通过 `currentId` 与 `progress` 恢复状态，手动播放时分别进入模拟引擎或 AVFoundation 引擎。

## Migration Plan

无需迁移现有曲库数据。首次升级后如果没有播放记忆文件，应用保持现有未播放启动行为。实现完成后运行 `swift build` 和 `Scripts/bundle.sh`，并手动验证退出重启恢复、恢复后不自动播放、手动播放从恢复进度继续、以及上次歌曲缺失时安全回退。

## Open Questions

无。
