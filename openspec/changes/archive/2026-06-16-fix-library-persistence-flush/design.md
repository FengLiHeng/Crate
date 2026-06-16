## Context

当前 `persist()` 将 JSON 编码和写入放入串行后台队列。这样能避免在 UI 线程做 I/O，但如果用户在导入后立即退出，队列中尚未执行的保存任务会随进程终止丢失。

## Goals / Non-Goals

**Goals:**

- 保留后台异步保存，避免常规操作阻塞 UI。
- 退出应用前同步写入最新曲库快照。
- 连续数据变更时只需要保证最终最新快照被保存。

**Non-Goals:**

- 不迁移到数据库。
- 不改变 `library.json` 的 Codable schema。
- 不持久化运行时失效曲目标记。

## Decisions

- `persist()` 记录最新 `PersistedLibrary` 快照，并调度一个后台 drain 任务；drain 写入当前最新快照，如果写入期间又有新快照，则继续写下一轮。
- `flushPersistence()` 在应用终止通知中调用，先更新最新快照，再通过同一串行队列同步写入，等待所有已排队保存完成。
- 写盘失败时不覆盖内存状态；当前实现延续既有静默失败策略。

## Risks / Trade-offs

- [Risk] 退出时同步写入大曲库可能短暂阻塞退出。 → Mitigation：只在终止前执行，且换取数据不丢失。
