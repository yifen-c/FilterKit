# Stage 2.2-C3-Engine-A：双路线 Parser Engine 前置接口审计报告

> 批次定位：Stage 2.2-C3-C3 第一批（C3-Engine-A，前置只读审计）。基线提交 `12bcd73`（C3-C2 代码冻结，Runner 待出证）。
> 状态：**只读审计完成 / 契约待 Engine-B 实现授权**；本文件只记录审计事实、既有接口复用面、建议示意与冻结契约的对照结论、缺口与待评审项，**未落地任何 Swift 代码**。
> 关联规格：[Stage-2.2-C3-Parser-Data-Contract.md](./Stage-2.2-C3-Parser-Data-Contract.md)（PC3-1~14、§5.4/5.6/5.7、§10.1 目录分层）、[Stage-2.2-C3-C1-RootHide-Parser-Implementation.md](./Stage-2.2-C3-C1-RootHide-Parser-Implementation.md)、[Stage-2.2-C3-C2-Rootless-Parser-Implementation.md](./Stage-2.2-C3-C2-Rootless-Parser-Implementation.md)、[Stage-2.2-Core-Models-Migration.md](./Stage-2.2-Core-Models-Migration.md)。
> 输入基线：C3-C1 已验收（run `43993649974`，275 例 0 失败）；C3-C2 代码冻结待 Runner；C2 Pairing 已验收；C3-B Reader/Decoder 已验收；S1-06 离线基线 22 例（`Tests/S1-06/`、`Tests/Fixtures/S1-06/`）。

## 1. 本轮授权边界

### 已允许并执行（本地离线只读）

- 只读核对现有 `Models/`、`Core/PluginPairing/`、`Core/PlistParser/`、`Adapters/` 协议、既有测试结构与 Stage 1 S1-06 基线，梳理 Engine 输入衔接面、可复用类型与状态传递口径。
- 撰写本审计报告、Engine 数据契约冻结文档与测试计划（设计层）。

### 禁止项（本轮均未触碰）

- 未修改任何源码、`Models/`、`Adapters/`、七方法协议、Stage 1 fixtures/harness/metadata 及既有 Swift 测试。
- 未编译、未执行 GitHub Actions Runner、未扫描真机、未读取未配对 plist、未修改任何 plist 或插件文件。
- 未实现 Engine / `FilterParseSnapshot` / `FilterParseCounts` / `PluginParseInput` 落地代码；未进入归属识别、统一导出、服务装配与 GUI。

## 2. 既有接口清单（审计事实，以仓库现状为准）

### 2.1 C2 配对快照与记录（已验收冻结）

| 类型 | 文件 | Engine 可用字段 | 用途 |
|---|---|---|---|
| `PluginPairingSnapshot` | `Core/PluginPairing/PluginPairingSnapshot.swift` | `route: String?`、`sourceDirectory: String?`、`status: PairingStatus`、`records: [PluginPairingRecord]`、`unknownItems: [UnknownItem]`、`counts: PluginPairingCounts`、`warnings: [ReportWarning]` | Engine 唯一上游快照；路线、目录、记录、归集条目与告警原样透传 |
| `PluginPairingRecord` | `Core/PluginPairing/PluginPairingRecord.swift` | `category: PairingCategory`、`pairing: Pairing?`、`pairingKey: String?`、`dylib: PluginFileEvidence?`、`plist: PluginFileEvidence?`、`candidates: [PluginFileEvidence]`、`reason: String?`、`basis: PairingEvidenceBasis`、`evidence: EvidenceBlock?`、`warnings: [ReportWarning]` | 逐条配对记录；仅 `.paired` 进入解析管线 |
| `PluginFileEvidence` | `Models/PluginEnumeration/PluginFileEvidence.swift` | `path: String?`、`name`、`extension`、`kind`、`exists/readable/isSymlink` 等 | plist 路径取 `record.plist?.path`；dylib 路径取 `record.dylib?.path`；证据原样引用 |
| `PairingCategory` | `Core/PluginPairing/PairingCategory.swift` | `paired / missingPlist("missing_plist") / orphanPlist("orphan_plist") / ambiguous / uncertain` | 五桶互斥归类；非 `paired` 一律 `not_parsed` |
| `UnknownItem` | `Models/PluginModels.swift` | `path: String?`、`base: String?`、`reason: String`、`sourceStage: String`、`detail: [String: String]` | 非配对条目与 C2 归集条目的归集载体 |

