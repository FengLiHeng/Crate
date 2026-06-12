# Design: local-music-player

## Context

设计材料位于 `docs/设计材料/`：`本地音乐播放器.html` 是入口，`tokens.css` / `player.css` 定义视觉规范（OKLCH 颜色、间距、圆角、阴影、浅深双主题），`player-app.jsx` / `player-views.jsx` / `player-ui.jsx` 是完整的交互参考实现（React），`music-data.js` 是示例曲库。仓库目前为空，无既有代码约束。

目标平台由用户指定：**Swift 原生 macOS 应用，仅适配 Apple Silicon（arm64）**。

## Goals / Non-Goals

**Goals:**

- 以 SwiftUI 还原设计稿的布局、视觉与交互：侧边栏、歌曲表格、播放条、待播清单面板、右键菜单、toast、拖拽导入遮罩
- 真实音频播放（导入的本地文件），完整的队列/随机/循环语义与设计稿参考实现一致
- 浅色/深色主题手动切换并持久化
- 曲库与播放列表的增删改持久化，重启后保留

**Non-Goals:**

- 不支持 Intel（x86_64）构建
- 不做 iCloud / 网络同步、流媒体、歌词、均衡器
- 不做曲库文件夹监听（只支持显式导入）
- 不上架 App Store（不做公证/签名流程）

## Decisions

### D1: UI 框架 — SwiftUI，最低 macOS 14（Sonoma）

- **选择**：SwiftUI + Observation 框架（`@Observable`）。
- **理由**：设计稿是组件化声明式 UI，SwiftUI 映射成本最低；macOS 14 起 `@Observable` 取代 ObservableObject，状态管理更接近参考实现里的 React state 模型。M 系列芯片机型全部支持 macOS 14+，与 arm64-only 约束自洽。
- **备选**：AppKit（还原像素更可控但开发量大）；Electron/Tauri（违背用户指定技术栈）。

### D2: 工程形态 — Swift Package Manager + 应用打包脚本

- **选择**：SwiftPM `executableTarget` 组织源码，`swift build` 可直接编译；提供 `Scripts/bundle.sh` 把产物组装成 `Crate.app`（拷贝二进制 + Info.plist + 图标）。仓库不提交 `.xcodeproj`。
- **理由**：纯 CLI 可构建、可 CI、diff 友好；Xcode 用户仍可直接 `open Package.swift`。
- **备选**：XcodeGen/Tuist（引入额外工具依赖）；手工维护 xcodeproj（merge 噩梦）。
- **构建参数**：`--arch arm64`；不开启 App Sandbox（见 D6）。

### D3: 播放引擎 — AVAudioPlayer，示例曲目降级为模拟播放

- **选择**：`AVAudioPlayer`（AVFoundation）播放导入的真实文件，delegate 回调驱动自动切歌；Core Audio 原生支持 MP3/M4A/AAC/WAV/AIFF/FLAC。
- **示例曲目**：`music-data.js` 移植的 25 首示例曲目没有音频文件——对这些曲目使用定时器模拟进度（与设计稿行为一致），保证应用开箱即有内容可演示；导入的真实文件走真实播放。`Song` 模型用 `fileURL: URL?` 区分两种来源，播放引擎按是否有 URL 选择实现。
- **备选**：AVPlayer（为流媒体设计，此处过重）；AVAudioEngine（需要自行管理图，超出需求）。

### D4: 状态架构 — 两个 @Observable Store（MVVM）

- **选择**：
  - `LibraryStore`：曲库、播放列表、搜索、导入、删除（对应参考实现的 library/playlists/search 状态）
  - `PlayerStore`：当前曲目、播放上下文 `ctx(ids/originalIds/pos)`、插播队列 `manualQueue`、shuffle/repeat/volume/progress（对应 player-app.jsx 的播放状态机）
- **理由**：参考实现的状态划分已被验证可行，直接平移降低行为偏差风险；队列语义（插播优先、插播结束回到上下文、shuffle 重排保持当前曲目在首位等）严格照搬 player-app.jsx 的逻辑。
- **备选**：单一 AppStore（耦合大）；SwiftData 驱动 UI（播放瞬态不适合入库）。

