# Stage 2.3：GUI Foundation 实施规格（0.1-C，设计冻结 + 授权分批落地）

- 上游依据：0.1-B 第四轮验收 Runner `44224350333`（397 例 0 fail / 0 skip，证据 `Tests/Stage2/evidence/run-44224350333-acceptance/`）；冻结模型 `Models/ReportEnvelope.swift`、`Models/PluginModels.swift`、`Models/EnvironmentModels.swift`；Reporting 接缝 `Core/Reporting/ReportService.swift`、`Core/ReportExporter/ReportExporter.swift`；Stage-2.1 App Target 方案 `Stage-2.1-App-Target-Plan.md`。
- 状态：**实施规格冻结，授权按 C1～C6 分批落地**。每批只做 L1 静态自检，不单独调度 Runner；C1～C6 全部完成后统一阶段 Runner。本机 Linux 无 Swift/Xcode 工具链，编译、渲染与交互结论以阶段末 Runner 日志为准。
- 前置事实：0.1-B 闭环仅为 CI/Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据；0.1-D 探针与真机验证未授权。本阶段不解除任何未决门禁，PARSE-009-B 继续独立挂起。
- 真实 API 一律以现有 `Models/`、`Core/` 类型为准；本规格新增类型仅限 App 展示层（Presentation 纯映射 + SwiftUI 视图/ViewModel），不新增第二套插件、配对、规则或归属模型。

## 1. 实施总原则

1. **App 只负责展示**：扫描、枚举、配对、解析、归属、报告归并全部归 Core/Models；SwiftUI View 与 ViewModel 不直接调用 `FileManager` 扫描 TweakInject、`PlistDecoder`、`PluginPairingEngine`、Adapter 底层文件访问方法。
2. **数据只经报告信封与接缝**：界面数据来自 `ReportEnvelope`；JSON 导出经 Core `ReportExporting` 接缝，UI 层不重新编码 JSON、不复制 Exporter 排序策略。
3. **只读产品面**：不提供插件启停、删除、安装/卸载、plist/规则修改、注入规则修改、越狱目录写入；导出文件只写 App 自身临时目录。
4. **三层状态严格分离**：`installed`（文件层，`Bool?` 三态）、`configured`（关联层，`Bool`）、`loaded`（运行层，`LoadedState`）互不推导；`loaded` 无运行时证据恒 `.unknown`，界面不得渲染为 Not Loaded。
5. **不确定状态显式保留**：`unknown / partial / heuristic / conflict / not_parsed / read_failed` 原样展示；`nil` 展示为 Unknown/未提供，不留空串冒充已知；Ownership Unknown 不提供任何管理能力暗示。
6. **不改冻结契约**：不修改公共 Models 字段/init/解码契约、七方法 `ElleKitAdapter` 协议、Parser 语义、`ReportEnvelope` 契约与 Stage1 fixtures；不为适配 ViewModel 回改 Core 协议。
7. **合成报告仅用于预览**：0.1-C 无真机快照接入；界面预览使用固定合成信封与空信封两种状态。合成报告通过只证明 UI 展示映射正确，不代表真实 RootHide 文件权限。

## 2. 分层与目录

