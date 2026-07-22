## Why

UI 调整后需要人工启动应用、切换四个展示状态、截图并核对 README，流程重复且容易受到个人曲库、主题偏好和窗口状态影响。需要提供一次命令即可重复生成稳定 README 截图的本地开发工具。

## What Changes

- 新增隔离的截图启动模式，使用固定演示曲库、播放状态与歌词，不读写用户真实数据。
- 支持浅色首页、深色首页、浅色待播清单和浅色歌词四个确定性场景。
- 新增本地脚本，构建最新 app、逐场景启动、等待渲染、截取窗口并覆盖 `docs/截图/`。
- 自动检查截图文件、尺寸一致性和 README 中的固定图片引用。
- 在 README 的本地开发说明中补充截图更新命令。

## Capabilities

### New Capabilities

- `ui-screenshot-automation`：定义隔离截图场景、自动窗口捕获、输出校验与 README 引用检查。

### Modified Capabilities

无。

## Impact

- 影响应用启动配置、`AppState` 演示数据初始化和窗口准备流程。
- 新增 `Scripts/update-screenshots.sh` 及窗口编号辅助程序。
- 更新 README 开发命令和 `docs/截图/` 下四张图片。
- 仅用于显式截图参数，不改变普通用户启动行为，不引入第三方依赖。
