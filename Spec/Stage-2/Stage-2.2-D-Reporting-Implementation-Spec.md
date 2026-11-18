# Stage 2.2-D：统一扫描报告与 JSON 导出实施规格（设计冻结，待独立授权分批落地）

- 上游依据：`Spec/Stage-1/S1-08-Unified-Model-JSON-Export.md`（整合原则、确定性规则、EXPORT-001～013）；`Spec/Plugin-Data-Model.md` §2/§3/§5；`Stage-2.2-B-Data-Contract-Freeze.md`（环境/路径增补字段与协议边界）；现有 `Models/`、`Core/` 真实接口。
- 状态：**实施规格冻结**。本轮只冻结 D1～D5 文件、类型、方法、输入输出、测试用例与验收标准；不写生产代码、不编译、不调度 Runner。
- 前置事实：Engine C2 已在第五轮统一验收 Runner `44106064051` 取得 CI/Simulator 口径证据，C-G1～G7 判为 passed（379 例 0 fail / 0 skip，见 `Tests/Stage2/evidence/run-44106064051-acceptance/`）；该证据不构成真机权限、真实加载或 Rootless 真机兼容背书。本阶段实现仍待独立授权；规格落地不解除任何未决门禁，PARSE-009-B 继续独立挂起。
- 真实 API 一律以现有 `Models/`、`Core/` 类型为准；本文件出现的类型名均为仓库现有类型或本规格冻结的新增 Core 组装类型，不新增第二套插件/配对/规则模型。

## 1. 实施总原则

1. **复用既有公共模型**：信封与条目直接使用 `ReportEnvelope / Plugin / FilterRule / Ownership / OwnershipDetails / UnknownItem / ReportWarning`；不为 GUI 展示新增并行模型或展示态投影。
2. **只读整合与序列化**：Builder 只归并上游快照，Validator 只发现不一致，Exporter 只编码；不重新扫描、不重新解析、不补判归属、不回写设备。
3. **三层状态严格分离**：`installed`（文件层）、`configured`（关联层）、`loaded`（运行层）互不推导；`loaded` 无独立运行时证据恒 `.unknown`。
4. **来源与权限分离**：`ownership / writablePolicy` 不推导 `permission.decision`；本阶段 `permission` 恒 `undetermined`。
5. **不确定状态显式保留**：`unknown / partial / ambiguous / conflict / heuristic` 原样保留；缺失字段为 `nil`，不留空串冒充已知。
6. **证据不裁剪**：配对异常、解析告警、跳过字段、扩展键、归属冲突、混合来源、备注与清单路径必须有对应落点。
7. **确定性版本化**：除 `generatedAt` 外，相同输入两次导出深比较一致；对象键序与数组排序策略固定。
8. **上游不重分类**：上游 `warnings / unknownItems` 原样归集；新增告警只追加并按 `code` 去重，不覆盖、不删除、不改写上游告警。

## 2. 批次拆分（D1～D5）

| 批次 | 名称 | 内容 | 阻塞条件 | 产物（实现批次落地） |
|---|---|---|---|---|
| D1 | Report Models Audit | 核对现有报告模型字段与接口；记录差异；不改公共契约 | 无（静态审计） | 本规格 §3 审计表；差异登记入 §10 |
| D2 | Report Builder | 将环境/枚举/配对/解析/归属快照归并为 `ReportEnvelope` | 既有快照类型冻结 | `Core/Reporting/ReportBuilder.swift` |
| D3 | Report Validator | 检查报告完整性与状态一致性；只发现不修复 | D2 产物结构冻结 | `Core/Reporting/ReportValidator.swift` |
| D4 | JSON Exporter | 稳定、可复现的 JSON 编码与排序策略 | 既有 Codable 契约冻结 | `Core/ReportExporter/ReportExporter.swift`、`Core/ReportExporter/ReportSerialization.swift` |
| D5 | Report Service | 统一服务入口，供 CLI / GUI 共用；装配 Builder→Validator→Exporter | D2～D4 落地 | `Core/Reporting/ReportService.swift` |

> 开发期间按批次持续补充 XCTest；不要求每批启动 GitHub Actions。阶段结束再进行一次统一 Runner。若发现公共模型契约冲突、Core 无法编译或重大架构问题，提前暂停并针对性验证。

## 3. D1：报告模型审计（真实字段口径）

### 3.1 现有模型字段核对（以仓库源码为准）

