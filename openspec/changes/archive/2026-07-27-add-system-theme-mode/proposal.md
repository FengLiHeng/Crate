## Why

当前应用只支持手动切换浅色与深色主题，无法随 macOS 外观自动变化。增加常见的“系统 / 浅色 / 深色”三态偏好，可让用户明确选择固定外观或保持与系统一致。

## What Changes

- 将主题按钮从二态立即切换改为提供“系统 / 浅色 / 深色”三个选项。
- “系统”模式不强制颜色方案，并在系统外观变化时自动更新应用主题。
- 持久化用户选择的主题模式，重启后恢复相同模式。
- 兼容已有的浅色、深色持久化值和确定性截图场景。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `app-shell`：将主题切换与持久化要求扩展为系统、浅色、深色三态，并定义系统跟随行为。

## Impact

- 主题状态模型与偏好持久化：`src/AppState.swift`、`src/Theme.swift`
- 应用颜色方案注入：`src/CrateApp.swift`
- 内容区主题控件：`src/Views/LibraryContentView.swift`
- 现有依赖实际明暗主题的视图保持兼容
