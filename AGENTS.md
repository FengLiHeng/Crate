# Repository Guidelines

## Project Structure & Module Organization

本仓库是一个 macOS SwiftUI 音乐播放器。

- `src/`：应用源码。入口是 `CrateApp.swift`；全局状态、曲库和导入逻辑在 `AppState.swift`；播放相关逻辑在 `PlayerStore.swift` 与 `PlaybackEngine.swift`。
- `src/Views/`：SwiftUI 页面和可复用视图组件。
- `docs/设计材料/`：设计参考、原始 Web 原型和样式材料。
- `Scripts/bundle.sh`：本地打包脚本。
- `build/`：生成产物，不要手动编辑。

## Build, Test, and Development Commands

- `swift build`：编译 SwiftPM target，检查 Swift/SwiftUI 编译错误。
- `swift run Crate`：通过 SwiftPM 启动应用，适合本地 GUI 验证。
- `open Crate.xcodeproj`：用 Xcode 打开项目，处理签名、运行和调试。
- `Scripts/bundle.sh`：按仓库脚本生成本地 app bundle。
- 完成构建验证后应运行 `Scripts/bundle.sh`，确保最新可测试 app bundle 复制/生成到项目 `build/Crate.app`。

## Coding Style & Naming Conventions

使用 Swift 5.9+ 风格和 4 空格缩进。类型名使用 `UpperCamelCase`，属性、方法和局部变量使用 `lowerCamelCase`。优先保持 SwiftUI `View` 小而聚焦；共享状态和业务行为放在 `AppState`，避免在视图中复制状态。用户可见文案保持简体中文。

## Testing Guidelines

当前没有独立测试 target。提交前至少运行 `swift build`。涉及 UI、导入、播放或持久化时，需要手动验证：空曲库首次启动、文件导入、文件夹导入、重复路径处理、播放控制和重启后数据保留。未来新增测试 target 时，测试应聚焦具体行为并随功能一起提交。

## Commit & Pull Request Guidelines

提交信息保持简洁，描述一个逻辑变更。历史中既有 `feat:` 前缀，也有祈使句式，例如 `feat: 本地音乐播放器...`、`Add music import menu`。PR 应包含变更摘要、验证步骤；可见 UI 变更应附截图或录屏。

## GitHub Release 更新说明

GitHub Release 的更新说明面向最终用户，目标是让用户快速理解本次版本带来的体验改进。保持简洁、使用用户语言，不写开发过程、技术实现、提交信息、分支信息、构建/打包过程、校验结果或单元测试信息。

后续创建 tag 和 GitHub Release 时，更新说明统一使用以下模板；仅保留实际发生的用户可感知条目：

```md
## 更新

- <新增的用户能力或体验改进>
- <修复的用户可见问题>
```
