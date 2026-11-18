# FilterKit 0.1.8 实现说明 — Helper Foundation & Trust Infrastructure

## 一、阶段边界

0.1.8 在 0.1.7 只读安全加固基线之上，建立 FilterKit 自有 Helper 的**身份模型、可信发布清单、v1 协议、只读能力模型、传输抽象与报告/备份/审计/门禁整合基础**。本版本仍为只读预演（preview_only），不开放任何 Root 写操作。

| 边界项 | 0.1.8 状态 |
|---|---|
| 真实 Helper 连接 / 真实 IPC 读取 | 未实现，仅模型与抽象接口 |
| 真实启停 / 安装卸载 / 改 Injector 配置 | 未开放，门禁默认拒绝 |
| Root Daemon 真机部署 | 未创建 |
| 真实签名链验证通过 | 不宣称；签名证据保守归 Unsupported |
| 可信发布锚点 / Manifest 校验通过 | 接口与结果模型就位，0.1.8 默认不产生 Verified |

锁定身份口径：Product `FilterKit`；Component `FilterKitHelper`；Helper ID `com.filterkit.helper`；Protocol major 1 / minor 0；Version `0.1.8`；BuildID `FKH-018`；Manifest channel/releaseStatus `development`；报告 `schemaVersion: 2`。

## 二、安全红线（贯穿实现）

- 发现层只产出候选与元数据，不自产 Verified 可信结论；普通系统工具候选不记为 FilterKit Helper。
- 无可信发布来源记录时身份保持 Unknown，不因 ID / 版本符合预期自动通过。
- SHA-256 计算成功只代表可算摘要；与可信发布锚点匹配才算完整性通过，无锚点保持 Unknown。本地摘要不自动存为可信锚点，也不从待验证 Helper 读取其自报锚点。
- 签名校验 API 不可用时返回 Unsupported；签名验证与二进制代码签名是两件事，不互相替代。
- IPC 只建模型、握手与传输抽象，不虚构端点连接；当前正确状态为 Unavailable。Nonce / 时间戳不取代身份认证。
- 能力按只读白名单细分，不使用总开关；写能力与未知能力默认拒绝。
- 测试中的 Mock / 模拟数据只验证本地门禁逻辑，必须标注 `mock`，不记录为真机已连接或已获得写权限。
- 真实启停、写注入器配置、改 Filter、导入 dylib、删除插件文件、恢复系统文件，在无可信 Helper 端点 / 签名链 / 协议验收 / 授权证据前默认拒绝。

## 三、模块落地（Commit 划分）

### Commit01 Identity + Metadata + BuildInfo
- `FKHelperIdentity`：Helper 稳定身份模型（标识、组件、协议版本、版本、构建标识）。
- `FKHelperReleaseMetadata`：发布元数据（与 0.1.7 候选采集元数据 `FKHelperMetadata` 区分，避免同名冲突）。
- `FKHelperBuildInfo`：构建渠道、发布状态、构建号等构建信息。

### Commit02 Trust Manifest
- `FKHelperTrustManifest`：发布清单与制品（`FKHelperArtifact`）结构；`+isValidSHA256Hex:` 公开校验。
- `FKHelperManifestVerifier`：`FKHelperManifestVerificationResult` 与可替换 `FKHelperManifestVerifying` 协议；默认保守判定，0.1.8 默认不产生 Verified。

### Commit03 Integrity
- 扩展既有 `FKHelperIntegrityVerifier`，新增 `FKHelperIntegrityResult` 与 `verifyFileAtPath:expectedSHA256:`；复用 `FKFileHasher` 流式 SHA-256。

### Commit04 Protocol v1
- `FKHelperMessage`（含 `FKHelperNonceCache`）、`FKHelperMessageError`、`FKHelperCapabilities`、`FKHelperHandshake`。
- 错误码使用 `FKHelperMessageErrorCode`，避免与既有 `FKHelperIPCErrorCode` 冲突。

### Commit05 Transport + Client
- `FKHelperTransport` 协议、`FKHelperTransportState`、`FKHelperTestTransport`（Mock）、`FKHelperReadOnlyClient`、`FKMockHelperClient`、`FKHelperServiceInfo`、`FKHelperReadOnlyProvider`。
- 传输层不直接依赖 Unix socket；长 jbroot 路径下的 socket 长度限制留待真实接入阶段处理。

### Commit06 TrustReport + 主流程 + 报告分层
- `FKHelperTrustReport` 扩展 v2 分层字段：`helperID`、`buildID`、`manifestStatus`、`capabilities`。
- 报告 JSON 输出 `schemaVersion: 2` 与 `helper / manifest / capabilities / permissions` 分层；既有顶层键与 0.1.7 回归断言全部保留。
- 主流程调用链：`FKScanner → FKHelperTrustEvaluator（汇总 Discovery / Identity / Signature / Integrity / Permission / IPC）→ FKHelperTrustReport → Home / Settings / Preview / SecurityReport JSON / OperationGate`。
- 旧 `FKHelperTrustVerifier` 保留为兼容层，未直接删除。

