## Context

Crate 是 macOS SwiftUI 应用，入口 `CrateApp` 持有单一 `AppState` 实例，并通过 environment 注入视图树。播放状态和控制语义集中在 `PlayerStore`：`togglePlay()`、`prev()`、`next()` 已被底部播放条和键盘快捷键复用。

macOS Dock 栏右键菜单属于 AppKit 层能力，需要通过 `NSApplicationDelegate.applicationDockMenu(_:)` 或等效机制提供 `NSMenu`。SwiftUI `App` 生命周期可以用 `@NSApplicationDelegateAdaptor` 接入 AppKit delegate，但 delegate 需要能访问当前 `AppState` 或至少访问 `PlayerStore`。

## Goals / Non-Goals

**Goals:**

- 在 Dock 栏右键菜单中提供上一首、播放/暂停、下一首。
- 菜单项状态与当前播放状态同步：有当前曲目时启用控制项，播放中显示“暂停”，暂停或恢复态显示“播放”。
- Dock 菜单动作复用 `PlayerStore` 的既有方法，保持与播放条和快捷键一致的切歌、队列、循环、失效曲目跳过语义。
- 保持实现范围局部，不改变曲库、播放队列、持久化或音频引擎模型。

**Non-Goals:**

- 不新增菜单栏状态项、媒体键集成或 Now Playing Center 集成。
- 不在 Dock 菜单中显示当前曲目信息、进度、音量、随机或循环模式。
- 不改变无当前曲目时播放按钮无法启动播放的既有语义。

## Decisions

### D1: 使用 `NSApplicationDelegate` 提供 Dock 菜单

在 `CrateApp` 中通过 `@NSApplicationDelegateAdaptor` 注册一个轻量 `CrateAppDelegate`，实现 `applicationDockMenu(_:) -> NSMenu?`。

原因：Dock 右键菜单是 AppKit API，使用 delegate 是系统原生入口，避免在 SwiftUI 视图层构造无法被 Dock 使用的菜单。

替代方案：在 SwiftUI `Commands` 中添加命令。该方案适合主菜单和快捷键，但不能直接覆盖 Dock 右键上下文菜单，因此不采用。

### D2: 通过显式绑定把 `AppState` 提供给 delegate

`CrateApp` 创建 `AppState` 后，在窗口内容出现时将该实例传给 `CrateAppDelegate`，delegate 内部以弱引用保存。

原因：`CrateApp` 已经是全局状态所有者；让 delegate 调用同一个 `AppState.player` 可以避免创建第二套播放状态。弱引用可避免 AppKit delegate 与应用状态之间形成不必要的生命周期绑定。

替代方案：引入全局 singleton 或 NotificationCenter 命令总线。前者会扩大状态所有权边界，后者会让简单同步命令变得间接且难以验证，因此不采用。

### D3: Dock 菜单每次请求时动态构建

`applicationDockMenu(_:)` 每次被系统请求时重新创建 `NSMenu`，根据 `player.currentSong` 和 `player.isPlaying` 设置菜单标题和启用状态。

原因：Dock 菜单打开频率低，动态构建成本很小，且能自然反映最新播放状态，不需要监听 `PlayerStore` 变化并手动维护菜单项。

替代方案：缓存 `NSMenu` 并在播放状态变化时更新。该方案需要额外观察机制，复杂度高于收益。

### D4: 菜单动作直接调用现有 `PlayerStore` 控制方法

菜单项 target 指向 `CrateAppDelegate`，action 分别调用：

- 上一首：`appState?.player.prev()`
- 播放/暂停：`appState?.player.togglePlay()`
- 下一首：`appState?.player.next()`

原因：这些方法已经承载播放条和快捷键语义。Dock 菜单只应新增入口，不应复制播放状态机逻辑。

替代方案：在 delegate 中根据当前状态自行计算切歌或播放行为。这样会产生第二套控制逻辑，容易和 `PlayerStore` 漂移，因此不采用。

### D5: 无当前曲目时禁用所有播放控制项

Dock 菜单使用 `player.currentSong != nil` 作为上一首、播放/暂停、下一首的启用条件。

原因：播放条当前也是无曲目时禁用上一首、播放、下一首；Dock 菜单应保持一致。后续如果引入“从资料库第一首开始播放”的全局播放语义，可以单独扩展。

## Risks / Trade-offs

- [Risk] SwiftUI `@State` 初始化的 `AppState` 与 delegate 绑定时机不正确，导致菜单动作没有状态对象 → 在窗口内容 `onAppear` 或 app 初始化路径中显式绑定，并让无绑定状态下菜单项禁用。
- [Risk] Dock 菜单标题在菜单已打开期间不会随着播放状态即时变化 → 菜单每次打开时重建，接受打开期间状态变化需要重新打开菜单才能反映。
- [Risk] AppKit action 可能不在主线程调用播放状态 → 菜单 action 中通过 `DispatchQueue.main.async` 或 `@MainActor` 包装调用，确保修改 Observable 状态发生在主线程。
- [Risk] delegate 强持有 `AppState` 可能造成生命周期不清晰 → 使用弱引用，`CrateApp` 继续作为状态所有者。

## Migration Plan

1. 新增 `CrateAppDelegate`，实现 Dock 菜单构建与三个 action。
2. 在 `CrateApp` 中注册 app delegate，并把现有 `AppState` 绑定给 delegate。
3. 复用 `PlayerStore.currentSong`、`isPlaying`、`prev()`、`togglePlay()`、`next()`，不修改播放状态机。
4. 编译验证 `swift build`，再运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。

回滚策略：移除 app delegate 注册和相关 delegate 文件/类型后，应用回到没有自定义 Dock 菜单的状态，不影响播放核心逻辑和持久化数据。

## Open Questions

- Dock 菜单项文案是否只使用“播放/暂停”，还是需要补充“上一首”“下一首”的快捷键提示；初始实现保持简洁文案。
