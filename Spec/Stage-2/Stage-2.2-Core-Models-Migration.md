# Stage-2.2-Core-Models-Migration.md — 2.2 Core / Models Migration 冻结规格（设计层）

- 归属：Stage 2.2，Core / Models Migration；承接已闭环的 Stage 2.1。
- 状态：**2026-11-16 授权起草（仅设计）**。本文冻结迁移边界、模块职责、协议/Models 映射、Fixture 回归方案、五批次计划与验收门禁；**不含实现代码，不修改现有 Models 与 Adapter 协议，不执行 Swift 回归**。实现、契约变更与测试执行均须在对应批次单独授权（§13）。
- 上游依据：
  - `Spec/Stage-2/Stage-2-Implementation-Plan.md` §4 Stage 1 → Core 迁移映射、§5.2 2.2 验收标准；
  - `Spec/Plugin-Data-Model.md` §2/§4 冻结数据模型与枚举口径；
  - `Spec/Architecture.md` §4.1 双 Adapter 协议边界；
  - Stage 1 八阶段离线验收：`Tests/S1-01…S1-08/report/*-report.json` 与 `Tests/Fixtures/S1-01…S1-08/`，合计 135/135；
  - 2.1 闭环记录：`Tests/Stage2/Stage-2.1-Final-Acceptance.md`、`Stage-2.1-CI-Acceptance.md`。

> 本文取代 2.2 建议稿中的示意类型与示意协议；示意代码仅作形态说明，落地一律以 §3/§4 的现有冻结契约为准。

## 1. 目标与非目标

### 1.1 目标

1. 把 Stage 1 已离线验证的八个环节逻辑迁入正式 Swift Core / Adapter / Models 架构，CLI 与 App 共用同一套核心，不复制第二套扫描/解析实现。
2. RootHide 与 Rootless 使用独立 Adapter，规则代码互不复用；Core 只持有协议引用，不写路线 `if/else` 分支。
3. Models 与 Stage 1 JSON Schema 保持一致；输出模型、分类口径、告警与不确定状态在迁移前后行为保持。
4. 复用 Stage 1 全部 135 项 fixture 作为行为回归基线；除 `generatedAt` 外做确定性深比较。
5. 保留全部 unknown / ambiguous / conflict / 不可访问 / 解析失败等不确定状态；`loaded` 无独立运行时证据恒 `unknown`；来源识别不产生管理授权（`permission.decision` 恒 `undetermined`）。

### 1.2 非目标（2.2 不做）

- 不实现插件启停、改 plist、加 Bundle ID、删 dylib、改软链、安装/卸载、dpkg 写入、自动修复；
- 不接真机文件访问、不做权限探针（属 2.4）；
- 不自研注入引擎、不建常驻 Daemon、不改目标 App Bundle、不重签名；
- 不在 2.2 重设计 Models 字段/枚举/原始值；不合并双路线 Parser；
- 不把离线 fixture 通过等同于真机验证；Rootless 结果不以 RootHide 结果代替。

### 1.3 完成定义

2.2 通过只代表核心逻辑从 Stage 1 原型迁入正式工程并通过离线回归；不代表能在越狱设备扫描，不代表 GUI 权限通过，不代表插件已实际加载。

## 2. Stage 1 → Stage 2.2 迁移矩阵

迁移为**行为保持**重构；输出分类、告警、不确定状态必须与 Stage 1 fixture 预期一致，不得借迁移放宽校验或合并路线规则。

| Stage 1 harness（Node，验证载体） | 目标 Core / Adapter 模块 | 迁移口径（不变项） |
|---|---|---|
| S1-01 `detector.js`（15 项） | `Core/Environment/` + Adapter 环境识别 | 环境类型、架构、iOS 版本、ElleKit 实现/版本、Profile 识别；版本五态 `parsed / not_installed / unreadable / unparsable / conflicted`；单证据不推断整环境 |
| S1-02 `resolver.js`（18 项） | `Core/PathResolver/`（JBROOT） | 候选隔离、命名/结构校验、歧义不选边、jbrand 不补零；不存在与不可访问明确区分；失败不回退 `/var/jb` 或 `/` |
| S1-03 `resolver.js`（15 项） | `Core/PathResolver/`（ElleKit 目录） | 三路线目录状态、软链状态独立记录、回退限制；路线隔离；Rootful 仅作诊断参照 |
| S1-04 `enumerator.js`（23 项） | `Core/PluginScanner/` | 单层非递归、仅识别小写 `.dylib`、plist 独立枚举、确定性排序、软链不跟随、部分失败不阻断、不据文件存在推断 loaded |
| S1-05 `pairing.js`（15 项） | `Core/PluginPairing/` | 同名大小写敏感配对；不读 plist 内容、不模糊匹配、不 lowercase fallback；多候选不挑一个；保留原始文件信息 |
| S1-06 `parser.js`（22 项） | `Core/PlistParser/` + Adapter Filter 解析 | RootHide 严格校验 / Rootless Codable 双实现差异保留；`read_failed / parse_failed / type_mismatch` 分别区分；保留 otherKeys |
| S1-07 `resolver.js`（14 项） | `Core/OwnershipResolver/` | dpkg 精确命中、冲突不选边、混合分文件、标记损坏降级；来源与可写策略分离；FilterKit 标记不覆盖 dpkg 事实；dpkg 不可用不猜测 |
| S1-08 `exporter.js`（13 项） | `Core/ReportExporter/` + Models | 信封版本化、证据保留、三层状态分离；除 `generatedAt` 外确定性导出；null 与缺失语义不改 |

## 3. 现有 Models 字段与枚举映射（唯一基准）

2.2 不得凭空新增枚举或状态；所有迁移结果必须落到下列现有冻结类型。下列清单取自 `Models/` 现文件，实现批次以本清单核对为准。

### 3.1 现有枚举（`Models/ModelEnums.swift`）

