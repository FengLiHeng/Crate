## Context

核心播放器（引擎、状态机、导入、持久化）已在 `local-music-player` 变更中实现并归档。本地文件可能被删除、移动或随外接盘拔出而失效。现状：

- `PlayerStore.startPlaying`（src/PlayerStore.swift:220）在播放时检查 `fileExists` + 尝试构造 `AVAudioPlayerEngine`，失败则计数跳过并 toast。
- 失效只在播放那一刻被发现，列表无任何标记；`Song` 模型与 `library.json` 仅存裸 `fileURL` 绝对路径。
- 应用非沙盒、未签名、单机自用（无 entitlements），裸路径在重启后仍可访问，因此**不需要** security-scoped bookmark。

已识别的真实缺陷：① `prev()` 直接调 `startPlaying`，其跳过分支永远调 `next()`，导致上一首撞缺失会反向跳到后面；⑤ 终止边界 `ctx.ids.count + manualQueue.count + 1` 在跳过过程中 `manualQueue` 被 `removeFirst` 缩短而漂移；④ `AVAudioPlayer(contentsOf:)` 在主线程同步构造，大文件/网络卷会卡 UI。

## Goals / Non-Goals

**Goals:**
- 失效曲目在列表中可见（置灰 + 警告图标），可一键清理，可重新定位（含同目录批量修复）。
- 启动时批量对账整库，播放时即时补标；拔/插盘后重扫即自洽。
- 修正 prev 跳过方向与跳过终止条件，消除大文件主线程阻塞。
- `Song` 模型与持久化格式保持不变。

**Non-Goals:**
- 沙盒 / security-scoped bookmark / App Store 上架。
- 歌词、均衡器、播放历史等扩展功能。
- 文件系统实时监听（FSEvents）——本期用启动扫描 + 播放即时探测，不做后台 watcher。

## Decisions

### D1：失效状态是派生的运行时数据，不持久化
在 `AppState` 新增 `var missingIds: Set<String>`（`@Observable`，不进 `PersistedLibrary`）。

- 理由：文件在不在是运行时事实，外接盘重插后应自动恢复。若写进 `Song`/`library.json`，找回文件后仍显示失效，需手动刷新。
- 备选：在 `Song` 加 `isAvailable` 字段并持久化——拒绝，违背"重插即自洽"，且污染数据模型。

### D2：探测时机 = 启动批量 + 播放即时
- 启动后台异步任务遍历 `library`，对每首有 `fileURL` 的曲目做 `fileExists` 检查，汇总写入 `missingIds`（一次性 `@MainActor` 赋值，避免逐条触发渲染）。
- `PlayerStore` 播放撞到缺失时，通过注入的回调 `onMissing(id)` 即时把该 id 补进 `missingIds`；重新定位/导入成功后移出。
- 备选：每次窗口激活重扫——拒绝，自用场景下 IO 过度；仅启动 + 播放即时已够。

### D3：跳过带方向
将 `startPlaying` 的隐式 `next()` 跳过改为显式方向：

```
enum SkipDirection { case forward, backward }
startPlaying(id:, skipOnMissing: SkipDirection = .forward)
```

- `next()` / 自动切歌 / playFrom 用 `.forward`。
- `prev()` 用 `.backward`：撞缺失时在 `ctx.ids` 内继续向前找可用曲目，到头则停在原地或回到曲首，绝不前进。
- 插播曲目（isManual）缺失：归入 forward 跳过，回落到 `next()` 既有语义。

### D4：用已访问集合替代漂移计数
跳过循环内维护一个本轮已尝试的 id 集合，当候选 id 已在集合中（绕了一圈）则判定整库不可播，`stopPlayback()` + toast "没有可播放的曲目"。替换 `consecutiveSkips` 与依赖 `manualQueue.count` 的漂移边界。

### D5：引擎异步构造
`AVAudioPlayerEngine` 的 `AVAudioPlayer(contentsOf:)` 移到后台队列构造，成功后回主线程接管播放；构造期间若用户已切走则丢弃。`SimulatedEngine` 路径不变（示例曲目无 IO）。保持 `PlaybackEngine` 协议对外行为一致。

### D6：重新定位的同目录批量修复
用户为某失效曲目选定新文件后：
1. 更新该 `Song.fileURL`，从 `missingIds` 移除。
2. 记录"旧目录 → 新目录"映射，遍历其余失效曲目：若其旧路径在同一旧目录、且新目录下存在同名文件，则一并改写 `fileURL` 并移出 `missingIds`。
- 仅做文件名匹配（不校验内容），自用场景下足够且省事。

## Risks / Trade-offs

- [启动扫描在超大曲库 / 慢速网络盘上耗时] → 后台异步执行，不阻塞首屏；标记延迟到达可接受（播放即时探测兜底）。
- [扫描与播放即时探测对 `missingIds` 的并发写] → 全部在 `@MainActor` 上更新，无数据竞争。
- [TOCTOU：扫描判定可用但播放瞬间文件被删] → 播放路径仍保留 `fileExists` + 构造失败兜底，即时补标，不依赖扫描结果的时效。
- [同目录批量修复误匹配同名不同曲] → 自用、文件名匹配的小概率风险；仅在用户主动重定位时触发，可接受。
- [文件删除发生在当前正在播放的曲目] → AVAudioPlayer 持有已打开句柄，当前曲目通常可继续播完；切到下一首时由既有路径捕获。本期不主动中断当前播放。
