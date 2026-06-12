## Context

当前 `AppState` 在没有持久化曲库时回退到 `SampleData.albums`、`SampleData.songs` 和 `SampleData.playlists`，因此首次启动会显示虚拟歌曲与歌单。导入能力已经集中在 `AppState.importViaPanel()` 与 `AppState.importFiles(_:)`：前者打开多选文件面板，后者过滤支持的音频扩展名、去重、解析元数据、追加到 `library` 并持久化。

内容区头部的 `+` 按钮位于 `LibraryContentView.ContentHeader`，当前直接调用 `app.importViaPanel()`。本变更需要把这个单一动作改为二级菜单，并为目录导入增加文件收集入口，同时保持现有导入管线的去重、元数据解析、toast 和持久化行为。

## Goals / Non-Goals

**Goals:**

- 首次启动没有持久化曲库时显示空资料库，而不是虚拟示例歌曲和歌单。
- 将右上角 `+` 改为菜单，提供“导入文件”和“导入文件夹”两个入口。
- 文件导入继续支持多选音频文件。
- 文件夹导入扫描所选目录中的受支持音频文件，并将这些文件加入歌曲列表。
- 复用现有导入处理，保持扩展名过滤、重复路径跳过、不可解码文件跳过、元数据解析和导入结果提示一致。

**Non-Goals:**

- 不引入递归扫描子目录，除非规格阶段明确要求。
- 不新增播放器、队列、歌单管理或元数据编辑能力。
- 不改变已存在用户持久化曲库的结构或清空用户已有数据。
- 不移除 `SampleData.swift` 文件本身，除非实现阶段确认没有任何测试或预览依赖它。

## Decisions

### 1. 首次启动使用空曲库作为默认状态

当 `library.json` 不存在或无法解码时，`AppState.init()` 应初始化为空数组：`albums = []`、`library = []`、`playlists = []`。这样可以直接暴露真实空状态，并让用户通过导入建立自己的资料库。

选择该方案是因为需求是“删除虚拟数据”，而不是只隐藏虚拟数据。替代方案是保留 `SampleData` 作为开发预览或调试开关，但这会让运行时默认状态继续依赖虚构内容，容易与需求冲突。

### 2. `+` 按钮使用 SwiftUI `Menu` 承载二级动作

将当前 `ToolButton(systemName: "plus")` 替换为视觉尺寸一致的菜单按钮，菜单项包括：

- `导入文件...`：调用现有文件选择入口。
- `导入文件夹...`：调用新的目录选择入口。

选择 `Menu` 是因为它是 macOS SwiftUI 的标准菜单交互，适合少量二级动作，也能保持右上角工具区结构稳定。替代方案是自定义 popover，但当前只需要两个命令，自定义 popover 会增加状态和焦点处理复杂度。

### 3. 目录导入只负责收集 URL，导入仍走 `importFiles(_:)`

新增 `AppState.importFolderViaPanel()` 打开 `NSOpenPanel`，设置 `canChooseDirectories = true`、`canChooseFiles = false`、`allowsMultipleSelection = false`。用户确认后，使用 `FileManager` 读取目录直接子项，筛选出普通文件 URL，再交给 `importFiles(_:)`。

选择复用 `importFiles(_:)` 是为了避免目录导入和文件导入在支持格式、去重、解码校验、元数据解析、toast 文案和持久化行为上分叉。替代方案是在目录导入中单独处理过滤和追加，但会复制已有逻辑并增加行为不一致风险。

### 4. 支持格式继续以扩展名集合为第一层过滤

目录扫描使用现有 `AppState.audioExtensions` 作为快速过滤依据，继续覆盖 `mp3`、`m4a`、`flac`、`wav`、`aac`、`ogg`、`aiff`。后续仍由 `AVAudioPlayer` 和 `AVURLAsset` 做可解码校验与元数据读取。

选择扩展名过滤是因为当前文件导入已经按该集合工作，目录导入应保持一致。替代方案是仅依赖 `UTType.audio`，但从目录枚举得到的 URL 类型推断在边界文件上不如显式扩展名规则可控。

## Risks / Trade-offs

- [Risk] 用户之前从未保存过曲库时，升级后会看到空资料库而不是示例内容。→ Mitigation: 这是本变更的目标行为；保留空状态提示，引导拖入或通过 `+` 菜单导入。
- [Risk] 目录中包含大量文件时，主线程枚举和导入可能造成短暂卡顿。→ Mitigation: 本次仅扫描直接子项并复用当前异步导入流程；如后续需要递归或超大目录，再引入后台扫描进度。
- [Risk] 不递归扫描可能不符合部分用户对“选择目录”的直觉。→ Mitigation: 在规格中明确目录导入范围；若产品希望包含子目录，应在 specs 中补充递归要求。
- [Risk] 保留 `SampleData.swift` 可能让代码中仍存在虚拟数据。→ Mitigation: 实现阶段应移除运行时引用；是否删除文件取决于是否还有预览或测试依赖。

## Migration Plan

1. 修改 `AppState.init()` 的无持久化数据分支，默认初始化为空数组。
2. 保持既有 `library.json` 解码逻辑不变，确保已有用户曲库继续加载。
3. 新增目录选择入口与目录 URL 收集逻辑。
4. 调整 `ContentHeader` 的 `+` 控件为菜单，并连接文件与目录两个导入动作。
5. 验证首次启动空状态、文件导入、目录导入、重复路径导入和无有效音频文件提示。

Rollback 策略：若需要恢复示例数据，仅回退 `AppState.init()` 默认分支和 `+` 菜单改动，不需要迁移持久化文件。

## Open Questions

- 目录导入是否应递归包含子目录？当前设计按直接子项处理。
- 目录导入是否允许一次选择多个目录？当前设计按单目录处理。
