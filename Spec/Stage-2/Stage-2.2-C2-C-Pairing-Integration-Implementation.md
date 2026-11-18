# Stage 2.2-C2-C：C1 Enumeration → C2 Pairing 集成桥接实现记录（代码冻结，Runner 验收待授权）

- 状态：**Implementation Complete / Local Static Review Passed**；**Runner Build & Test 未执行**（本机 Linux 无 Swift 工具链；编译、C2-A/B/C 与既有/S1-05 回归统一纳入 C2-D Runner 验收）。既有 114 例（B 91 + C1 23）与 Stage 1 基线未改动。
- 依据：C1 验收 `5b481e6`、G-C3 契约 `7dbac87`、C2-A 冻结 `cc5c98e`、C2-B 冻结 `35d8d76`、集成契约 `Stage-2.2-C2-C-Pairing-Integration-Contract.md`。
- 批次定位：C2-C 只验证 C1 快照 → C2 快照的 Core 内部数据流衔接；不重写枚举/配对算法，不接服务层。C2-D 完整 Runner 验收不在本批。

## 1. 本轮授权边界

### 已允许并执行

- `PluginPairingInput`：配对输入视图（route/sourceDirectory/enumeration/files/unknownItems/warnings）。
- `PluginPairingInputAdapter`：C1 快照 → 输入视图；仅过滤 dylib/plist，字段原样搬运。
- `PluginPairingPipeline`：纯编排，组合适配器视图与 C2-B 冻结引擎。
- `PluginPairingIntegrationResult` / `PluginPairingIntegrationCheck`：内部核对结果模型（不入公共 Models、不进信封）。
- `PluginPairingIntegrationValidator`：INT-C2-001 ~ 014 逐项完整性校验。
- 集成专项测试 32 例（A 输入转换 8 / B 状态告警 7 / C 配对行为 9 / D 稳定性隔离 8）；`Package.swift` 登记新源与测试源。

### 禁止项（本轮均未触碰）

- 未修改 C1 枚举器/Models、C2-A 冻结模型、C2-B 冻结引擎、七方法协议、双路线 Adapter、Stage 1 fixtures/harness、既有通过测试。
- 未接入 `PluginScanService` / `AdapterResolver`；未实例化具体 Adapter；未演进服务协议；未做 GUI 展示。
- 未编译、未跑 Runner、未扫描真机；无插件文件修改、软链改动、注入配置修改或启停。
- 未进入 C2-D；快照未进 `ReportEnvelope`，未组装最终 `Plugin`。

## 2. 文件清单

| 文件 | 模块 | 职责 |
|---|---|---|
| `Core/PluginPairing/Integration/PluginPairingInput.swift` | Core | 配对输入视图结构（Equatable） |
| `Core/PluginPairing/Integration/PluginPairingInputAdapter.swift` | Core | 类型过滤 + 字段原样搬运；不重扫/不重读/不重算哈希 |
| `Core/PluginPairing/Integration/PluginPairingPipeline.swift` | Core | 编排入口；原始快照原样入引擎，执行前后不改写 |
| `Core/PluginPairing/Integration/PluginPairingIntegrationResult.swift` | Core | 核对结果 + 单项检查记录（内部辅助） |
| `Core/PluginPairing/Integration/PluginPairingIntegrationValidator.swift` | Core | 14 项完整性校验纯计算 |
| `Tests/Stage2/PluginPairingIntegrationTests.swift` | Test | 四组 32 例集成专项测试 |

## 3. 状态传递矩阵（审计 C2-B 实际实现）

| C1 EnumerationStatus | C2 行为 | C2 PairingStatus | C2-B 实现核对 |
|---|---|---|---|
| `enumerated` | 正常配对；uncertain >0 降级 partial | `enumerated` / `partial` | ✅ `SnapshotBuilder`：uncertain 存在 → partial |
| `partial` | 保留可用证据并配对 | `partial` | ✅ 枚举 `.partial` 直通 partial |
| `enumeration_failed` | 不生成记录 | `enumeration_failed` | ✅ `Engine.isUnresolved` 短路；保留归集/告警 |
| `unresolved` | 不生成记录 | `unresolved` | ✅ 目录缺失/未决短路；`inventory_unresolved` 在位 |

