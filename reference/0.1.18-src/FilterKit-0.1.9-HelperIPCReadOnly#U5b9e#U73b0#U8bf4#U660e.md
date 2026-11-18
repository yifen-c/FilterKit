# FilterKit 0.1.9 实现说明 — Helper IPC Read-only（真实通信边界）

## 一、阶段边界

0.1.9 在 0.1.8 Helper Foundation 基线之上，按《Helper IPC Read-only —— 真实》规划推进**服务发现、对端身份验证、握手会话、只读白名单路由、插件/配置只读数据模型与 IPC 审计事件**。本地无 Theos / SDK / 真机 / 可信发布产物与凭据，本轮只落地模型层、协议边界、白名单路由与单元测试骨架；真实 IPC 传输、独立 Helper 构建目标、真机只读数据读取属环境依赖，本地不伪造连通、不伪造读取结果。

| 边界项 | 0.1.9 状态 |
|---|---|
| 真实 Helper 连接 / 真实 Mach·Socket 传输 | 未实现；复用 0.1.8 传输抽象与 Mock 占位，正确状态为 Unavailable |
| 真机插件列表 / 注入器配置只读读取 | 未实现；强类型只读模型就位，Provider 无真实来源时标记 unsupported |
| 真实启停 / 安装卸载 / 改 Injector 配置 / 恢复系统文件 | 未开放；路由白名单外一律拒绝，门禁默认拒绝 |
| Root Daemon 真机部署 | 未创建 |
| 真实签名链验证通过 | 不宣称；签名证据保守归 Unsupported |
| 报告 schema 升级 v3 | 未升级；主报告仍 `schemaVersion: 2`，目标 v3 格式见规划 1044–1088 行 |

锁定身份口径：Product `FilterKit`；Component `FilterKitHelper`；Helper ID `com.filterkit.helper`；Protocol major 1 / minor 0；Version `0.1.9`；BuildID `FKH-019`；Manifest channel/releaseStatus `development`；主报告 `schemaVersion: 2`。

## 二、安全红线（贯穿实现）

- 服务发现只产出候选端点与元数据，不自行产生 `Verified`；系统工具候选、标识不符、元数据不足分别归类，不记为 FilterKit Helper。
- 对端验证无状态：会话变化后必须重新验证，不缓存上一连接的 Verified 结论；断开即撤销 Peer Verified。
- 握手响应中的身份字段属于待验证声明，必须与本地可信身份、清单、完整性证据比对；Nonce / 时间戳只辅助防重放，不取代身份认证。
- 服务端路由使用严格只读白名单，按方法名显式映射到已定义 Provider；不接受客户端传入任意方法名，不动态调用任意 Objective-C selector。
- 推断来源（`inferred`）与 FilterKit 自身关联记录（`filterkit_database`）不得冒充设备真实插件清单 / Injector 实际配置。
- 插件元数据可读（Readable）不等于插件安全、可注入或已启用；只读模型不携带启用 / 注入结论字段。
- 审计事件只记录动作、结果与必要元数据，不写入完整敏感配置或文件正文。
- Mock / 模拟数据只验证本地边界逻辑，必须标注 `mock`，不记录为真机已连接或已获得写权限。

## 三、模块落地（Commit 划分）

### Commit01 服务发现（SRV）
- `FKHelperServiceEndpoint`：服务名、Helper 标识、发现状态、来源、原因码与 JSON 字典。
- `FKHelperServiceDiscovery`：从候选字典映射端点；系统工具候选 → `Incomplete/system_tool_candidate`；标识不符 → `Invalid/helper_id_mismatch`；元数据缺失 → `Incomplete/metadata_incomplete`；形态完整仅记 `Found`，Discovery 不自产 `Verified`。
- `FKHelperConnectionStatus`：Unknown / Unavailable / Connecting / Handshaking / Verifying / ReadyReadOnly / Disconnected / Timeout / Rejected，含就绪与终态判定。

