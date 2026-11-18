# Stage-2.2-B-Data-Contract-Freeze.md — Environment / Path 数据契约冻结（D1~D12 定稿）

> 状态：**2.2-B 数据契约冻结（设计层）**。本文定稿 G-B1~G-B3 增补模型字段、类型、Optional 规则、枚举原始值、JSON 编码与旧 JSON 兼容策略、G-B4 协议边界、G-B5 测试口径；**不含任何 Swift 源码实现**。
> 生效条件：B1–B5 实现、Models 增补落地、协议修改、测试代码编写均仍未授权；实现阶段必须以本文契约为准。
> 依据：`Stage-2.2-B-Environment-Path.md`（有条件冻结基线）、`Stage-2.2-B-Gap-Review.md`（缺口评审）、`Stage-2.2-B-Data-Contract-Reconciliation.md`（D1~D12 分歧登记）；Stage 1 基线 `Tests/S1-01~03` 报告/夹具、`Tests/S1-08` 导出器与报告；现有 Models/协议现文件。

## 1. 冻结总则

1. **只增补，不改语义**：现有 `JailbreakEnvironment / PathEvidence / EnvironmentPaths` 既有字段名称、类型、原始值、解码行为不变；新模型与新字段一律 `Optional` 并提供旧 JSON 兼容默认值。
2. **三态校验**：校验位 `Bool?` 中 `true`=已验证通过、`false`=已验证失败、`nil`=未验证；未验证不得填 `false`，不留空串冒充已知。
3. **未知不丢信息**：来源/路线/状态等开放取值用 `String` 原样保留；封闭取值集见 §4；非已知值原样入库并附未知类告警，不映射、不丢弃、不在解码期抛错。
4. **事实与规则分离**：模型只记录事实（路径、来源、校验位、状态、证据、告警）；RootHide/Rootless 校验算法与路径规则只在各自 Adapter 内实现，模型内不出现路线判断代码。
5. **唯一权威**：每个事实只允许一个权威数据源；兼容投影必须由权威结构派生，不维护第二套可独立变更的状态。
6. **不新增配对领域状态**：JBROOT 候选裁决状态不得并入插件 `Pairing` 枚举。

## 2. D1~D12 决策定稿表