| 枚举 | 原始值取值 | 2.2 使用口径 |
|---|---|---|
| `JailbreakType` | `roothide` / `rootless` / `unknown` | 环境识别结果；失败 `unknown`，不套用任一开放路线规则 |
| `SourceType` | `dpkg_sileo` / `filterkit` / `manual` / `unknown` | 插件来源；dpkg 前端差异不改变归属性质 |
| `OwnershipStatus` | `owned_package` / `filterkit_managed` / `manual_import` / `unknown` | 归属建模；与 `SourceType` 区分，不互相替代 |
| `LoadCategory` | `manager` / `oldabi` / `tweak` / `unknown` | 建模分类，不等同运行结果 |
| `LoadedState` | `unknown` / `loaded` / `not_loaded` | 运行层加载状态；无独立运行时证据恒 `unknown` |
| `EvidenceLevel` | `verified` / `partial` / `unverified` | 二手内省不得标 `verified` |
| `WritablePolicy` | `read_only` / `managed` / `confirmed_managed` / `forbidden` | 可写策略；归属识别 ≠ 管理授权 |
| `Confidence` | `exact_record` / `heuristic` / `unknown` | 归属置信度 |
| `Pairing` | `paired` / `missing_plist` / `orphan_plist` / `missing_dylib` | dylib ↔ plist 配对分类；**不新增** `dylibOnly / ambiguous` 配对态 |
| `PermissionDecision` | `undetermined` | 只读阶段恒 `undetermined`，不由归属自动推导 |
| `CoreFoundationMode` | `max` / `range` | Filter 版本约束模式 |

### 3.2 现有结构体

| 类型 | 字段 | 归属环节 |
|---|---|---|
| `PathEvidence` | `tweakInject: String?`、`dynamicLibraries: String?`、`jbrootCandidates: [String]` | S1-02/03 候选与定位证据，候选全量保留不选边 |
| `JailbreakEnvironment` | `jailbreakType`、`ellekitImplementation?`、`ellekitVersion?`、`profileId`、`jbroot?`、`jbrand?`、`iosVersion?`、`architecture?`、`evidenceLevel`、`pathEvidence` | S1-01 环境快照；未取到显式 `nil`，不留空串冒充已知 |
| `ProfileRef` | `id: String`、`route: String` | 信封内 Profile 引用；路线标识走 `route`，不新增 `AdapterProfile` 枚举 |
| `CoreFoundationVersion` | `mode: CoreFoundationMode`、`min: Int?`、`max: Int?` | S1-06 版本约束；缺失 `nil` |
| `FilterRule` | `bundles: [String]`、`classes: [String]`、`executables: [String]`、`coreFoundationVersion?`、`otherKeys: [String]` | S1-06 解析结果；otherKeys 保留未识别字段 |
| `Ownership` | `sourceType: SourceType`、`packageID: String?`、`listPath: String?`、`confidence: Confidence`、`writablePolicy: WritablePolicy` | S1-07 归属与可写策略，两者分列 |
| `OwnershipDetails` | `fileOwnership: String?`、`markers: String?`、`conflicts: [String]`、`notes: [String]`、`packageVersion: String?`、`architecture: String?` | 多包冲突、分文件归属、标记损坏等原始证据；冲突落 `conflicts` |
| `ValidationReport` | `status: String`、`warnings: [String]`、`skippedFields: [String]` | 解析/校验结果；类型错误、读取失败经 `status + warnings` 表达 |
| `PermissionState` | `decision: PermissionDecision`、`reason: String` | 授权状态；只读阶段 decision 恒 `undetermined` |
| `EvidenceBlock` | `sourceStages: [String]`、`evidenceType: String`、`evidenceLevel: EvidenceLevel` | 证据块；记录来源阶段、类型、等级 |
| `Plugin` | 见 `Models/PluginModels.swift`（pluginID / name / version? / dylibPath? / plistPath? / pairing / source / ownership / ownershipDetails? / filter? / isTweakManager / loadCategory / installed: Bool? / configured: Bool / loaded / validation / permission / profileId / evidence） | 统一插件记录；三层状态 `installed / configured / loaded` 互不推导 |
| `UnknownItem` | `path: String?`、`base: String?`、`reason: String`、`sourceStage: String`、`detail: [String: String]` | 无法归类/解析条目，保留路径、原因与来源阶段 |
| `ReportWarning` | `code: String`、`message: String`、`sourceStage: String` | 全局告警 |
| `ReportEnvelope` | `schemaVersion`、`generatorVersion`、`profile: ProfileRef`、`generatedAt: String?`、`environment`、`plugins: [Plugin]`、`unknownItems: [UnknownItem]`、`warnings: [ReportWarning]` | S1-08 导出顶层；`generatedAt` 不参与确定性比较 |

### 3.3 建议稿示意类型 → 现有契约重映射

建议稿中的下列示意类型/状态在现有 Models 中不存在；2.2 一律按下表落位，不得照示意新建：

| 建议稿示意 | 现有落位 | 说明 |
|---|---|---|
| `AdapterProfile.rootHide / .rootless` | `JailbreakType` + `ProfileRef.route: String` | 路线标识沿用现有字符串口径 |
| `PathResolutionResult.unconfirmed` | `EnvironmentPaths.jbroot = nil` + `ReportWarning`；证据等级 `EvidenceLevel.unverified / .partial` | 候选保留在 `PathEvidence.jbrootCandidates` |
| `PathResolutionResult.candidate(URL)` | `EnvironmentPaths.tweakInject / dynamicLibraries` 带证据与告警 | 候选必须带证据等级，不无条件记为已确认 |
| `PathResolutionResult.notFound` | 路径字段 `nil` + 告警；**禁止**回退 `/var/jb` 或 `/` | S1-02/03 回退限制 |
| `PathResolutionResult.ambiguous([候选])` | `jbrootCandidates` 全量保留 + 告警/冲突记录 | 多候选不选边 |
| `DirectoryResolutionResult` | `EnvironmentPaths` + `PathEvidence` | 软链状态经告警/证据字段记录 |
| `EnumerationResult.readFailed` | `PluginCandidate.readable = nil/false` + `warnings`；失败条目进 `UnknownItem` | 部分失败不阻断其余枚举 |
| `PluginPair.dylibOnly / .paired / .ambiguous` | `Pairing.missing_plist / .paired`；多 plist 歧义按 S1-05 口径落 `missing_plist`/`orphan_plist` + 告警 | 不新增歧义配对枚举值 |
| `OwnershipDatabaseResult` | `Ownership` + `OwnershipDetails`；dpkg 不可用 → `sourceType=.unknown`、`confidence=.unknown` + 告警 | 不猜测归属 |
| `FilterParseResult.typeMismatch / .parseFailed / .valid` | `ValidationReport.status + warnings/skippedFields`；成功才返回 `FilterRule`，否则 `nil` | 失败三态经状态与告警区分 |
| `RootlessFilter`（Decodable 结构） | 解析结果落现有 `FilterRule`；Codable 解码中间模型仅在 Parser 内部使用，不进入公共 Models | 内部解码类型不污染公共模型层 |
| `PluginFile` / `JBRootCandidate` / `EnvironmentReport` / `FilterParseResult` | `PluginCandidate` / `PathEvidence` 候选 / `JailbreakEnvironment` / `ValidationReport` | 现有类型承载；缺字段按 §7 流程评审 |

