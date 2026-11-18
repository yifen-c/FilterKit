# Tests/Stage1 回归接入位置

Stage 1 离线夹具与 harness（`Tests/S1-01~S1-08/`、`Tests/Fixtures/S1-01~S1-08/`）是 2.2 迁移后的行为回归基线，合计 **135/135**。

- 2.1 骨架阶段：仅保留接入位置，**不迁移完整扫描逻辑**。
- 2.2 迁移后：Core/Adapter 行为须与 Stage 1 夹具预期深比较（除 `generatedAt` 外），135 项回归保持通过。
- 现有 harness 为 Node 验证载体，不进入 App 运行时；Node 仅用于 CI 编排/打包。
