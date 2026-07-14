# playback Specification

## Purpose
TBD - created by archiving change local-music-player. Update Purpose after archive.
## Requirements
### Requirement: 音频播放引擎
对带有真实文件的歌曲，应用 SHALL 通过 AVFoundation 实际解码播放（支持 MP3/M4A/AAC/WAV/AIFF/FLAC）；对无文件的示例曲目，应用 SHALL 以定时器模拟进度推进。两种来源 SHALL 表现出一致的控制行为（播放/暂停/进度/切歌）。真实文件的播放引擎构造 SHALL 在后台进行，不得阻塞 UI 主线程。后台引擎构造完成前，如果用户停止播放、删除当前曲目、清空曲库或切换到其他曲目，旧构造结果 MUST NOT 恢复播放或改变当前状态。当某曲目文件缺失或无法解码时，应用 SHALL 不崩溃，即时将其标记为失效，toast 提示并按当前操作方向自动跳过；当一轮跳过遍历所有候选曲目仍无可播放曲目时，应用 SHALL 停止播放、清空当前曲目并 toast 提示"没有可播放的曲目"，不得无限跳过，也不得停留在失效曲目上。

#### Scenario: 播放导入的真实文件
- **WHEN** 用户播放一首通过导入加入的歌曲
- **THEN** 实际输出音频，进度与音频播放位置同步

#### Scenario: 播放示例曲目
- **WHEN** 用户播放一首内置示例曲目
- **THEN** 进度按实际时间推进至曲目时长，行为与真实播放一致（无音频输出）

#### Scenario: 文件缺失
- **WHEN** 用户播放的导入歌曲其源文件已被移动或删除
- **THEN** 不崩溃，该曲目被标记为失效，toast 提示文件不可用并自动跳到下一首

#### Scenario: 大文件不阻塞 UI
- **WHEN** 用户播放一首位于慢速卷上的大文件
- **THEN** 引擎在后台构造，界面在加载期间保持可交互

#### Scenario: 构造期间停止播放
- **WHEN** 用户播放慢速卷上的大文件且引擎仍在后台构造时清空曲库或停止播放
- **THEN** 后台构造完成后不会恢复该文件播放，播放条仍保持未播放状态

#### Scenario: 全部曲目不可播
- **WHEN** 上下文与插播队列中所有曲目的文件均已删除，用户尝试播放
- **THEN** 应用跳过一轮后停止播放、清空当前曲目并 toast 提示"没有可播放的曲目"，不陷入无限跳过

### Requirement: 底部播放条
播放条 SHALL 常驻窗口底部，包含三个区域：左侧当前曲目信息（封面、标题、艺术家；未播放时显示占位态"未在播放"），中部控制组（播放模式、上一首、播放/暂停、下一首、收藏）与进度条（已播时间 / 拖动滑块 / 剩余时间），右侧音量滑块与待播清单开关。播放模式按钮 SHALL 在"顺序播放 → 随机播放 → 列表循环 → 单曲循环 → 顺序播放"之间循环切换，随机播放与任一循环模式 MUST 互斥，不得同时启用。无当前曲目时上一首/播放/下一首 SHALL 禁用。当前曲目缺少可用封面时，播放条 SHALL 使用与歌曲表格一致的唱片/纸套式封面占位符。播放条背景 SHALL 叠加基于当前专辑双色相的低透明度氛围渐变，该渐变 MUST NOT 降低标题、控制按钮或进度信息的可读性。播放条左侧当前歌曲封面 SHALL 作为歌词播放动态页面入口：当当前歌曲存在可解析的同名 `.lrc` 文件时点击封面 SHALL 打开歌词页；当当前歌曲没有可用歌词时 SHALL 保持当前界面并显示 toast。

#### Scenario: 播放暂停切换
- **WHEN** 用户点击播放/暂停按钮
- **THEN** 播放状态切换，按钮图标在播放与暂停之间切换，进度停止/恢复推进

#### Scenario: 拖动进度
- **WHEN** 用户拖动进度滑块到任意位置
- **THEN** 播放位置跳转到对应时间，已播/剩余时间显示同步更新

#### Scenario: 调节音量
- **WHEN** 用户拖动音量滑块到 0
- **THEN** 音量图标变为静音样式，真实播放的输出静音

#### Scenario: 未播放时显示占位态
- **WHEN** 当前没有正在播放的歌曲
- **THEN** 播放条左侧显示统一的封面占位态和"未在播放"文案，播放控制保持禁用状态

#### Scenario: 通过封面打开歌词页
- **WHEN** 当前播放歌曲存在可解析的同名 `.lrc` 文件，用户点击播放条左侧封面
- **THEN** 应用打开歌词播放动态页面，底部播放条继续显示并可操作

#### Scenario: 封面入口无歌词提示
- **WHEN** 当前播放歌曲没有可解析的同名 `.lrc` 文件，用户点击播放条左侧封面
- **THEN** 应用保持当前界面不变并显示对应 toast 提示

