## Context

歌曲表格通过 AppKit pasteboard 写入自定义标识符，侧边栏通过 SwiftUI `onDrop(of:)` 声明同一类型。当前接收端使用 `UTType(rawIdentifier)!`，该初始化器是可失败的；当系统类型注册表尚未识别该标识符时，侧边栏布局即崩溃。

## Goals / Non-Goals

**Goals:**

- 自定义歌曲拖放类型在所有受支持 macOS 版本上都能安全构建。
- 写入端和接收端共享同一标识符与类型定义。
- 保持现有多选拖放载荷格式和分组去重语义。

**Non-Goals:**

- 不改变拖放 JSON 载荷结构。
- 不增加新的拖放目标或跨应用拖放行为。

## Decisions

在 `SongDragPayload` 中使用 `UTType(exportedAs:)` 定义非可选 `contentType`，并让 SwiftUI 接收端直接引用该值。`exportedAs:` 表达应用拥有此类型，且不会依赖系统动态查询结果。AppKit pasteboard 继续从同一 `contentType.identifier` 构造类型，避免两端字符串漂移。

不选择保留 `UTType(identifier)` 再做条件分支，因为那会让拖放能力在启动后静默消失，也无法从根本上表达该类型由 Crate 定义。

## Risks / Trade-offs

- [自定义类型未写入 Info.plist 导出声明] → 当前拖放只在应用内部使用，运行时 `UTType(exportedAs:)` 足以提供稳定类型对象；后续若需要跨应用互操作，再补文档类型声明。
- [模型文件新增框架导入] → `UniformTypeIdentifiers` 是 macOS 系统框架，不增加第三方依赖或部署成本。
