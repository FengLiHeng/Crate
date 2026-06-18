## 1. 待播去重

- [x] 1.1 修改 `PlayerStore.playFrom`，重建播放上下文时按歌曲 id 保序去重。
- [x] 1.2 修改 `playNextSong` 与 `addToQueue`，加入插播前移除同一歌曲在插播队列和后续上下文中的旧位置。
- [x] 1.3 恢复播放记忆时清理旧插播队列中的重复项。

## 2. 验证

- [x] 2.1 增加单元测试覆盖播放入口、下一首播放和待播清单插入去重。
- [x] 2.2 运行 `swift test`。
- [x] 2.3 运行 `swift build`。
- [x] 2.4 运行 `openspec validate dedupe-play-queue`。
- [x] 2.5 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
