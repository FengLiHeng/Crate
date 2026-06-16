## Why

导入音乐目录后，如果用户很快退出应用，曲库保存任务可能仍在后台异步队列中尚未完成，进程终止后会丢失最新导入数据。下次启动读取到的仍是旧的空曲库。

## What Changes

- 将曲库持久化改为可合并的最新快照写入，减少连续导入/元数据解析期间的重复写盘。
- 在应用终止前同步 flush 当前曲库快照，确保导入、删除、分组变更在退出后保留。
- 保持现有 `Application Support/Crate/library.json` 存储格式不变。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `music-library`: 曲库与分组变更在应用退出前必须强制落盘，避免后台异步保存未完成导致重启后丢失。

## Impact

- 影响 `src/AppState.swift` 与 `src/CrateApp.swift`。
- 不改变曲库 JSON 格式、导入流程或 UI 行为。
