## Context

Crate 目前通过 `Scripts/bundle.sh` 生成 `build/Crate.app`，并按 GitHub Release 约定上传 `Crate-vX.Y-macOS-arm64.zip`。应用自身没有更新入口，用户只能离开应用去 GitHub 手动下载。

GitHub latest release API 可在公开仓库无需认证读取最新正式 release，响应里包含 `tag_name`、`html_url`、`body` 和 assets 的 `browser_download_url`。当前发布包是单一 arm64 macOS zip，因此 OTA 可以围绕该资产约定实现。

## Goals / Non-Goals

**Goals:**
- 提供应用内“检查更新”命令，读取最新正式 GitHub Release。
- 使用当前 bundle 的 `CFBundleShortVersionString` 与 release tag 做语义版本比较。
- 选择符合 `Crate-*-macOS-arm64.zip` 约定的 release asset，下载后解压并替换当前 `.app`。
- 在网络、资产缺失、解压、校验或写入失败时用中文状态反馈解释原因。

**Non-Goals:**
- 不在本变更中引入 Sparkle、appcast 或独立签名密钥管理。
- 不支持增量更新、后台静默安装或自动提权安装到受保护目录。
- 不改变现有 GitHub Release 发布流程和资产命名约定。

## Decisions

1. 使用 GitHub REST latest release API，而不是列出所有 releases。
   - 理由：需求只需要正式最新版；该端点已经过滤 draft 和 prerelease，公开仓库可无认证访问。
   - 备选：列出 releases 后本地筛选。该方案更复杂，也更容易和 GitHub 的 latest 语义不一致。

2. 以 bundle 版本和 release tag 做本地语义比较。
   - 理由：`Scripts/bundle.sh` 已经写入 `CFBundleShortVersionString`，这是用户正在运行的版本事实来源。
   - 备选：使用 `CFBundleVersion`。该值是构建号，不能直接对应 `v1.x` release tag。

3. 手写轻量更新器，不引入 Sparkle。
   - 理由：当前仓库没有外部依赖，已有发布包也不是 Sparkle appcast 形态；引入 Sparkle 还需要额外签名和发布管线改造。
   - 备选：Sparkle 是更成熟的 macOS 自动更新方案，但本次目标是直接对接现有 GitHub Release OTA。

4. 安装前校验解压出的 `.app`。
   - 理由：仅凭下载 URL 不足以确认包内容。安装前必须确认包内 `CFBundleIdentifier` 与当前应用一致，且版本等于待安装 release 版本。
   - 备选：下载后直接替换。该方案风险更高，错误资产会破坏当前安装。

## Risks / Trade-offs

- 手写替换流程不具备 Sparkle 的完整签名校验和权限处理能力。→ 仅从 HTTPS GitHub Release 下载，校验资产命名、bundle identifier 和版本；写入不可用时停止并提示用户。
- 应用正在运行时无法直接覆盖自身 bundle。→ 下载和校验在应用内完成，替换交给退出后启动的短生命周期安装脚本执行。
- GitHub API 存在速率限制或网络失败。→ 更新检查保持用户触发，失败时不影响播放器主流程。
- 未来发布 universal 或 x86_64 资产时选择规则需要扩展。→ 资产选择集中在更新服务中，优先按当前架构和命名约定评分。
