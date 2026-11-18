# FilterKit 0.1.10 实现说明

## 版本定位

**0.1.10 — Helper Read-only Boundary Hardening**

本版本以用户上传的 `FilterKit-0.1.9-source.zip` 为唯一代码基线，在既有平铺目录和类体系上做增量修改。它不是把 0.1.9 目录树推倒重建，也不是把 0.1.9 的模型骨架描述成真实 IPC 已完成。

0.1.10 继续保持 `preview_only` / `allowsRealOperation = NO`：不启用或禁用插件、不加载或执行 dylib、不写 Injector 配置、不修改 Filter 规则、不发送进程信号、不恢复系统文件。

## 一、承接决策

| 争议点 | 0.1.10 决策 |
|---|---|
| 目录 | 保持 `Sources/Helper/` 平铺，不迁移子目录 |
| 能力评估器 | 复用 `Sources/Security/FKCapabilityEvaluator.*`，不新增 `FKHelperCapabilityEvaluator` |
| IPC 审计模型 | 复用 `FKHelperIPCAuditEvent`，增加 `buildID`、`sessionID` 和 Helper Info/Health 读取动作 |
| Manifest | 复用 `FKHelperTrustManifest`、`FKHelperManifestVerifier`、`FKHelperReleaseMetadata`，不新增第二套 Manifest |
| Session | 复用 `FKHelperSession`，只补 `sessionID` 字段，不重复 typedef 状态枚举 |
| 报文 | `FKHelperMessage` 是 v1 只读报文的唯一规范模型；`FKIPCRequest` / `FKIPCResponse` 保留为旧接口兼容模型，不新增 `FKHelperRequest` / `FKHelperResponse` |
| Discovery | 复用 `FKHelperServiceEndpoint` / `FKHelperServiceDiscovery`；现有实现是候选元数据映射，不等于已完成真实 launchd 服务发现 |

所有 0.1.9 历史实现说明保留原样，避免把旧版本文件伪装成 0.1.10 产物。

## 二、0.1.10 已修改的代码

### 1. 协议报文严格化

文件：
- `Sources/Helper/FKHelperMessage.h/.m`
- `Sources/Helper/FKHelperMessageError.h/.m`

改进：
- JSON 反序列化要求完整字段和正确字段类型，不再把缺失字段静默填成默认值。
- 非法 `messageType` 直接拒绝，不再 clamp 成合法枚举。
- 1 MiB 上限应用于完整 JSON 报文，而不只是 payload。
- Request 必须有非空 Nonce；新增独立 `invalid_nonce` 错误码。
- Response 必须有合法状态；错误响应必须携带错误对象。
- `matchesResponse:` 同时核对 Request ID、方法名、协议主/次版本和响应结构。
- Nonce Cache 会清理过期项并限制最多 4096 项，避免长期运行时缓存无界增长。

Nonce / 时间戳仍只承担防重放辅助职责，不构成身份认证或消息完整性保护。

### 2. 服务端 Router 二次校验

文件：`Sources/Helper/FKHelperRequestRouter.m`

改进：
- Router 自己调用 `validateWithError:`，不假设客户端已校验。
- 服务端 Nonce Cache 拒绝重复请求。
- 白名单外方法在进入 Provider 前拒绝。
- `capabilities.list` 返回 `capabilities` 数组，不再误用通用 `records` 字段。
- `config.inspect` 无 Provider 时返回 `source=unsupported`、空 `entries` 和 `validationStatus=unsupported`。
- `plugin.inspect` 缺少 pluginID 时拒绝；未找到记录时返回 `found=false`。
- 无 Provider 时只返回 Unsupported 空骨架，不伪造真实插件或配置数据。

### 3. 只读客户端准入与响应验证

文件：`Sources/Helper/FKHelperReadOnlyClient.h/.m`