| 模型 | 真实字段数 | 字段清单 | 建议稿口径 | 差异记录 |
|---|---:|---|---|---|
| `ReportEnvelope` | 8 | `schemaVersion`、`generatorVersion`、`profile`、`generatedAt`、`environment`、`plugins`、`unknownItems`、`warnings` | 8 个顶层键 | 一致 |
| `JailbreakEnvironment` | 11 | `jailbreakType`、`ellekitImplementation`、`ellekitVersion`、`profileId`、`jbroot`、`jbrand`、`iosVersion`、`architecture`、`evidenceLevel`、`pathEvidence`、`versionReadiness` | 环境 + 路径证据合计 10 | 多出 B1 增补可选字段 `versionReadiness`；旧信封缺省解码为 `nil`，不改既有语义 |
| `PathEvidence` | 4 | `tweakInject`、`dynamicLibraries`、`jbrootCandidateDetails`、`jbrootCandidates` | 路径证据 | 一致；`jbrootCandidates` 为权威候选的派生投影 |
| `Plugin` | 19 | `pluginID`、`name`、`version`、`dylibPath`、`plistPath`、`pairing`、`source`、`ownership`、`ownershipDetails`、`filter`、`isTweakManager`、`loadCategory`、`installed`、`configured`、`loaded`、`validation`、`permission`、`profileId`、`evidence` | 18 | 多出 `evidence: EvidenceBlock` 证据块；其余口径一致 |
| `FilterRule` | 5 | `bundles`、`classes`、`executables`、`coreFoundationVersion`、`otherKeys` | 5 | 一致 |
| `Ownership` | 5 | `sourceType`、`packageID`、`listPath`、`confidence`、`writablePolicy` | 5 | 一致 |
| `OwnershipDetails` | 6 | `fileOwnership`、`markers`、`conflicts`、`notes`、`packageVersion`、`architecture` | 6 | 一致 |
| `UnknownItem` | 5 | `path`、`base`、`reason`、`sourceStage`、`detail` | 5 | 一致 |
| `ReportWarning` | 3 | `code`、`message`、`sourceStage` | 3 | 一致 |
| `ValidationReport` | 3 | `status`、`warnings`、`skippedFields` | — | 解析校验证据落点，D2 从 `FilterParseResult` 映射 |
| `PermissionState` | 2 | `decision`、`reason` | — | 门禁分离；本阶段恒 `undetermined` |
| `EvidenceBlock` | 3 | `sourceStages`、`evidenceType`、`evidenceLevel` | — | 离线样本 `evidenceType=fixture`，不得标真机 |

### 3.2 审计结论（D1 不改契约）

- `ReportEnvelope` 可容纳环境、插件、未知项、告警四类结果；无需新增顶层键。
- `Plugin` 可表示配对状态：`Pairing` 四态（`paired / missing_plist / orphan_plist / missing_dylib`）；配对类别中的 `ambiguous / uncertain` 保留在记录原因与 `unknownItems`，不并入 `Pairing` 枚举；解析状态由 `validation.status` + `filter: FilterRule?` 保留。
- `Ownership` 与管理授权分离：归属字段在 `ownership`，授权结论在 `permission`，二者不互通。
- `loaded` 为 `LoadedState` 三态（`unknown / loaded / not_loaded`），允许保留 `unknown`，不得落 `nil → false`。
- `ReportWarning` 可表达来源（`sourceStage`）与原因（`code / message`）；`UnknownItem` 保留无法识别对象的路径、基名、原因与细节。
- **契约缺口（登记，不在 D1 改模型）**：
  1. `pluginID` 稳定标识规则 0.2.0 定稿；离线按「优先 `<packageID>:<base>`，回退 `<base>`」生成，确定性可复现。
  2. `Core/OwnershipResolver/` 目前仅有 `.gitkeep`，归属分类器尚未迁移；D2/D5 的归属输入为已解析快照注入，分类器迁移单列后续批次。
  3. 运行时加载取证接口后续阶段接入；本阶段 `loaded` 恒 `unknown`。

## 4. D2：ReportBuilder

### 4.1 输入（只读快照，全部来自既有 Core 类型）

