## 1. 动效基础

- [x] 1.1 在主题层增加统一 MotionTokens，并替换主要内联动效时长
- [x] 1.2 在关键视图读取 accessibilityReduceMotion，并为页面/面板动效提供降级路径

## 2. 播放焦点

- [x] 2.1 优化底部播放条换歌、播放/暂停、进度和当前歌曲信息的状态过渡
- [x] 2.2 优化歌词页进入/退出、封面焦点和歌词行推进动效
- [x] 2.3 优化待播清单展开/收起和队列行新增/移除反馈

## 3. 界面反馈

- [x] 3.1 优化歌曲表格行 hover、选中、当前播放和更多按钮的短反馈
- [x] 3.2 优化侧边栏选中态、主题切换、搜索清除、按钮 hover/press 和拖拽导入遮罩反馈

## 4. 验证

- [x] 4.1 运行 openspec validate refine-motion-polish
- [x] 4.2 运行 swift build
- [x] 4.3 运行 Scripts/bundle.sh 生成 build/Crate.app