改进：
- Mock Transport 即使错误报告 `connected=YES` 也不能被生产客户端接受。
- 原有单参数 initializer 保留兼容，但不会凭空创建可信 Session；没有 ReadyReadOnly Session、信任报告和只读能力集合时，请求在发送前拒绝。
- 发送前通过既有 `FKCapabilityEvaluator` 逐项评估能力。
- 响应必须通过报文解析、请求关联、方法和协议版本校验。
- Helper 的 error 响应映射为 NSError 并保留 reasonCode。
- 能力响应混入未知/写能力时整份拒绝；插件列表包含非法记录时拒绝。
- 新增 Helper Health、Plugin Inspect、Configuration Snapshot 只读 API。
- 请求等待期间若 Session 被关闭或 Peer 状态失效，返回的旧响应会被丢弃。
- 增加可注入 `auditEventHandler`，避免客户端直接依赖具体审计存储实现。

注意：当前项目没有真实生产 Transport，因此这里的 `connected` / 测试夹具不等于真实 IPC 连接。没有真实、已验证 Transport 时，审计来源保持 `unsupported` 或 `mock`，不会冒充 `real_ipc`。

### 4. Peer 与能力证据门槛收紧

文件：
- `Sources/Helper/FKHelperPeerVerifier.m`
- `Sources/Security/FKCapabilityEvaluator.m`

Peer Verified 现在同时要求：
- Helper 身份字段整体匹配（包含组件、版本、Build ID、协议版本）。
- 候选元数据标识匹配，文件存在、为常规文件且可执行。
- 候选不是系统工具。
- Manifest 状态为 verified。
- 签名状态为 Valid/Verified 且 `signatureVerified=YES`。
- 完整性状态为 Verified。
- 权限检查通过，只读允许、写权限关闭。
- IPC 状态 Connected 且 `ipcVerified=YES`。

任一关键证据缺失时返回 Unverified / Mismatch / Rejected，不以握手成功或自报字段代替信任证据。

### 5. IPC 审计事件持久化

文件：
- `Sources/Helper/FKHelperIPCAuditEvent.h/.m`
- `Sources/Managers/FKAuditManager.h/.m`

改进：
- IPC 事件增加 `buildID`、`sessionID`。
- 增加 Helper Info / Health 读取动作。
- 增加事件字典安全重建接口。
- `FKAuditManager` 持久化 schema 从 2 升至 3。
- 新增 `appendHelperIPCAuditEvent:` 与 `helperIPCAuditEvents`。
- 原操作历史继续读取；旧 schema v2 文件没有 `helper_ipc_events` 时按空数组迁移。
- JSON 导出与 persistenceStatus 包含 IPC 事件计数和事件列表。
- 存储仍只位于 App 沙盒，不写越狱系统目录。

只读客户端通过 `auditEventHandler` 暴露事件回调；实际 App 装配时可绑定到 `FKAuditManager.appendHelperIPCAuditEvent:`。当前没有真实 IPC 请求，因此不能宣称已经产生真实设备通信审计记录。

## 三、版本号和发布元数据

| 项目 | 0.1.9 上传基线 | 0.1.10 工作副本 |
|---|---|---|
| App Version | 0.1.9 | 0.1.10 |
| CFBundleVersion | 1 | 110 |
| Helper Version Contract | 0.1.9 | 0.1.10 |
| Helper Build ID | FKH-019 | FKH-0110 |
| Protocol | 1.0 | 1.0（不做不兼容协议升级） |
| Manifest Channel | development | development |
| Helper Artifact | 空 | 空 |
| Trusted Signing Key | 未配置 | 未配置 |

`Resources/Helper/helper-release-manifest.json` 仍为 development，`artifacts` 为空，签名身份、Key ID 和 SHA256 锚点均为空。版本字段更新只是开发合同更新，不代表已生成或签名 Helper 二进制。

## 四、Helper 部署、权限和 IPC 环境风险

以下是 0.1.10 的未完成门槛，不通过文档或 Mock 代替：

