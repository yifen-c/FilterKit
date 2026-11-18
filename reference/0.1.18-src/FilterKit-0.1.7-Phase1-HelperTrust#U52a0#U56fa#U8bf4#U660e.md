# FilterKit 0.1.7 Phase 1 实现说明 — Helper Trust Hardening（只读安全加固）

## 一、阶段边界

0.1.7 按用户确认方案只实施 **Phase 1：Helper Trust Hardening**。本阶段只做发现、元数据、身份、签名、完整性、IPC 模型、权限预评估与统一报告接线，**不开放任何真实写操作**。

| 阶段 | 名称 | 范围 | 是否修改系统 |
|---|---|---|---|
| Phase 1（本次） | Helper Trust Hardening | 发现 / 元数据 / 身份 / 签名 / 完整性 / 权限预评估 | 否 |
| Phase 2（后续） | Helper IPC Read-only | 可信 Helper 连接、握手、真实插件读取 | 否 |
| Phase 3（后续） | Controlled Plugin Management | 受控启用 / 禁用 / 配置修改 / 备份回滚 | 是，授权后 |

阶段一最终回答：Helper 是什么、在哪里、有什么证据、哪些能力尚未验证、为什么不能执行真实操作。

## 二、安全红线（贯穿实现）

- 发现层只产出候选与元数据，**不自产 Verified 可信结论**；
- 无可信发布来源记录时身份保持 **Unknown**，不因 ID / 版本符合预期自动通过；
- SHA-256 计算成功只代表可算摘要，**与可信发布锚点匹配才算完整性通过**，无锚点保持 Unknown；
- 签名校验 API 不可用时返回 **Unsupported**，不臆断 Valid / Invalid；
- IPC 只建模型与状态机，**不虚构端点连接**，当前正确状态为 Unavailable；
- 权限按操作类型细分（本地只读 / IPC 只读 / 写），不使用总开关；
- 设置页、预演页、详情页与 JSON 导出读取**同一份信任报告**，不出现页面未验证而报告 / 执行入口放行；
- 测试中的模拟数据只验证本地门禁逻辑，**不记录为真机已获得写权限**；
- 真实启停、写注入器配置、改 Filter、导入 dylib、删除插件文件、恢复系统文件，在无可信 Helper 端点 / 签名链 / 协议验收 / 授权证据前默认拒绝。

## 三、模块落地（`Sources/Helper/`）

### A. Discovery + Metadata

- `FKHelperMetadata`：候选路径、存在性、文件类型、大小、可读、归属包集合、版本、身份标识、协议版本、缺失字段、系统工具候选标记。
- `FKHelperDiscovery`：五态分层 `NotFound / Found / Incomplete / Invalid / Verified`；`Verified` 仅占位，发现模块不产出。识别 `path_helper` 等普通系统工具候选，不记为 FilterKit Helper。

### B. Identity

- `FKHelperIdentityVerifier` 细化四态 `Unknown / Verified / Mismatch / Incomplete`；保留旧 BOOL 接口兼容既有调用。
- 缺可信发布来源 → Unknown；标识不符 → Mismatch；必要信息缺失 → Incomplete。

### C. Signature + Integrity

- `FKSignatureStatus` 扩展六态并保留 `Verified / Unverified` 兼容别名；当前未接入可用签名校验 API，返回 Unsupported。
- `FKHelperIntegrityVerifier` 四态 `Unknown / Verified / Mismatch / Unavailable`，复用 `FKFileHasher` 计算本地 SHA-256；无可信锚点保持 Unknown。

### D. IPC 模型（不建真实连接）

- `FKHelperIPCError`：错误码分类。
- `FKHelperIPCHandshake`：握手请求 / 响应模型、协议版本比较、`FKHelperIPCStatus` 七态连接状态机与状态码 / 文案。
- `FKHelperIPCCapabilities`：只读 / 写权限清单模型。

### E. Permission

- `FKHelperCapabilityManager`：权限键分类与阶段一默认能力。
  - 本地只读：`local.helper.inspect`、`local.plugin.inspect`（开放评估）；
  - IPC 只读：`ipc.plugin.list`、`ipc.config.read`（仅评估，需身份 + 连接 + 协议兼容）；
  - 写：`plugin.enable`、`plugin.disable`、`config.write`、`plugin.delete`（阶段一全拒）。
- `FKOperationPermissionEvaluator`：按权限键评估，为既有 `FKOperationGate` 提供能力结论，不另建第二套写门禁。

### F. SecurityReport

- `FKHelperTrustReport` 汇总分层段：`discovery / identity / signature / integrity / ipc / permission / realOperationAllowed / reasonCodes`。
- `FKHelperTrustEvaluator` 经 Discovery 选候选、采集元数据，逐级填充身份 / 签名 / 完整性 / IPC / 权限结论与机器可读原因码。
- 链路：MainVC 评估生成报告 → `report.helperTrust = JSONDictionary` → Scanner `helper_trust` 段 → 各控制器注入同一报告对象或字典。

## 四、测试与门禁回归（52 项）

套件 `FKHelperTrustTests`（runner 名 `trust`），分组对齐方案验收编号：

| 分组 | 编号 | 数量 |
|---|---|---|
| Discovery | DISC701–706 | 6 |
| Identity | ID701–707 | 7 |
| Signature / Integrity | INT701–707 | 7 |
| IPC Model | IPC701–708 | 8 |
| Permission | PER701–708 | 8 |
| Report / Integration | REP701–708 | 8 |
| Gate 写操作回归 | GATE701–708 | 8 |
| **合计** | | **52** |

GATE 回归覆盖：Helper 不存在、身份 Unknown、签名 Invalid、完整性 Unknown、IPC Unavailable、未授权、备份无效，以及"所有模拟条件通过仍不能绕过真实验证与授权要求"。

## 五、编译与验收状态

- 本地无 Theos / SDK / 设备，未执行真机编译；本版本结论基于静态核对、装配对账与远端 CI，**不标记为 iOS 真机编译通过或设备验收通过**。
- 校验脚本 `scripts/validate-project.js` 退出码 0；Makefile 与磁盘 `.m` 登记一致。
- 未引入 `installPackage / uninstallPackage / launchctl / system( / popen( / NSTask / posix_spawn / executeCommand` 等真实特权入口。

## 六、后续待办（不在本次范围）

- Phase 2：接入可信 Helper 端点与真实握手，落地 IPC 只读读取；
- Phase 3：在可信通道、签名锚点、协议验收与真机授权证据齐备后，开放受控真实管理；
- 旧入口 `FKHelperTrustVerifier` 仍保留重复候选选择逻辑，待后续与新 Evaluator 合并；
- `FKConfigurationBackup` 接入 BackupManager、测试骨架补强为历史遗留项，非本次阻断。
