## Context

当前 OTA 使用 `URLSession.shared.download(for:)` 一次性等待下载完成，只能显示“正在下载”。安装脚本通过 `Process.run()` 启动 `/bin/sh`，脚本内部等待 `pgrep -x Crate` 结束后再替换 app；如果子进程仍继承当前进程的 stdio 或没有脱离进程组，用户会看到“正在退出并安装更新”但 app 没有及时退出。

## Goals / Non-Goals

**Goals:**
- 下载过程中持续更新 UI，优先显示百分比和已下载/总大小。
- 没有 `Content-Length` 时显示已下载大小，避免用户误以为卡死。
- 安装脚本启动成功后立即触发当前 app 退出。
- 安装脚本脱离当前 app 进程的 stdio 和进程组，避免脚本等待 app 退出时阻塞当前进程。

**Non-Goals:**
- 不增加后台自动下载或断点续传。
- 不引入第三方更新框架。
- 不改变 release 资产命名或 GitHub Release 发布流程。

## Decisions

1. 使用 `URLSession.shared.bytes(for:)` 流式下载。
   - 理由：可以在写入临时 zip 的同时读取响应头中的 expected content length，并按收到的字节数回调 UI。
   - 备选：`URLSessionDownloadDelegate`。该方案需要引入 delegate 对象和 session 生命周期管理，当前需求用 async bytes 更直接。

2. 新增 `AppUpdateDownloadProgress` 值类型。
   - 理由：把字节数、总大小、百分比和用户可见文案集中计算，方便 UI 和测试复用。
   - 备选：直接把字符串传到 `AppState`。该方案难测试，也会把格式化散在多个层。

3. 安装脚本通过 `nohup sh script ... >/tmp/log 2>&1 &` 启动。
   - 理由：子进程脱离当前 app 的 stdio，当前 app 只需要确认命令启动成功，然后立刻终止。脚本会在 app 退出后继续执行替换和重启。
   - 备选：直接 `Process.run()` 原脚本。该方案已出现用户可感知的“等待退出但没有退出”问题。

## Risks / Trade-offs

- 服务器可能不提供总大小。→ UI 显示已下载大小和“大小未知”，仍保持活动状态。
- `nohup` 启动成功不等于安装最终成功。→ 保留安装脚本备份恢复和日志输出，安装失败不会破坏当前 app。
- 下载回调过于频繁会造成 UI 抖动。→ 只在百分比或已下载 MB 文案变化时更新可见状态。