### D5: 设计令牌映射 — tokens.css → Theme.swift 常量

- **选择**：把 `tokens.css` 的 OKLCH 颜色预先换算为 sRGB，生成 `Theme.swift`（颜色/字号/间距/圆角常量，按浅/深两套组织）。主题为应用内手动切换（非跟随系统），存 UserDefaults（键 `lmp-theme`，与设计稿 localStorage 键名对齐）。
- **理由**：设计稿主题是显式按钮切换并持久化，跟随系统会偏离设计行为；预换算避免运行时 OKLCH 转换。
- **备选**：Asset Catalog 颜色（跟随系统外观，与设计行为不符）。
- **专辑封面**：设计稿用 OKLCH 双色渐变（h1/h2 色相）生成封面，SwiftUI 用 `LinearGradient` 等价还原。

### D6: 持久化与文件访问 — JSON + 不开沙盒

- **选择**：曲库/播放列表序列化为 JSON 存 `~/Library/Application Support/Crate/`；主题、音量等偏好存 UserDefaults。应用**不启用 App Sandbox**，导入文件直接记录绝对路径。
- **理由**：不上架 App Store；不开沙盒可免去 security-scoped bookmark 的复杂度，重启后仍可访问导入文件。
- **备选**：SwiftData（模型简单，杀鸡用牛刀）；开沙盒 + bookmark（仅在未来需要公证分发时再迁移）。
- **风险承担**：用户移动/删除源文件后条目失效，播放时检测文件不存在则 toast 提示。

### D7: 窗口外壳 — 原生隐藏式标题栏，不绘制假红绿灯

- **选择**：`.windowStyle(.hiddenTitleBar)` + 全尺寸内容视图，原生交通灯按钮悬浮于侧边栏左上（与设计稿位置一致），侧边栏材质用 `.ultraThinMaterial` 近似设计稿的毛玻璃。
- **理由**：设计稿里的红绿灯是 Web 演示的模拟物；原生应用应使用真实窗口控件，行为（关闭/最小化/全屏）免费获得。
- **备选**：完全自绘窗口 chrome（可访问性与系统行为损失大）。

### D8: 交互细节对齐参考实现

- 右键菜单用 SwiftUI `contextMenu`（含"添加到播放列表"子菜单）；菜单项与 player-views.jsx 一致，"在 Finder 中显示"对真实文件调用 `NSWorkspace.activateFileViewerSelecting`，示例曲目弹 toast
- 快捷键：空格播放/暂停（焦点在搜索框时不拦截）、⌘+→ 下一首
- 拖拽导入：`onDrop` of `.fileURL`，全窗口遮罩样式照搬 `.drop-overlay`
- 上一首语义：进度 >3 秒或当前为插播曲目时回到曲首，否则退到上一曲（照搬参考实现）
- 元数据：导入时用 `AVURLAsset.load(.commonMetadata, .duration)` 异步读取标题/艺人/时长，缺失时回退文件名 + "未知艺人"

## Risks / Trade-offs

- [OKLCH→sRGB 手工换算引入色差] → 换算脚本/工具统一生成，浅深两套全量核对关键色（accent、背景、文字三级）
- [SwiftUI Table/List 还原设计稿表格样式受限] → 不用原生 `Table`，用 `LazyVStack` 自绘行（hover、选中、当前播放态均为自定义样式），列表规模（几百首）下性能可接受
- [示例曲目模拟播放 与 真实播放并存，状态机有两条路径] → 抽象 `PlaybackEngine` 协议，`AVAudioPlayerEngine` 与 `SimulatedEngine` 实现同一接口，PlayerStore 只面向协议
- [不开沙盒导致未来无法直接公证分发] → 接受；若需分发再加沙盒与 bookmark（D6 已留迁移说明）
- [FLAC 个别编码变体 AVAudioPlayer 不支持] → 导入时尝试创建 player 校验可解码，失败的文件 toast 提示并跳过

## Migration Plan

全新代码，无迁移。回滚 = 删除新增目录。

## Open Questions

- 应用图标暂缺设计稿，先用占位图标（后续可单独出图）
- 示例曲目是否提供"一键清空示例数据"入口——暂不做，删除操作已可逐条移除
