# Proposal: local-music-player

## Why

Crate 目前是空仓库，需要按照 `docs/设计材料/` 下的设计稿（入口为 `本地音乐播放器.html`）落地一个 macOS 原生本地音乐播放器。设计材料给出完整的视觉规范（design tokens、player.css）和交互参考实现（React JSX），本变更负责将其实现为 Swift 原生 macOS 应用（仅适配 Apple Silicon / M 系列芯片）。

## What Changes

- 新建 Swift 原生 macOS 应用（SwiftUI，arm64-only），视觉与交互还原设计稿
- 实现整体布局：侧边栏（资料库 + 播放列表）、内容区（歌曲表格）、底部播放条、可收起的待播清单面板；浅色/深色双主题
- 实现真实音频播放（AVFoundation）：播放/暂停、上一首/下一首、进度拖动、音量、随机播放、循环模式（关/列表/单曲）、播放结束自动切歌
- 实现待播队列：插播（下一首播放）、添加到待播清单、队列面板查看/双击播放/移除/清空
- 实现曲库与播放列表：示例曲库数据、歌单视图、搜索（标题/艺术家/专辑）、右键菜单（立即播放、插播、加入歌单、在 Finder 中显示、从资料库删除）
- 实现导入：文件选择面板或拖拽音频文件（MP3/M4A/FLAC/WAV/AAC 等）导入资料库，读取真实元数据与时长
- 主题选择持久化（UserDefaults）
- 键盘快捷键：空格播放/暂停、⌘+→ 下一首

## Capabilities

### New Capabilities

- `app-shell`: 应用窗口外壳、侧边栏导航、主题切换与持久化、toast 提示、整体布局
- `music-library`: 曲库与播放列表浏览、歌曲表格、搜索过滤、右键菜单与歌曲操作（含从资料库删除、在 Finder 中显示）
- `playback`: 真实音频播放控制（播放/暂停/上下首/进度/音量/随机/循环）与底部播放条
- `play-queue`: 插播队列与待播清单面板（查看、插播、追加、移除、清空、双击跳播）
- `library-import`: 文件选择与拖拽导入音频文件，解析元数据并入库

### Modified Capabilities

（无 —— 本仓库尚无既有规格）

## Impact

- **新增代码**：Xcode / SwiftPM 工程（SwiftUI 视图、播放引擎、数据模型、示例数据），目录结构在 design.md 中确定
- **技术栈**：Swift + SwiftUI + AVFoundation；构建目标仅 arm64（Apple Silicon），最低系统版本在 design.md 中决策
- **设计来源**：`docs/设计材料/` 为唯一视觉与交互依据（tokens.css、player.css、player-*.jsx、music-data.js、macos-window.jsx），CSS design tokens 需映射为 Swift 颜色/字号/间距常量
- **与设计稿的差异**：设计稿为模拟播放进度的 Web 演示；原生版使用 AVFoundation 真实播放，示例曲目无音频文件时仅作 UI 展示（具体策略在 design.md 中决策）
- **无后端**：纯本地应用，数据持久化方式（UserDefaults/JSON/SwiftData）在 design.md 中决策