- 两类状态原始值同名但语义分属阶段：桥接层不共享枚举类型，不通过原始字符串跨阶段判状态。
- 失败/未决目录不猜测身份；五桶计数全 0；C1 unknownItems/warnings 保留，C2 告警追加在后不覆盖。

## 4. 完整性验收对照（INT-C2-001 ~ 014）

| 编号 | 口径 | 落地 |
|---|---|---|
| 001 | route 原样传递 | 校验器比对 `snapshot.route == baseline.route` |
| 002 | sourceDirectory 原样传递 | 同上目录位比对 |
| 003 | dylib/plist 证据完整传递 | `input.files` 与 C1 候选集合 `Equatable` 相等 |
| 004 | 非候选不入配对索引 | 记录两侧位 + candidates 证据类型全为 dylib/plist |
| 005 | unknownItems 不丢失 | C1 每条 unknownItem 原样包含于输出 |
| 006 | warnings 不丢失 | C1 每条 warning 原样包含于输出 |
| 007 | entryStatus 不被改变 | 视图与 C1 候选逐条状态比对 |
| 008 | `readable=nil` 不转 false | 视图与 C1 候选逐条三态位比对 |
| 009 | unresolved 正确处理 | 状态/空记录/零计数/告警在位 |
| 010 | partial 正确处理 | 状态 partial 且 C1 告警保留 |
| 011 | 五桶计数互斥 | 五桶之和 = records.count，total 一致 |
| 012 | 输入快照前后一致 | baseline 与 after 深比较相等 |
| 013 | 重复执行一致 | 二次执行快照与首次 `Equatable` 相等 |
| 014 | 路线不交叉转换 | 输出/输入路线均等于 C1 原值，无跨路线套用 |

## 5. 测试映射（32 例）

### A. 输入转换（8）
仅 dylib / 仅 plist / 混合 / directory 排除 / symlink 排除 / other 排除 / 原始字段不变 / 空目录。

### B. 状态与告警传递（7）
enumerated 正常 / partial 保留证据 / enumeration_failed 短路 / unresolved 短路 / unknownItems 保留 / warnings 保留 / 新增告警不覆盖原有告警。

### C. 配对行为集成（9）
单组配对 / 缺 plist / 孤儿 plist / 多 dylib 歧义 / 多 plist 歧义 / 受限 uncertain / readable nil 且 ok / 计数互斥 / Pairing 四值兼容。

### D. 稳定性与隔离（8）
打乱顺序稳定 / 重复 100 次一致 / 输入快照不变 / RootHide 路线隔离 / Rootless 路线隔离 / 不读 plist 内容 / 不访问真实文件系统 / 原始数据不被修改。

> S1-05 原始 15 例行为映射回归归 C2-D Runner；本批集成测试不替代该基线。

## 6. 静态审查记录与未决项

- 隔离核对：5 个新 Core 源仅 `import Foundation`/`Models`；无 Adapter/Resolver/Service 引用；隔离脚本三向通过。
- 括号平衡、类型引用、初始化参数按既有范式静态核对；本机无工具链，编译结果以 C2-D Runner 出证为准。
- 待 C2-D 实测：C1 目录状态透传在真实枚举链路下的表现、不可读文件保留、unknownItems/warnings 完整传递、两侧目录作用域一致、C2 始终不读 plist 内容。
- 2.2-A R6（未知枚举原始值默认解码行为）仍未实测；本批未新增枚举原始值。
- 若后续发现 C2-A/B 冻结模型无法承载集成需求，先报告契约冲突，不得直接改冻结代码。

## 7. 非目标

- `PluginScanService`/`AdapterResolver` 装配、协议演进、GUI、真机扫描、启停与文件修改。
- C3 Filter 解析、S1-07 归属、S1-08 导出；C2-D 编译与全量回归。

## 8. 下一阶段门槛

- **C2-D 授权前**：本批静态审查通过；C1/C2-A/C2-B/协议/Adapter/夹具/既有测试零改动。
- **C2-D Runner 验收门槛**：Swift Build 通过；Swift Test 零失败；既有 114 例 + C2-A 12 + C2-B 37 + C2-C 32 不回退；S1-05 15 例通过；五桶互斥、三态保留、确定性与隔离正确；App Build 成功；Stage 1 基线不被修改。
