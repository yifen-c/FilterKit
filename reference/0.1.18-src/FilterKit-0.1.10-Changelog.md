# FilterKit 0.1.10 变更摘要

- 基线：用户上传的 `FilterKit-0.1.9-source.zip`。
- 版本：App `0.1.10` / Build `110`；Helper 开发身份合同 `0.1.10` / `FKH-0110`；Protocol 仍为 `1.0`。
- 保留 0.1.9 历史实现说明、平铺目录和既有 Helper 类名。
- 强化 FKHelperMessage 严格解析、报文大小限制、Nonce 校验/去重、响应关联。
- 强化 FKHelperRequestRouter 服务端二次校验、只读白名单和响应结构。
- 强化 FKHelperReadOnlyClient Mock 隔离、Session/Trust/Capability 准入和响应验证。
- 收紧 FKHelperPeerVerifier 与 FKCapabilityEvaluator 的证据门槛。
- 将 FKHelperIPCAuditEvent 接入 FKAuditManager schema v3 沙盒持久化。
- 新增 FKHelperBoundaryTests；测试套件 22 个，静态声明断言 264 项。
- `node scripts/validate-project.js` 通过；未执行 Theos 编译、iOS SDK 构建、签名或真机 IPC 验收。
- 真实 Helper Target、launchd 部署、Mach/Socket Transport、可信签名链、真实插件/配置读取均未完成；所有真实写操作继续拒绝。
