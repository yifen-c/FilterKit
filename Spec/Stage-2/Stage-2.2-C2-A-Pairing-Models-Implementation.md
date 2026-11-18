# Stage 2.2-C2-A：Plugin Pairing Models / Snapshot 实现记录（代码冻结，Runner 验收待授权）

- 状态：**Implementation Complete / Local Static Review Passed**；**Runner Build & Test 未执行**（本机 Linux 无 Swift 工具链，编译与回归待 C2-D Runner 验收授权）。既有 114 例（B 段 91 + C1 23）未改动。
- 依据：C1 验收提交 `5b481e6`、C1 代码冻结提交 `b6b4cef`、G-C3 契约冻结提交 `7dbac87`、`Stage-2.2-C2-Pairing-Contract.md` PC1~PC12。
- 批次定位：C2-A 只落地冻结的数据结构与 Codable；Key/Index/Engine 归 C2-B，C1→C2 集成证据归 C2-C，完整 Runner 回归归 C2-D。

## 1. 本轮授权边界

### 已允许并执行

- 按 G-C3 契约落地配对模型：`PairingCategory`、`PairingStatus`、`PluginPairingCounts`、`PairingEvidenceBasis`、`PluginPairingRecord`、`PluginPairingSnapshot`。
- 配套模型/Codable 测试：枚举原始值、`Pairing` 四值兼容、计数互斥求和、候选完整保留、三态 nil、快照往返、缺省解码、未知键忽略、重建确定性。
- `Package.swift` 登记 6 个 Core 源与 1 个测试源。

### 禁止项（本轮均未触碰）

- 未实现配对键生成、索引、配对引擎/分类器/快照构建器（C2-B）。
- 未接入 `PluginScanService`、AdapterResolver 或任何服务装配；未修改七方法协议与双路线 Adapter。
- 未修改既有 Models 字段/枚举/原始值与解码行为；未改动 Stage 1 夹具/harness/报告与既有 Stage2 测试。
- 未编译、未运行 Runner、未扫描真机；无插件读写、软链改动、注入配置修改或启停。
- 未进入 C3 解析；快照未进 `ReportEnvelope`，未组装最终 `Plugin`。

## 2. 文件清单

| 文件 | 模块 | 内容 |
|---|---|---|
| `Core/PluginPairing/PairingCategory.swift` | Core | 五桶分类封闭枚举：`paired / missing_plist / orphan_plist / ambiguous / uncertain` |
| `Core/PluginPairing/PairingStatus.swift` | Core | 目录级配对四态：`enumerated / partial / enumeration_failed / unresolved` |
| `Core/PluginPairing/PluginPairingCounts.swift` | Core | 五桶计数；`total` 为五桶之和；JSON 键 `missing_plist/orphan_plist` 对齐基线 |
| `Core/PluginPairing/PairingEvidenceBasis.swift` | Core | 匹配依据封闭码五类（契约 §4.3 外延） |
| `Core/PluginPairing/PluginPairingRecord.swift` | Core | 单条配对记录：分类/可选 Pairing/键/两侧证据/候选/原因/依据/证据块/告警 |
| `Core/PluginPairing/PluginPairingSnapshot.swift` | Core | 配对快照：route/sourceDirectory/status/records/unknownItems/counts/warnings |
| `Tests/Stage2/PluginPairingCodableTests.swift` | Test | C2-A 模型与 Codable 口径测试（12 例） |
| `Package.swift` | 接线 | Core sources 登记 6 个配对源；testTarget 登记 `PluginPairingCodableTests.swift` |

## 3. 契约落地对照（PC1~PC12）

| 编号 | 契约要求 | 落地情况 |
|---|---|---|
| PC1 | 输入边界仅消费 C1 快照 | ✅ 模型层不持有扫描器；记录/快照只引用既有 `PluginFileEvidence` 等类型 |
| PC2 | 仅 dylib/plist 入候选，其他类归集 | ✅ 候选范围判定归 C2-B；模型不臆造候选类别 |
| PC3 | 配对键剥离精确后缀、大小写敏感 | ⏳ 键生成归 C2-B；模型仅保存 `pairingKey: String?` |
| PC4 | 空键不参与配对 | ⏳ 空键归集判定归 C2-B；模型层保留可选键位 |
| PC5 | 同目录作用域，不跨目录/跨快照 | ✅ 快照保留 `sourceDirectory`；模型不提供跨目录索引面 |
| PC6 | 五态互斥，前三个映射 `Pairing`，后两个 `pairing=nil` | ✅ `PairingCategory` 五值；记录 `pairing: Pairing?`，ambiguous/uncertain 为 nil |
| PC7 | 歧义全候选保留、不选边 | ✅ `candidates: [PluginFileEvidence]`，模型层不取 first；测试验证候选完整往返 |
| PC8 | 不确定留置候选、不判缺失/孤儿 | ✅ `reason` 承载 entryStatus 原值；记录 `pairing=nil` |
| PC9 | 目录级四态，原始值对齐 S1-05 | ✅ `PairingStatus` 四值逐字一致 |
| PC10 | 计数按组数、五桶互斥求和 | ✅ `PluginPairingCounts.total`；测试断言五数之和等于记录组数 |
| PC11 | 复用既有证据模型，不新增自由字符串证据数组 | ✅ 依据用封闭枚举 `PairingEvidenceBasis`；证据块复用 `EvidenceBlock` |
| PC12 | 排序确定性 | ✅ 模型不内置排序算法；测试验证相同输入重建快照深比较一致；记录排序归 C2-B 编排 |

