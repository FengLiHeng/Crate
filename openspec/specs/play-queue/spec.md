# play-queue Specification

## Purpose
TBD - created by archiving change local-music-player. Update Purpose after archive.
## Requirements
### Requirement: 插播队列
应用 SHALL 维护独立于播放上下文的插播队列："添加到下一首播放" SHALL 将歌曲插到队列头部，"添加到待播清单" SHALL 追加到队列尾部，均 toast 确认。待播面板 SHALL 将插播队列与播放上下文中的后续曲目连续呈现在同一“接下来”列表中，插播队列位于列表最前方。插播队列与播放上下文中的后续曲目 SHALL 按歌曲 id 去重，同一首歌 MUST NOT 同时出现在两者中。插播曲目播放完毕后 SHALL 回到原播放上下文继续，不改变上下文位置与顺序。无搜索词时，从【歌曲】视图或具体分组视图发起播放 SHALL 先清空插播队列，再用当前视图完整歌曲集合重建播放上下文。搜索词非空时，双击搜索结果 SHALL 立即播放目标歌曲，保留已有插播队列与后续上下文的相对顺序，并从后续上下文中移除目标歌曲。

#### Scenario: 添加到下一首播放
- **WHEN** 播放中用户对某歌曲选择"添加到下一首播放"
- **THEN** 该歌曲出现在“接下来”列表第一位，当前曲目结束后先播放该曲目，之后回到原上下文的下一首继续

#### Scenario: 连续添加到下一首播放
- **WHEN** 用户连续对多首歌曲选择“添加到下一首播放”
- **THEN** 最近一次选择的歌曲位于“接下来”列表第一位，先前选择保持在其后且原有上下文后续曲目继续保留

#### Scenario: 插播优先于上下文
- **WHEN** 插播队列非空且当前曲目播放完毕
- **THEN** 播放“接下来”列表头部的插播曲目并将其移出队列，而非播放上下文中的下一首

#### Scenario: 搜索结果插播保留待播顺序
- **WHEN** 待播清单中已有插播曲目或后续上下文，用户在分组搜索结果中双击某歌曲
- **THEN** 旧插播队列不被清空，既有后续上下文不重建；目标歌曲立即播放并从后续上下文中移除

#### Scenario: 首次搜索结果播放
- **WHEN** 不存在播放上下文时，用户在当前视图搜索到一首歌曲并双击播放
- **THEN** 目标歌曲立即播放；“接下来”按完整当前视图的原始顺序显示其余歌曲，且不包含目标歌曲

#### Scenario: 其他分组歌曲插入当前待播
- **WHEN** 用户通过右键菜单对其他分组中的歌曲选择"添加到下一首播放"
- **THEN** 该歌曲插入当前“接下来”列表最前面，当前视图生成的后续待播歌曲保留

#### Scenario: 下一首播放移动已有后续歌曲
- **WHEN** 当前“接下来”列表已包含某歌曲，用户对该歌曲选择"添加到下一首播放"
- **THEN** 该歌曲只在“接下来”列表第一位出现一次

#### Scenario: 添加到待播清单去重
- **WHEN** 插播队列或播放上下文后续已包含某歌曲，用户对该歌曲选择"添加到待播清单"
- **THEN** “接下来”列表中该歌曲只保留一个条目

### Requirement: 待播清单面板
播放条的队列按钮 SHALL 切换右侧待播清单面板的展开/收起。面板 SHALL 分区展示正在播放（含均衡器动画）与接下来；“接下来” SHALL 按实际播放顺序连续包含插播队列和播放上下文中当前位置之后的曲目，MUST NOT 显示独立的“插播 · 下一首播放”分区。无后续曲目时 SHALL 显示空状态引导文案。面板 SHALL 对“接下来”列表使用懒加载渲染，MUST NOT 在打开面板时一次性创建全部队列行视图。成功执行“下一首播放”后，目标歌曲 SHALL 在列表第一位获得短暂强调反馈，并保留 toast 确认。

#### Scenario: 打开面板
- **WHEN** 用户点击播放条的队列按钮
- **THEN** 右侧滑出待播清单面板，分区显示正在播放和一份连续的“接下来”列表；再次点击收起

