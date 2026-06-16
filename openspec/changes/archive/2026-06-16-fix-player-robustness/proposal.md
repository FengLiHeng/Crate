## Why

当前播放器已具备本地导入、持久化、播放队列和失效曲目处理，但代码审查发现若干健壮性缺口会在真实使用中造成状态不一致、静默数据丢失或界面卡顿。需要把这些问题作为一个收敛修复，确保现有规格承诺可稳定兑现。

## What Changes

- 修复播放状态机在全量不可播、删除/停止期间异步引擎回调、立即播放插播回归等路径上的竞态与边界行为。
- 加强曲库持久化：读取失败不再自动覆盖用户数据，写入失败可被用户感知。
- 将导入解码、元数据读取和封面处理移出主线程，并减少批量导入期间的重复持久化。
- 限制持久化封面数据体积，避免大封面导致 `library.json` 膨胀和 UI 解码抖动。
- 让支持格式文案与实际 AVFoundation 解码能力保持一致，避免承诺不稳定的 OGG 支持。
- 改善启动失效探测与重新定位的边界校验，避免后台旧结果覆盖用户后续操作。

## Capabilities

### New Capabilities

### Modified Capabilities

- `playback`: 收紧不可播跳过、停止竞态和插播播放回归的行为约束。
- `play-queue`: 明确立即播放插播结束后必须回到原上下文推进。
- `library-import`: 收紧导入线程、支持格式和封面数据持久化要求。
- `music-library`: 补充曲库持久化读取/写入失败时的数据保护要求。
- `track-availability`: 收紧失效探测结果合并与重新定位文件校验要求。

## Impact

- 主要影响 `src/AppState.swift`、`src/PlayerStore.swift`、`src/PlaybackEngine.swift`、`src/Views/RootView.swift` 和导入/播放相关文案。
- 需要新增聚焦播放状态机、持久化保护和导入元数据处理的测试，当前项目没有测试 target，需补 SwiftPM test target。
- 不改变现有 `library.json` schema；封面数据仍使用可选 `Data` 字段，但新增尺寸控制和写入失败提示。