### Commit02 对端验证（PEER）
- `FKHelperPeerVerifier` + `FKHelperPeerStatus`（Unknown / NotConnected / Unverified / Verified / Mismatch / Rejected）。
- 未连接 → NotConnected；身份 / 元数据缺失 → Unverified；Helper ID 或 BuildID 不符 → Mismatch；清单非 verified → Rejected；身份经本地证据验证且标识 / 清单一致 → Verified。验证器不缓存旧会话结论。

### Commit03 握手与会话（HSK）
- `FKHelperSession`：状态机 Disconnected / Connecting / Handshaking / Verifying / ReadyReadOnly / Failed / Closed；进入失败 / 断开 / 关闭态撤销 peerVerified；`isReadOnlyReady` 要求就绪态且对端已验证。
- `FKHelperHandshakeValidator`：校验请求标识、Nonce、时间窗、协议版本、Helper ID、清单状态、对端证据与能力边界；返回机器可读拒绝原因码，空数组表示通过。
- 既有 `FKHelperIPCHandshakeRequest/Response`、`FKHelperHandshake` 承载握手报文，本轮不重复新建 HelloRequest/Response。

### Commit05 请求白名单路由（RTE）
- `FKHelperRequestRouter`：结构校验（请求类型、请求标识）+ 严格只读白名单；非白名单方法（含全部写方法）返回 `UnsupportedMethod` 错误响应；白名单方法按显式 if 映射到 `FKHelperReadOnlyProvider`，不做任意 selector 调用；Provider 为空时返回 `source: unsupported` 的空数据响应，不伪造真实记录。

### Commit06 插件 / 配置只读模型（PLG / CFG）
- `FKHelperPluginInfo`：标识、显示名、文件名、来源、架构、文件大小、SHA256、BundleID、InjectorID、检查状态与证据来源；`FKPluginInspectionStatus`（Unknown / Readable / Incomplete / Invalid / Unsupported）；`isFromRealReadSource` 仅认可 `injector_api` / `filesystem_metadata`。
- `FKHelperConfigurationSnapshot`：快照标识、InjectorID、模式版本、条目、采集时间、来源、SHA256、校验状态；`FKConfigurationValidationStatus`（Unknown / Valid / Incomplete / Invalid / Unsupported / Unavailable）；`isConfirmedValid` 要求只读接口确认且状态有效。

### Commit07 IPC 审计事件（AUD）
- `FKHelperIPCAuditEvent` + `FKAuditHelperIPCAction`（Connect / Disconnect / Handshake / PeerVerify / CapabilityFetch / PluginList / PluginInspect / ConfigurationRead / Rejected）。
- 事件模型只保存事件 ID、时间戳、来源、动作、结果、HelperID、请求 ID、原因码与记录数；不承载配置 / 文件正文。真实持久化落库待环境接入。

## 四、自动化测试

21 个测试套件，统一范式：`+checkCount` 与 `+runChecks`（返回失败描述数组，空 = 全过）；`FKTestRunner` 在 `suites`、`classes`、`names` 三处同步注册。本地静态核对合计 **238** 断言（基线回归 168 + 0.1.9 新增 70）。

### 0.1.9 新增套件

| 套件 | 编号 | 数量 |
|---|---|---|
| discovery | SRV901–908 | 8 |
| peer | PEER901–908 | 8 |
| handshake | HSK901–912 | 12 |
| router | RTE901–910 | 10 |
| plugin | PLG901–912 | 12 |
| configuration | CFG901–910 | 10 |
| audit | AUD901–910 | 10 |

### 基线回归套件（沿用 0.1.8）

model、backup、json、operation、trust、identity、metadata、manifest、integrity、protocol、transport、report、capability、gate，共 14 套件 168 断言；其中 `gate`（GATE801–810）同时承担 0.1.9 门禁回归，未另建 GATE9 重复套件。

## 五、规划覆盖与未落地项

