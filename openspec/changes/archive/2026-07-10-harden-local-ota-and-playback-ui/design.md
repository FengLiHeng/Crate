## Context

Crate 通过公开 GitHub Release 提供 `Crate-vX.Y-macOS-arm64.zip`，应用直接下载、解压并替换当前 bundle。项目是本地自用应用，没有 Apple Developer ID；现有产物只有临时 adhoc/linker 签名，因此不能用 Team ID 或 Apple 公证链验证更新。GitHub Release API 已为资产返回 `size` 与 `digest`（`sha256:<hex>`），当前 v2.0 资产也具备这两项元数据。

播放状态机在向后跳过失效曲目时会先覆盖当前曲目；若一路到达上下文开头，现有边界分支会对已经失效且没有引擎的曲目执行 seek。歌曲表格和待播清单另有鼠标入口与规格/辅助功能语义不一致的问题。

## Goals / Non-Goals

**Goals:**

- 在不依赖 Apple 签名的情况下发现下载损坏、错误资产与内容替换。
- 明确并最小化 OTA 的信任边界：只信任 `FengLiHeng/Crate` 的 HTTPS GitHub Release 元数据与资产。
- 让上一首的失效曲目跳过逻辑在边界处恢复有效状态。
- 让“更多”、待播播放和待播移除入口对鼠标、键盘与 VoiceOver 一致可用。

**Non-Goals:**

- 不抵御 GitHub 账号或仓库发布权限本身被攻破；digest 与资产来自同一受信 GitHub 边界。
- 不引入 Apple Developer ID、App Store、公证、Sparkle 或第三方依赖。
- 不改变正常歌曲的播放队列、循环或搜索语义。

## Decisions

### D1: 使用 GitHub API 的 SHA-256 digest 和 size

应用只在资产具有合法的 `sha256:<64 hex>` digest 和正数 size 时提供安装。下载完成后先比较文件大小，再分块计算 SHA-256 并做常量语义的完整字符串比较；不匹配时停止解压和替换。

采用系统 `CryptoKit`，因为 macOS 14 已内置且无需新增依赖。相比自行在 Release 描述中维护校验值，GitHub 资产 digest 不需要额外发布步骤，也避免文案与文件不同步。

### D2: 资产来源与名称使用精确匹配

兼容资产必须精确命名为 `Crate-<tag>-macOS-<arch>.zip`，初始下载 URL 必须为 `https://github.com/FengLiHeng/Crate/releases/download/<tag>/<asset>`。不再使用包含关键字的评分选择，避免备份包、调试包或相似名称被误选。URLSession 重定向后的最终响应仍必须使用 HTTPS。

### D3: 向后搜索保存原有效播放回退点

用户从有效上下文曲目触发上一首时，状态机记录原曲目 id 与上下文位置。向后候选成功接管播放后清除回退点；若所有更早候选均失效，则恢复原曲目并从头播放，而不是停留在最后一个失效候选。若原曲目也失效，现有访问集合继续防止循环并最终安全停止。

### D4: 使用原生 Menu 和稳定队列动作

歌曲行尾使用 SwiftUI `Menu` 复用 `SongContextMenu`，保证点击与右键内容一致。待播移除按钮在可移除行中始终存在，仅调整普通/悬停视觉强度；行继续保留双击播放，并补充命名的辅助功能播放与移除动作。

## Risks / Trade-offs

- [Risk] GitHub 账号被攻破时攻击者可以同时替换资产和 digest。→ Mitigation：明确接受自用场景的 GitHub 信任边界；未来若威胁模型变化，再引入离线公钥签名。
- [Risk] 历史 Release 缺少 digest 时无法 OTA。→ Mitigation：停止安装并给出中文提示，用户仍可从 GitHub 手动下载；当前 v2.0 已验证包含 digest。
- [Risk] 向后回退需要重新构造当前曲目引擎。→ Mitigation：复用 `startPlaying` 和 play token，避免旧异步引擎接管。
- [Risk] 待播移除按钮常驻会轻微改变视觉密度。→ Mitigation：非悬停状态使用较弱透明度，保持可发现但不抢占标题信息。
