# Stage 2.2-C3-Engine-C2-Audit：双路线完整集成回归前置审计报告

- 基线依据：Engine-A `78365be`、Engine-B `6bb34f8`、Engine-C-Audit `dd5ac27`、Engine-C1 `f86b7f0`；C3-B / C3-C1 / C3-C2 冻结实现与测试契约。
- 本轮性质：**只读审计 + 规格冻结**。未修改源码、Models、Adapters、七方法协议、Stage 1 fixtures / harness；未编译、未跑 Runner、未扫真机。
- 定位：Engine-C2（Dual-Route Full Integration Regression）不新增解析功能或路线识别机制，只验证已实现 C3 链路在完整 Engine 编排下的行为保持与隔离。

## 1. 接口审计事实表（以仓库 `f86b7f0` 现状为准）

### 1.1 输入边界（Core 中间层，复用 C2 配对模型，不新建第二套配对结构）

| 类型 | 关键签名 / 字段 | 来源 |
|---|---|---|
| `PluginPairingSnapshot` | `init(route: String? = nil, sourceDirectory: String? = nil, status: PairingStatus = .enumerated, records: [PluginPairingRecord] = [], unknownItems: [UnknownItem] = [], counts: PluginPairingCounts = PluginPairingCounts(), warnings: [ReportWarning] = [])`；`route / sourceDirectory / status / records / unknownItems / counts / warnings`，`Codable, Equatable` | `Core/PluginPairing/PluginPairingSnapshot.swift` |
| `PluginPairingRecord` | `init(category: PairingCategory, pairing: Pairing? = nil, pairingKey: String? = nil, dylib: PluginFileEvidence? = nil, plist: PluginFileEvidence? = nil, candidates: [PluginFileEvidence] = [], reason: String? = nil, basis: PairingEvidenceBasis, evidence: EvidenceBlock? = nil, warnings: [ReportWarning] = [])` | `Core/PluginPairing/PluginPairingRecord.swift` |
| `PluginFileEvidence` | `init(path: String? = nil, name: String, extension: String? = nil, kind: PluginFileKind, exists: Bool? = nil, readable: Bool? = nil, …)`；三态事实位 `nil=未验证` | `Models/PluginEnumeration/PluginFileEvidence.swift` |
| `UnknownItem` | `init(path: String? = nil, base: String? = nil, reason: String, sourceStage: String, detail: [String: String] = [:])` | `Models/PluginModels.swift` |
| `ReportWarning` | `init(code: String, message: String, sourceStage: String)` | `Models/PluginModels.swift` |
| `PairingCategory` | `paired / missingPlist("missing_plist") / orphanPlist("orphan_plist") / ambiguous / uncertain` | `Core/PluginPairing/PairingCategory.swift` |
| `PairingEvidenceBasis` | `exactFilenameMatch / noOppositeCandidate / ambiguousMultiCandidate / uncertainAccess / heldAgainstUncertain` | `Core/PluginPairing/PairingEvidenceBasis.swift` |

### 1.2 Engine 编排与依赖接缝

| 类型 | 关键签名 | 说明 |
|---|---|---|
| `PluginFilterParseEngine` | `init(reader: PlistDataReading = PlistDataReader(), decoder: PlistDecoding = PlistDecoder(), rootHideParser: FilterParsing = RootHideFilterParser(), rootlessParser: FilterParsing = RootlessFilterParser(), resolver: FilterParseRouteResolver = FilterParseRouteResolver(), builder: FilterParseSnapshotBuilder = FilterParseSnapshotBuilder())`；`func parse(snapshot: PluginPairingSnapshot) -> FilterParseSnapshot` | 六参均可注入测试桩；生产默认接冻结实现 |
| `PlistDataReading` | `func read(path: String) -> PlistReadResult` | C3-B Reader 协议 |
| `PlistDecoding` | `func decode(data: Data) -> PlistDecodeResult` | C3-B Decoder 协议 |
| `FilterParsing` | `func parse(object: Any?, pairingKey: String?, dylibPath: String?, plistPath: String?, route: String?, plistFormat: String, readStatus: String) -> FilterParseResult` | Core 内部注入接缝；`RootHideFilterParser` / `RootlessFilterParser` 经本文件扩展接入，未改各自源文件 |
| `FilterParseRouteResolver` | `init()`；`func resolve(route: String?) -> FilterParseRoute`；`roothide→.rootHide`、`rootless→.rootless`（大小写不敏感），其余含 `nil/rootful/unknown/开放串→.unknown` | 无状态纯函数；不访问文件系统、不读 plist、不实例化 Adapter |
| `FilterParseSnapshotBuilder` | `build(upstream:parsed:notParsed:) -> FilterParseSnapshot`；`buildUnresolved(upstream:) -> FilterParseSnapshot` | 纯计算：计数、目录级状态、按 code 去重告警 |
| `FilterParseIntegrationValidator` | `validate(snapshot:) -> FilterParseIntegrationResult`；`allPassed`；checks `C3B-001~007` | 完整性自洽校验，不替代 Runner 验收 |

