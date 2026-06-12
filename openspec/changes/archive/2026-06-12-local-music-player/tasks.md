# Tasks: local-music-player

## 1. 工程骨架（src/）

- [x] 1.1 创建 SwiftPM 工程：`Package.swift`（executableTarget `Crate`，源码目录 `src/`，macOS 14+）
- [x] 1.2 应用入口 `CrateApp.swift`：隐藏式标题栏窗口、最小尺寸、主题应用
- [x] 1.3 数据模型 `Models.swift`：`Album` / `Song` / `Playlist`（Song 含可选 fileURL 区分示例与导入曲目）
- [x] 1.4 示例数据 `SampleData.swift`：移植 music-data.js（8 专辑 / 25 歌曲 / 4 歌单）
- [x] 1.5 设计令牌 `Theme.swift`：OKLCH→sRGB 换算 + tokens.css 浅/深两套颜色常量

## 2. UI 还原（本阶段范围：仅 UI 与视图状态，不含播放/导入/持久化逻辑）

- [x] 2.1 基础组件 `Components.swift`：封面（双色渐变+音符)、歌单马赛克封面、均衡器动画、自绘滑杆、时间格式化
- [x] 2.2 应用状态 `AppState.swift`：视图切换/搜索/选中/主题/面板开关等 UI 状态（播放状态仅占位）
- [x] 2.3 侧边栏 `SidebarView.swift`：资料库/播放列表分组、选中态、交通灯留白
- [x] 2.4 内容区 `LibraryContentView.swift`：标题与统计、搜索框、+ / 主题按钮、播放与随机播放按钮
- [x] 2.5 歌曲表格 `SongTableView.swift`：六列网格、hover 播放按钮、选中/当前播放态、右键菜单（UI）、空状态
- [x] 2.6 播放条 `PlayBarView.swift`：曲目信息/控制组/进度/音量/队列开关、专辑氛围渐变、未播放占位态
- [x] 2.7 待播清单面板 `QueuePanelView.swift`：滑入滑出、三分区（正在播放/插播/接下来）、空状态
- [x] 2.8 Toast 与根布局 `RootView.swift`：整体组装、toast 显示与自动消失
- [x] 2.9 `swift build` 构建通过并启动验证 UI

## 3. 播放逻辑（后续）

- [x] 3.1 `PlaybackEngine` 协议 + `SimulatedEngine`（示例曲目）+ `AVAudioPlayerEngine`（真实文件）
- [x] 3.2 `PlayerStore` 播放语义：上下文/插播队列/随机重排/循环模式/上一首下一首规则
- [x] 3.3 自动切歌、进度同步、文件缺失降级处理
- [x] 3.4 键盘快捷键：空格播放暂停（搜索框聚焦除外）、⌘+→ 下一首
- [x] 3.5 待播清单交互接线：双击跳播、移除插播、清空队列

## 4. 曲库操作与导入（后续）

- [x] 4.1 右键菜单动作接线：立即播放/下一首播放/加待播清单/加歌单（含去重）/在 Finder 中显示/删除
- [x] 4.2 文件选择导入（NSOpenPanel）+ 拖拽导入（onDrop + 全窗口遮罩）
- [x] 4.3 元数据解析（AVURLAsset：标题/艺人/时长，缺失回退）与不可解码文件跳过
- [x] 4.4 持久化：曲库/歌单 JSON 存 Application Support，主题/音量存 UserDefaults，路径去重

## 5. 打包与验证（后续）

- [x] 5.1 `Scripts/bundle.sh`：arm64 构建并组装 `Crate.app`
- [x] 5.2 对照 specs 全量走查 40 个场景