```
App/
├── AppEntry/
│   ├── FilterKitApp.swift          # 唯一 @main 入口；组合根装配
│   └── AppDependencies.swift       # 报告信封来源 + 导出接缝注入轮廓
├── Navigation/
│   ├── AppTab.swift                # 底部 Tab 枚举
│   └── RootTabView.swift           # TabView 四页容器
├── Presentation/                   # 纯 Foundation 映射层（可被 SwiftPM 单测编译）
│   ├── DisplayStatus.swift        # 展示状态枚举与语义分级
│   ├── DashboardOverview.swift     # 环境行 + 统计计数 + 系统状态行映射
│   ├── PluginRowSummary.swift      # 列表行摘要 + 搜索/筛选
│   ├── PluginDetailModel.swift     # 详情分区模型
│   ├── DiagnosticsSections.swift    # 诊断分组模型
│   ├── ReportLabels.swift          # 冻结枚举 → 展示文案（唯一文案落点）
│   └── SyntheticReportFactory.swift# 0.1-C 预览用固定信封（测试/占位）
├── Features/
│   ├── Dashboard/DashboardView.swift + DashboardViewModel.swift
│   ├── Plugins/PluginListView.swift + PluginListViewModel.swift
│   ├── Plugins/PluginDetailView.swift
│   ├── Diagnostics/DiagnosticsView.swift + DiagnosticsViewModel.swift
│   └── Settings/SettingsView.swift + SettingsViewModel.swift
├── Shared/Components/              # 只读通用行/卡片/标签组件
└── PermissionProbe/                # 2.4 预留，本阶段不实现探针
```

- `Presentation/` 不 import SwiftUI / UIKit，只依赖 Foundation 与 Models；供 App target 与 SwiftPM `AppPresentation` 目标共同编译。
- `Features/` 视图与 ViewModel 依赖 `Presentation` + Models；不直接依赖 Adapters 具体类型。

## 3. 批次拆分（C1～C6）

| 批次 | 名称 | 内容 | 产物 |
|---|---|---|---|
| C1 | GUI Architecture | 单一入口、Tab 导航、依赖装配轮廓、Presentation 模块与 SwiftPM/XcodeGen 接线 | `AppEntry/`、`Navigation/`、`Presentation/` 骨架、Package.swift `AppPresentation` 目标 |
| C2 | Dashboard | 环境卡片、插件统计、系统状态行；Overview 映射 + ViewModel + View | `Features/Dashboard/`、`Presentation/DashboardOverview.swift` |
| C3 | Plugin List | 列表行摘要、关键词搜索、ALL/PAIRED/ISSUES 筛选 | `Features/Plugins/PluginListView(Model).swift`、`Presentation/PluginRowSummary.swift` |
| C4 | Plugin Detail | 三层状态、文件路径、配对、Filter 规则、归属与冲突细节、证据标签 | `Features/Plugins/PluginDetailView.swift`、`Presentation/PluginDetailModel.swift` |
| C5 | Diagnostics & Export | 诊断分组；Settings 版本信息与经 `ReportExporting` 接缝的 JSON 导出（临时目录 + Share Sheet） | `Features/Diagnostics/`、`Features/Settings/`、`Presentation/DiagnosticsSections.swift` |
| C6 | GUI Integration | 四页整合、空/加载/错误态收口、Presentation 单测、隔离脚本 GUI 禁止面扩展 | `Tests/Stage2/GUIPresentationTests.swift`、`scripts/check-adapter-isolation.sh` 增补 |

> 开发期间持续补充 Presentation 层 XCTest；不要求每批启动 CI。阶段末统一 Runner 验证：Core 既有回归、Reporting 18 例、GUI 新增测试、App Build、模拟器启动、导航与页面交互、合成报告展示、JSON 导出、GUI/Core 架构隔离。

## 4. 真实 API 审计（以仓库源码为准）

### 4.1 报告信封与条目（冻结，只读绑定）

