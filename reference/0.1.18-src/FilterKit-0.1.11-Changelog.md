# FilterKit 0.1.11 变更摘要

- 基线：用户上传且已在线编译成功的 `FilterKit-0.1.10-source.zip`。
- 版本：App `0.1.11` / Build `111`；Helper Identity `0.1.11` / `FKH-0111`；Protocol `1.0`。
- 强化 Helper 候选路径、路径穿越、字段类型、文件类型、包 ID 与协议版本校验。
- Discovery 对无效路径/元数据返回 Invalid，对不可执行候选返回 Incomplete。
- 在既有 `FKHelperServiceDiscovery` 增加逐候选证据报告和计数汇总。
- `FKHelperTrustEvaluator` 对不安全候选提前终止，避免后续文件摘要/签名读取；不安全候选不再触发可读性路径探测。
- 扩展 SRV909–SRV916 八项边界测试；静态登记断言 272 项。
- 不增加新编译源文件；保留 Sources/Helper 平铺结构。
- 继续只读：无真实 Helper、Transport、签名锚点或写操作。
- 0.1.11 未在本环境执行 Theos/在线 CI/真机编译；需用户在线构建验收。