| # | 决策项 | 定稿选择 | 选择理由 | 对 Stage 1 基线影响 | 旧 JSON 兼容策略 | 补充测试安排 |
|---|---|---|---|---|---|---|
| D1 | G-B1 前向字段 | 首版含 `rawVersion: String?`、`parsedVersion: String?`；`sources` 暂缓，不进首版契约（预留不实现） | 五态与原始串基线已有；解析后版本供 GUI/导出复用、避免重读文件；来源列表当前无消费场景 | 不改现有 `ellekitVersion`；`VersionReadiness` 为增补结构；当前夹具 `parsedVersion` 与原始串一致，归一化逻辑归 Adapter | 新字段缺省解码为 `nil`；旧信封解码不报错 | 随 B1 夹具补 Codable 往返一例；本轮不写测试代码 |
| D2 | 版本状态是否入信封 | **进入** `ReportEnvelope`，挂 `JailbreakEnvironment` 增补可选字段 `versionReadiness: VersionReadiness?` | 版本读取状态属环境诊断证据，CLI/GUI 结果一致，后续模块不重读版本文件 | S1-08 基线当前未持久化该字段；Swift 侧多出的增补可选字段不计入 48 项行为差异，深比较显式标注为"增补可选" | 旧信封缺该字段解码为 `nil`；新 JSON 显式输出 | 深比较规则在 G-B5 标注该字段豁免基线缺失 |
| D3 | 告警载体 | G-B1~G-B3 新结构统一 `[ReportWarning] {code,message,sourceStage}`；不另造告警类型 | 与现有 Adapter 模型、S1-08 导出形态一致 | 不改 Stage 1 报告内 code 串形态；入库前经既有告警收集归一化为对象 | 旧告警 code 串经归一化路径转换；新结构解码缺省 `[]` | 随 B1/B2/B3 覆盖告警往返 |
| D4 | 候选状态取值集 | 保留 Stage 1 **六态**，不合并；首版 `status: String?` 承载，封闭集文档化；`pending` 仅 resolver 内部初始态，不落最终报告 | 六态区分 `partial / cross_route / rejected_invalid vs rejected_missing / resolve_failed`，合并会丢诊断 | 对齐 S1-02 候选 `status` 实测六值；不新增基线外状态 | 未知状态原样保留并附告警，不抛解码错误 | 随 B2/B3 夹具覆盖六态 |
| D5 | 候选 `route` 类型 | `route: String`；不扩展 `JailbreakType` | 基线含 `rootful`，现有 `JailbreakType` 无此值；协议 `route: String` 已是 String，沿用 `ProfileRef.route` 先例 | 取值集 `roothide / rootless / rootful`；未知原样保留 | 解码缺省/缺失为 `nil` 或空串保守值，不反推路线 | 随 B2 覆盖三路线 |
| D6 | 候选校验位字段集 | 五项三态对齐基线：`nameValid: Bool?`、`exists: Bool?`、`structureMatch: Bool?`、`readable: Bool?`、`realpath: String?`；**不纳入** `checksumValid` | 基线无校验和位；四项布尔校验位 + realpath 覆盖 S1-02 校验链 | 字段语义与 S1-02 候选键逐一对齐；`nil`=未验证 | 旧 JSON 缺校验位解码为 `nil`，不填 `false` | 随 B2/B3 覆盖三态与各校验位 |
| D7 | 未知来源兼容 | `source: String` 原样保留；已知集 `api / scan / bootstrap / rootless / rootful`；非已知值原样入库 + 未知来源告警；不采用会丢原始值的强枚举 | S1-08 实测存在 `jbroot_container` 等基线外来源；原始信息必须可追溯 | 已知五值对齐 S1-02；未知值不丢、不崩 | 缺失来源为 `nil`；解码不抛错 | 随 B2 覆盖已知 + 未知来源样例 |
| D8 | 旧 `jbrootCandidates: [String]` 去留 | **双字段过渡**：`jbrootCandidateDetails: [JBRootCandidate]` 为唯一权威；旧 `jbrootCandidates: [String]` 为派生投影（由权威结构 `path` 生成），构造时同步；旧字段废弃时点待消费者迁移完毕另行评审 | 避免旧 CLI/旧资料/GUI 未迁移即失候选路径；同时避免两套独立状态漂移 | 现有 `[String]` 字段名与解码行为保留；权威数据以新结构为准 | 旧信封解码只填投影字段；新信封两字段同源派生 | 随 B2 加投影一致性校验：投影 = 权威结构路径列表 |
| D9 | 目录状态口径 | 保留独立 `status: String?`；不用 `evidenceLevel` 替代；目录级首版不另挂证据等级 | `status` 是目录读取/结构裁决状态，`evidenceLevel` 是环境级证据可信度，语义不同 | 对齐 S1-03 `tweakInject.status` | 缺失解码为 `nil` | 随 B4 覆盖目录状态 |
| D10 | 软链字段集 | 保留 `symlinkState: String?` 五态 + 独立 `targetMatch: Bool?`；提案 `targetExists / targetReadable / resolutionSucceeded` 首版不纳入 | 五态承载 `loop / denied / broken` 等分类，布尔组合无法表达；`targetMatch` 是独立判定 | 对齐 S1-03 `dynamicLibraries` 六键；`isSymlink: Bool?` 保留三态（`false` 已确认非软链 / `nil` 未检查） | 缺省 `nil`；`isSymlink=false` 与未检查不得混同 | 随 B4 覆盖五态 + targetMatch |
| D11 | 证据容器落点 | 证据结构挂公共环境/路径证据模型（`PathEvidence` / `EnvironmentPaths` 增补侧车字段），不进 Adapter 私有规则；Adapter 只采集与判定，产出统一模型 | Core 只消费统一模型；路线规则留在 Adapter | 现有 `String?` 路径字段保留至 Models 增补授权时界定替换范围 | 侧车字段 Optional 缺省 `nil` | 随 B3/B4 校验模型装配结果 |
| D12 | G-B5 基线固化位置 | 测试只读引用 `Tests/Fixtures/S1-01~03/` 原始夹具；不复制第二套易漂移基线；比较 helper 内联于 Stage2Tests 测试目标（共享辅助目标待测试规模增长再评） | 单一事实源，避免双份基线失同步 | 期望以夹具报告为准；除 `generatedAt` 外逐字段深比较 | — | B5 落地时按 §7 维度实现 |

