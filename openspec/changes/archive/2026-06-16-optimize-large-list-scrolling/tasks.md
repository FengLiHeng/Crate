## 1. 列表渲染优化

- [x] 1.1 为歌曲与专辑封面缩略图增加 `NSImage` 缓存。
- [x] 1.2 保持歌曲表格原有 `LazyVStack` 滚动布局，避免自定义虚拟化破坏滚动行为。
- [x] 1.3 将侧边栏分组列表从普通 `VStack` 改为懒加载容器。

## 2. 验证

- [x] 2.1 运行 `openspec validate optimize-large-list-scrolling` 验证变更通过。
- [x] 2.2 运行 `swift build` 验证编译通过。
- [x] 2.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