| 类型 | 绑定字段 |
|---|---|
| `ReportEnvelope` | `schemaVersion`、`generatorVersion`、`profile: ProfileRef`、`generatedAt: String?`、`environment: JailbreakEnvironment`、`plugins: [Plugin]`、`unknownItems: [UnknownItem]`、`warnings: [ReportWarning]` |
| `JailbreakEnvironment` | `jailbreakType: JailbreakType`、`ellekitImplementation: String?`、`ellekitVersion: String?`、`profileId: String`、`jbroot: String?`、`jbrand: String?`、`iosVersion: String?`、`architecture: String?`、`evidenceLevel: EvidenceLevel`、`pathEvidence: PathEvidence`、`versionReadiness: VersionReadiness?` |
| `PathEvidence` | `tweakInject: String?`、`dynamicLibraries: String?`、`jbrootCandidateDetails: [JBRootCandidate]`、`jbrootCandidates: [String]` |
| `Plugin` | `pluginID`、`name`、`version: String?`、`dylibPath: String?`、`plistPath: String?`、`pairing: Pairing`、`source: SourceType`、`ownership: Ownership`、`ownershipDetails: OwnershipDetails?`、`filter: FilterRule?`、`isTweakManager: Bool`、`loadCategory: LoadCategory`、`installed: Bool?`、`configured: Bool`、`loaded: LoadedState`、`validation: ValidationReport`、`permission: PermissionState`、`profileId: String`、`evidence: EvidenceBlock` |
| `FilterRule` | `bundles: [String]`、`classes: [String]`、`executables: [String]`、`coreFoundationVersion: CoreFoundationVersion?`、`otherKeys: [String]` |
| `Ownership` | `sourceType: SourceType`、`packageID: String?`、`listPath: String?`、`confidence: Confidence`、`writablePolicy: WritablePolicy` |
| `OwnershipDetails` | `fileOwnership: String?`、`markers: String?`、`conflicts: [String]`、`notes: [String]`、`packageVersion: String?`、`architecture: String?` |
| `UnknownItem` | `path: String?`、`base: String?`、`reason: String`、`sourceStage: String`、`detail: [String: String]` |
| `ReportWarning` | `code: String`、`message: String`、`sourceStage: String` |

### 4.2 Reporting 接缝（真实签名，不得回改）

- `public protocol ReportServiceProtocol`：`buildReport(input: ReportBuildInput) -> ReportEnvelope`；`validate(_:) -> ReportValidationResult`；`exportJSON(_:) throws -> Data`。
- `public protocol ReportExporting`：`export(_ report: ReportEnvelope) throws -> Data`；`ReportExporter` 已遵循。
- 注意：**不存在** `generateReport()` 异步方法；`buildReport(input:)` 需要上游快照组装的 `ReportBuildInput`。0.1-C 不接入真机快照，ViewModel 直接消费注入的 `ReportEnvelope?`；导出经 `ReportExporting` 接缝。不得为 GUI 给 `ReportServiceProtocol` 增加方法或异步包装。

## 5. 展示状态映射（文案唯一落点：`ReportLabels.swift`）

### 5.1 三层状态

| 模型值 | 展示文案 | 语义分级 |
|---|---|---|
| `installed == true` | Installed · Yes | success |
| `installed == false` | Installed · No | warning |
| `installed == nil` | Installed · Unknown | unknown |
| `configured == true` | Configured · Yes | success |
| `configured == false` | Configured · No | warning |
| `loaded == .loaded` | Loaded | success |
| `loaded == .notLoaded` | Not Loaded | warning |
| `loaded == .unknown` | Unknown · Runtime state not verified | unknown |

### 5.2 配对 / 来源 / 归属 / 证据

| 枚举 | 文案 |
|---|---|
| `Pairing.paired` | Paired |
| `Pairing.missingPlist` | Missing Plist |
| `Pairing.orphanPlist` | Orphan Plist |
| `Pairing.missingDylib` | Missing Dylib |
| `SourceType.dpkgSileo` | dpkg / Sileo |
| `SourceType.filterkit` | FilterKit |
| `SourceType.manual` | Manual |
| `SourceType.unknown` | Unknown |
| `WritablePolicy.readOnly` | Read Only |
| `WritablePolicy.managed` | Managed |
| `WritablePolicy.confirmedManaged` | Confirmed Managed |
| `WritablePolicy.forbidden` | Forbidden |
| `EvidenceLevel.verified` | Verified |
| `EvidenceLevel.partial` | Partial |
| `EvidenceLevel.unverified` | Unverified |

### 5.3 解析状态（`validation.status` 封闭词表）