## 4. 现有 ElleKitAdapter 协议映射（唯一基准）

2.2 协议层以 `Adapters/ElleKitAdapter.swift` 现有契约为唯一基准，**不平行创建第二套接口**；确需演进的方法列入 §4.3 缺口清单，在对应批次实现前走协议评审，本阶段不改协议。

### 4.1 现有协议方法

```
public protocol ElleKitAdapter {
    var route: String { get }
    func getEnvironment() -> JailbreakEnvironment
    func resolvePaths() -> EnvironmentPaths
    func scanPlugins() -> [PluginCandidate]
    func readPlugin(_ candidate: PluginCandidate) -> Plugin?
    func validatePlugin(_ plugin: Plugin) -> ValidationReport
    func parseFilter(_ plugin: Plugin) -> FilterRule?
    func resolvePath(_ relative: String) -> AbsolutePath
}
```

配套现有类型：`AbsolutePath(value: String)`、`EnvironmentPaths(jbroot?/tweakInject?/dynamicLibraries?/warnings)`、`PluginCandidate(base/dylibPath?/plistPath?/readable?/warnings)`。

### 4.2 方法 → Stage 1 环节映射

| 协议方法 | 对应环节 | 只读职责 |
|---|---|---|
| `route` | S1-01 | 路线标识（roothide / rootless / unknown）；unknown 不执行扫描 |
| `getEnvironment()` | S1-01 | 环境类型、实现/版本、Profile、证据等级识别 |
| `resolvePaths()` | S1-02 / S1-03 | JBROOT 候选校验、TweakInject / DynamicLibraries 目录定位、软链与告警 |
| `scanPlugins()` | S1-04 | 单层枚举 dylib/plist，返回候选与可读证据，部分失败不阻断 |
| `readPlugin(_:)` | S1-05 | 候选配对、文件在位/可读证据，组装 `Plugin` 骨架 |
| `validatePlugin(_:)` | S1-06 校验部分 | 结构/类型校验，产出 `ValidationReport` |
| `parseFilter(_:)` | S1-06 解析部分 | 双路线 Filter 解析，成功返回 `FilterRule`，否则 `nil` + 校验报告 |
| `resolvePath(_:)` | S1-02/03 辅助 | 相对路径经 Adapter 解析为 `AbsolutePath`；Core/UI 不直接拼接路线路径 |

### 4.3 协议演进缺口（记录，不在本规格实现）

- S1-07 归属库读取：现有协议未暴露归属数据库读取方法。2.2-D 批次前若确认需要在协议层增加只读归属读取入口，须提交协议演进评审，明确输入/输出/错误口径，且不得引入任何写入方法；在此之前 Core 不直接实例化具体 Adapter。
- 禁止出现在协议与实现中的方法（只读边界）：`enablePlugin / disablePlugin / installPlugin / uninstallPlugin / deletePlugin / modifyFilter` 及任何写设备、写 plist、装卸、改软链接口。

## 5. 八个 Core 环节的模块职责

Core 只编排 Adapter 调用与模型聚合，不写路线特有规则；各环节独立服务，不写成单一 `PluginManager.swift`。目录沿用 2.1 骨架约定：

| Core 目录 | 服务（对应计划 §4） | 职责 | 输入 → 输出（现有类型） |
|---|---|---|---|
| `Core/Environment/` | EnvironmentDetector（S1-01） | 汇总 Adapter 环境证据，判定 `JailbreakEnvironment`；版本冲突保留 `conflicted` 口径；单证据不推断整环境 | 证据/Adapter → `JailbreakEnvironment` |
| `Core/PathResolver/` | JBRootResolver（S1-02） | JBROOT 候选校验、优先级与非法位拒绝、歧义保留；不回退固定根路径 | 候选/Adapter → `EnvironmentPaths` + `PathEvidence` |
| `Core/PathResolver/` | ElleKitDirectoryResolver（S1-03） | 按 Adapter 路线解析 TweakInject/DynamicLibraries；软链状态独立记录；Rootful 仅诊断参照；失败不静默回退 | `EnvironmentPaths` 输入 → 定位结果 + 告警 |
| `Core/PluginScanner/` | PluginEnumerator（S1-04） | 单层非递归枚举、扩展名口径、确定性排序、软链不跟随、权限异常保留条目与失败证据 | 目录/Adapter → `[PluginCandidate]` + `UnknownItem` |
| `Core/PluginPairing/` | PluginPairer（S1-05） | 大小写敏感同名配对；不读内容、不模糊匹配、不 lowercase fallback；多候选保留歧义告警 | `[PluginCandidate]` → 带 `Pairing` 的 `Plugin` 骨架 |
| `Core/PlistParser/` | FilterParser（S1-06） | 编排双路线 Parser；RootHide 严格校验 / Rootless Codable；失败三态区分；otherKeys 保留 | `Plugin` → `FilterRule?` + `ValidationReport` |
| `Core/OwnershipResolver/` | PluginOwnershipResolver（S1-07） | 归属与可写策略分列；dpkg 精确命中、冲突不选边、混合分文件、标记损坏降级；来源不覆盖授权 | `Plugin` → 补全 `Ownership / OwnershipDetails` |
| `Core/ReportExporter/` | ReportExporter（S1-08） | 组装 `ReportEnvelope`；稳定排序；证据与状态字段不丢；`generatedAt` 除外确定性导出 | 环境/插件/未知项/告警 → `ReportEnvelope` |

现有 Core 编排协议（`Core/CoreServices.swift`：`EnvironmentService / PathResolutionService / PluginScanService / PluginParseService / OwnershipService / ReportExportService / AdapterResolver`）作为组合根轮廓；服务实现挂在上述目录，`AdapterResolver` 在识别失败时返回 `nil`（保守只读模式），未知 Profile 不执行扫描。

## 6. RootHide / Rootless 双 Parser 设计

两条路线解析规则分别实现，不共用一个宽松 Parser；不得因 RootHide 接受某格式就认为 Rootless 也接受，反之亦然。

### 6.1 RootHide Parser（严格校验）

- 根节点必须为 Dictionary；`Filter` 必须为 Dictionary；
- `IsTweakManager`（如存在）必须为 Bool；
- `Bundles / Classes / Executables` 必须为 String Array；
- `CoreFoundationVersion` 为数字数组，长度 1 或 2；
- 任一类型不符 → 整份标记类型错误（落 `ValidationReport.status` + warnings，`FilterRule = nil`）；
- 区分读取失败、解析失败、类型错误三种状态；保留 `otherKeys` 未识别字段；
- 具体字段校验与证据构造按 S1-06 夹具规则逐项实现。