### 1.3 Reader / Decoder / Parser 结果类型

| 类型 | 字段 / 状态词 |
|---|---|
| `PlistReadResult` | `status: PlistReadStatus`（`success / accessDenied / notFound / readFailed`）、`data: Data?`、`path: String`、`errorCode: Int?`、`errorDescription: String?`；Equatable |
| `PlistDecodeResult` | `status: PlistDecodeStatus`（`success / parseFailed("parse_failed")`）、`object: PlistDecodedObject?`、`errorDescription: String?` |
| `PlistDecodedObject` | `rootObject: Any`、`format: PropertyListSerialization.PropertyListFormat` |
| `FilterParseResult` | `pairingKey / dylibPath / plistPath / route: String?`、`status: FilterParseStatus`、`reason: String?`、`filter: FilterRule?`、`isTweakManager: Bool?`、`skippedFields: [SkippedField]`、`otherKeys: [String]`、`warnings: [ReportWarning]`、`plistFormat: String`、`readStatus: String`；`Codable, Equatable` |
| `FilterParseStatus` | `valid / parseFailed("parse_failed") / typeMismatch("type_mismatch") / readFailed("read_failed") / notParsed("not_parsed")` |
| `SkippedField` | `key: String`、`reason: String`、`expectedType: String`、`observedType: String`、`route: String`、`index: Int?` |
| `FilterRule`（公共 Models） | `bundles / classes / executables: [String]`、`coreFoundationVersion: CoreFoundationVersion?`、`otherKeys: [String]` |
| `FilterParseSnapshot` | `route / sourceDirectory / status: String / parsed: [FilterParseResult] / notParsed: [UnknownItem] / counts: FilterParseCounts / warnings: [ReportWarning]`；`Codable, Equatable` |
| `FilterParseCounts` | `valid / parseFailed / typeMismatch / readFailed / notParsed: Int`；`total` 计算属性；Codable 键 `parse_failed / type_mismatch / read_failed / not_parsed` |

### 1.4 流水线阶段（与 `PluginFilterParseEngine` 源码逐格核对）

| Stage | 判断 | 归集 / 输出 | 下游调用 |
|---|---|---|---|
| 0 | `snapshot.status == .unresolved` 或 `sourceDirectory == nil` | 空快照 + `inventory_unresolved`，状态 `unresolved` | Reader / Decoder / Parser 全 0 |
| 1 | `record.category != .paired` | `UnknownItem`，原因对齐类别（`missing_plist / missing_dylib / ambiguous / uncertain`） | 全 0 |
| 2 | 归一后 `route == .unknown` | `UnknownItem`，原因 `unknown_route`，detail 带 `route` 原值 | 全 0 |
| 3 | Reader 非 success（含 plistPath 缺失） | `read_failed`；`readStatus/reason` 词 `access_denied / read_failed`，`plistFormat=unknown` | Decoder / Parser 0 |
| 4 | Decoder `parseFailed` | `parse_failed`，reason `invalid_plist`，`plistFormat=unknown`，附 `invalid_plist` 告警 | Parser 0 |
| 5 | 唯一可信路线 Parser | 五态直传不改写；无跨路线 fallback / 重试 | 对应路线 1，另一路线 0 |

信号映射：`readStatus` `ok / access_denied / read_failed`；`plistFormat` `xml / binary / unknown`；路线证据 `FilterParseResult.route` 保持基线开放词，内部 `FilterParseRoute` 枚举不泄漏进单条结果或公共 Models。

## 2. 既有覆盖盘点（去重矩阵）

既有测试静态盘点（`Tests/Stage2/`，`func test` 计数，未经 Runner 执行）：Engine-B `FilterParseEngineTests` 19 例；Engine-C1 Parser 基线 8 例、Engine 基线 7 例；RootHide 32、Rootless 22、Reader 6、Decoder 9、PlistValueKind 11、Pairing 引擎/集成/键/索引/S105/Codable 共 96、Enumeration 14、Inventory Codable 9、Environment 7、JBROOT 28、Directory 15、Models Codable 21、B5 20、FilterParseResult 7。