### 2.2 Reader / Decoder（C3-B 已验收）

| 接缝 | 签名 / 结果 | 状态封闭集 |
|---|---|---|
| `PlistDataReading`（协议） | `func read(path: String) -> PlistReadResult` | `PlistReadStatus`: `success / notFound / accessDenied / readFailed` |
| `PlistReadResult` | `status: PlistReadStatus`、`data: Data?`、`path: String`、`errorCode: Int?`、`errorDescription: String?`；失败 `data` 恒 `nil` | — |
| `PlistDecoding`（协议） | `func decode(data: Data) -> PlistDecodeResult` | `PlistDecodeStatus`: `success / parseFailed("parse_failed")` |
| `PlistDecodeResult` | `status`、`object: PlistDecodedObject?`、`errorDescription: String?`；失败 `object` 恒 `nil` | — |
| `PlistDecodedObject` | `rootObject: Any`、`format: PropertyListSerialization.PropertyListFormat` | 根对象仅限 Core 内部消费 |

### 2.3 双路线 Parser（C3-C1 已验收 / C3-C2 冻结待 Runner）

| Parser | 路线标识 | 入口签名 |
|---|---|---|
| `RootHideFilterParser` | `static let routeName = "roothide"` | `parse(object: Any?, pairingKey: String? = nil, dylibPath: String? = nil, plistPath: String? = nil, route: String? = "roothide", plistFormat: String = "unknown", readStatus: String = "ok") -> FilterParseResult` |
| `RootlessFilterParser` | `static let routeName = "rootless"` | 同签名；证据归属固定 `rootless` |

- 单条结果 `FilterParseResult`（C3-C1 冻结）：`pairingKey / dylibPath / plistPath / route / status: FilterParseStatus / reason / filter: FilterRule? / isTweakManager: Bool? / skippedFields: [SkippedField] / otherKeys: [String] / warnings: [ReportWarning] / plistFormat / readStatus`。
- 五态 `FilterParseStatus`：`valid / parseFailed("parse_failed") / typeMismatch("type_mismatch") / readFailed("read_failed") / notParsed("not_parsed")`，互斥。
- 两个 Parser 均不访问文件系统、不调用 Reader/Decoder、不接 Engine；双路线规则独立、互不引用。

### 2.4 路线唯一可信来源链（审计结论）

现有透传链（C1 → C2，B5 桥接原样传递，校验项 INT-C2-001）：

```
PluginInventorySnapshot.route
  → PluginPairingInput.route（InputAdapter 原样映射）
  → PluginPairingSnapshot.route（SnapshotBuilder 原样写入）
```

- 上游 B1：`EnvironmentDetectionResult.jailbreakType: String` + `outcome: String`；`EnvironmentRouteMapper` 归一为 `roothide / rootless / rootful`；冲突（`conflict_no_profile`）/ 未识别 → `nil`，不强行选边。
- 公共 Models：`JailbreakEnvironment.jailbreakType: JailbreakType`（`roothide / rootless / unknown`）。
- **审计结论**：Engine 的路线只认 `PluginPairingSnapshot.route`（已确认 Profile 的透传值）；`PluginPairingRecord` 自身不携带路线字段。Engine 不得根据记录路径、文件名、插件来源或 plist 内容反推路线。

## 3. 建议示意 vs 冻结契约 / 实际代码 对照

