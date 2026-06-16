## Context

`ScrollView + LazyVStack` 可以减少 SwiftUI 一次性创建的歌曲行数量，但可见行和预取行仍会频繁进入 `body` 计算。当前 `CoverView` 与 `AlbumCoverTile` 在计算属性中直接调用 `NSImage(data:)`，当封面数据较多或用户快速拖动滚动条时，主线程会重复执行图片解码。

侧边栏分组列表当前使用 `ScrollView + VStack`。当用户拥有大量分组时，SwiftUI 会同步构造全部 `SideItem`，拖动滚动条和拖动排序状态变化都需要处理完整视图树。

## Goals / Non-Goals

**Goals:**

- 避免同一歌曲或专辑封面在滚动期间被反复同步解码。
- 让大量分组列表只创建可见区域附近的行视图。
- 保持现有 UI、上下文菜单、拖动排序和播放行为不变。
- 保持实现局部，便于后续如有必要再迁移到 AppKit 虚拟表格。

**Non-Goals:**

- 不引入 `NSTableView`/`NSOutlineView` 重写歌曲表格。
- 不改变封面持久化格式或导入流程。
- 不新增分页、后台缩略图生成或数据库索引。

## Decisions

- 使用 `NSCache<NSString, NSImage>` 作为进程内封面缓存。缓存键包含来源类型、实体 id 与数据长度；实体 id 变化或封面长度变化时自然重新解码。
- 封面缓存只保存成功解码的 `NSImage`，无封面时继续走现有占位符。
- 歌曲表格保留 `ScrollView + LazyVStack`，避免自定义滚动偏移虚拟化破坏 SwiftUI 布局与滚动条行为。
- 侧边栏滚动内容使用 `LazyVStack` 替代 `VStack`。

## Risks / Trade-offs

- [Risk] 缓存会增加一定内存占用。 → Mitigation：使用 `NSCache`，由系统在内存压力下自动回收。
- [Risk] 同一实体 id 的封面数据被替换且长度相同，缓存可能继续使用旧图。 → Mitigation：当前导入/回填流程通常生成新实体或改变数据长度；如后续支持编辑封面，可在写入时显式清缓存。