### 与既有 `Pairing` 枚举的兼容关系

- `Pairing` 冻结四值不动：`paired / missing_plist / orphan_plist / missing_dylib`。
- C2 五桶分类为独立 `PairingCategory`；`missing_dylib` 不在分类枚举重复造值，孤儿 plist 记录以 `reason="missing_dylib"` 文本口径承载。
- 不存在两个枚举的一对一硬转换；测试分别锁定分类原始值与 `Pairing` 四值原始值。

## 4. C2-A 测试映射（12 例，模型/Codable 层）

| # | 测试方法 | 覆盖口径 |
|---:|---|---|
| 1 | `testPairingCategoryRawValues` | 五桶分类原始值冻结 |
| 2 | `testPairingStatusRawValues` | 目录级四态原始值冻结 |
| 3 | `testPairingEvidenceBasisRawValues` | 依据封闭码原始值冻结 |
| 4 | `testPairingFourValuesRemainUnchanged` | 既有 `Pairing` 四值原始值未改 |
| 5 | `testRecordCategoryToPairingMapping` | 分类→Pairing 映射；ambiguous/uncertain 的 pairing 为 nil |
| 6 | `testCountsTotalEqualsFiveBuckets` | 五桶互斥求和 = 记录组数 |
| 7 | `testAmbiguousCandidatesPreservedFull` | 歧义候选全量保留，不取 first，往返候选数一致 |
| 8 | `testRecordRoundTripPreservesNilOptionals` | 三态可选 nil 保留，不转 false |
| 9 | `testSnapshotRoundTrip` | 快照状态/记录/归集/计数/告警往返一致 |
| 10 | `testSnapshotMinimalJSONDecodesWithDefaults` | 最小 JSON 缺省计数/数组/状态成立 |
| 11 | `testUnknownKeysAreIgnored` | 未知键忽略，不抛解码错误 |
| 12 | `testDeterministicReconstructionEqual` | 相同输入重建快照与记录深比较一致 |

> 注：上表实际 12 个测试方法（含确定性重建）。S1-05 原始 15 例行为回归（PAIR-001~013 + 2 合成）归 C2-B 引擎与 C2-D Runner 回归；本批模型测试不替代该基线。

## 5. 六个易错点自查

| 易错点 | 本批处置 |
|---|---|
| 大小写 `lowercased()` | 模型层不做文件名比较；键比较归 C2-B，契约 PC3 已冻结大小写敏感 |
| 多候选取 `first` | 记录 `candidates` 全量保留；测试断言往返后候选数与顺序一致 |
| 权限异常当成不存在 | uncertain 记录 `pairing=nil`、`reason` 保留原值，不判 missing/orphan |
| 跨目录全局基名索引 | 快照按 `sourceDirectory` 作用域；模型不提供跨目录索引面 |
| 三态 nil 转 false | 可选证据位沿用 C1 口径；测试往返后 nil 仍为 nil |
| 配对成功推断 loaded | 本批不产出运行层结论；`loaded/configured/installed` 不由配对快照推导 |

## 6. 静态审查记录与未决项

- 本机无 Swift 工具链：未执行 `swift build`/`swift test`；类型引用、初始化参数、CodingKeys 与缺省解码按既有 C1 范式静态核对，编译/回归结果待 C2-D Runner 出证。
- 隔离静态核对：6 个新 Core 源仅 `import Foundation`（记录/快照另 `import Models`），无 Adapter 引用、未实例化具体 Adapter；隔离脚本三向口径沿用。
- 2.2-A R6（未知枚举原始值默认解码行为）仍未实测未修改；本批新增枚举的解码表现由 C2-D Runner 轮记录，不在契约层假定静默默认值。
- `PairingEvidenceBasis` 为契约 §12 允许在 C2-A 落地评审时细化的封闭码枚举；若 C2-B 发现需新增依据码，须回补本记录并经评审，不在记录内塞自由文本。

## 7. 非目标（明确不在 C2-A 范围）

- 配对键生成、dylib/plist 字典索引、五态归类引擎、快照构建排序（C2-B）。
- C1 清单→C2 快照的集成链路、不可读/歧义/归集证据传递验证（C2-C）。
- 完整 Runner 编译、114 既有 + S1-05 15 回归、隔离/App 构建验收（C2-D）。
- C3 Filter 解析、S1-07 归属识别、S1-08 统一导出；真机兼容/权限/注入/启停。

## 8. 下一阶段门槛

- **C2-B 授权前**：本批模型静态审查通过；`Pairing` 四值未扩、既有 Models/协议/夹具/测试未改。
- **C2-B 落地**：按契约 §5 键与索引规则、§6 归类决策表实现 Key/Index/Engine；不改变本批模型字段与原始值。
- **C2-D Runner 验收门槛**：Swift Build 通过；Swift Test 零失败；既有 114 例不回退；S1-05 15 例通过；快照 Codable 往返、三态、确定性正确；双 Adapter 与 Core 隔离通过；App Build 成功；Stage 1 基线不被修改。