### Requirement: 上一首/下一首语义
下一首 SHALL 优先取插播队列头部；队列为空时按播放上下文顺序推进；当当前曲目本身是立即播放或插播曲目时，下一首 SHALL 回到原播放上下文并播放原位置之后的曲目，不重复播放原上下文当前曲目。到达末尾时若循环为"列表"则回到第一首，否则停止在末尾。上一首 SHALL 在进度大于 3 秒或当前为插播曲目时回到曲首；否则退回上下文中的前一首；已在第一首时回到曲首。跳过失效曲目 SHALL 遵循当前操作方向：下一首/自动切歌向后寻找可用曲目，上一首向前寻找可用曲目，绝不因失效跳过而改变前进/后退方向。

#### Scenario: 列表末尾自然结束
- **WHEN** 上下文最后一首播放完毕且循环为"关"且插播队列为空
- **THEN** 播放停止，进度停在曲目末尾

#### Scenario: 立即播放结束后回到上下文下一首
- **WHEN** 用户在上下文播放中对另一首歌选择"立即播放"，且该插播曲播放完毕
- **THEN** 应用继续播放原上下文当前位置之后的下一首，而不是重复播放原上下文当前曲目

#### Scenario: 进度过半点上一首
- **WHEN** 当前曲目已播放超过 3 秒时用户点击上一首
- **THEN** 当前曲目回到 0 秒继续播放，不切换曲目

#### Scenario: 上一首撞到失效曲目
- **WHEN** 当前在曲首（进度 ≤ 3 秒），用户点击上一首，而上下文中前一首的文件已删除
- **THEN** 应用继续向前寻找可用曲目播放，而非跳到后面的曲目；若前面再无可用曲目则停在当前曲首

### Requirement: 播放模式
播放模式 SHALL 由同一个按钮控制，并按"顺序播放 → 随机播放 → 列表循环 → 单曲循环 → 顺序播放"循环切换。随机播放与列表循环、单曲循环 MUST 互斥；从随机播放切换到任一循环模式时，应用 SHALL 先关闭随机并恢复原始顺序，再启用循环模式。随机开启时 SHALL 即时重排播放上下文：保持当前曲目为队首、其余洗牌；关闭随机时 SHALL 恢复原始顺序并将位置对齐到当前曲目。单曲循环时曲目播完 SHALL 从头重播；列表循环时上下文末尾播完 SHALL 回到第一首。非顺序播放状态 SHALL 在播放条以强调色图标标识，且 SHALL NOT 显示浅红色圆角矩形背景。若旧播放记忆中同时保存了随机与循环状态，应用启动恢复时 SHALL 归一化为单一播放模式。

#### Scenario: 播放中开启随机
- **WHEN** 顺序播放状态下，播放中用户点击播放模式按钮切换到随机播放
- **THEN** 当前曲目不变，其后的播放顺序变为随机排列，且随机图标以强调色显示但没有浅红色圆角矩形背景

#### Scenario: 随机切换到列表循环
- **WHEN** 随机开启状态下用户再次点击播放模式按钮
- **THEN** 随机关闭，上下文恢复原始顺序并启用列表循环，且随机与循环不会同时高亮或同时生效

#### Scenario: 单曲循环
- **WHEN** 循环为"单曲"且当前曲目播放完毕
- **THEN** 同一曲目从 0 秒重新播放

### Requirement: 自动切歌
当前曲目播放到时长终点时，应用 SHALL 按循环与队列规则自动推进（等同触发"下一首"，单曲循环除外），无需用户操作。

#### Scenario: 顺序自动切歌
- **WHEN** 循环为"关"、队列为空且当前曲目（非末尾）播放完毕
- **THEN** 自动开始播放上下文中的下一首

### Requirement: 键盘快捷键
应用 SHALL 支持：空格切换播放/暂停（输入框聚焦时不拦截）、⌘+→ 下一首。

#### Scenario: 空格暂停
- **WHEN** 焦点不在搜索框且有当前曲目时用户按下空格
- **THEN** 播放/暂停状态切换

#### Scenario: 搜索框中按空格
- **WHEN** 焦点在搜索框内用户按下空格
- **THEN** 正常输入空格字符，播放状态不变

### Requirement: 播放控制入口一致性
应用 SHALL 确保不同入口触发的播放控制使用同一套播放语义。底部播放条、键盘快捷键和 Dock 栏播放控制菜单触发的播放/暂停、上一首、下一首命令 MUST 调用一致的播放状态机，不得因入口不同而改变队列优先级、上一首阈值、循环模式、失效曲目跳过方向或播放记忆恢复后的手动播放行为。

#### Scenario: Dock 下一首遵循队列优先级
- **WHEN** 插播队列中存在曲目且用户在 Dock 菜单中选择“下一首”
- **THEN** 应用优先播放插播队列头部曲目，与底部播放条“下一首”行为一致