```swift
public struct ReportBuildInput {
    public let environment: JailbreakEnvironment
    public let inventory: PluginInventorySnapshot?      // S1-04；缺失为 nil
    public let pairing: PluginPairingSnapshot?           // S1-05；缺失为 nil
    public let parsing: FilterParseSnapshot?             // S1-06；缺失为 nil
    public let ownershipByKey: [String: Ownership]       // S1-07 已解析归属，按配对键/基名索引
    public let ownershipDetailsByKey: [String: OwnershipDetails]
    public let profile: ProfileRef
}
```

- 上游某阶段整体缺失时，对应字段 `nil`；Builder 不回退其他阶段结果补齐，相关条目落 `unknownItems` 并在 `warnings` 标注缺失阶段（如 `inventory_unresolved`）。
- 归属映射键：优先 `pairingKey`，回退条目 `base`；未命中映射的条目 `ownership = Ownership()`（`sourceType=.unknown`、`confidence=.unknown`、`writablePolicy=.readOnly`），`ownershipDetails = nil`。

### 4.2 归并键与条目来源

- 跨阶段对齐键：`base`（`PluginFileEvidence.name` / 记录基名）+ 规范化路径；`pairingKey` 作为配对/解析侧关联键。
- 条目集合 = 枚举 `items` ∪ 配对 `records` ∪ 解析 `parsed`；仅出现在配对/解析/归属侧而无 dylib 枚举记录的条目仍保留为 `Plugin` 或 `UnknownItem`，不丢弃。
- 归并冲突（多路径/多基名指向同一插件）不强行合并；保留各自记录，`warnings` 追加 `pairing_ambiguous`。

### 4.3 输出

```swift
public struct ReportBuilder {
    public init()
    public func build(_ input: ReportBuildInput) -> ReportEnvelope
}
```

- 信封 `schemaVersion / generatorVersion` 取既有模型默认值 `0.1.0`；`profile` 来自输入；`generatedAt` 由 Exporter/服务层填充，Builder 不写时间戳。
- 归并顺序：环境识别结果 → JBROOT/目录路径证据 → 枚举条目 → 配对结果 → 解析结果 → 归属关联 → 告警合并 → 未知项保留 → 生成信封。

### 4.4 状态映射口径（允许 / 禁止）

| `Plugin` 字段 | 允许来源 | 禁止推导 |
|---|---|---|
| `installed` | 枚举 dylib 在位/可读证据（`PluginFileEvidence.exists/readable`） | 禁止由 plist 存在、Bundles 命中、dpkg 归属推导 |
| `configured` | 解析 `status == .valid` | 禁止由 `installed`、`source=dpkg_sileo` 推导 |
| `loaded` | 独立运行时取证（本阶段无） | 禁止由在位/配置/归属/进程内命中推导；恒 `.unknown` |
| `validation` | `FilterParseResult.status / reason / skippedFields / warnings` | 失败条目不得清空校验证据 |
| `filter` | 解析 `.valid` 携带的 `FilterRule`；其余为 `nil` | 解析失败不得回填默认规则 |
| `source` / `ownership` | S1-07 归属映射 | 未知来源不得判为 FilterKit 自管 |
| `permission.decision` | 后续授权门禁（本阶段不评估） | 禁止由 `writablePolicy=managed` / `sourceType=filterkit` 推导放行 |
| `isTweakManager` | 解析结果 `isTweakManager`；缺失为 `false` | 不由归属/规则内容反推 |

### 4.5 五条不可违反规则（对应建议稿）

1. **不丢失未知状态**：`loaded = nil/unknown` 不得因 GUI 显示需要变成 `false`。
2. **不混淆三层状态**：`installed / configured / loaded` 互不推导。
3. **不丢失失败条目**：解析失败（`type_mismatch / parse_failed / read_failed / not_parsed`）条目保留在 `plugins`，`filter=nil`，`validation.status` 记录原因。
4. **不把未知来源判成自管**：来源识别与管理授权是两件独立事情。
5. **不改变双路线解析结果**：RootHide / Rootless 各自使用对应 Adapter/Parser 结果，Builder 不跨路线回填规则或状态。

### 4.6 D2 测试用例（Stage2Tests 内组织）