#### Scenario: 长队列打开面板
- **WHEN** 当前播放上下文包含大量后续曲目且用户打开待播清单面板
- **THEN** 面板只渲染可见区域附近的队列行，打开过程不因一次性创建全部行视图而卡顿

#### Scenario: 双击跳播
- **WHEN** 用户双击“接下来”列表中的某曲目
- **THEN** 应用按该曲目所属的插播队列或播放上下文语义立即播放该曲目

#### Scenario: 移除手动待播曲目
- **WHEN** 用户点击“接下来”列表中某个手动待播曲目的移除按钮
- **THEN** 该曲目从插播队列和列表中移除，不影响当前播放

#### Scenario: 下一首置顶反馈
- **WHEN** 用户成功将一首歌曲设为下一首播放且待播面板可见
- **THEN** 该歌曲移动到“接下来”第一位并获得短暂强调，普通歌曲不产生持续循环动效

### Requirement: 清空待播清单
面板存在后续曲目时 SHALL 显示"清空"按钮：点击 SHALL 清空插播队列并截断上下文中当前曲目之后的全部待播曲目，使“接下来”列表为空；当前播放不中断，toast 确认。

#### Scenario: 清空队列
- **WHEN** 用户点击待播清单面板的"清空"按钮
- **THEN** “接下来”列表清空，当前曲目继续播放，当前曲目结束后播放停止

### Requirement: 立即播放不打乱上下文
通过右键菜单"立即播放"单曲 SHALL 作为插播立即开始播放，不重建播放上下文；该曲目播完后 SHALL 回到原上下文继续，并从原上下文当前位置之后的下一首开始推进。立即播放期间手动点击"下一首"也 SHALL 使用相同回归规则。若原上下文已为空或已到末尾且未开启列表循环，立即播放结束后 SHALL 停止播放。

#### Scenario: 立即播放后回归
- **WHEN** 在上下文播放中用户对另一首歌选择"立即播放"，且该曲播放完毕
- **THEN** 继续播放原上下文中（原位置的）下一首

#### Scenario: 立即播放期间点击下一首
- **WHEN** 在立即播放插播曲期间用户点击"下一首"
- **THEN** 应用停止当前插播曲，并播放原上下文当前位置之后的下一首

#### Scenario: 无上下文时立即播放结束
- **WHEN** 用户在没有播放上下文时对某首歌选择"立即播放"，且该曲播放完毕
- **THEN** 应用停止播放并清空当前曲目

### Requirement: 清空歌曲列表时重置待播清单
当用户确认清空歌曲列表时，应用 SHALL 停止当前播放，并清空插播队列、播放上下文和待播清单中的全部残留曲目。清空完成后，待播清单面板 MUST NOT 展示旧歌曲的“正在播放”或“接下来”条目。

#### Scenario: 清空歌曲列表同步清空待播清单
- **WHEN** 用户确认清空歌曲列表
- **THEN** 当前播放停止，插播队列为空，播放上下文为空，待播清单不再显示任何旧歌曲

### Requirement: Queue row actions are accessible without pointer hover
The app SHALL expose play and remove actions for applicable queue rows without requiring pointer hover. Removable rows SHALL keep a stable remove control, and assistive technologies SHALL receive named actions for playing and removing a row.

#### Scenario: VoiceOver plays a queued track
- **WHEN** a VoiceOver user focuses a queued track and invokes its Play action
- **THEN** the app starts that queued track using the same queue semantics as a mouse double-click

#### Scenario: Keyboard or VoiceOver removes a manual queue item
- **WHEN** a removable manual queue row is not pointer-hovered and the user invokes its remove control or named Remove action
- **THEN** the item is removed from the manual queue

### Requirement: 批量加入待播清单
应用 SHALL 允许用户将当前选择的多首歌曲按当前可见顺序加入待播清单。批量操作 SHALL 保持现有待播内容的相对顺序，并 MUST 避免歌曲在插播队列或后续上下文中重复出现。