| C2 场景 | 既有落点 | 已覆盖 | 缺口（C2 待补，不重复实现） |
|---|---|---|---|
| **C2-01 双路线端到端** | E-B `testRootHideRouteCallsOnlyHideParser` / `testRootlessRouteCallsOnlyRootlessParser`（桩 Parser，单条 paired）；C1-C `testFixtureEngineBaselines`（真实 Parser，但按夹具单路线快照逐条跑）；C1 Parser 测试为直调 Parser | 路线选边、调用次数、路线原值透传 | 同一快照内多插件按真实 Parser 完成端到端（Hide 快照多插件 / Less 快照多插件对称）；真实 Decoder 根对象进真实 Parser 的完整链路；Rootless 多插件端到端受 C-G2 阻塞 |
| **C2-02 五态传递** | E-B2 短路矩阵；E-B3 Reader 状态映射；E-B4 失败不跨路线；C1-C 夹具条目状态对照 | 读取失败不降级、解码失败归 `parse_failed`、不跨路线重试 | 显式「不可转换矩阵」：RootHide `type_mismatch` 不得变 `parse_failed`；Rootless Codable 失败不得变 `type_mismatch`；Reader 失败不得变 `parse_failed`；真实 Parser 结果经 Engine 直传 |
| **C2-03 多插件组合 / 失败隔离** | E-B5 `testCountsAcrossFiveBuckets`（逐条单独跑 Engine 后由 Builder 合并，非单次 Engine 批次）；C1-C `testPartialCorruptKeepsGoodAndCounts`（2 条） | 失败条目不中断兄弟条目；五桶计数与 partial 状态 | **单次 Engine 运行**混合 5 条（valid / read_failed / type_mismatch / not_parsed / valid）；首条失败后续条目仍被处理；记录顺序保持；计数 2/0/1/1/1、total 5 |
| **C2-04 Snapshot / Counts / Warnings** | E-B5 计数 / enumerated / partial；E-B6 上游 unknownItems 保留、输入不可变；C1-C 上游保留、不可变、确定性深比较；Validator C3B-001~007 | 三条计数不变量；上游归集不重分类；快照不可变；重复执行等值 | 告警合并语义专项：上游 warnings 原样保留、Engine 新增告警不覆盖上游；重复告警按 code 去重的冻结口径；确定性字段级顺序核对（记录 / UnknownItem / Warnings / Counts / SkippedField / Evidence）；必要时字段级比较（不强行要求新增 Equatable） |
| **C2-05 22 项基线完整链路** | C1 Parser 层直调结果；C1-C Engine 层经桩 Reader/Decoder + 计数包装真实 Parser | 22 项注册表、比较器、夹具/合成驱动、PARSE-010 证据 | 三层可追踪关联：Parser 单独结果 → Reader+Decoder+Parser 完整结果 → Engine Snapshot 最终结果；PARSE-015 在 #151 通过前保持待验证 |
| **C2-06 回归 / 架构隔离** | 各模块既有专项；B5 / Engine-B 隔离三向部分核对 | 模块级无回归基线；双路线 Parser 源码隔离 | C2 集中回归全量跑；C1/C2/C3-B/C3-C1/C3-C2/Engine-B 无损伤；GUI 无私有 Parser；CLI/GUI 共享 Core；七方法 Adapter 协议未演进静态核对 |

## 3. PARSE-009-B 证据对照方案（独立处理，不并入 C2 生产期望）

### 3.1 现状事实

- 夹具：`Tests/Fixtures/S1-06/parse-versions-wrong`，根对象 `{Filter:{CoreFoundationVersion:["1600"]}}`。
- 基线报告（`S1-06-report.json` 例 13，BadVer）：`skippedFields[0] = {key: CoreFoundationVersion, reason: versions_type, expectedType: number[], observedType: array}`，无 `index`。
- Swift 校验器分支（`RootHideFilterValidator.checkCoreFoundationVersion`）：值非 null、可解为数组 → 逐元素校验；元素 `"1600"` 非数字时产出 `reason: versions_type`、`expectedType: number[]`、`observedType: observedTypeWord(element)="string"`、`index: 0`，随后返回 nil。非数组分支（观测词 `array`、无 index）仅在 CFV 本身不是数组时进入。
- 既有 C3-C1 测试 `testCFVStringElementIsTypeMismatch` 只断言 `status == .typeMismatch` 与 `reason == versions_type`，未断言观测类型词与下标；Engine-C1 注册表该项只冻结 key / reason / expectedType，observedType / index 留 nil 待对照。

