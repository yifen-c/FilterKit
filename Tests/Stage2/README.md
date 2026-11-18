# Tests/Stage2 测试记录位置

- 2.1：Core/Adapter/Models 骨架单测的接入位置；非界面层已在 runner 通过（4 用例）。
  - `Stage-2.1-CI-Acceptance.md`：两轮 CI 日志核对与失败复盘；
  - `Stage-2.1-Final-Acceptance.md`：2.1 最终验收 8 条标准与待办；
  - `evidence/`：各轮 runner 原始日志归档。
- 2.2：迁移后 Core/Adapter 单测，复用 Stage 1 夹具。
- 2.4：GUI 进程内权限探针测试记录（独立于 CLI 结果）。
- 2.5：RootHide 真机只读扫描验证记录；Rootless 真机项独立标记，不以 RootHide 结果代替。

证据标签沿用：`[源码确认]` / `[RootHide 真机验证]` / `[Rootless 合成样本验证]` / `[Rootless 真机待验证]` / `[权限待验证]`。