| 用例 | 输入 | 断言 |
|---|---|---|
| Builder-001 | 完整混合快照（合法/失败/孤儿/歧义） | 信封字段齐全；条目归并到对应 `Plugin`；失败条目保留 |
| Builder-002 | RootHide / Rootless 双路线快照 | 路线字段与规则不串线；未知路线条目落 `unknownItems` |
| Builder-003 | 解析失败条目 | `filter=nil`、`validation.status` 保留原因、`skippedFields` 在位 |
| Builder-004 | 归属冲突/混合来源 | 细节进入 `ownershipDetails`，不选边；`ownership` 公共字段不合并 |
| Builder-005 | 上游阶段缺失 | 缺失阶段字段 `nil/unknown`；告警标注；不回退补齐 |
| Builder-006 | 状态分离样本 | `installed/configured` 按允许来源派生；`loaded=.unknown`；`permission.decision=.undetermined` |

## 5. D3：ReportValidator

### 5.1 结果结构

```swift
public struct ReportValidationResult: Equatable {
    public let isValid: Bool
    public let errors: [ReportWarning]
}

public struct ReportValidator {
    public init()
    public func validate(_ report: ReportEnvelope) -> ReportValidationResult
}
```

- Validator 不修改原始报告、不推断未知状态、不自动修复数据；发现的不一致以 `ReportWarning`（`code` 对应检查项编号，`sourceStage="validator"`）记入 `errors`。

### 5.2 检查项（RV-001～010）

| 编号 | 检查内容 | 不一致判据 |
|---|---|---|
| RV-001 | 信封必填信息 | `schemaVersion / generatorVersion / profile.id / profile.route` 为空；`environment` 缺失 |
| RV-002 | 插件唯一标识 | `pluginID` 重复；空串冒充标识 |
| RV-003 | 配对状态与文件证据一致 | `pairing` 状态与 dylib/plist 证据矛盾（如 `paired` 但两侧路径均缺失） |
| RV-004 | Filter 解析状态互斥 | 同一条目出现多个互斥解析状态；状态不在封闭集内 |
| RV-005 | 仅 `valid` 携带规则 | 非 `.valid` 条目携带非空 `filter`；`.valid` 条目 `filter=nil` |
| RV-006 | `loaded` 未知状态保留 | 运行层 `loaded` 被置为有证据取值而无运行时证据；`nil` 被转成 `false` |
| RV-007 | Ownership 与来源一致 | `plugin.source` 与 `ownership.sourceType` 矛盾；未知归属携带确定包标识 |
| RV-008 | Warning 不重复 | 同 `code + message + sourceStage` 重复条目 |
| RV-009 | UnknownItem 不丢失 | 上游失败/未配对条目在报告中无对应 `Plugin` 也无 `UnknownItem` |
| RV-010 | 双路线结果隔离 | 条目携带对方路线规则/状态证据；路线字段与 `profile.route` 矛盾 |

### 5.3 D3 测试用例

| 用例 | 输入 | 断言 |
|---|---|---|
| Validator-001 | 合法完整报告 | `isValid == true`，`errors` 为空 |
| Validator-002 | 注入各类不一致 | 对应 RV 编号告警；原始报告未被改写 |
| Validator-003 | 失败/未知条目样本 | RV-009 闭合核对：`plugins + unknownItems` 覆盖上游全部条目 |
| Validator-004 | 重复告警样本 | RV-008 检出重复；不擅自去重改写原报告 |

## 6. D4：JSON Exporter

### 6.1 类型落点

```swift
public struct ReportExporter {
    public init()
    public func export(_ report: ReportEnvelope) throws -> Data
}

public enum ReportSerialization {
    /// 确定性排序：plugins 按 pluginID；unknownItems 按 path（空则 base）；warnings 按 code。
    public static func sortedPlugins(_ plugins: [Plugin]) -> [Plugin]
    public static func sortedUnknownItems(_ items: [UnknownItem]) -> [UnknownItem]
    public static func sortedWarnings(_ warnings: [ReportWarning]) -> [ReportWarning]
}
```

### 6.2 编码规则

1. 符合 Stage 2.2-A/B 既有 Codable 契约；复用模型自有 `CodingKeys` 与解码兼容策略（如 `PathEvidence` 旧投影解码）。
2. `Optional Bool` 保留三态：`true / false / nil`；`nil` 序列化为 `null`，不缺省为 `false`。
3. 不丢失 `nil/null/缺失` 的既定编码行为；既有 `encodeIfPresent` 语义不变。
4. 确定性：`JSONEncoder` 开启 `.sortedKeys`（仅保证对象键序）；数组排序由 `ReportSerialization` 显式策略处理，不在导出时随意排序有语义的数组。
5. 相同输入产生确定性输出；`generatedAt` 排除在一致性比较之外。
6. 不修改原始报告；编码失败抛出明确错误（导出错误类型在实现批次定义，区分编码失败与数据不一致）。