> 对照输入：用户建议 MD（C3-C3 三批次拆分，C3-Engine-A 只读审计授权文本）；冻结依据：C3 Parser 数据契约 PC3-1~14 与 §5/§10.1。

| # | 建议示意 | 仓库现状 / 冻结契约 | 审计结论 |
|---|---|---|---|
| 1 | `enum FilterParseRoute: String { rootHide / rootless / unknown }` | 现有契约全链路路线字段为 `route: String?`，基线词汇 `roothide / rootless / unknown`；Parser `routeName` 字符串为 `roothide`（全小写） | Engine 内部可新增归一化枚举（Core 中间层，不进公共 Models）；枚举原始值必须对齐基线字符串；证据 `route` 字段保持 `String?`，不把枚举类型泄漏进 `FilterParseResult` |
| 2 | `FilterParseInput { pairingSnapshot, route }` 双参 | 契约 PC3-1：唯一上游为 `PluginPairingSnapshot`；快照已携带 `route`；记录级输入按 §5.4 `PluginParseInput { record, route, read }` | **拒绝第二事实来源**：快照级入口只收 snapshot，路线取自 `snapshot.route`；不提供可与快照冲突的外部 route 覆盖参数 |
| 3 | `Resolver.resolve(environment: JailbreakEnvironment) -> FilterParseRoute` | 实际上游是经 B5 透传的 `snapshot.route`；`JailbreakEnvironment` 属服务装配层模型，Engine 编排层不直接消费 | Resolver 以 `snapshot.route` 字符串为输入做归一；不直接读 `JailbreakEnvironment` 猜路；环境类型保留给后续服务装配批次 |
| 4 | 单条伪代码：`category == .paired` 门禁 → `route != .unknown` 门禁 → `reader.read` → `decoder.decode` → 按路线 switch 调 Parser | 与 PC3-2（仅 paired 进管线）、PC3-8（路线选择）、PC3-9（读取级失败）、PC3-10（解析级失败）一致；路径取 `record.plist?.path` | 流水线顺序冻结为：配对门禁 → 路线门禁 → Reader → Decoder → 路线 Parser；未知 Profile 判定先于任何文件读取 |
| 5 | `FilterParseCounts { valid, parseFailed, typeMismatch, readFailed, notParsed }` | 契约 §5.7 五桶互斥计数；基线 counts 原始值 `valid / parse_failed / type_mismatch / read_failed / not_parsed` | 字段与原始值对齐基线；计数按结果组数，不按文件数 / 跳过字段数 |
| 6 | `notParsed` 载体未指定 | 契约 §5.6：`notParsed: [UnknownItem]`；基线 `notParsed` 由 missing_plist / orphan_plist / ambiguous / uncertain 四桶映射，保留 base、路径、pairing 原因 | 非 paired 记录映射为 `UnknownItem`；C2 `unknownItems` 原样并入，不丢弃、不重算归类 |
| 7 | Unknown Profile：不读 plist、不调任何 Parser、不猜、不改 Snapshot、留 `not_parsed` | 与 PC3-8、PC3-2 一致；基线 route-isolation 合成样本（route `nil`、目录 `nil`）空结果 | 冻结为 Resolver 前置硬约束；调用次数测试兜底证明下游零调用 |
| 8 | 双路线独立，失败不互相兜底 | 两个 Parser 独立实现；契约总则 §1.3：双路线规则独立、互不调用，未知/rootful 不自动套用开放路线规则 | Engine 禁止 RootHide 失败后重试 Rootless，反之亦然；跨路线兜底列为隔离红线 |

## 4. 接口缺口与待评审项

