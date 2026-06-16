## 1. 播放会话重建

- [x] 1.1 修改 `PlayerStore.playFrom`，从当前视图发起播放时清空 `manualQueue`。
- [x] 1.2 保持 `playNextSong` 插入队头的跨分组插播行为不变。
- [x] 1.3 将右键菜单文案更新为“添加到下一首播放”。

## 2. 验证

- [x] 2.1 运行 `swift build` 验证编译通过。
- [x] 2.2 运行 `openspec validate reset-queue-on-context-play` 验证变更通过。
- [x] 2.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