### 6.2 Rootless Parser（Codable 模型为准）

- 以 Codable 解码为口径，字段范围对应 Rootless plist：`Bundles`、`Executables`、`UnloadAfter` 等；
- 解码中间结构为 Parser 内部类型，不进入公共 Models；解码结果映射到现有 `FilterRule`；
- 解码失败按 S1-06 Rootless 夹具口径记录校验报告，不套用 RootHide 的严格类型规则。

### 6.3 隔离要求

- 两 Parser 代码分属各自 Adapter/路线实现路径，互不调用；
- Core 只经 `parseFilter(_:)` / `validatePlugin(_:)` 协议方法调用，不感知路线；
- Rootless 解析结果不得被 RootHide 规则覆盖；Rootless 真机兼容仍待设备验证。

## 7. 中间结果类型设计

### 7.1 原则

- 2.2-A 不重设计 Models；中间结果优先复用 §3.2 现有结构体承载；
- 候选、告警、失败证据优先落 `PluginCandidate / EnvironmentPaths / PathEvidence / UnknownItem / ReportWarning / EvidenceBlock`；
- 确需新增的中间结果类型（例如路径候选校验位、枚举失败条目细分），先在对应批次子规格中给出字段、Codable 口径与 Stage 1 对照，经评审冻结后再实现；**不得在编码中临时新增枚举值或改变现有状态语义**。

### 7.2 待评审缺口（实现批次前补设计）

| 缺口 | 现状承载 | 评审要求 |
|---|---|---|
| 路径候选校验位（api/scan/bootstrap/rootless/rootful 候选与非法位） | `PathEvidence.jbrootCandidates: [String]` | 若字符串候选不足以表达校验结果，提交候选结构评审；优先级、拒绝规则对齐 S1-02 |
| 枚举失败条目细分 | `UnknownItem` + `PluginCandidate.readable/warnings` | 按 S1-04 夹具区分权限异常、坏软链、隐藏文件、目录条目等口径 |
| 归属库读取结果（协议层） | §4.3 协议演进缺口 | 2.2-D 前评审；只读，错误口径对齐 S1-07 |
| 解析失败三态内部表达 | `ValidationReport.status` 字符串 | 若需强类型状态，提交枚举评审；取值与 Stage 1 报告口径一致 |

## 8. Fixture 读取与深比较方案

### 8.1 载体与落点

- 行为基线：`Tests/Fixtures/S1-01…S1-08/<case>/{environment.json, metadata.json}`；预期结果：`Tests/S1-01…S1-08/report/<stage>-report.json` 各 `cases[]` 的 `result`。
- Node harness（`Tests/S1-0x/*.js`）保留为行为基线参照与排查依据，**不迁入 App 运行时**；Swift 实现不依赖 Node。
- Swift 回归挂在现有 SwiftPM `testTarget` `Stage2Tests`（`Package.swift`）；不另建 `Tests/Stage1` Swift target。实现批次新增测试文件归入 `Tests/Stage2/` 下的回归子目录，并在批次子规格中更新 `Package.swift` 的 testTarget sources。

### 8.2 读取流程（每个 fixture）

1. 按 `report.json` 的 `source: fixture:<case>` 定位 `Tests/Fixtures/S1-0x/<case>/`；
2. 读取 `environment.json` / `metadata.json` 构造 Core 输入；
3. 调用对应 Core 服务（经 Adapter 协议，离线注入 fixture 适配器）；
4. 将输出编码为与 Stage 1 同构的模型/字典；
5. 与 `cases[].result` 深比较，`generatedAt` 除外；
6. 记录通过/失败与差异字段；失败须能定位到 fixture 与环节。

### 8.3 确定性与语义要求

- 数组按确定性顺序排序（文件名/路径稳定序）；字典键序稳定；
- 状态字段不丢失；`null` 与字段缺失语义保持，不把缺省补成空串/空数组冒充已知；
- 除 `generatedAt` 外的内容参与确定性比较；`evidenceType` 在离线回归中保持 `fixture` 口径；
- 三层状态 `installed / configured / loaded` 互不推导；`permission.decision` 恒 `undetermined`。

## 9. 135 项回归映射

回归矩阵与 Stage 1 验收报告总数逐项核对一致：

| Stage | 环节 | 用例数 | 用例编号前缀（report.json） | Swift 回归归属（2.2 批次） |
|---|---|---|---|---|
| S1-01 | Environment Detection | 15 | `ENV-` | 2.2-B |
| S1-02 | JBROOT Resolution | 18 | `pathId`（fixture 驱动） | 2.2-B |
| S1-03 | ElleKit Directory | 15 | `DIR-` | 2.2-B |
| S1-04 | Plugin Enumeration | 23 | `ENUM-` | 2.2-C |
| S1-05 | Plugin Pairing | 15 | `pairId`（fixture 驱动） | 2.2-C |
| S1-06 | Plist Parsing | 22 | `parseId`（fixture 驱动） | 2.2-C |
| S1-07 | Ownership | 14 | `OWN-` | 2.2-D |
| S1-08 | Unified Model / Export | 13 | `EXPORT-` | 2.2-D |
| **合计** | | **135** | | 2.2-E 全量复验 |

### 9.1 附加回归（135 之外，随对应批次补）

- Models Codable 往返：信封/插件/归属/规则编码再解码字段不丢；
- 双 Adapter 隔离：RootHide / Rootless 互不引用；Core 不直接实例化具体 Adapter；
- 未知 Profile 禁止扫描：识别失败返回保守只读结果 + 告警；
- `loaded` 无证据保持 `unknown`；
- 归属（source）与可写策略（writablePolicy）互不推导；
- 除 `generatedAt` 外重复导出确定性深比较。

### 9.2 映射规则

- 每个原始 fixture 有明确 Swift 用例对应；用例命名保留 Stage 1 编号（如 `ENV-008`、`PARSE-017`）以便回溯；
- 前序回归在后续阶段保持通过（沿用 Stage 1 report.json `regression` 口径）。

## 10. 五批次实现计划

每批次完成后独立验收，不得一次性越级实现；批次内只做该批次范围的 Models/Adapter/Core/测试改动。

