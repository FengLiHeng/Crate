## 1. AppKit Dock 菜单接入

- [x] 1.1 新增轻量 `CrateAppDelegate`，实现 `NSApplicationDelegate.applicationDockMenu(_:)` 并返回自定义 `NSMenu`
- [x] 1.2 在 `CrateApp` 中通过 `@NSApplicationDelegateAdaptor` 注册 app delegate
- [x] 1.3 将 `CrateApp` 持有的现有 `AppState` 显式绑定给 app delegate，避免创建第二套播放状态

## 2. Dock 播放控制实现

- [x] 2.1 在 Dock 菜单中添加“上一首”“播放/暂停”“下一首”三个播放控制项
- [x] 2.2 根据 `PlayerStore.currentSong` 设置播放控制项启用状态，无当前曲目时禁用
- [x] 2.3 根据 `PlayerStore.isPlaying` 动态显示“播放”或“暂停”
- [x] 2.4 为菜单 action 调用现有 `PlayerStore.prev()`、`togglePlay()`、`next()`，不复制播放状态机逻辑
- [x] 2.5 确保菜单 action 在主线程修改播放状态

## 3. 行为验证

- [x] 3.1 验证播放中右键 Dock 图标时菜单显示“上一首”“暂停”“下一首”且均可触发
- [x] 3.2 验证暂停或恢复播放记忆后右键 Dock 图标时菜单显示“上一首”“播放”“下一首”
- [x] 3.3 验证无当前曲目时 Dock 菜单播放控制项不可触发
- [x] 3.4 验证 Dock 菜单“下一首”优先播放插播队列头部曲目
- [x] 3.5 验证 Dock 菜单“上一首”在当前进度超过 3 秒时回到曲首而不切歌

## 4. 构建与交付检查

- [x] 4.1 运行 `swift build` 验证编译通过
- [x] 4.2 运行 `openspec validate add-dock-playback-menu` 验证变更规格有效
- [x] 4.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`
