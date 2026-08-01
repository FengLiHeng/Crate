<p align="center">
  <img src="docs/logo.png" alt="Crate 应用图标" width="128">
</p>

<h1 align="center">Crate</h1>

<p align="center">一款为 macOS 打造的本地音乐播放器。</p>

<p align="center">
  <a href="https://github.com/FengLiHeng/Crate/releases">下载最新版</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#功能">功能</a>
</p>

Crate 专注于让个人曲库重新变得好用：导入文件或文件夹后，你可以在紧凑清晰的表格曲库中浏览、搜索和整理音乐，随时控制播放、待播队列与分组。它提供浅色与深色主题、动态歌词和本地持久化，不需要把音乐交给云端。

> 仅处理你选择导入的本地音乐文件；曲库与偏好保存在本机。

## 界面预览

<!-- ui-screenshots:start -->
| 浅色主题 | 深色主题 |
| --- | --- |
| ![Crate 浅色主题首页](docs/截图/浅色-首页.png) | ![Crate 深色主题首页](docs/截图/深色-首页.png) |

| 待播清单 | 动态歌词 |
| --- | --- |
| ![Crate 浅色主题待播清单](docs/截图/浅色-待播清单.png) | ![Crate 浅色主题歌词页](docs/截图/浅色-歌词.png) |
<!-- ui-screenshots:end -->

完成 UI 调整后，可运行以下命令启动最新版应用、生成四个固定场景的截图，并更新上面的预览区块：

```bash
Scripts/update-screenshots.sh
```

首次运行时，macOS 可能会要求为终端或 Codex 授予“屏幕与系统音频录制”权限。

## 功能

- **本地曲库**：导入音频文件，或登记多个音乐文件夹并递归扫描；重新扫描会同步新增、移动、修改和删除的歌曲。
- **高效浏览**：表格曲库、实时搜索、标题/艺人/专辑/添加时间排序，以及失效文件的重新定位和批量清理。
- **自由整理**：使用 Command/Shift 多选歌曲，批量收藏、加入待播或拖放到普通分组。
- **完整播放控制**：播放/暂停、上下首、进度与音量调节、随机播放、循环模式，并支持 macOS 控制中心、媒体键和耳机控制。
- **待播清单**：清楚区分当前播放、即将插播与后续曲目，支持拖动或 VoiceOver 调整播放顺序。
- **歌词体验**：自动读取同名 `.lrc`，歌词跟随进度高亮滚动；点击歌词即可跳转播放位置。
- **封面回退**：没有内嵌封面时，可读取同目录同名 `.jpg`、`.jpeg`、`.png` 或 `.webp` 图片。
- **桌面化外观**：暖白收藏目录风格与石墨器材面板风格两套主题，选择会自动保留。

## 歌词与封面文件

Crate 使用音乐文件旁的 sidecar 文件，不会复制或改动你的歌词与封面文件。

```text
Music/
  少女的祈祷 - 杨千嬅.mp3
  少女的祈祷 - 杨千嬅.lrc
  少女的祈祷 - 杨千嬅.jpg
```

- 歌词文件使用同名 `.lrc`；补放歌词后无需重新导入歌曲。
- 封面可使用同名 `.jpg`、`.jpeg`、`.png` 或 `.webp`。
- 支持标准 LRC 时间戳、单行多个时间戳和 `[offset:+/-毫秒]`。
- 文件内缺少艺术家时，会识别 `歌曲 - 歌手` 形式的文件名作为补充信息。

## 快速开始

### 使用应用

从 [GitHub Releases](https://github.com/FengLiHeng/Crate/releases) 下载最新的 macOS 应用，首次打开后导入音乐文件或音乐文件夹即可开始使用。

添加音乐文件夹后，Crate 只记录原始位置，不会复制或修改其中的文件。应用启动时会在后台增量扫描，也可以从资料库右上角的更多菜单手动重新扫描或管理来源。

### 本地开发

```bash
# 编译
swift build

# 启动应用
swift run Crate

# 生成可测试的 app bundle
Scripts/bundle.sh
```

打包后的应用位于 `build/Crate.app`。如需处理签名或调试，可运行 `open Crate.xcodeproj`。

## 项目结构

```text
src/
  CrateApp.swift          应用入口
  AppState.swift          曲库、导入、歌词、分组与持久化
  PlayerStore.swift       播放状态、上下文与待播队列
  PlaybackEngine.swift    AVAudioPlayer 播放封装
  Views/                  SwiftUI 页面与组件

Scripts/bundle.sh         生成 build/Crate.app
Scripts/update-screenshots.sh  自动生成 README 界面截图
docs/截图/                README 界面截图
docs/logo.png             README 与应用图标源图
openspec/                 产品规格与变更记录
```

## 技术栈

Swift 5.9+ · SwiftUI · AVFoundation · Swift Package Manager · XCTest · OpenSpec

## 贡献与验证

欢迎通过 Issue 或 Pull Request 提出建议。涉及行为变更时，请同步维护 OpenSpec 变更；提交前至少运行：

```bash
swift test
swift build
Scripts/bundle.sh
```