### 6.3 排序策略

| 数组 | 排序键 | 次键 |
|---|---|---|
| `plugins` | `pluginID` | 空则 `name`，再空则 `plistPath ?? dylibPath` |
| `unknownItems` | `path`（空则 `base`） | `reason` |
| `warnings` | `code` | `sourceStage`、`message` |
| 条目内集合（`bundles/classes/executables/otherKeys/conflicts/notes`） | 沿用上游既有顺序；不在 Exporter 重排语义列表 | — |

### 6.4 D4 测试用例

| 用例 | 输入 | 断言 |
|---|---|---|
| Exporter-001 | 合法信封 | 编码成功；JSON 顶层 8 键齐全；可解码回等价信封 |
| Exporter-002 | 三态字段样本 | `Bool?` 的 `nil` 编码为 `null`；往返后三态保持 |
| Exporter-003 | 非确定性顺序样本 | 两次导出除 `generatedAt` 外字节/深比较一致 |
| Exporter-004 | 含 otherKeys/skippedFields/markers/conflicts/notes | 证据字段全部序列化可比对 |
| Exporter-005 | 编码失败样本 | 抛出明确错误；原始报告未被改动 |

## 7. D5：ReportService

### 7.1 复用既有协议（CoreServices.swift）

既有协议保持冻结，不在 D5 新建第二套服务抽象：

- `ReportExportService.export(environment:plugins:unknownItems:warnings:) -> ReportEnvelope`：信封组装轮廓。
- `OwnershipService.resolveOwnership(for:)`：归属编排接缝（分类器迁移后接入）。
- `EnvironmentService / PathResolutionService / PluginScanService / PluginParseService`：上游编排接缝。

### 7.2 统一入口

```swift
public protocol ReportServiceProtocol {
    /// 汇总上游快照并生成通过校验的信封；离线/注入路径为同步。
    func buildReport(input: ReportBuildInput) -> ReportEnvelope
    /// 校验报告；不通过时返回结果（不抛异常阻断），由调用方决定是否导出。
    func validate(_ report: ReportEnvelope) -> ReportValidationResult
    /// 导出只读 JSON 快照。
    func exportJSON(_ report: ReportEnvelope) throws -> Data
}

public struct ReportService: ReportServiceProtocol {
    public init(builder: ReportBuilder = ReportBuilder(),
                validator: ReportValidator = ReportValidator(),
                exporter: ReportExporter = ReportExporter())
}
```

- 编排顺序：环境 → 路径定位 → 插件扫描 → 配对 → 解析 → 归属分类 → Builder → Validator → `ReportEnvelope`；`exportJSON` 在校验后由调用方触发。
- 离线/夹具路径通过注入 `ReportBuildInput` 构造；接入真实 Adapter 时经既有 `AdapterResolver` 选择 Adapter，未知 Profile 不执行扫描。
- **GUI 边界**：GUI 只调用 `ReportServiceProtocol` 消费报告，不另写插件扫描器/解析器/路径解析器；本阶段不实现 GUI 页面。

### 7.3 D5 测试用例

| 用例 | 输入 | 断言 |
|---|---|---|
| Service-001 | 注入完整快照 | `buildReport` 产出信封；`validate` 通过；`exportJSON` 可解码 |
| Service-002 | 校验不通过样本 | 服务不抛异常；`validate` 返回错误项；`exportJSON` 是否导出由调用方决定 |
| Service-003 | 协议接缝注入 | Builder/Validator/Exporter 可替换为桩；服务不直接实例化具体上游实现 |

## 8. 文件落点与 Package 接线（实现批次登记）

| 文件 | 目标 | 内容 |
|---|---|---|
| `Core/Reporting/ReportBuilder.swift` | Core target | D2 输入、归并与状态映射 |
| `Core/Reporting/ReportValidator.swift` | Core target | D3 检查项 RV-001～010 |
| `Core/Reporting/ReportService.swift` | Core target | D5 协议与默认装配 |
| `Core/ReportExporter/ReportExporter.swift` | Core target | D4 编码入口 |
| `Core/ReportExporter/ReportSerialization.swift` | Core target | D4 排序策略 |
| `Tests/Stage2/ReportBuilderTests.swift` | Stage2Tests | D2 用例 |
| `Tests/Stage2/ReportValidatorTests.swift` | Stage2Tests | D3 用例 |
| `Tests/Stage2/ReportExporterTests.swift` | Stage2Tests | D4 用例 |
| `Tests/Stage2/ReportServiceTests.swift` | Stage2Tests | D5 用例 |

