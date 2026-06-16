## 1. 待播清单渲染

- [x] 1.1 将待播清单滚动内容从 `VStack` 改为懒加载容器。
- [x] 1.2 按队列 id 与索引懒解析歌曲，避免打开时为全部条目构造行视图。
- [x] 1.3 保持当前播放、插播、接下来、移除和双击跳播行为不变。

## 2. 验证

- [x] 2.1 运行 `swift build` 验证编译通过。
- [x] 2.2 运行 `openspec validate virtualize-queue-panel` 验证变更通过。
- [x] 2.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
