## Context

`CrateApp.init()` 会在 SwiftUI 完成 `NSApplication` 建立前创建 `AppState`。系统主题的初始解析直接读取全局 `NSApp`；该符号是隐式解包可选值，在这一生命周期阶段为 `nil`，因此 Release 应用在进入首个窗口前崩溃。

## Goals / Non-Goals

**Goals:**

- 系统主题模式能够在应用生命周期最早阶段安全解析当前 macOS 外观。
- 保留首帧主题正确和后续系统外观变化同步。
- 用真实打包应用启动验证覆盖崩溃路径。

**Non-Goals:**

- 不改变主题菜单或持久化格式。
- 不调整浅色、深色视觉令牌。

## Decisions

1. 使用 `NSApplication.shared.effectiveAppearance` 取得当前外观。`shared` 会安全返回或创建应用单例，避免直接解包尚为空的 `NSApp`，同时仍可在 `AppState` 初始化时得到真实系统外观。
2. 保留 SwiftUI 环境 `colorScheme` 的运行时同步逻辑；本次只修复首帧初始化路径。
3. 除 Debug/Release 编译外，直接启动新生成的 `.app` 并观察进程存活，覆盖报告中的真实生命周期顺序。

## Risks / Trade-offs

- [初始化阶段显式访问共享应用对象会提前建立单例] → 这是 AppKit 支持的访问方式，且应用启动本就需要该单例；相比直接访问 `NSApp` 不存在空值风险。
- [仅编译无法发现生命周期崩溃] → 增加真实 bundle 冷启动检查。
