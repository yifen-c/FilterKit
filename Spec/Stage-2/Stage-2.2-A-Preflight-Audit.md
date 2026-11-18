# Stage-2.2-A-Preflight-Audit.md — 2.2-A 前置只读核对审计

- 归属：Stage 2.2 批次 2.2-A（Models 对齐与 Codable）前置核对；承接 `Stage-2.2-Core-Models-Migration.md` §10。
- 授权范围（2026-11-16，方案 A：仅测试补齐）：
  - ✅ 补齐 9 个枚举原始值测试；
  - ✅ 补齐全模型 Codable 往返测试；
  - ✅ 测试 nil / null / 字段缺失行为（仅测试，不修复）；
  - ✅ 测试空数组编码行为（仅测试，不修复）；
  - ✅ 允许新增 Codable 测试、在 macOS runner 执行、记录实测结果；
  - ✅ 本核对清单存档为 Markdown。
- 禁止边界（本次不授权）：
  - ❌ 修改 Models 字段、枚举、原始值；
  - ❌ 修改 Models 解码行为 / 自定义未知枚举解码；
  - ❌ 修改 `ElleKitAdapter` 协议；
  - ❌ 修改 Stage 1 行为基线（`Tests/S1-0x/`、`Tests/Fixtures/`）；
  - ❌ 未知枚举、Optional、null/缺失等问题只记录实测结果，不自行修复。
- 行为基线：以 `Tests/S1-08/exporter.js` 实际导出结构为准；`Spec/Plugin-Data-Model.md` §5 序列化草图为更早草案，滞后项见 §5。
- 本机 Linux 无 Swift/Xcode 工具链；编译/测试结论以 macOS runner 日志为准（§7 待回填）。

## 1. 字段对齐核对（Swift Models ↔ exporter.js 导出结构）

逐项比对 `Models/` 现有结构体与 `exporter.js` `buildEnvironment / buildPlugin / collectUnknownItems / collectWarnings` 输出键集：

| 模型 | 核对结果 | 备注 |
|---|---|---|
| `ReportEnvelope` | ✅ 一致 | `schemaVersion / generatorVersion / profile{id,route} / generatedAt / environment / plugins / unknownItems / warnings` |
| `JailbreakEnvironment` | ✅ 一致 | `jailbreakType / ellekitImplementation? / ellekitVersion? / profileId / jbroot? / jbrand? / iosVersion? / architecture? / evidenceLevel / pathEvidence` |
| `PathEvidence` | ✅ 一致 | `tweakInject? / dynamicLibraries? / jbrootCandidates: [String]` |
| `Plugin` | ✅ 一致 | 18 字段与 `buildPlugin()` 输出一致，含 `source / ownership / ownershipDetails? / filter? / permission / evidence` |
| `FilterRule` | ✅ 一致 | `bundles / classes / executables / coreFoundationVersion? / otherKeys`；Rootless `UnloadAfter` 入 `otherKeys`，不进规则字段 |
| `CoreFoundationVersion` | ✅ 一致 | `mode / min? / max?` |
| `Ownership` | ✅ 一致 | `sourceType / packageID? / listPath? / confidence / writablePolicy` |
| `OwnershipDetails` | ✅ 一致 | `fileOwnership? / markers? / conflicts / notes / packageVersion? / architecture?` |
| `ValidationReport` | ✅ 一致 | `status / warnings / skippedFields` |
| `PermissionState` | ✅ 一致 | `decision / reason` |
| `EvidenceBlock` | ✅ 一致 | `sourceStages / evidenceType / evidenceLevel` |
| `UnknownItem` | ✅ 一致 | `path? / base? / reason / sourceStage / detail` |
| `ReportWarning` | ✅ 一致 | `code / message / sourceStage` |
| `ProfileRef` | ✅ 一致 | `id / route` |

**结论**：字段层面对齐，未发现 Models 必须修改的结构性缺陷。

