# Crate

Crate 是一个 macOS SwiftUI 本地音乐播放器，面向本地曲库导入、整理和播放。应用支持浅色/深色主题、底部播放控制、右侧待播清单，以及左侧音乐分组管理。

![Crate 应用图标](docs/music.png)

## 功能

- 本地音频导入：支持导入单个音频文件或文件夹。
- 曲库浏览：以表格展示歌曲标题、艺术家、专辑和时长。
- 搜索过滤：按标题、艺术家、专辑名实时搜索当前视图。
- 播放控制：支持播放/暂停、上一首/下一首、进度、音量、随机播放和循环模式。
- 待播清单：右侧面板展示当前播放、插播队列和接下来曲目。
- 音乐分组：侧边栏可创建分组，将歌曲加入分组，支持重命名、删除和拖动排序。
- 文件可用性处理：失效曲目标识、重新定位和清理失效曲目。
- 本地持久化：曲库、分组和主题偏好会在重启后保留。

## 运行与构建

```bash
swift build
```

编译 SwiftPM target，用于检查 Swift/SwiftUI 编译错误。

```bash
swift run Crate
```

通过 SwiftPM 启动应用，适合开发期快速验证。

```bash
open Crate.xcodeproj
```

用 Xcode 打开项目，处理签名、调试和图标资源。

```bash
Scripts/bundle.sh
```

构建 Release 并生成可测试 app bundle：

```text
build/Crate.app
```

## 项目结构

```text
src/
  CrateApp.swift          应用入口
  AppState.swift          曲库、分组、导入、持久化和全局状态
  PlayerStore.swift       播放状态、上下文和待播队列
  PlaybackEngine.swift    AVAudioPlayer 播放封装
  Views/                  SwiftUI 页面和组件
  Assets.xcassets/        应用图标资源

openspec/
  specs/                  当前产品能力规格
  changes/                进行中的 OpenSpec 变更
  changes/archive/        已归档变更

Scripts/
  bundle.sh               生成 build/Crate.app 的本地打包脚本

docs/
  music.png               应用 logo 源图
  设计材料/               原始 Web 原型和样式参考
```

## 验证

提交前至少运行：

```bash
swift build
openspec validate <change-name>
Scripts/bundle.sh
```

涉及 UI、导入、播放或持久化时，需要手动验证：

- 空曲库首次启动
- 文件导入和文件夹导入
- 重复路径处理
- 播放控制和待播清单
- 分组创建、重命名、删除、拖动排序
- 重启后曲库和分组保留

## OpenSpec 工作流

行为变更应先创建或更新 OpenSpec change，再实现代码。实现完成后：

1. 同步 delta specs 到 `openspec/specs/`。
2. 准确勾选对应 `tasks.md`。
3. 通过 `openspec validate <change-name>`。
4. 将完成的 change 归档到 `openspec/changes/archive/YYYY-MM-DD-<change-name>/`。

## 技术栈

- Swift 5.9+
- SwiftUI
- AVFoundation
- Swift Package Manager
- Xcode project
