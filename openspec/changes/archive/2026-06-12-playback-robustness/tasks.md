## 1. 失效状态与探测（AppState）

- [x] 1.1 在 `AppState` 新增 `var missingIds: Set<String>`（@Observable，不加入 `PersistedLibrary`）
- [x] 1.2 实现启动后台批量探测：异步遍历 `library` 中带 `fileURL` 的曲目，`fileExists` 检查后在 @MainActor 一次性写入 `missingIds`
- [x] 1.3 暴露 `markMissing(_ id:)` / `clearMissing(_ id:)`，供 `PlayerStore` 即时标记与重定位/导入后清除调用
- [x] 1.4 导入成功的新曲目确保不在 `missingIds` 中

## 2. 播放跳过修正（PlayerStore + PlaybackEngine）

- [x] 2.1 定义 `enum SkipDirection { case forward, backward }`，`startPlaying(id:skipOnMissing:)` 接受方向参数
- [x] 2.2 撞缺失时调用注入的 `onMissing(id)` 回调即时标记，并按方向寻找下一个可用曲目
- [x] 2.3 `next()` / 自动切歌 / `playFrom` 使用 `.forward`；`prev()` 使用 `.backward`，在 `ctx.ids` 内向前找可用曲目，到头停在曲首不前进
- [x] 2.4 用本轮已访问 id 集合替换 `consecutiveSkips`：候选 id 重复出现即判定全库不可播，`stopPlayback()` + toast "没有可播放的曲目"
- [x] 2.5 `AVAudioPlayerEngine` 的 `AVAudioPlayer(contentsOf:)` 移到后台队列构造，成功回主线程接管；构造期间用户已切走则丢弃
- [x] 2.6 在 `AppState.init` 中接好 `player.onMissing` 回调到 `markMissing`

## 3. 重新定位与清理（AppState）

- [x] 3.1 实现 `relocate(_ song:)`：NSOpenPanel 选新文件 → 更新 `fileURL`、`clearMissing`
- [x] 3.2 重定位后自动批量修复：对其余失效曲目，若旧路径同处一旧目录且新目录下存在同名文件，改写 `fileURL` 并 `clearMissing`
- [x] 3.3 实现 `cleanupMissing()`：批量移除 `missingIds` 中曲目（复用 `removeSong` 路径同步歌单/上下文），toast 显示数量

## 4. 视图（SongTableView / Components）

- [x] 4.1 失效行置灰 + 警告图标（依据 `appState.missingIds.contains(song.id)`）
- [x] 4.2 失效行右键菜单加"重新定位…"与"从资料库移除"入口
- [x] 4.3 工具栏 / 提示区加"清理失效曲目"入口（仅在存在失效曲目时可见）

## 5. 验证

- [x] 5.1 `swift build` 通过；`Scripts/bundle.sh` 可出包
- [ ] 5.2 手动验证：删除已导入文件 → 启动标记失效、双击 toast 跳过、上一首向前跳、整库删除后干净停止、重新定位修复同目录、清理批量移除