| 批次 | 内容 | 覆盖回归 | 验收门槛 |
|---|---|---|---|
| 2.2-A | Models 对齐与 Codable：核对现有 Models 与 Stage 1 Schema；补 Codable 往返与枚举原始值用例；**不重设计 Models**，不接扫描逻辑 | 现有 4 骨架用例 + 新增往返/枚举用例 | 现有用例保持通过；模型字段/枚举原始值与 Stage 1 一致；无路线分支字段泄漏进公共模型。前置只读核对见 `Stage-2.2-A-Preflight-Audit.md`；本批次授权范围为**仅测试补齐**，不改 Models 解码行为/协议/Stage 1 基线 |
| 2.2-B | Environment / Path：Core Environment、PathResolver + Adapter 环境/路径只读实现 | S1-01 15 + S1-02 18 + S1-03 15（合计 48） | 48 项回归通过；路径不回退固定根；歧义/不可访问/不存在口径保持。子规格草案 `Stage-2.2-B-Environment-Path.md`（设计层，实现待授权） |
| 2.2-C | Enumeration / Pairing / Parser：Scanner、Pairer、双路线 Parser | S1-04 23 + S1-05 15 + S1-06 22 | 60 项回归通过；双 Parser 隔离；配对大小写敏感；失败三态区分 |
| 2.2-D | Ownership / Export：OwnershipResolver、ReportExporter | S1-07 14 + S1-08 13 | 27 项回归通过；归属/可写分离；冲突不选边；导出确定性（除时间戳） |
| 2.2-E | 完整集成回归：CLI 与 App 共用同一 Core 服务；全量深比较与附加回归 | 135/135 + 附加用例 | 135 项全绿；双路线规则未合并；未新增 GUI 专用扫描器；未实现启停/写入 |

> 批次门槛未达成不进入下一批次；任一批次发现行为与 Stage 1 预期不符，先冻结问题、回退到对应夹具核对，不在编码中放宽规则。

## 11. CI 验收门禁

- runner：macOS（沿用 2.1 工作流工具链口径）；Node 仅用于 CI 脚本/打包，不进入 App 运行时；
- 编译：Models / Adapters / Core 在真实 Apple 工具链编译通过；
- 测试：`Stage2Tests` 全绿；各批次回归日志归档为 artifact；
- 隔离：双 Adapter 静态隔离检查通过（沿用 `scripts/check-adapter-isolation.sh` 口径；运行时隔离另记）；
- 行为门禁：135 项 fixture 深比较通过（除 `generatedAt`）；未知 Profile 不扫描；只读边界核对无写入/启停/装卸接口；
- 每批次在 CI 留下编译/测试/隔离/归档证据，结论以 runner 日志为准；本机 Linux 无 Swift/Xcode 工具链，不作为编译通过证据。

## 12. 风险与待验证事项

| 项 | 现状 | 归属 |
|---|---|---|
| Rootless 真机适配 | 无设备；离线 fixture 结果不代表真机兼容 | 具备 Rootless 设备后 |
| Theos 打包链 / 16.5 SDK 对 iOS 17 兼容 | 2.2 不参与打包；runner SDK 26.5 不能作为 16.5 SDK 兼容证据 | 打包阶段 / 2.5 真机 |
| 包产品平台三元组 | SPM 默认 iOS 12.0，App target 17.0；Package.swift 平台最低版本未显式声明 | 打包阶段复核 |
| 协议演进（归属读取入口） | §4.3 缺口，2.2-D 前评审 | 2.2-D 前置设计 |
| Node → Swift 行为等价 | 迁移须逐 fixture 深比较；规则口径以 Stage 1 验收报告为准 | 2.2 各批次 |
| 路径候选无真机证据 | 离线夹具合成；真机 JBROOT/目录性质待探针 | 2.4 / 真机验证 |
| 运行时隔离 | 2.1 仅静态文本核对 | 后续阶段运行时复核 |
| 真机文件访问 / entitlement / `jbroot()` | 未探针 | 2.4 权限探针 |

## 13. 实现阶段授权边界