## 3. G-B1 定稿模型：VersionReadiness

### 3.1 状态枚举（五态，原始值冻结）

```
enum VersionReadinessStatus: String, Codable {
    case parsed
    case notInstalled = "not_installed"
    case unreadable
    case unparsable
    case conflicted
}
```

- 取值与 S1-01 `ellekitVersionStatus` 实测五值逐字一致；基线无第六态，不预留未确认值。

### 3.2 结构（增补，未落地为 Swift 代码）

```
struct VersionReadiness: Codable, Equatable {
    let status: VersionReadinessStatus
    let rawVersion: String?        // 原始版本串（对应现有 ellekitVersion 原始值）
    let parsedVersion: String?    // 归一化后版本；当前夹具与 rawVersion 一致
    let warnings: [ReportWarning]
}
```

- `sources: [String]` 暂缓（D1），首版不出现该字段；
- `rawVersion` 与 `parsedVersion` 不可互相替代：多来源不一致时 `status = conflicted`，不得任选其一作为最终版本；
- 挂接位置：`JailbreakEnvironment.versionReadiness: VersionReadiness?`（增补可选字段，D2）；
- 不改变现有 `ellekitImplementation / ellekitVersion / evidenceLevel` 语义。

## 4. G-B2 定稿模型：JBRootCandidate

### 4.1 校验位结构

```
struct JBRootValidationBits: Codable, Equatable {
    let nameValid: Bool?
    let exists: Bool?
    let structureMatch: Bool?
    let readable: Bool?
    let realpath: String?
}
```

### 4.2 候选结构

```
struct JBRootCandidate: Codable, Equatable {
    let path: String
    let source: String            // 已知集 api/scan/bootstrap/rootless/rootful；未知原样保留（D7）
    let route: String             // roothide/rootless/rootful；未知原样保留（D5）
    let validation: JBRootValidationBits
    let status: String?           // 六态封闭集（D4）
    let warnings: [ReportWarning]
}
```

### 4.3 封闭取值集（文档化，非强枚举）

- `status`：`confirmed / partial / cross_route / rejected_invalid / rejected_missing / resolve_failed`；`pending` 仅内部初始态；
- `source` 已知集：`api / scan / bootstrap / rootless / rootful`；
- `route` 已知集：`roothide / rootless / rootful`；
- 顶层裁决保留现有模型字段：`jbroot / jbrand / realpath` 入 `JailbreakEnvironment / EnvironmentPaths`；多确认候选 `ambiguous` 不选边，全量候选保留；`selectedSource` 仅唯一确认时非 `nil`。

### 4.4 兼容投影（D8）

- 权威：`PathEvidence.jbrootCandidateDetails: [JBRootCandidate]`；
- 投影：`PathEvidence.jbrootCandidates: [String]`，由权威结构 `path` 派生；
- 投影与权威在构造点同步；测试须校验投影 == 权威路径列表；
- 旧字段废弃：待所有消费者迁移完毕，单独评审后再移除，不在本批次删除。

