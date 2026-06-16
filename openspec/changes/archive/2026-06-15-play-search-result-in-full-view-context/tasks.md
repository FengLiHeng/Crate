## 1. 播放上下文

- [x] 1.1 在 `AppState` 中拆分未过滤的当前视图歌曲集合与搜索过滤后的表格歌曲集合。
- [x] 1.2 让顶部【播放】和【随机播放】使用未过滤的当前视图歌曲集合。
- [x] 1.3 让搜索结果行双击播放时，在未过滤集合中按歌曲 id 定位并重建待播清单。

## 2. 验证

- [x] 2.1 运行 `swift build` 验证编译通过。
- [x] 2.2 运行 `openspec validate play-search-result-in-full-view-context` 验证变更通过。
- [x] 2.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