### 3.2 Runner 对照步骤（C2 实施期独立执行）

1. 输入：原始 PARSE-009-B 样本（只读夹具，不改文件）。
2. 调真实 RootHide Parser，导出 `SkippedField` 全量字段：`key / reason / expectedType / observedType / route / index`。
3. 逐项对照：`reason` 必须为 `versions_type`；`expectedType` 必须为 `number[]`；记录实际 `observedType` 与 `index`；补充多错误元素样本的排序口径（按数组元素顺序）。
4. 判定分叉：
   - 若 Swift 观测词 / 下标与基线一致 → 回填 C1 注册表该项期望，取消留空。
   - 若不一致 → 保留 Runner 日志；形成独立缺陷报告；先判定属 Parser 实现问题还是测试预期问题；**经独立授权后再修复**；不在 C2 提前调整期望值迁就任一侧。
5. Rootless 路线不涉及该项（CFV 由 Codable 模型口径处理）；不把 009-B 差异记入双路线隔离结论。

## 4. 门禁与 Runner 依赖表

| 门禁 | 定义（沿用 Engine-C-Audit §4） | 当前状态 | 对 C2 的约束 |
|---|---|---|---|
| C-G1 | Engine-B 外部 Runner 全过：Core Build 0 error/0 warning、E-B1~E-B6、既有回归、S1-05、App Build 与隔离 | ✅ **passed**（run `44106064051`，`FilterParseEngineTests` 19 例 0 fail / 0 skip） | 硬门禁已出证；证据归档 `evidence/run-44106064051-acceptance/` |
| C-G2 | C3-C2 Rootless Parser Runner 全过（22 例专项 + 既有回归无损伤） | ✅ **passed**（run `44106064051`，`RootlessFilterParserTests` 22 例 0 fail / 0 skip，无 Skip 隐藏） | 硬门禁已出证；Rootless 对称端到端用例本轮实际执行通过 |
| C-G3 | S1-06 22 项全部映射到 Swift XCTest 并逐项对照基线 | ✅ **passed**（run `44106064051`；注册表 22 项自校验通过，Parser 8 + Engine 7 例 0 fail） | C2-D 链路集成以 C1 注册表 / 比较器为基线 |
| C-G4 | 双路线隔离：失败不跨路线重试，未知路线零调用 | ✅ **passed**（路线选边/不回退 6 例、批次隔离 4 例；隔离脚本 1a/1b/2a/2b OK） | C2-01/02 复核通过 |
| C-G5 | 五态与 Counts 不变量：四桶和==parsed.count；notParsed==条目数；五桶和==总数 | ✅ **passed**（SnapshotWarnings 6 + CombinedScenario 5 + 集成校验器不变量断言） | C2-03/04 复核通过 |
| C-G6 | 既有回归全部通过（Models / Environment / JBROOT / Directory / Enumeration / Pairing / Reader-Decoder / 双 Parser / Engine） | ✅ **passed**（run `44106064051` 全量 379 例 0 fail / 0 skip，既有 275 例无损伤） | C2-E 集中回归通过 |
| C-G7 | App Build 成功，架构隔离通过（无 GUI 私有解析、无服务装配泄漏、七方法协议未演进） | ✅ **passed**（BUILD SUCCEEDED，PID 3508 存活；隔离第 4 项 OK；七方法签名未演进） | C2-E 执行通过；模拟器证据不等同真机权限 |

**执行序列**（依授权附件 §6）：Engine-B Runner → C-G1 Passed；C3-C2 Runner → C-G2 Passed；Engine-C1 Runner 22 项通过；三者齐备后 Engine-C2 全量回归；证据归档；C3 最终验收仅在 C-G1~G7 全过后给出。任一硬门禁未过，保持「待验收」，不宣布双路线集成完成。

## 5. 本轮未执行事项（边界留痕）

- 未落地 C2 任何测试或生产代码；未编译、未跑 Runner。
- 未修改 Core / Models / Adapters / 七方法协议 / C1 / C2 / C3-B / C3-C1 / C3-C2 / Engine-B 冻结源码与 Stage1 fixtures / harness。
- 未扫真机；未改插件文件、plist、注入配置；未做启停 / 装卸 / 写入。
- PARSE-009-B 未在本轮改 Parser 或改期望；C2 实现、C2 验收、C3 Final Acceptance 均待独立授权。