#### Scenario: 多首歌曲加入待播
- **WHEN** 用户选择多首歌曲并执行“加入待播清单”
- **THEN** 所选歌曲按当前可见顺序追加到待播清单，既有待播歌曲相对顺序保持不变

#### Scenario: 批量加入时去重
- **WHEN** 所选歌曲中的一首已存在于插播队列或后续上下文
- **THEN** 该歌曲在最终待播清单中只出现一次，其他所选歌曲仍按顺序加入

### Requirement: 待播分区支持重新排序
应用 SHALL 允许用户在单一“接下来”列表中拖动曲目重新排序；插播队列曲目与播放上下文后续曲目仍 SHALL 分别在各自内部序列中移动，跨内部队列类型拖动 MAY 被拒绝。队列行 SHALL 显示清晰的拖动手柄，并以稳定动画反馈顺序变化。拖动预览 SHALL 使用尺寸稳定且内容清晰的不透明视觉，原列表位置 SHALL 只保留不重复歌曲内容的占位反馈，MUST NOT 因预览与原行叠加产生文字、封面或背景残影。排序后实际下一首播放顺序 SHALL 立即更新，并 SHALL 通过现有播放记忆持久化。排序操作 MUST NOT 改变当前曲目、当前播放上下文位置或播放进度。

#### Scenario: 调整手动待播顺序
- **WHEN** 用户将“接下来”列表中的手动待播曲目拖到同类型曲目的另一位置
- **THEN** 列表与实际插播播放顺序立即按新顺序更新，当前播放保持不变

#### Scenario: 调整上下文后续顺序
- **WHEN** 用户将“接下来”列表中的播放上下文曲目拖到同类型曲目的另一位置
- **THEN** 上下文后续曲目与实际后续播放顺序立即按新顺序更新，当前曲目、上下文位置和播放进度保持不变

#### Scenario: 拖动预览不产生残影
- **WHEN** 用户长按并拖动任一可排序队列行经过其他目标位置
- **THEN** 指针附近只显示一个紧凑且不透明的歌曲预览，列表中的拖动行仅显示稳定占位，不重复显示歌曲文字或封面

#### Scenario: 取消拖动后恢复原行
- **WHEN** 用户开始拖动队列行后在无效目标或非队列区域释放鼠标
- **THEN** 应用取消排序并立即清除拖动占位，原歌曲行恢复正常显示

#### Scenario: 拒绝无效移动
- **WHEN** 移动请求包含越界索引、相同索引或跨内部队列类型目标
- **THEN** 队列顺序和当前播放状态保持不变，应用不会崩溃

#### Scenario: 重启后恢复调整顺序
- **WHEN** 用户调整待播顺序、播放记忆完成保存并重启应用
- **THEN** 待播清单恢复为调整后的顺序

### Requirement: 队列排序支持辅助技术
应用 SHALL 为可排序的队列行提供命名的“上移”和“下移”无障碍动作，并 SHALL 仅在所属内部队列类型的对应方向存在有效目标时暴露或执行该动作。无障碍移动 SHALL 与指针拖动使用相同的队列排序语义。

#### Scenario: VoiceOver 调整队列顺序
- **WHEN** VoiceOver 用户聚焦可排序队列行并调用“上移”或“下移”
- **THEN** 曲目在所属内部队列类型中移动一个位置，单一“接下来”列表和实际播放顺序同步更新

#### Scenario: 在内部序列边界调用移动
- **WHEN** 用户尝试将所属内部队列类型的第一项上移或最后一项下移
- **THEN** 队列顺序保持不变且应用不会崩溃

### Requirement: 随机模式保留原始顺序
随机模式下调整“接下来”分区 SHALL 只改变当前随机播放的有效顺序，MUST NOT 改写 `originalIds`；关闭随机模式后 SHALL 恢复调整前由 `originalIds` 记录的原始顺序，并将上下文位置对齐当前曲目。

#### Scenario: 随机模式调整后关闭随机
- **WHEN** 用户在随机模式中调整后续曲目顺序后关闭随机模式
- **THEN** 当前随机顺序曾立即生效，但关闭随机后上下文恢复为既有原始顺序且当前曲目保持不变