## 2. 现有测试覆盖（2.1 骨架 4 用例）

| 用例 | 覆盖口径 |
|---|---|
| `testDefaultPluginStateIsUnknownAndUndetermined` | 默认 `loaded=.unknown`、`permission.decision=.undetermined`、`ownership.sourceType=.unknown`、`writablePolicy=.readOnly`、`installed=nil`、`configured=false` |
| `testEnvelopeRoundTrip` | 信封编码再解码，`profile.id / plugins / warnings` 不丢 |
| `testSourceTypeRawValues` | `SourceType` 四值原始值 |
| `testWritablePolicyRawValues` | `WritablePolicy` 四值原始值 |

## 3. 枚举原始值核对表（2.2-A 补测试覆盖）

| 枚举 | 原始值 | 现有测试 | 2.2-A |
|---|---|---|---|
| `JailbreakType` | `roothide / rootless / unknown` | 无 | 补原始值往返 |
| `SourceType` | `dpkg_sileo / filterkit / manual / unknown` | ✅ 已覆盖 | 保持 |
| `OwnershipStatus` | `owned_package / filterkit_managed / manual_import / unknown` | 无 | 补原始值往返 |
| `LoadCategory` | `manager / oldabi / tweak / unknown` | 无 | 补原始值往返 |
| `LoadedState` | `unknown / loaded / not_loaded` | 无 | 补原始值往返 |
| `EvidenceLevel` | `verified / partial / unverified` | 无 | 补原始值往返 |
| `WritablePolicy` | `read_only / managed / confirmed_managed / forbidden` | ✅ 已覆盖 | 保持 |
| `Confidence` | `exact_record / heuristic / unknown` | 无 | 补原始值往返 |
| `Pairing` | `paired / missing_plist / orphan_plist / missing_dylib` | 无 | 补原始值往返 |
| `PermissionDecision` | `undetermined` | 无（默认口径用例间接覆盖） | 补原始值往返 |
| `CoreFoundationMode` | `max / range` | 无 | 补原始值往返 |

## 4. 待 runner 实测的 Codable 风险清单（仅记录，不修复）

| # | 风险点 | 核对口径 | 本次处理 |
|---|---|---|---|
| R1 | 其余 9 个枚举原始值往返 | 编码 → 解码后 `rawValue` 与原枚举一致 | 补测试；runner 实测 |
| R2 | 全模型往返 | `Plugin / Ownership / OwnershipDetails / FilterRule / CoreFoundationVersion / ValidationReport / PermissionState / EvidenceBlock / UnknownItem / ReportWarning / ProfileRef / PathEvidence / JailbreakEnvironment / ReportEnvelope` 编码再解码字段不丢、Equatable 相等 | 补测试；runner 实测 |
| R3 | nil / null / 字段缺失 | Optional 字段缺失或为 `null` 解码后为 `nil`；不把缺省补成空串/空数组/false | 补测试记录现有行为；**不**改解码逻辑 |
| R4 | Optional Bool 三态 | `installed: Bool?` 缺字段解码为 `nil`，不得默认 `false` | 补测试记录现有行为；**不**修复 |
| R5 | 空数组编码 | `otherKeys / conflicts / notes / warnings / bundles / classes / executables / sourceStages / jbrootCandidates` 空值编码为 `[]`，不编码为 `null` | 补测试记录现有行为 |
| R6 | 未知枚举原始值解码 | Swift 枚举遇未知原始值默认解码抛错；Stage 1 口径为保留 `unknown`。是否需要自定义解码落 `unknown`，待实测现有行为后单独评审 | **本次不实现**；runner 观察默认行为并记录结论 |

> R3/R4/R6 若 runner 实测与 Stage 1 口径存在偏差，只在验收报告中记录差异与建议，留待 2.2-A 之后单独授权评审；本次不修改 Models。

## 5. 文档滞后事项（文案同步，非 Models 语义修改）

