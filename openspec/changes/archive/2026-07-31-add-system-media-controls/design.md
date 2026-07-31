## Context

`PlayerStore` 是播放状态与命令语义的唯一来源，但目前没有向 macOS MediaPlayer 框架发布状态。`AppState` 负责解析歌曲关联的专辑、艺人与封面，应用代理已经持有 `AppState` 的弱引用并提供 Dock 菜单控制。系统媒体回调可能不在主线程，而播放状态必须在主线程访问。

## Goals / Non-Goals

**Goals:**

- 以独立组件将 `AppState`/`PlayerStore` 状态映射为系统正在播放快照。
- 将系统媒体命令转发至 `PlayerStore` 既有方法。
- 让发布与命令路由逻辑可使用内存后端测试。
- 无曲目或组件释放时清理系统残留状态。

**Non-Goals:**

- 不更改播放队列、上一首/下一首或跳转的既有语义。
- 不添加联网元数据、系统通知或锁屏自定义界面。
- 不修改音频会话或播放引擎。

## Decisions

1. 新增 `SystemMediaControls` 协调器和 `SystemMediaControlsBackend` 抽象。协调器负责状态观察与命令语义，MediaPlayer 后端只负责框架字典和 `MPRemoteCommandCenter` 适配。相比直接将 MediaPlayer 代码放入 `PlayerStore`，该方式减少共享文件冲突并能隔离测试。
2. 使用 Observation 的一次性追踪机制反复注册状态观察。快照读取当前歌曲、关联专辑、封面、时长、进度和播放状态；变化后在主线程重新发布，无需在 `PlayerStore` 各状态写入点增加回调。
3. 系统命令通过枚举统一表达。播放和暂停先检查当前状态，仅在需要转换时调用 `togglePlay()`；切换、上下曲和跳转分别调用现有方法。无当前歌曲时协调器拒绝命令，后端同时禁用命令。
4. 由 `CrateAppDelegate` 持有协调器，在绑定 `AppState` 时启动，在应用终止和对象释放时停止。这样系统集成与应用生命周期一致，且不改变持久化模型。

## Risks / Trade-offs

- [进度更新会频繁触发系统发布] → 仅生成轻量值快照，并让后端缓存封面对象，避免每次重建图像。
- [MediaPlayer 回调线程不确定] → 后端仅解析事件并调度到主线程，所有 `PlayerStore` 访问均保持主线程隔离。
- [系统命令到主线程存在极短异步延迟] → 回调立即返回成功，实际状态随后由观察器重新发布，符合系统媒体控制交互模型。
