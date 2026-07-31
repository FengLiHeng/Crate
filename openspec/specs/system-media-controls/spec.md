# system-media-controls Specification

## Purpose
定义 Crate 与 macOS 系统正在播放信息及媒体命令的集成行为。

## Requirements

### Requirement: 发布当前播放信息
系统 SHALL 在存在当前歌曲时向 macOS 正在播放中心发布歌曲标题、艺人、专辑、可用封面、时长、当前进度和与播放状态一致的播放速率。

#### Scenario: 开始播放歌曲
- **WHEN** 用户开始播放一首具有完整元数据和封面的本地歌曲
- **THEN** macOS 控制中心显示对应标题、艺人、专辑、封面和时长，并以速率 1 表示正在播放

#### Scenario: 播放状态或进度变化
- **WHEN** 当前歌曲被暂停、恢复或跳转进度
- **THEN** 系统正在播放信息更新进度，并以速率 0 或 1 准确反映暂停或播放状态

#### Scenario: 元数据缺失
- **WHEN** 当前歌曲没有歌曲级艺人、专辑或封面
- **THEN** 系统使用 Crate 与界面一致的艺人和专辑回退文案，并省略不可用封面

### Requirement: 响应系统媒体命令
系统 SHALL 响应 macOS 控制中心、键盘媒体键以及耳机或蓝牙设备发出的播放、暂停、播放/暂停切换、上一首、下一首和进度跳转命令，并复用 `PlayerStore` 既有语义。

#### Scenario: 播放与暂停
- **WHEN** 系统在暂停状态发送播放命令，或在播放状态发送暂停命令
- **THEN** `PlayerStore` 通过既有播放/暂停逻辑切换到请求状态

#### Scenario: 切换与上下曲
- **WHEN** 系统发送播放/暂停切换、上一首或下一首命令
- **THEN** `PlayerStore` 分别执行既有 `togglePlay()`、`prev()` 或 `next()` 语义

#### Scenario: 跳转进度
- **WHEN** 系统发送包含目标时间的进度跳转命令
- **THEN** `PlayerStore` 使用既有 `seek(to:)` 语义设置播放进度

### Requirement: 无当前歌曲时清理系统状态
系统 SHALL 在没有当前歌曲时清空 macOS 正在播放信息并禁用所有支持的媒体命令。

#### Scenario: 播放会话结束
- **WHEN** 当前歌曲被移除或播放会话重置为无当前歌曲
- **THEN** 系统清空正在播放字典并禁用全部媒体命令

#### Scenario: 无歌曲时收到命令
- **WHEN** 无当前歌曲时仍收到延迟到达的系统媒体命令
- **THEN** 命令不改变 `PlayerStore` 状态并返回不可执行结果
