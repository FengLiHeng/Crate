## Why

当前 OTA 只校验可被修改的 bundle 标识与版本，无法发现下载损坏或 Release 资产错配；同时播放状态机和歌曲/队列交互仍有几个会让用户卡住或无法操作的缺口。应用为本地自用且没有 Apple Developer ID，因此需要在信任自有 GitHub 仓库的前提下，用无需 Apple 签名的完整性校验和可测试的交互修复收敛这些问题。

## What Changes

- OTA 仅接受符合固定 GitHub Release 路径和精确命名的资产，并使用 GitHub API 返回的 SHA-256 digest 与文件大小校验下载结果。
- 安装前继续校验 bundle identifier 与版本，同时明确该方案信任 `FengLiHeng/Crate` GitHub 仓库，不声称替代 Apple Developer ID 签名。
- 修复“上一首”连续遇到失效曲目时停留在不可播放曲目的状态机错误，并补充边界回归测试。
- 让歌曲行尾“更多”按钮真正打开与右键一致的菜单。
- 为待播项提供稳定的移除入口和 VoiceOver 可发现的播放、移除动作。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `app-update`: 增加 Release 资产来源、精确命名、SHA-256 digest 和文件大小完整性校验要求。
- `playback`: 明确向后跳过失效曲目到达边界时不得停留在失效曲目。
- `play-queue`: 增加待播项播放与移除操作的辅助功能要求。

## Impact

- 更新 `src/AppUpdateService.swift`、`src/PlayerStore.swift`、`src/Views/SongTableView.swift` 与 `src/Views/QueuePanelView.swift`。
- 扩充 `Tests/CrateTests/AppUpdateServiceTests.swift` 与 `Tests/CrateTests/PlayerStoreTests.swift`。
- 不引入第三方依赖，不要求 App Store、Apple Developer ID 或公证流程。