| 编号 | 缺口 / 风险 | 现状 | 处置建议（Engine-B 评审） |
|---|---|---|---|
| G-E1 | Parser 目前是具体 `final class`，无协议接缝；调用次数测试需要可替换的测试替身 | Reader/Decoder 已有 `PlistDataReading / PlistDecoding` 协议；Parser 无对应协议 | Engine-B 评估抽取内部解析协议（仅 Core 内部接缝，不改 Adapters 七方法协议、不扩公共 Models）；测试替身经协议注入计数 |
| G-E2 | `FilterParseSnapshot / FilterParseCounts` 尚未落代码 | 契约 §5.6/§5.7 字段已冻结；类型归属 Core 中间层还是公共 Models 未定 | 沿用 G-C3-1/G-C3-2 评审口径；Engine-B 先按 Core 中间层落地，不进 `ReportEnvelope` |
| G-E3 | 契约 §5.3/§5.4 草案的 Reader 信号形态与 C3-B 落地结果类型存在字段差 | 草案字段 `plistPath/format/readStatus/payloadInvalid/decodedRoot`；落地 `PlistReadResult` 为 `status/data/path/errorCode/errorDescription`，`PlistDecodeResult` 携带 `object/errorDescription` | Engine-B 在编排层做信号投影：`plistFormat` 取 Decoder `format` 映射 `xml/binary/unknown`，`readStatus` 取 Reader 分类映射 `ok/access_denied/read_failed`；不回改 Reader/Decoder 冻结类型 |
| G-E4 | 快照目录级状态计算规则需显式冻结 | 契约 §5.6 列 `enumerated/partial/unresolved`；基线 `parser.js` L323-325：任一失败态 → `partial` + `partial_parsing`，否则 `enumerated`；目录未定位 → `unresolved` | 状态映射规则写入 Engine 数据契约 §5.3；与 C2 `PairingStatus` 不共享枚举类型 |
| G-E5 | `rootful` 路线条目级行为无基线样本 | B1 可识别 `rootful` 并附 `unsupported_rootful` 告警；C3 双路线不支持 rootful | Resolver 归 `.unknown`，条目 `not_parsed`；是否附路线级告警线索留 Engine-B 评审，不得自动降级 Rootless |
| G-C3-1 | 五态强类型枚举落 Models 还是 Core 内部 | 沿用 C3-B 评审结论（Core 中间层） | Engine-B 不提升为公共枚举 |
| G-C3-2 | 公共 `ValidationReport.skippedFields` 是否结构化 | 未决 | 归属后续评审，Engine 不扩公共 Models 字段 |
| G-C3-4 | Adapter `parseFilter` 签名是否扩展状态/证据载体 | 未决 | Engine 不演进七方法协议 |
| G-C3-5 | Rootless `UnloadAfter` 导出层归属 | C3-C2 仅内部解码保留，不入规则、不增公共字段 | 导出批次评审，Engine 不新增导出字段 |

## 5. 审计冻结结论（供 Engine-B 实现引用）

1. Engine 只做编排：调度 Reader → Decoder → 路线 Parser → 汇总快照；不重新实现任何解析规则，不复制 Parser 内的类型核对 / Codable 口径。
2. 路线唯一来源为 `PluginPairingSnapshot.route`；不猜路径、不猜来源、不猜内容；未知 / rootful / nil 一律 `.unknown`，不降级、不跨路线重试。
3. 仅 `category == .paired` 记录进入 Reader；非配对四桶与 C2 `unknownItems` 原样归集 `notParsed`，保留上游 `reason / basis / candidates / warnings`。
4. 读取级失败（notFound / accessDenied / readFailed）→ `read_failed`；解码失败 → `parse_failed`（`invalid_plist`）；路线 Parser 结果五态直传，Engine 不改写其 reason 与归类。
5. 单条失败不中断整轮；不修改上游快照、记录与夹具；输出按稳定序；解析成功不等于已配置 / 已加载。
6. 本批不落地 Engine 代码；Engine-B（Resolver / Pipeline / Snapshot 实现）与 Engine-C（22 项基线映射 + 全量回归）待逐批独立授权。