## 5. G-B3 定稿模型：PathLocationEvidence / SymlinkEvidence

### 5.1 目录路径证据

```
struct PathLocationEvidence: Codable, Equatable {
    let requestedPath: String
    let resolvedPath: String?     // 对应基线 realpath
    let exists: Bool?
    let readable: Bool?
    let enumerable: Bool?
    let structureMatch: Bool?
    let status: String?           // 目录裁决状态（D9），不用 evidenceLevel 替代
    let warnings: [ReportWarning]
}
```

### 5.2 软链证据

```
struct SymlinkEvidence: Codable, Equatable {
    let isSymlink: Bool?
    let targetPath: String?       // 对应基线 symlinkTarget
    let realpath: String?
    let symlinkState: String?     // 五态（D10）
    let targetMatch: Bool?
    let warnings: [ReportWarning]
}
```

- `symlinkState` 封闭集：`resolved / broken / loop / denied / not_symlink`；
- `isSymlink` 三态：`false`=已检查确认非软链；`nil`=未检查，二者不得混同；
- 首版不纳入 `targetExists / targetReadable / resolutionSucceeded / structureValid` 等基线外布尔位。

### 5.3 容器侧车（D11，落点在 Models 增补授权时定稿字段名）

```
// 设计示意；现有 String? 路径字段保留，侧车与之并列，替换范围另行授权
struct ElleKitPathSidecar: Codable, Equatable {
    let tweakInject: PathLocationEvidence?
    let dynamicLibraries: PathLocationEvidence?
    let dynamicLibrariesSymlink: SymlinkEvidence?
}
```

- RootHideAdapter 产 RootHide 证据，RootlessAdapter 产 Rootless 证据；Core 只消费统一模型；
- Rootful 路径仅诊断参照，经 `status` + 告警表达，不进可执行 Profile；Rootless 无真机结论经证据等级 + 风险告警保留，模型内不标真机兼容。

## 6. G-B4 协议边界（已冻结，不改协议）

- 七方法协议保持冻结：`route: String`、`getEnvironment()`、`resolvePaths()`、`scanPlugins()`、`readPlugin(_:)`、`validatePlugin(_:)`、`parseFilter(_:)`、`resolvePath(_:)`；
- `resolvePaths()` 维持**无参**；环境在 `AdapterResolver.resolveAdapter(for:)` 选择阶段传入；Core 不回传路线参数；
- 不新增 `resolveJBRoot() / resolveElleKitDirectory()` 平行接口；
- 协议演进触发条件（任一满足才走单独协议评审，且只允许只读方法）：
  1. Adapter 取不到执行解析所需环境信息；
  2. 须引入可变共享状态才能完成解析；
  3. 同一 Adapter 须处理多个不同 Profile；
  4. 现有返回值无法完整承载解析结果。

## 7. G-B5 测试口径（已冻结）

- 载体：Stage2Tests 原生只读引用 `Tests/Fixtures/S1-01~03/` JSON，不复制测试数据；
- 流程：读夹具 → 调 Swift Core → 生成结果 → Codable 编码 → 规范化 JSON → 与 Stage 1 基线深比较 → 报告差异；
- 深比较维度：
  - S1-01：类型 / 实现 / 版本 / 五态 / Profile / 证据等级 / 告警；
  - S1-02：候选数量 / 来源 / 顺序 / 路线 / 校验位 / 状态 / 歧义 / 选中来源 / 告警；
  - S1-03：路线 / 目录各位 / 软链状态与匹配位 / 告警；
- 排除与豁免：`generatedAt` 时间差异；B 阶段 `plugins` 不比较（属 2.2-C）；D2 增补可选字段在基线缺失时豁免为 `nil`；
- 告警/候选顺序按夹具固定顺序比较，不在测试内无序排序兜底；除允许变化字段外逐字段深比较；
- 测试文件建议：`EnvironmentDetectionTests / JBRootResolutionTests / ElleKitPathResolutionTests / EnvironmentPipelineTests.swift`；helper 内联测试目标。