`Spec/Plugin-Data-Model.md` 序列化草图落后于 `exporter.js` 与现有 Models，列为后续文案同步项，**不混入 Models 语义修改**：

| 位置 | 滞后内容 | 行为基线 |
|---|---|---|
| §2.0 信封草图 | 缺 `generatorVersion`、`profile{id,route}` | 以 `ReportEnvelope` / exporter 为准 |
| §2.2 Plugin 草图 | 缺 `ownershipDetails / permission / evidence` | 以 `Plugin` / exporter 为准 |
| §4 枚举清单 | 缺 `Pairing / EvidenceLevel / Confidence / PermissionDecision / CoreFoundationMode` | 以 `ModelEnums.swift` 为准 |

文档同步是否执行、何时执行，另行授权；本次不改 `Plugin-Data-Model.md` 语义表述。

## 6. 暂停点与后续门禁

- 2.2-A 完成判据：新增 Codable 测试在 macOS runner 全绿；R1–R5 实测结果记录归档；R6 记录默认解码行为结论；无 Models/协议/Stage 1 基线改动。
- 2.2-A 验收通过后**暂停**，等待 2.2-B（Environment / Path）单独授权；不越级实现。
- 若 runner 暴露 Models 行为偏差：记录差异 → 单独评审是否授权 A+（Models 解码微调），不在本批次内顺手修复。

## 7. Runner 实测记录（第八轮 run 43741322151，已回填）

- Runner：`yi-fen/005` @ `f28b67001f5201ffbf6d51e8715bdab5d1b6b3e4`（镜像提交，对应本地 `ddd042f`）；macOS 26 arm64 / Xcode 26.6 / Swift 6.3.3 / SDK 26.5；`workflow_dispatch` 手动触发。
- 证据归档：`Tests/Stage2/evidence/run-43741322151/`（日志、metadata、test-log、app-build 日志/截图、`RUN-METADATA.md`）。

| 项 | 结果 | 证据 |
|---|---|---|
| Runner / commit SHA | ✅ `yi-fen/005` @ `f28b6700` | metadata 14172851309，五文件与本地逐字节一致 |
| 编译（Models / Adapters / Core） | ✅ 通过 | `Build complete! (4.47s)`，三模块 Emitting module |
| 枚举原始值用例（R1） | ✅ 9 例新增 + 2 例既有全过 | test-log：21 例 0 失败 |
| 全模型往返用例（R2） | ✅ 通过 | FilterRule / Ownership / Plugin / Envelope 往返 Equatable 相等 |
| nil/null/缺失（R3） | ✅ 通过 | 空 Plugin 往返保 nil；最小 JSON 缺字段解码为 nil |
| Optional Bool（R4） | ✅ 通过 | `installed` 缺失解码为 `nil`，非 `false` |
| 空数组编码（R5） | ✅ 通过 | 规则/证据空数组编码为 `[]`，非 `null` |
| 未知枚举解码默认行为（R6） | ⏸ 未实测 | 本批次未构造未知值输入；默认解码行为未锁定、未修改，留待后续批次按需观察评审 |
| 用例总数 / 失败数 | ✅ 21 / 0 | `Executed 21 tests, with 0 failures (0 unexpected) in 0.011 (0.013) seconds`；test-log 14172795167（1184 bytes） |

**结论**：2.2-A 授权范围（仅测试补齐）在 runner 取得通过证据；未改 Models/协议/Stage 1 基线。R6 未实测项按边界保留，不视为已闭环。App Target 沿用 2.1 闭环口径复验通过：`** BUILD SUCCEEDED **`，launch PID 4693，存活 PID 4693 一致，`dashboard.png` 1206×2622 文案逐字一致（app-build artifact 14172880428，449101 bytes）。

**暂停点**：2.2-A 验收通过；2.2-B（Environment / Path）须单独授权后方可启动。