### Commit07 Backup + Audit + Gate
- `FKConfigurationBackup` 纳入 `FKBackupManager`：操作前备份记录聚合 `configuration_snapshot` 配置快照；只记录原始配置上下文与只读摘要，不复制、不覆盖原配置文件，不开放系统配置恢复。
- 审计事件类型扩展：`manifest_validation`、`integrity_check`、`protocol_validation`、`capability_evaluation`、`operation_rejected`；既有发现 / 身份 / 签名 / 权限 / IPC / 门禁 / 备份事件保留。
- 门禁评估新增 `helper_manifest` 检查项：仅清单状态为 `verified` 视为通过，`unavailable / unknown / invalid` 阻断真实操作。
- `FKCapabilityEvaluator` 独立能力评估器：综合身份、清单、完整性、对端通道、协议兼容、能力存在与白名单范围判定；信任链任一未验证即拒绝，写能力与未知能力直接拒绝，并输出拒绝原因码。
- 独立回归套件：`FKHelperCapabilityTests`（CAP801–809，只读白名单边界与评估器判定）、`FKHelperGateTests`（GATE801–810，门禁阻断、Mock 不变真实连接、全模拟不放行、断开撤销能力）。

## 四、报告 v2 结构（schemaVersion 2）

```
schemaVersion: 2
helper      { helperID, version, buildID }
discovery   { status, candidateType }
identity    { status, verified }
manifest    { status }
signature   { status }
integrity   { status }
ipc         { code, text }
capabilities { local.inspect, helper.info, plugin.list, plugin.inspect,
               config.inspect, plugin.enable, plugin.disable, config.write }
permissions { readOnly, write }
realOperationAllowed: false
reasons / reasonCodes / evidence / checked_at
```

`realOperationAllowed = identityVerified && manifestVerified && integrityVerified && signatureVerified && peerVerified && protocolCompatible && capabilityAuthorized && backupValid && userAuthorized`；0.1.8 此条件不被满足。

只读白名单方法键：`helper.info`、`helper.health`、`capabilities.list`、`plugin.list`、`plugin.inspect`、`config.inspect`。
禁止进入白名单：`plugin.enable`、`plugin.disable`、`plugin.delete`、`config.write`、`filter.modify`、`file.restore`。

## 五、自动化测试

12 个测试套件，统一范式：`+checkCount` 与 `+runChecks`（返回失败描述数组，空 = 全过）；`FKTestRunner` 在 `suites`、`classes`、`names` 三处同步注册。

| 套件 | 编号 | 数量 |
|---|---|---|
| model（基线回归） | — | 5 |
| backup（基线回归） | — | 5 |
| json（基线回归） | — | 7 |
| operation（基线回归） | — | 13 |
| trust（基线回归，含 REP701–708、GATE701–708） | — | 53 |
| identity | HFA801–808 | 8 |
| metadata | HFM801–806 | 6 |
| manifest | HMF801–812 | 12 |
| integrity | INT801–809 | 9 |
| protocol | PRO801–812 | 12 |
| transport | TRN801–807 | 7 |
| report | REP801–812 | 12 |
| capability | CAP801–809 | 9 |
| gate | GATE801–810 | 10 |

0.1.8 规划编号用例合计 85 项（identity 8 + metadata 6 + manifest 12 + integrity 9 + protocol 12 + transport 7 + report 12 + capability 9 + gate 10）；其余为 0.1.7 基线回归套件。

门禁回归覆盖：Helper 不存在、清单未验证、身份 Unknown、完整性 Unknown、IPC Unavailable、未授权、备份无效、模拟齐备仍不放行；Mock 握手 / 模拟客户端必须标注 mock，不得变为真实连接；断开连接后撤销相关能力。

## 六、构建与校验

- 平铺目录结构（`Sources/Helper/` 等），规划中的 Core/Trust/Protocol 子目录拆分作为目标结构在本说明标注，未在本版本落地。
- 新增 `.m` 同步登记：`Makefile` 的 `FilterKit_FILES`、`scripts/validate-project.js` required 清单、`FKTestRunner` 三处数组；头文件与实现配对。
- 本地 `validate-project.js` 为静态核对，不代表 Theos 编译或真机验收。

## 七、未落地与后续阶段

- Helper 本体最终形态（独立 root daemon vs 依附注入器进程）待有正式构建环境与可信发布产物后确定；传输适配方案未选定。
- Manifest 签名校验的具体密码学实现需按当前 iOS SDK 与构建环境确认；0.1.8 只提供可替换接口与明确结果 / 原因码。
- 资源 manifest JSON 的 Theos bundle 拷贝链路未接入；当前模型测试走字典构造，不依赖 bundle 资源。
- Helper 详情四区域（身份 / 信任状态 / 通信 / 能力）独立页面已落地：`FKHelperDetailsViewController`，从首页 Helper 安全状态「查看详细报告」进入；Unknown/Unavailable 用灰色、不符/失败用红色、通过才用绿色，无真实 Helper 不显示连接成功。Settings 内 Helper 管理分组细化留待后续迭代。
- 报告/协议模型尚未单列 `peerVerified` 对端身份字段，评估器暂以 IPC 通道已验证代理；待真实 IPC 阶段补建模。
- 服务端 `FKHelperService` / `FKHelperRequestRouter` 只读壳未建；目录未按 Core/Trust/Protocol/Client/Transport/Server 子目录拆分，保持平铺。

## 八、发布口径

**可宣称**：Helper Foundation 架构已建立；身份模型完成；可信发布清单机制建立；SHA-256 完整性检查实现；IPC v1 协议模型完成；只读能力模型完成；Helper Client / Server 接口建立；安全门禁与审计体系整合。

**不可宣称**：已连接真实 Helper；已实现真实 IPC 插件读取；真实启停；改 Injector 配置；Root Daemon 真机部署；通过真实签名链验证。