| 事项 | 当前授权（2026-11-16） |
|---|---|
| Stage 2.1 闭环 | ✅ 已授权（保留观察项备注 O1–O5） |
| 归档 2.1 观察项到 2.4 / 后续真机 | ✅ 已授权 |
| 起草本 2.2 冻结规格文档 | ✅ 已授权（设计层） |
| 2.2-A 仅测试补齐（枚举原始值/全模型往返/nil 与缺失/空数组编码用例，runner 实测记录） | ✅ 已授权（方案 A；不改 Models 解码行为）；第八轮 run 43741322151 复验 21 例 0 失败，R6 未知枚举解码未实测未修改 |
| 2.2-B 子规格有条件冻结 + G-B1~G-B5 设计评审（仅设计，不改 Models/协议/源码/测试） | ✅ 已授权；见 `Stage-2.2-B-Environment-Path.md`、`Stage-2.2-B-Gap-Review.md`、`Stage-2.2-B-Data-Contract-Reconciliation.md`；D1~D12 已定稿 |
| 2.2-B 数据契约冻结（D1~D12 定稿，字段/类型/枚举原始值/兼容规则；设计层，不落地代码） | ✅ 已冻结；见 `Stage-2.2-B-Data-Contract-Freeze.md`；B1–B5 实现、Models 增补授权待单独决定 |
| 2.2-B1 Environment Detection（VersionReadiness/VersionParser/EnvironmentDetector/双路线顾问 + ENV-001~015 回归） | ✅ runner 验收通过（run-43793314782：build 通过、28 例 0 失败、隔离三向 OK、App 构建启动存活）；见 `Stage-2.2-B1-Environment-Detection.md`；B2~B5 未授权 |
| 2.2-B2 JBROOT Candidate Collection（候选结构/快照/收集器：规范化/来源/路线/顺序/多来源保留/精确去重/未知告警；不裁决） | ✅ runner 验收通过（run-118584150452：build 通过、38 例 0 失败、隔离三向 OK、App 构建启动存活）；见 `Stage-2.2-B2-Candidate-Collection.md`；B3/B4/B5 未授权 |
| 2.2-B3 JBROOT Validation（命名/存在/结构/可读/realpath 五项三态校验、六态分类、多候选裁决；不定位目录软链） | 🟡 本地验收通过（方案 B，基准提交 `3e878cb`）；CI Runner/独立构建/正式闭环延后 B5 集中回归（71 项逐阶段映射）；见 `Stage-2.2-B3-Validation-Adjudication.md`；B4/B5 未授权 |
| 2.2-B4 Directory/Symlink + 2.2-B5 Pipeline/集成回归 | ✅ B5 runner 集中验收通过（run `43817618222`，SHA `7fc5d53`：build 成功、91 例 0 失败、隔离三向 OK、App 构建启动存活）；见 `Stage-2.2-B5-Implementation-Record.md` §4C；B1~B5 闭环 |
| 2.2-C 第一步：只读审计与实现规格冻结（Enumeration/Pairing/Parser） | ✅ 设计层授权；见 `Stage-2.2-C-Audit.md` 与 `Stage-2.2-C-Enumeration-Pairing-Parser.md`；C1~C4 编码、Models/协议演进、Runner 执行待逐批单独授权 |
| 2.2-C 第二步：G-C1/G-C2 枚举模型增补评审与数据契约冻结 | ✅ 设计层冻结；见 `Stage-2.2-C-Enumeration-Models-Contract.md`（`PluginFileEvidence`/`PluginInventorySnapshot`/封闭枚举/计数/输入信号快照字段、Optional 与 Codable 口径；G-C3~G-C6 归属 C2/C3/2.5）；Models 增补落地、C1 编码待单独授权 |
| 2.2-C1：Plugin Enumeration 实现（Runner 验收通过） | ✅ 编码落地并验收；见 `Stage-2.2-C1-Enumeration-Implementation.md` 与 `Tests/Stage2/evidence/run-43825045361/RUN-METADATA.md`：Models 3 类型 + Core 8 枚举器源 + 2 个 C1 测试文件；Runner `swift build` 18.08s 成功、`swift test` **114 例 0 失败**（既有 91 零损伤 + C1 23）、隔离三向 OK、App 构建存活；未做 C2 配对/C3 解析/信封改动/真机操作；服务装配接入归后续授权 |
| 2.2-C2 第一步：G-C3 配对数据契约审计与冻结（设计层） | ✅ 设计层冻结；见 `Stage-2.2-C2-Pairing-Contract.md`：`PluginPairingSnapshot`/`PluginPairingRecord`/`PairingCategory`/`PairingStatus`/`PluginPairingCounts` 字段、五态互斥归类、配对键大小写敏感规则、同目录作用域、歧义/不确定不扩 `Pairing` 枚举、计数与 Codable/确定性口径、S1-05 15 例映射；未改 Swift 源码/Models/协议/夹具/harness/既有测试，未编译未跑 Runner；C2-A~C2-D 编码待逐批单独授权 |
| 2.2-C2-A：Plugin Pairing Models / Snapshot 实现（代码冻结，Runner 验收待授权） | ✅ 编码落地待 Runner；见 `Stage-2.2-C2-A-Pairing-Models-Implementation.md`：Core 6 源（`PairingCategory`/`PairingStatus`/`PluginPairingCounts`/`PairingEvidenceBasis`/`PluginPairingRecord`/`PluginPairingSnapshot`）+ 1 个 Codable 测试源（12 例），Package 接线完成；`Pairing` 四值未扩，歧义/不确定 `pairing=nil`，候选全量保留，五桶计数互斥求和；未实现 Key/Index/Engine，未接服务装配/Adapter，未编译未跑 Runner；C2-B/C2-C/C2-D 待逐批授权 |
| 2.2-C2-B：Plugin Pairing Key / Index / Engine 实现（代码冻结，Runner 验收待授权） | ✅ 编码落地待 Runner；见 `Stage-2.2-C2-B-Pairing-Engine-Implementation.md`：Core 6 源（KeyBuilder/Index/IndexBuilder/Classifier/Engine/SnapshotBuilder）+ 3 个专项测试源（37 例：Key 11/Index 5/Engine 21），Package 接线完成；五桶归类、同目录作用域、大小写敏感、多候选全保留、受限 uncertain 留置、确定性排序落地；未接服务装配/Adapter，未跨目录合并，未编译未跑 Runner；C2-C/C2-D 待逐批授权 |
| 2.2-C2-C：C1 Enumeration → C2 Pairing 集成桥接（代码冻结，Runner 验收待授权） | ✅ 编码落地待 Runner；见 `Stage-2.2-C2-C-Pairing-Integration-Implementation.md` 与集成契约 `Stage-2.2-C2-C-Pairing-Integration-Contract.md`：Core 5 源（Input/InputAdapter/Pipeline/IntegrationResult/IntegrationValidator）+ 1 个集成测试源（32 例：A 输入 8/B 状态告警 7/C 行为 9/D 稳定隔离 8），Package 接线完成；状态传递矩阵冻结、INT-C2-001~014 完整性校验落地；未接服务装配/Adapter，未改冻结代码，未编译未跑 Runner；C2-D 待独立授权 |
| 2.2-C2-D：Runner 验收清单冻结与 C2 只读审计（Runner 未执行） | ✅ 审计完成/清单冻结；见 `Stage-2.2-C2-D-Runner-Acceptance-Checklist.md`：已有 XCTest 195（B 91 + C1 23 + C2-A 12 + C2-B 37 + C2-C 32），F 组 S1-05 15 例映射当前接入 0 待独立批次补齐，G 组架构/隔离/完整性/确定性/App Build 检查项冻结；四类数字分列统计、十项硬门槛与证据归档结构定稿；冻结面零改动、隔离三向通过；Runner 编译回归待独立授权，未宣称已通过编译 |
| 2.2-C2-D1：S1-05 原始配对基线映射测试（代码冻结，Runner 验收待授权） | ✅ 编码落地待 Runner；见 `Stage-2.2-C2-D1-S105-Fixture-Mapping-Implementation.md`：测试 target 内独立 loader `S105FixtureLoader.swift` + 映射测试 `PluginPairingS105FixtureTests.swift`（13 组夹具逐例独立标识 + 2 合成用例，共 15 例），Package 接线完成；environment/metadata 字段映射、五桶逐桶比较、归类基名/文件名/告警/软链标记断言落地，foreign 陷阱条目在测试加载层按 C1 边界排除；未改 fixtures/metadata/harness/Core/Models/Adapters/协议/既有测试，未编译未跑 Runner；C2-D2 完整 Runner 验收待独立授权 |
| 2.2-C2-D2：Runner 编译/测试/独立构建验收 | ✅ Runner 验收通过（run `43857670397` / Run ID `118727393219`，基线 `59ee5f8`）：build 0 error/0 warning，全量 210 例 0 失败，S1-05 独立过滤 15 例 0 失败，隔离三向 OK，App Simulator 构建存活（PID 3991）；见 `Tests/Stage2/evidence/run-43857670397/acceptance-report.md` 与 Preflight §11；Stage 2.2-C Enumeration & Pairing Core Migration 收口，结论仅限离线 Core 数据处理链路 |
| 2.2-C3-A：Filter Parser 前置只读审计与数据契约冻结（设计层） | ✅ 设计层冻结；见 `Stage-2.2-C3-A-Preflight-Audit.md` 与 `Stage-2.2-C3-Parser-Data-Contract.md`：五态互斥、RootHide 严格/Rootless Codable 双路线规则、`SkippedField/otherKeys/Evidence` 传递、错误分类、`Core/PlistParser/` 分层与 C3-A~D 门禁定稿；G-C3-1/2/4/5 缺口留实现批次评审；未改源码/Models/Adapters/协议/fixtures/harness/既有测试，未编译未跑 Runner；C3-B 起逐批单独授权 |
| 2.2-C3-B：Plist Reader / Decoder（✅ Runner 验收通过） | ✅ 编码落地并经第五轮 Runner（run `43889143343`，SHA `11f8b7f8…`）验收：三库 Build 完成、全量 236 例 0 失败、S1-05 独立过滤 15 例 0 失败、隔离复查 OK、App BUILD SUCCEEDED 存活截图归档；见 `Stage-2.2-C3-B-Reader-Decoder-Implementation.md` §7.1~§7.5 与 `Tests/Stage2/evidence/run-43889143343-acceptance/`：Core 8 源（Reader 3 + Decoder 5）+ 3 个测试源（26 例：Reader 6 / Decoder 9 / 类型识别 11），Package 两处显式 sources 接线完成；Reader 四态与 Decoder 两态严格分离，XML/Binary 解码，CFBoolean 优先判定 Bool/NSNumber；Reader/Decoder→五态映射表冻结（notFound 对 `.paired` 记录归 `read_failed`，`not_parsed` 仅限未进 Reader 的非配对条目）；未建 Input/路线 Parser/Result/Engine，未改 Models/Adapters/协议/C1/C2/Stage1 fixtures；C3-C1 统一 Result + RootHide Parser 进入实现，Rootless/Engine/22 项基线映射留 C3-C2/C3-C3 独立授权 |
| 2.2-C3-C1：统一 Result + RootHide Filter Parser（**Runner 验收通过**） | ✅ 验收通过：Actions run `43993649974`（SHA `919185b1…`，本地 `245ea12`，元数据逐文件一致），Core Build 0 error，全量 275 例 0 失败（既有 236 + 新增 39：Result 7 + RootHide 32），S1-05 独立过滤 15 例 0 失败，隔离三项 OK，App `BUILD SUCCEEDED` 存活截图归档 `Tests/Stage2/evidence/run-43993649974-acceptance/`。过程修复：首轮缺 `import Models` 补导入（`run-af7f163a-build-failure/`）；第二轮数组 mismatch 顶层 reason 归 `field_type`（`run-44376c62-test-failure/`）。见 `Stage-2.2-C3-C1-RootHide-Parser-Implementation.md` §7：Core 7 源（Result 3：`FilterParseStatus/SkippedField/FilterParseResult`；RootHide 4：类型谓词/校验器/映射器/主入口）+ 2 个测试源（39 例），Package 两处显式 sources 接线完成；五态互斥、RootHide 严格类型核对、Bool-NSNumber 区分、otherKeys 去重排序、空配置告警落地；复用 `FilterRule/CoreFoundationVersion/ReportWarning` 与 C3-B `PlistValueClassifier`；未实现 Rootless Parser、未建 Engine/Snapshot/Counts/Input，未改公共 Models/Adapters/协议/C1/C2/Stage1 fixtures；C3-C2 Rootless Codable、C3-C3 双路线 Engine + S1-06 22 项映射待独立授权 |
| 2.2-C3-C2：Rootless Codable Filter Parser（代码冻结，Runner 验收待授权） | 🟡 编码落地待 Runner；见 `Stage-2.2-C3-C2-Rootless-Parser-Implementation.md`：Core 3 源（`RootlessFilterCodable/RootlessFilterMapper/RootlessFilterParser`）+ 1 个专项测试源（22 例：A 正常 9 / B 结构 5 / C 类型 5 / D 确定性 3），Package 两处显式 sources 接线完成；仅 `Bundles/Executables/UnloadAfter` 三 Codable 字段，序列化 + `PropertyListDecoder` 解码边界，失败一律 `parse_failed`（不套 RootHide `type_mismatch`），小写规范化、otherKeys 两层合并去重排序、`isTweakManager` 恒 nil；复用 C3-C1 Result 模型、现有 `FilterRule/ReportWarning` 与 C3-B `PlistValueClassifier`；`UnloadAfter` 按 G-C3-5 仅内部解码保留，不入规则、不增公共字段；未建 Engine/Snapshot/Counts/Input，未改公共 Models/Adapters/协议/C1/C2/Stage1 fixtures；本机 Linux 无工具链，编译 / 22 例专项 / 既有 275 例回归 / S1-05 15 例 / App Build 待独立 Runner 出证；C3-C3 双路线 Engine + S1-06 22 项映射待独立授权 |
| 2.2-C3-Engine-A：双路线 Parser Engine 前置只读审计与数据契约冻结（设计层） | ✅ 设计层冻结；见 `Stage-2.2-C3-Engine-A-Interface-Audit.md`、`Stage-2.2-C3-Engine-A-Data-Contract.md`、`Stage-2.2-C3-Engine-A-Test-Plan.md`：审计 C2 Snapshot/Record、Reader/Decoder、双路线 Parser 实际接口与路线透传链；冻结内部 `FilterParseRoute` 归一、Resolver 安全红线（不猜路径/来源/内容、不降级、不跨路线兜底）、Stage 0~5 流水线五态映射、`FilterParseSnapshot/Counts` 字段与计数不变量、非配对 → `UnknownItem` 映射、五组测试分组与调用次数矩阵、S1-06 22 项基线映射表；Engine 唯一路线来源为 `snapshot.route`，拒绝第二事实来源；未落地 Engine/Input/Snapshot/Counts 代码，未改公共 Models/Adapters/协议/C1/C2/Stage1 fixtures，未编译未跑 Runner；C3-C2 Runner 未过前 Engine-C 不得标记集成完成，Engine 测试结果不得掩盖 Rootless Parser 缺陷；Engine-B 编排实现、Engine-C 基线映射与全量回归待逐批独立授权 |
| 2.2-C3-Engine-B：Dual-Route Filter Parse Engine 实现（代码冻结，Runner 验收待授权） | 🟡 编码落地待 Runner；见 `Stage-2.2-C3-Engine-B-Implementation.md`：Core 8 源（Route/Protocol/Resolver/Engine/Counts/Snapshot/Builder/Validator）+ 1 个专项测试源（E-B1~E-B6 六组，含调用次数桩与双路线隔离断言），Package 两处显式 sources 接线完成；Stage 0~5 短路编排、readStatus/plistFormat 信号投影、五桶计数不变量、非配对/未知路线 → UnknownItem 归集、上游告警与 unknownItems 原样保留落地；分 B1 `9b14ce8` / B2 `9194342` / B3 三提交。未改 C3-C2 源码、C2 配对模型、Stage1 fixtures、七方法 Adapter 协议；未接服务装配/Adapter 实例化；本机 Linux 无工具链，编译 / 专项 / 既有 275 例回归 / S1-05 15 例 / App Build 待独立 Runner 出证；Engine-B 测试通过不视为 C3-C2 验收通过；Engine-C 22 项基线映射与完整集成验收待独立授权 |
| 2.2-C3-Engine-C-Audit：S1-06 双路线基线覆盖审计与测试规格冻结（设计层） | ✅ 设计层冻结；见 `Stage-2.2-C3-Engine-C-Audit.md`（22 项逐条覆盖矩阵、专项已覆盖/部分/缺失/待 Runner 分类、C-G1~G7 门禁）、`Stage-2.2-C3-Engine-C1-Test-Spec.md`（基线描述模型、夹具/合成驱动、断言维度、C1-01~09 分组、计数纪律）、`Stage-2.2-C3-Engine-C2-Regression-Plan.md`（回归范围矩阵、五类计数分列、证据归档结构、最终验收序列）；审计确认 CFV 错误顶层 reason 保留 `versions_type`、Rootless `UnloadAfter` 不入 otherKeys；未落地 C1/C2 代码，未改 Models/Adapters/协议/C1/C2/C3-B/C3-C1/C3-C2 源码与 Stage1 fixtures，未编译未跑 Runner；C-G1（Engine-B Runner）、C-G2（C3-C2 Runner #151）为 C2 完整集成验收硬门禁；Engine-C1 编码、Engine-C2 回归待逐批独立授权 |
| 2.2-C3-Engine-C1：S1-06 双路线基线映射 XCTest（测试层） | 🟡 测试代码落地，本地 Linux 无 Swift 工具链未编译，待外部 Runner 出证；测试层 7 文件：`EngineC1-BaselineModels/Loader/Registry`、`EngineC1-ResultComparator`、`EngineC1-ParserBaselineTests`、`EngineC1-EngineStubs`、`EngineC1-EngineBaselineTests`；22 项基线逐条绑定，PARSE-010 混合类型错误证据补缺（Bundles not_array + Classes element_type index 0 同时在位）；PARSE-015 保留 pendingRunner 挂起（#151 / C-G2）；计数五类分列，不把 22 项基线说成 XCTest 数；未改 Core/Models/Adapters/七方法协议/既有冻结源码与 Stage1 fixtures；C-G1/C-G2 未出证前不宣布双路线集成验收，Engine-C2 完整回归待独立授权；实现清单与 22 项映射状态见 `Stage-2.2-C3-Engine-C1-Implementation.md` |
| 2.2-C3-Engine-C2-Audit：双路线完整集成回归前置审计与实施规格冻结（设计层） | ✅ 设计层冻结；见 `Stage-2.2-C3-Engine-C2-Audit.md`（Engine-B 输入/输出/Resolver/Pipeline/Builder/Validator 真实接口事实表、C2-01~06 既有覆盖去重矩阵、PARSE-009-B 独立证据对照方案、C-G1~G7 门禁与 Runner 依赖表）与 `Stage-2.2-C3-Engine-C2-Implementation-Spec.md`（C2-A~E 批次拆分、端到端/五态/多插件隔离/Snapshot-Counts-Warnings/22 项链路集成/回归隔离规格、五类计数口径）；审计确认 Engine 唯一路线来源 `snapshot.route`、五态直传不改写、上游 warnings/unknownItems 原样归集不重分类；未落地 C2 测试或生产代码，未改 Core/Models/Adapters/七方法协议/既有冻结源码与 Stage1 fixtures/harness，未编译未跑 Runner；C-G1（Engine-B Runner）、C-G2（C3-C2 Runner #151）未过前不进入 C2 完整集成验收，不宣布双路线集成完成；C2 实现待独立授权 |
| 2.2-C3-Engine-C2-A~C：双路线集成测试实现（测试层，Runner 验收待授权） | 🟡 测试代码落地，本地 Linux 无 Swift 工具链未编译，待外部 Runner 出证；4 个测试层文件：`EngineC2-TestSupport`（受控 Reader/Decoder 桩 + 计数包装 + 构造器）、`EngineC2-EndToEndTests`（C2-A 真实 RootHide 端到端 6 例）、`EngineC2-BatchIsolationTests`（C2-B 五态/混合五插件/失败隔离 4 例）、`EngineC2-SnapshotWarningsTests`（C2-C 三层追溯/告警合并/确定性/不可变 6 例）；Rootless 对称结构 pendingRunner 挂起（#151 / C-G2）；Mock 仅用于受控故障注入与调用顺序，真实解析由真实 Parser 产出；未改 Core 生产逻辑/Models/Adapters/七方法协议/冻结 Parser 与 Stage1 fixtures；C2-D（22 项链路集成，含 Rootless）与 C2-E（全量回归/隔离/归档）未启动；C-G1/C-G2 未过前不宣布双路线集成完成；实现清单与 16 例映射见 `Stage-2.2-C3-Engine-C2-Implementation.md` |
| 修改现有 Models 字段 / 枚举 / 原始值 | ❌ 未授权 |
| 修改 `ElleKitAdapter` 协议 | ❌ 未授权（演进须单独评审） |
| 编写 2.2 实现代码（Core / Adapter / Parser / Exporter） | ❌ 未授权（按 §10 批次单独授权） |
| 运行 135 项 Swift 回归 | ❌ 未授权 |
| 接入真机扫描或权限探针 | ❌ 未授权（2.4） |
| 进入 Stage 2.3 GUI 基础 | ❌ 未授权（2.2 行为回归全绿后另行授权） |

**门禁顺序**：2.1 闭环 → 本规格评审冻结 → 2.2-A 单独授权 → 逐批验收 → 2.2-E 135/135 → 2.2 验收 → 等待授权进入 2.3。