#### Scenario: Dock 上一首遵循进度阈值
- **WHEN** 当前曲目已播放超过 3 秒且用户在 Dock 菜单中选择“上一首”
- **THEN** 应用将当前曲目进度回到 0 秒继续播放，不切换到上一曲

#### Scenario: Dock 播放恢复记忆曲目
- **WHEN** 应用启动后成功恢复上次曲目和进度且保持暂停，用户在 Dock 菜单中选择“播放”
- **THEN** 应用从恢复后的进度开始播放该曲目，不自动切换到其他曲目

#### Scenario: Dock 切歌保持失效跳过方向
- **WHEN** 用户在 Dock 菜单中选择“上一首”或“下一首”且目标方向上遇到失效曲目
- **THEN** 应用按所选方向继续寻找可播放曲目，不因入口来自 Dock 菜单而改变跳过方向

### Requirement: 播放记忆恢复
应用 SHALL 持久化最近一次当前曲目、播放进度以及恢复播放控制语义所需的播放上下文。应用启动后，如果持久化的当前曲目仍存在且可用于恢复，底部播放条 SHALL 显示该曲目并将进度恢复到上次保存的位置；恢复后应用 MUST 保持暂停状态，不得自动开始播放。用户手动触发播放后，应用 SHALL 从恢复后的进度继续播放。若持久化曲目无法在当前曲库中匹配，或真实文件已不可用，应用 SHALL 清理无效播放记忆并回退到未播放状态，不得崩溃、不得自动播放其他曲目。

#### Scenario: 退出后恢复播放进度
- **WHEN** 用户播放一首歌曲到中途后退出应用，并再次打开应用
- **THEN** 底部播放条显示上次歌曲，进度恢复到退出前保存的位置，播放按钮显示为可播放状态

#### Scenario: 恢复后不自动播放
- **WHEN** 应用启动并成功恢复上次歌曲和进度
- **THEN** 应用不输出音频，播放状态保持暂停，进度不会自动推进

#### Scenario: 手动播放恢复歌曲
- **WHEN** 应用已恢复上次歌曲和进度，用户点击播放按钮
- **THEN** 应用从恢复后的进度开始播放该歌曲

#### Scenario: 上次歌曲不可恢复
- **WHEN** 应用启动时持久化的上次歌曲已不在曲库中，或对应真实文件已被移动或删除
- **THEN** 应用清理无效播放记忆并显示未播放状态，不崩溃且不自动切换到其他歌曲

### Requirement: Preserve a valid state when backward skipping reaches the boundary
When the user requests the previous track and every earlier candidate is unavailable, the app SHALL NOT leave the current playback state pointing at an unavailable candidate with no playback engine. If the originating track remains playable, the app SHALL restore it at the beginning; if no candidate including the origin is playable, the app SHALL stop safely and report that no playable track exists.

#### Scenario: All earlier tracks are unavailable
- **WHEN** the current context track is playable and every earlier track fails availability or engine construction while processing Previous
- **THEN** the app restores the originating track at 0 seconds and keeps a valid playback state

#### Scenario: Origin also becomes unavailable
- **WHEN** all earlier tracks and the originating track fail while processing Previous
- **THEN** the app stops playback without looping or remaining on an unavailable track and reports that no playable track exists

### Requirement: 播放引擎加载状态
真实文件播放引擎在后台构造期间，应用 SHALL 将播放器标记为加载中并在播放条显示可感知反馈。加载期间重复点击播放 MUST NOT 再次创建引擎；停止、删除当前歌曲、清空曲库或切歌 SHALL 取消旧加载任务，旧结果不得接管播放。

#### Scenario: 慢速文件加载反馈
- **WHEN** 用户播放位于慢速卷上的歌曲且引擎尚未构造完成
- **THEN** 播放条显示该歌曲正在加载，且播放按钮不会表现为无响应

#### Scenario: 加载期间重复点击播放
- **WHEN** 播放引擎仍在构造且用户连续点击播放按钮
- **THEN** 应用只保留一个对应歌曲的引擎构造任务

#### Scenario: 加载期间切歌
- **WHEN** 当前歌曲仍在加载且用户选择另一首歌曲
- **THEN** 旧加载任务被取消或作废，只有新歌曲能够接管播放状态

### Requirement: 空播放状态进度语义
无当前歌曲时，播放进度滑杆 SHALL 处于禁用状态并 MUST NOT 暴露无效的可调节辅助功能操作。有当前歌曲时，辅助功能值 SHALL 同时表达已播时间与总时长。

#### Scenario: 无歌曲时使用 VoiceOver
- **WHEN** 当前没有歌曲且 VoiceOver 浏览底部播放条
- **THEN** VoiceOver 不提供一个可以调整但没有效果的播放进度控件

#### Scenario: 播放进度时间读法
- **WHEN** 当前歌曲播放到 40 秒且总时长为 3 分 35 秒
- **THEN** 播放进度的辅助功能值表达“0:40，共 3:35”或等价时间信息
