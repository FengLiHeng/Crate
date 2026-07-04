## Why

当前应用发布依赖 GitHub Release，但用户需要手动发现、下载并替换新版本。应用内 OTA 能让用户直接从已发布的 release 获取更新，减少版本滞后和安装操作成本。

## What Changes

- 新增基于 GitHub Releases 的更新检查能力，读取 `FengLiHeng/Crate` 的 latest release 并与当前 bundle 版本比较。
- 新增应用内更新入口，用户可手动检查更新，并在发现新版本时查看版本号和发布说明摘要。
- 新增 release asset 下载与安装流程，优先使用符合当前发布约定的 `Crate-vX.Y-macOS-arm64.zip`。
- 避免对同版本或更低版本执行更新，并对网络、解析、资产缺失和安装失败给出可理解的中文反馈。

## Capabilities

### New Capabilities
- `app-update`: 应用从 GitHub Release 检查、下载并安装新版本的行为。

### Modified Capabilities

## Impact

- 影响 SwiftUI 应用入口、菜单命令、更新状态 UI 和后台网络下载逻辑。
- 需要新增 GitHub Release API 响应解析、版本比较和更新安装相关代码。
- 打包脚本继续负责写入 `CFBundleShortVersionString` 与 `CFBundleVersion`，OTA 以这些值作为当前版本来源。