1. **进程拉起方式未锁定**：需要在目标 RootHide arm64e 真机验证 launchd Mach Service 注册、按需启动和生命周期；未创建 LaunchDaemon plist，也未安装或启动 Root Daemon。
2. **权限 / Entitlements 未验收**：必须明确 App 与 Helper 的运行身份、Mach Service 访问控制、必要 entitlements、沙盒可见路径和文件访问范围；当前没有真实 Helper Target 可供验证。
3. **传输机制未锁定**：先做 Mach bootstrap lookup / Mach IPC 与受控 Unix Socket 的可行性探针，再根据真实对端身份能力和路径约束决定；不能仅凭 API 可编译就宣布可用。
4. **消息完整性保护未完成**：Nonce 不等于 MAC。真实 Transport 必须提供可验证的对端身份绑定和会话消息完整性保护；未完成前不能把会话标为 ReadyReadOnly。
5. **签名链仍 Unsupported/Unknown**：平台当前签名验证能力和可信发布锚点尚未验收。不能通过放宽 PeerVerifier 来绕过此缺口。

### Transport 可行性探针验收

- 只在 RootHide arm64e 测试设备上验证服务注册和客户端发现。
- 用无敏感数据的只读 Echo / Helper Info 请求验证双向通信。
- 验证连接端身份、Build ID、协议版本和消息完整性。
- 验证服务重启、App 重启、断线、超时和无权限场景。
- 若平台无法提供可靠 Peer 证据，Transport 结果保持 Unsupported，不进入真实只读数据读取。

## 五、测试与验证结果

- `FKTestRunner` 注册 22 个套件。
- 静态声明测试点合计 264 项（0.1.9 的 238 项 + 0.1.10 新增/扩展 26 项）。
- 新增边界套件 `FKHelperBoundaryTests`，覆盖 Mock 隔离、未验证 Session 拒绝、响应 ID/方法/协议匹配、错误响应、能力污染、插件列表结构、配置读取和审计回调。
- 扩展协议、Peer、Router、Audit 测试。
- `node scripts/validate-project.js`：通过。

**未执行 / 未通过声明：** 当前执行环境没有 Theos、iOS SDK、签名凭据或目标真机；因此没有宣称 Objective-C 真正编译通过、CI 通过、真实 IPC 连通、签名链通过或 RootHide 真机验收通过。264 是登记的断言数，不是本轮实际执行通过数。

## 六、0.1.10 当前状态

| 项目 | 状态 |
|---|---|
| 0.1.9 类盘点与复用决策 | 完成 |
| 目录结构统一（保持平铺） | 完成 |
| 报文模型统一（FKHelperMessage v1） | 完成 |
| 严格消息解析与响应关联 | 已实现，待编译测试 |
| 客户端会话/能力双重准入 | 已实现，待编译测试 |
| Router 二次校验与 Nonce 防重放 | 已实现，待编译测试 |
| Peer 证据门槛收紧 | 已实现，待编译测试 |
| IPC 审计沙盒持久化接口 | 已实现，待真机验证写入/重启读取 |
| 真实 Helper Target | 未实现 |
| 真实 Mach/Socket Transport | 未实现 |
| Helper 拉起、Entitlements、权限验收 | 未实现 |
| 可信签名链 | 未实现 |
| 真实插件/配置只读读取 | 未实现 |
| 真实启停和写操作 | 明确禁止 |

## 七、后续 Commit 顺序

1. **Commit 01 — Service Discovery Evidence**：在既有 `FKHelperServiceEndpoint` / `FKHelperServiceDiscovery` 上接真实 launchd / 文件系统证据；不重建类。
2. **Commit 02 — Helper Deployment Feasibility**：确定 Helper Target 形态、拉起方式、entitlements、运行身份和权限范围；先做部署探针，不安装系统级持久化组件。
3. **Commit 03 — Transport Feasibility Probe**：在真机上对 Mach IPC / Socket 做只读连通性和 Peer 证据测试。
4. **Commit 04 — Authenticated Session Integrity**：建立对端身份绑定和消息完整性保护；没有可验证方案则保持 Unsupported。
5. **Commit 05 — Real Read-only Provider**：先 Helper Info / Health，再插件元数据；Injector 配置接口无正式支持时继续 Unsupported。
6. **Commit 06 — App Integration & Device Tests**：接入 Scanner、报告、UI、审计回调并做 RootHide arm64e 真机验收。

所有 Commit 继续保持写操作双端拒绝。只有上述真实只读链路完成并独立验收后，才讨论 0.2.0 的受控写操作。