- 实现批次落地时，上述 Swift 文件显式登记进 `Package.swift` 的 Core / Stage2Tests `sources`；`Core/Reporting/` 新目录无需在 `exclude` 中占位。
- 既有 `Core/ReportExporter/.gitkeep`、`Core/OwnershipResolver/.gitkeep` 在对应实现落地后保留或移除，按既有目录惯例处理。

## 9. 测试映射与验收标准

### 9.1 与 S1-08 既有用例对应

| S1-08 用例 | D 批次落点 |
|---|---|
| EXPORT-001 信封字段齐全 | D2 Builder-001 + D4 Exporter-001 |
| EXPORT-002 Rootless 路线独立 | D2 Builder-002 |
| EXPORT-003 失败/孤儿/歧义不裁剪 | D2 Builder-001/003 |
| EXPORT-004 冲突混合归属不选边 | D2 Builder-004 |
| EXPORT-005 dpkg 不可用归属 unknown | D2 Builder-004/005 |
| EXPORT-006 未知 Profile 不套路线规则 | D2 Builder-005 + D3 RV-010 |
| EXPORT-007 上游缺失不回退扫描 | D2 Builder-005 |
| EXPORT-008 证据保留 | D4 Exporter-004 |
| EXPORT-009 确定性导出 | D4 Exporter-003 |
| EXPORT-010 状态分离 | D2 Builder-006 + D3 RV-006 |
| EXPORT-011 归属/权限互斥 | D3 RV-007 |
| EXPORT-012 null/unknown 不冒充已知 | D4 Exporter-002 |
| EXPORT-013 前序回归无损伤 | 统一 Runner 全量回归 |

### 9.2 通过条件

- 信封与条目结构符合既有公共模型；前序证据无丢失；三层状态与来源/权限分离口径落实；不确定状态显式保留。
- 相同输入可重复导出（除时间戳外一致）；导出为只读快照，不回写设备。
- 全部离线证据标记 `fixture`，不冒充真机验证；既有 Stage1/C2 回归无损伤。

### 9.3 失败情形（任一即不通过）

- 为规整报告丢弃告警、冲突、跳过字段、扩展键、未配对/失败条目。
- 由 `installed`/归属/Bundles 命中推导 `configured` 或 `loaded`；由 `writablePolicy`/来源推导管理放行。
- 未知 Profile 强行套用 RootHide/Rootless 规则；未取到字段留空串冒充已知。
- 两次导出因排序/键序/时间戳处理不一致而不可重复。
- 导出过程读写设备、修改 dpkg/plist/dylib/软链，或执行启停/注入。
- 把离线 fixture 结论标为真机背书。

## 10. 边界、未决项与禁止项

### 10.1 本阶段不做

- 不做重新扫描、重新解析、归属补判、运行时取证、操作执行；不创建 GUI 页面、不处理 entitlement、不接入进程内 `jbroot()`。
- 不改 Core 生产扫描/配对/Parser 逻辑、不改冻结公共 Models、不改七方法 `ElleKitAdapter` 协议签名。
- 不实现插件启停、装卸、注入或任何写入路径。

### 10.2 未决项（登记，不在本规格内解决）

1. **归属分类器迁移**：`Core/OwnershipResolver/` 尚未实现；D2/D5 归属为已解析快照注入，分类器落地单列批次。
2. **`pluginID` 定稿规则**：0.2.0 定稿；离线按优先级规则生成。
3. **运行时加载取证**：`loaded` 脱离 `unknown` 待后续阶段接口。
4. **Engine C2 统一 Runner**：已由第五轮 run `44106064051` 出证，C2-D1～D4 21 项 0 fail / 0 skip，C-G1～G7 passed（CI/Simulator 口径）；2.2-D 实现仍不替代真机证据。
5. **真机导出完整性 / Profile 识别准确性 / Rootless 真机模型适配**：待真机只读采样，离线为合成快照。

### 10.3 计数口径

- XCTest 实际执行数、S1-06 基线覆盖数、各模块专项数、既有回归数、静态检查数五类分列，不相加；本规格冻结的用例编号不代表 Runner 已执行。