| status 原值 | 文案 | 归类 |
|---|---|---|
| `valid` | Valid | success |
| `parse_failed` | Parse Failed | failure |
| `type_mismatch` | Type Mismatch | failure |
| `read_failed` | Read Failed | failure |
| `not_parsed` | Not Parsed | unknown |
| 其他原值 | 原样保留 | unknown |

- `read_failed` 不降级为 `parse_failed`；`not_parsed` 不展示为解析失败。
- `permission.decision` 恒 `undetermined`，界面展示「尚未验证（2.4 探针）」，不展示已授权/可读写。

## 6. Dashboard 概览口径（`DashboardOverview`）

- 环境行：Jailbreak（`jailbreakType` 文案）、ElleKit（`ellekitImplementation` + `ellekitVersion`）、Adapter/Profile（`profileId` / `profile.route`）。
- 统计计数：
  - Total = `plugins.count`；
  - Paired = `pairing == .paired` 条数；
  - Missing = `pairing != .paired` 条数（missingPlist / orphanPlist / missingDylib）；
  - Parse Failed = `validation.status ∈ {parse_failed, type_mismatch, read_failed}` 条数；`not_parsed` 不计入 Parse Failed。
- 系统状态行：JBROOT（`environment.jbroot` 或 `pathEvidence.jbrootCandidates` 投影，缺失 = Unknown）、TweakInject（`pathEvidence.tweakInject` 可达性仅按证据位展示，缺失 = Unknown）、Permission（恒 undetermined 占位）。
- 空信封：各计数为 0，环境行展示 Unknown，不推断已识别路线。

## 7. Plugin List 口径（`PluginRowSummary`）

- 行字段：`name`、dylib 文件名（`dylibPath` 基名，缺失 = Unknown）、Installed / Configured / Loaded 三态标签、Pairing 标签、版本（`version` 缺失不展示行）。
- 搜索：`name` 与 `pluginID` 大小写不敏感包含；空关键词返回全量。
- 筛选段：
  - ALL：全量；
  - PAIRED：`pairing == .paired`；
  - ISSUES：`pairing != .paired` 或 `configured == false` 或 `validation.status != valid`。
- 列表不提供启用/禁用、删除、详情跳转以外的操作入口；详情经导航推入。

## 8. Plugin Detail 口径（`PluginDetailModel`）

- PLUGIN STATUS：Installed / Configured / Loaded 三态；Permission 行恒占位。
- FILES：Dynamic Library（`dylibPath`）、Filter Plist（`plistPath`）；路径缺失展示 Unknown，不拼默认路径。
- PAIRING：配对标签 + 配对键 `pluginID`。
- FILTER RULES：Bundles / Executables / Classes / 其他键（`otherKeys`）；空数组展示空态；`coreFoundationVersion` 按 mode 展示 min/max。
- OWNERSHIP：Source（`sourceType`）、Package（`packageID`）、Confidence、Writable Policy、明细（`ownershipDetails` 的 conflicts / notes / markers / packageVersion / architecture）；Unknown 来源不暗示管理权限。
- EVIDENCE：`evidence.sourceStages / evidenceType / evidenceLevel`；`validation.warnings`、`validation.skippedFields` 原样列出。
- 详情页只读，无编辑/删除/修复入口。

## 9. Diagnostics 与导出口径

### 9.1 诊断分组（`DiagnosticsSections`）

1. Environment：jailbreakType、ElleKit implementation/version、profile、iOS 版本、架构、证据等级。
2. JBROOT：`jbroot`、候选投影 `jbrootCandidates`、各候选 `source/route/status`。
3. DynamicLibraries：`pathEvidence.dynamicLibraries`、`pathEvidence.tweakInject`。
4. Enumeration：插件总数、各配对类别计数。
5. Parsing：valid / parse_failed / type_mismatch / read_failed / not_parsed 计数。
6. Warnings：`warnings` 的 code / message / sourceStage。
7. Unknown Items：`unknownItems` 的 base / path / reason / sourceStage / detail。

