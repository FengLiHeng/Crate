# dock-playback-menu Specification

## Purpose
定义 macOS Dock 栏右键上下文菜单中的播放控制入口与状态行为。

## Requirements
### Requirement: Dock 栏播放控制菜单
应用 SHALL 在 macOS Dock 栏右键上下文菜单中提供播放控制项：上一首、播放/暂停、下一首。Dock 菜单 SHALL 根据当前播放状态动态显示“播放”或“暂停”，并在没有当前曲目时禁用播放控制项。Dock 菜单触发的播放命令 MUST 复用应用现有播放控制语义。

#### Scenario: 播放中打开 Dock 菜单
- **WHEN** 当前存在播放曲目且正在播放，用户右键点击 Dock 栏应用图标
- **THEN** Dock 菜单显示“上一首”“暂停”“下一首”，且三个播放控制项可用

#### Scenario: 暂停时打开 Dock 菜单
- **WHEN** 当前存在播放曲目且播放状态为暂停，用户右键点击 Dock 栏应用图标
- **THEN** Dock 菜单显示“上一首”“播放”“下一首”，且三个播放控制项可用

#### Scenario: 未播放时打开 Dock 菜单
- **WHEN** 当前没有播放曲目，用户右键点击 Dock 栏应用图标
- **THEN** Dock 菜单显示播放控制项但这些控制项不可触发

#### Scenario: 从 Dock 菜单切换播放暂停
- **WHEN** 当前存在播放曲目，用户在 Dock 菜单中选择“播放”或“暂停”
- **THEN** 应用切换当前曲目的播放状态，并与底部播放条显示保持一致

#### Scenario: 从 Dock 菜单切歌
- **WHEN** 当前存在播放曲目，用户在 Dock 菜单中选择“上一首”或“下一首”
- **THEN** 应用按现有上一首或下一首语义切换曲目，并同步更新底部播放条