| 规划组 | 编号 / 数量 | 本轮状态 |
|---|---|---|
| Service Discovery | SRV901–908 / 8 | 已落地 |
| Peer Verification | PEER901–908 / 8 | 已落地 |
| Handshake | HSK901–912 / 12 | 已落地 |
| Transport | IPC901–912 / 12 | 环境依赖：复用既有传输抽象与 Mock，真实 Mach / Socket 传输未实现，本轮不铺用例 |
| Request Router | RTE901–910 / 10 | 已落地 |
| Plugin Read-only | PLG901–912 / 12 | 模型与边界已落地；真实读取待 Provider 接入 |
| Configuration Read-only | CFG901–910 / 10 | 模型与边界已落地；真实读取待 Provider 接入 |
| Audit / Report | AUD901–910 / 10 | 事件模型已落地；真实落库待环境接入 |
| Gate Regression | GATE901–910 / 10 | 复用既有 `gate` 套件回归 |

### 待环境 / 后续迭代

- 真实 Helper 构建目标与独立 Helper 进程形态、真实 Mach / Socket 通道、会话来源与消息大小校验，待 RootHide 目标环境与可信发布产物确认。
- `FKHelperHealthInfo`、`FKHelperIPCReport` 聚合模型尚未单列；当前 IPC 段复用既有 `FKHelperTrustReport` 分层字段。
- 主报告 schema v3（含 `peerStatus`、`session`、`dataSources` 等单列字段）待真实连接与各项验证完成后再升级；本轮不把本地摘要 / 自报信息输出为 Verified。
- 服务端 Provider 的真实只读读取（插件元数据、文件属性、架构、摘要；Injector 配置只读接口）须在不加载 / 不执行 dylib、不修改 Injector 私有文件格式的前提下接入。
- 快照恢复仍只允许恢复 FilterKit 自身历史记录与缓存数据，不恢复系统插件文件或 Injector 配置。

## 六、构建与校验

- 平铺目录结构（`Sources/Helper/` 等）；新增 `.m` 同步登记 `Makefile` 的 `FilterKit_FILES`、`scripts/validate-project.js` required 清单与套件注册检查、`FKTestRunner` 三处数组；头文件与实现配对。
- 本地 `validate-project.js` 为静态核对，不代表 Theos 编译或真机验收；本地无编译器，结论以静态扫描与模型边界核对为准。
- **CI 编译修复**：`FKHelperConnectionStatus` 原将状态枚举与工具宿主类同名，触发 `redefinition of ... as different kind of symbol`（-Werror）。已将工具宿主类改名为 `FKHelperConnectionStatusCodec`，枚举名保留；`FKHelperDiscoveryTests` 调用同步更新。全工程交叉扫描枚举标签名与 `@interface` 类名，无其他同名冲突。
- **第二轮 CI 修复**：`FKHelperHandshakeValidator.m` 使用 `FKHelperProtocolVersion`（声明于 `FKHelperProtocol.h`）但未导入该头文件，报 `use of undeclared identifier`。已补 `#import "FKHelperProtocol.h"`；其余本轮新增 Helper 文件的类型引用与头文件导入已静态核对。
- **第三轮 CI 修复**：`FKHelperAuditTests.m` 中将方法名点访问 `e.JSONDictionary` 的返回值直接接下标订阅并作为消息接收方（`[e.JSONDictionary[@"result"] ...]`），方括号嵌套触发 `expected identifier`。已改为先取局部字典变量再下标；其余已编译通过的既有下标写法未改动。
- **真机回归修复（RTE906）**：无 Provider 时 Router 提前统一兜底成 `records` 骨架，`plugin.list` 分支未执行，导致响应缺少空 `plugins` 数组。已改为无 Provider 时按方法返回空骨架：`plugin.list` 返回 `@{@"source": @"unsupported", @"plugins": @[]}`，`plugin.inspect` 返回仅含 `source` 的骨架，其余保留 `records` 空数组；不伪造任何记录。该用例需重新打包真机复测确认 238 断言全绿。

## 七、发布口径

**可宣称**：服务发现分层模型建立；对端身份验证边界建立；握手 / 会话状态机建立；服务端严格只读白名单路由建立；插件 / 配置强类型只读模型与来源证据边界建立；IPC 审计事件模型建立；既有门禁与只读能力模型回归通过。

**不可宣称**：已连接真实 Helper；已实现真实 IPC 插件 / 配置读取；真实启停；改 Injector 配置；安装 / 删除插件文件；恢复系统文件；Root Daemon 真机部署；通过真实签名链验证。