### 9.2 JSON 导出（Settings 页）

- 导出数据来自 `ReportExporting.export(_:)` 产出的 `Data`；UI 层不构造编码器、不重排键序。
- 文件写入 App 自身 `FileManager.default.temporaryDirectory`，文件名 `FilterKit-Report-<generatorVersion>.json`；不写越狱目录、不修改原始信封。
- 经 iOS Share Sheet 分享；导出失败以明确错误文案展示，不吞错、不返回空文件。
- 无信封时导出入口禁用并说明原因。

## 10. 架构隔离（静态检查增补）

- App 禁止引用的 Core 具体类型（既有脚本 §4 清单保留）：`PluginDirectoryEnumerator`、`PluginPairingEngine`、`RootHideFilterParser`、`RootlessFilterParser`、`PlistDataReader`、`PlistDecoder`、`JBRootResolver`、`ElleKitDirectoryResolver`、`EnvironmentDetector`。
- 本阶段增补禁止面：`PluginInventoryBuilder`、`PluginPairingEngine` 既有保留、`PluginFilterParseEngine`、`PluginPairingPipeline`、`PluginPairingInputAdapter`、`ReportBuilder`、`ReportValidator`、`ReportService`（具体实现；GUI 仅持有 `ReportExporting` / 信封模型接缝）。
- App 不得 `import Adapters` 后调用 Adapter 扫描/读取方法；组合根只保留协议注入轮廓。
- 隔离脚本为静态文本检查，不能替代编译期依赖分析；不构成真机权限证据。

## 11. 测试计划（阶段末统一 Runner）

### 11.1 Presentation 纯映射单测（`Tests/Stage2/GUIPresentationTests.swift`，SwiftPM `AppPresentation` 目标）

| 编号 | 覆盖点 |
|---|---|
| GUI-01 | 空信封：Overview 计数全 0、环境行 Unknown、诊断分组空态 |
| GUI-02 | Dashboard 计数：paired / missing / parse failed 归类正确，`not_parsed` 不计入 Parse Failed |
| GUI-03 | 列表搜索：name / pluginID 大小写不敏感命中；空关键词全量 |
| GUI-04 | 列表筛选：ALL / PAIRED / ISSUES 归类与交集口径 |
| GUI-05 | 三态标签：`installed` nil / true / false 文案与分级；`loaded` `.unknown` 不出现 Not Loaded |
| GUI-06 | 详情映射：路径缺失展示 Unknown；Filter 空数组空态；归属冲突/备注原样保留 |
| GUI-07 | 诊断分组：Warnings / UnknownItems 完整归集，不裁剪 |
| GUI-08 | 导出接缝：经 `ReportExporting` 导出的 Data 可解码回等义信封；UI 层不持有编码器 |

### 11.2 Runner 界面层验证（app-build job 口径）

- App `** BUILD SUCCEEDED **`；模拟器启动存活；四 Tab 可切换；合成信封渲染；空信封渲染；导出产物落临时目录（模拟器沙盒内）。
- 既有 Core 回归与 Reporting 18 例不回退；隔离脚本增补项全部 OK。

## 12. 缺口与未决项（本阶段不闭合）

- 真机快照 → `ReportBuildInput` → 信封的在线接入属 0.1-D 探针阶段；0.1-C 的合成信封不冒充扫描结果。
- UI 快照测试、交互录屏不在 SwiftPM `swift test` 范围；界面正确性以阶段末模拟器构建/截图为准。
- Deployment Target（草案 iOS 17.0）、Bundle ID（占位 `com.filterkit.manager`）仍待链接 + 真机证据冻结。
- `OwnershipResolver` 未迁移；`loaded` 恒 `.unknown`；`pluginID` 稳定标识规则 0.2.0 定稿；PARSE-009-B 挂起。
- 本阶段产物不构成真机权限、真实加载、Rootless 真机兼容或可写入管理证据。
