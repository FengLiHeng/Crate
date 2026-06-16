## 1. 持久化可靠性

- [x] 1.1 将异步持久化改为合并最新快照写入。
- [x] 1.2 增加应用终止前同步 flush 当前曲库快照。
- [x] 1.3 保持存储路径和 JSON schema 不变。

## 2. 验证

- [x] 2.1 运行 `openspec validate fix-library-persistence-flush`。
- [x] 2.2 运行 `swift build`。
- [x] 2.3 运行 `Scripts/bundle.sh` 生成最新 `build/Crate.app`。