## 8. 48 项回归映射（沿用 B 子规格 §3）

| 子批次 | 范围 | 项数 | 对应夹具 | 前置契约 |
|---|---|---|---|---|
| B1 | Environment Detection（环境识别 + 版本五态） | 15 | S1-01 | G-B1 已冻结（本文 §3） |
| B2 | JBROOT Candidate Collection（候选采集与完整性） | — | S1-02 | G-B2 已冻结（本文 §4） |
| B3 | JBROOT Validation（候选校验与裁决） | 18（B2+B3 合计） | S1-02 | G-B2 已冻结 |
| B4 | ElleKit Directory Resolution（目录 + 软链定位） | 15 | S1-03 | G-B3 已冻结（本文 §5） |
| B5 | Pipeline Integration（环境→路径统一编排） | 48 全量 | S1-01~03 | G-B1~G-B3 全部冻结 |

- 门禁：B1 开工前 G-B1 定稿；B2 开工前 G-B2 定稿；B4 开工前 G-B3 定稿；不得等到编码时再定模型；
- B1 只实现环境识别与版本五态，不提前实现 JBROOT 候选校验、目录解析或 Pipeline 集成。

## 9. 硬门禁自查（契约冻结前逐项核对）

| 门禁 | 结论 | 依据 |
|---|---|---|
| 不改变 Stage 1 48 项行为定义 | ✅ 通过 | 契约只增补可选结构；校验位/状态/来源/路线取值集逐项对齐基线 |
| 不改变 2.2-A 已通过 21 例 Codable 测试 | ✅ 通过 | 现有模型字段语义不动；`ValidationReport.warnings: [String]` 属 2.2-A 冻结面，本轮不改 |
| 不引入未经确认的枚举值 | ✅ 通过 | 封闭集均来自基线实测；开放取值走 String 兜底，不新增状态 |
| 未验证字段不默认填 `false` | ✅ 通过 | 校验位三态 `Bool?`，规则见 §1.2 |
| 未知来源不丢失原始信息 | ✅ 通过 | `source: String` 原样保留 + 未知告警（D7） |
| RootHide / Rootless 路线规则隔离 | ✅ 通过 | 模型无路线规则代码；规则在各自 Adapter（§1.4、§6） |
| 不出现两个互相矛盾的权威数据源 | ✅ 通过 | D8 投影派生；唯一权威为 `jbrootCandidateDetails` |

## 10. 暂缓与遗留事项

1. `VersionReadiness.sources`、提案软链布尔位、`checksumValid`：首版不纳入，后续有消费场景再评；
2. `parsedVersion` 归一化算法：Adapter 内部实现，契约只约束字段存在性；
3. 证据侧车字段名与现有 `String?` 路径字段的替换范围：Models 增补授权时定稿；
4. 旧 `jbrootCandidates: [String]` 废弃时点：消费者迁移完毕后单独评审；
5. Core/Adapter 文件目录拆分（EnvironmentDetector、JBRootValidator 等）为实现组织建议，B1 实现授权后尊重现有工程结构再定；
6. 规格文案滞后项（`Plugin-Data-Model.md` 草图缺字段/枚举）：属文档同步，不混入本轮 Models 语义。

## 11. 授权边界（保持）

| 事项 | 状态 |
|---|---|
| D1~D12 决策定稿与契约冻结文档 | ✅ 本轮产出 |
| 修改 Models 字段/类型/枚举/解码行为 | ❌ 未授权 |
| 修改 `ElleKitAdapter` 协议 | ❌ 未授权 |
| 编写 B 源码 / 测试代码 | ❌ 未授权 |
| 48 项 Swift 回归执行 | ❌ 未授权 |
| 2.2-C 及以后、进入 2.3 | ❌ 未授权 |
