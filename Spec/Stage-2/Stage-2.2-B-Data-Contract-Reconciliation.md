# Stage-2.2-B-Data-Contract-Reconciliation.md — G-B1~G-B3 契约对齐评审（提案 vs Stage 1 基线）

> 状态：**对齐评审稿，契约尚未最终冻结**。本轮仅做字段/枚举/兼容口径对照与分歧登记；未修改 Models、`ElleKitAdapter` 协议、源码、测试代码与 Stage 1 基线。
> 输入：用户提案（G-B1~G-B3 结构化模型草案、G-B4 维持无参、G-B5 夹具深比较）；Stage 1 基线 `Tests/S1-01~03` 报告/夹具、`Tests/S1-08` 导出器与报告；现有 Models/协议现文件。
> 上游：`Stage-2.2-B-Environment-Path.md`（有条件冻结基线）、`Stage-2.2-B-Gap-Review.md`（缺口评审）。

## 1. 评审结论摘要

| 编号 | 提案方向 | 对齐结论 | 待拍板分歧 |
|---|---|---|---|
| G-B1 | 新增结构化版本状态，五态强类型，进入 JSON | 方向采纳；结构须对齐 S1-01 实际字段 | D1 前向字段取舍；D2 是否入信封导出；D3 告警类型 |
| G-B2 | 新增强类型 JBROOT 候选模型 | 方向采纳；提案枚举/校验位与 Stage 1 口径有出入 | D4 候选状态取值集；D5 route 类型；D6 校验位字段集；D7 未知来源兼容；D8 旧 `[String]` 字段去留 |
| G-B3 | 通用路径证据 + 软链证据独立结构 | 方向采纳；软链状态分类须保留 Stage 1 五值 | D9 目录状态字段口径；D10 软链状态字段集；D11 容器落点 |
| G-B4 | 维持无参 `resolvePaths()` | ✅ 采纳，与上轮评审一致 | 无；协议演进触发条件沿用 Gap-Review §5.3 |
| G-B5 | Stage2Tests 原生读 Stage 1 夹具，确定性深比较 | ✅ 采纳 | D12 基线期望固化位置与比较工具形态 |

**四条通用约束（提案与冻结契约一致，纳入最终契约）**：

1. 新增字段一律 `Optional` 并提供旧 JSON 兼容默认值；
2. 不改变 Stage 1 既有字段含义；未取到显式值留 `nil`，不留空串冒充已知；
3. 校验位三态：`true` 已验证通过 / `false` 已验证失败 / `nil` 未验证；**不得把未检查映射为 `false`**；
4. 模型只描述事实，不含 RootHide/Rootless 路线判断代码；路线规则在各自 Adapter。

## 2. Stage 1 实际口径基线（对照基准，只读）

### 2.1 S1-01 环境识别（15 例）

- 版本状态 `ellekitVersionStatus`：`parsed / not_installed / unreadable / unparsable / conflicted`；
- 裁决 `outcome`：`profile_candidate / partial / unknown / conflict_no_profile / unsupported_profile`；
- 结果字段：`jailbreakType / architecture / iosVersion / bootstrap{name,version} / ellekitImplementation / ellekitVersion / adapterProfile / evidence / warnings`；
- `evidence.<field>`：逐字段 `{value, status, evidenceType, evidenceSource}`；
- 告警：Stage 1 报告为代码串；S1-08 导出为 `{code, message, sourceStage}` 对象（对齐现有 `ReportWarning`）。

### 2.2 S1-02 JBROOT 候选（18 例）

候选对象字段（10）：`root / source / route / nameValid / exists / structureMatch / readable / realpath / status / warnings`。

- `source`：`api / scan / bootstrap / rootless / rootful`；
- `route`：`roothide / rootless / rootful`；
- `status`：`confirmed / partial / cross_route / rejected_invalid / rejected_missing / resolve_failed`（resolver 内部另有 `pending` 初始态，不落最终报告）；
- 顶层：`jbroot / jbrand / realpath / ambiguous / outcome / selectedSource / candidateCount / candidates / warnings`。

### 2.3 S1-03 目录定位（15 例）

- `tweakInject` 字段（7）：`value / exists / readable / enumerable / realpath / structureMatch / status`；
- `dynamicLibraries` 字段（6）：`value / isSymlink / symlinkTarget / realpath / symlinkState / targetMatch`；
- `symlinkState`：`resolved / broken / loop / denied / not_symlink`；
- 顶层 `outcome`：`resolved / partial / not_found / unresolved / structure_conflict / rootful_diagnostic`。

### 2.4 S1-08 导出形态（信封 JSON 基线）

- 候选导出子集：`{source, path}`（来源示例另有 `jbroot_container`，不在 S1-02 五来源内）；
- `tweakInject` 导出子集：`{path, exists, readable?}`；`dynamicLibraries` 导出子集：`{symlink, target}` 或 `null`；
- 告警导出：`{code, message, sourceStage}`；
- 信封当前**未持久化**版本五态、候选全量校验位、目录/软链全量状态。

## 3. G-B1 对齐：VersionReadiness

### 3.1 提案草案 vs 基线对照

| 提案字段 | Stage 1 对应 | 对齐评审 |
|---|---|---|
| `status: VersionReadinessStatus`（五态强类型） | `ellekitVersionStatus` 五态 | ✅ 采纳；枚举原始值与五态字符串逐字一致（`not_installed` 等） |
| `rawValue: String?` | `ellekitVersion` 原始串 | ✅ 采纳；建议命名 `rawVersion` 以区别枚举 `rawValue` 概念 |
| `parsedVersion: String?` | 基线无对应（无版本归一化产物） | ⚠ 前向字段：当前 15 例夹具无覆盖；是否纳入首版契约待拍板（D1） |
| `sources: [String]` | 基线无来源列表字段 | ⚠ 前向字段；同上（D1） |
| `warnings: [String]` | 导出告警为 `ReportWarning` 对象 | ⚠ 建议对齐现有 `[ReportWarning]`，不用字符串数组（D3） |

### 3.2 建议落位（草案，未冻结）

- 新结构 `VersionReadiness` 作为 `JailbreakEnvironment` 的**可选**增补字段（如 `versionReadiness: VersionReadiness?`，默认 `nil`）；
- 首版最小字段集（对齐基线）：`status`、`rawVersion: String?`、`warnings: [ReportWarning]`；`parsedVersion / sources` 列为前向预留，待 D1 决定是否进入；
- `evidenceLevel`（证据可信度）与版本读取状态**不互相替代**：前者沿用现有 `EvidenceLevel`，后者由 `VersionReadiness.status` 表达；
- 逐字段证据位（`evidence.<field>`）首版不落公共模型，先经 `EvidenceBlock`/告警承载；是否增补字段级证据结构列入后续评审。

### 3.3 JSON 兼容

- 字段可选 + 默认 `nil`：旧信封 JSON 解码不报错；新 JSON 显式输出该字段；
- 是否将 `VersionReadiness` 序列化进 `ReportEnvelope` 属 D2：若入信封，S1-08 基线缺该字段，深比较须把"基线缺失"容忍为 `nil`；若瞬态则不参与导出；
- 不改动现有 `ellekitVersion / ellekitImplementation / evidenceLevel` 字段语义。

## 4. G-B2 对齐：JBRootCandidate

### 4.1 提案草案 vs 基线对照

| 提案项 | Stage 1 基线 | 对齐评审 |
|---|---|---|
| `source: JBRootCandidateSource`（api/scan/bootstrap/rootless/rootful） | 五来源 + 导出侧 `jbroot_container` | ⚠ 强枚举遇未知来源（`jbroot_container`）须有 `unknown` 兜底并保留原始串，不得解码崩溃（D7） |
| `route: JailbreakType` | `route` ∈ `roothide / rootless / rootful` | ⚠ 现有 `JailbreakType` 仅 `roothide/rootless/unknown`，**无 `rootful`**；建议 `route: String`（沿用 `ProfileRef.route` 先例），不把 `rootful` 塞进现有枚举（D5） |
| `validation.pathFormatValid` | `nameValid` | 字段重命名；建议保留基线命名语义映射，命名在冻结时统一（D6） |
| `validation.checksumValid` | 基线无校验和位 | ⚠ 基线不存在；首版不纳入（D6） |
| `validation.directoryExists` | `exists` | 三态 `Bool?` |
| `validation.structureValid` | `structureMatch` | 三态 `Bool?` |
| （提案缺）`readable / realpath` | `readable: Bool?`、`realpath: String?` | ⚠ 建议补回；可读位与 realpath 是 S1-02 校验链证据（D6） |
| `status: JBRootValidationStatus`（pending/confirmed/rejected/unconfirmed） | 六态 `confirmed/partial/cross_route/rejected_invalid/rejected_missing/resolve_failed` | ⚠ 提案四态合并会丢失 `partial / cross_route / rejected_invalid vs rejected_missing / resolve_failed` 区分；建议保留基线六态字符串（沿用 `ValidationReport.status` 先例）或强枚举完整覆盖六态（D4） |
| `warnings: [String]` | `ReportWarning` 对象 | ⚠ 对齐 `[ReportWarning]`（D3） |

### 4.2 建议落位（草案，未冻结）

- 候选结构承载：路径、来源、路线、校验位、裁决状态、候选告警；**不含校验算法**（算法在 Adapter）；
- 校验位三态：`nameValid / exists / structureMatch / readable: Bool?`，`realpath: String?`；`nil` = 未验证；
- 顶层裁决落位：`jbroot / jbrand / realpath` 入现有 `JailbreakEnvironment / EnvironmentPaths` 字段；`ambiguous` 多候选不选边，全量候选保留；`selectedSource` 仅唯一确认时非 `nil`；
- 候选状态与插件 `Pairing` 属不同领域，**不新增配对枚举值**。

### 4.3 旧字段兼容策略（D8）

- 现状：`PathEvidence.jbrootCandidates: [String]`；
- 提案建议双字段过渡：旧 `[String]` 作兼容投影，新结构数组为权威来源；
- 待拍板：首版是直接以新结构替换，还是双字段过渡；若双字段，须规定投影由权威结构派生，不维护两套独立数据；旧字段废弃时点另行评审。

## 5. G-B3 对齐：PathLocationEvidence / SymlinkEvidence

### 5.1 提案草案 vs 基线对照

**目录路径（tweakInject）**

| 提案字段 | Stage 1 基线 | 对齐评审 |
|---|---|---|
| `requestedPath` | `value` | 命名映射，冻结时统一（D9） |
| `resolvedPath` | `realpath` | ✅ `String?` |
| `exists / readable / enumerable` | 同名三态位 | ✅ `Bool?`，未验证 = `nil` |
| `structureValid` | `structureMatch` | 命名映射（D9） |
| `evidenceLevel: EvidenceLevel` | 基线目录对象无证据等级，有 `status` | ⚠ 建议保留基线目录 `status: String?`；目录级证据等级是否另挂待拍板（D9） |
| `warnings: [String]` | `ReportWarning` | ⚠ 对齐 `[ReportWarning]`（D3） |

**软链（dynamicLibraries）**

| 提案字段 | Stage 1 基线 | 对齐评审 |
|---|---|---|
| `isSymlink: Bool?` | `isSymlink` | ✅ 保留三态：`false` 已确认非软链 / `nil` 未检查 |
| `targetPath` | `symlinkTarget` | 命名映射（D10） |
| `realpath` | `realpath` | ✅ `String?` |
| `targetExists / targetReadable / resolutionSucceeded` | 基线无直接位；有 `symlinkState / targetMatch` | ⚠ 提案用布尔组合替代状态分类；基线 `symlinkState` 五值（resolved/broken/loop/denied/not_symlink）承载 loop/denied 等分类，建议**保留 `symlinkState: String?` 与 `targetMatch: Bool?`**，提案布尔位作为可选增补（D10） |
| `warnings: [String]` | `ReportWarning` | ⚠ 对齐 `[ReportWarning]`（D3） |

### 5.2 建议容器（草案，未冻结）

```
PathLocationEvidence { requestedPath, resolvedPath, exists?, readable?, enumerable?,
                       structureValid?, status: String?, warnings: [ReportWarning] }
SymlinkEvidence      { isSymlink?, targetPath, realpath, symlinkState: String?,
                       targetMatch: Bool?, warnings: [ReportWarning] }
```

- 目录证据与软链证据分结构，避免无关 Optional 字段堆积；
- 容器落点（`PathEvidence` 还是 `EnvironmentPaths`，或两者经 Adapter 映射）属 D11；现有两处 `String?` 字段的替换范围在 Models 增补授权时一并界定；
- Rootful 路径仅诊断参照，经 `status` + 告警 `rootful_route_not_profile` 表达，不进可执行 Profile；Rootless 无真机结论经证据等级 + 风险告警保留，模型内不标真机兼容。

## 6. G-B4 协议充分性（已采纳，不改协议）

- 七方法协议保持冻结；`resolvePaths()` 维持无参；环境在 `AdapterResolver.resolveAdapter(for:)` 选择阶段传入；
- Adapter 路线封闭，Core 不回传路线参数；不新增 `resolveJBRoot() / resolveElleKitDirectory()` 平行接口；
- 协议演进触发条件沿用 Gap-Review §5.3（Adapter 取不到所需环境 / 须引入可变共享状态 / 单 Adapter 须处理多 Profile / 返回值无法承载结果）；出现任一才走单独协议评审，且只允许只读方法。

## 7. G-B5 夹具深比较（已采纳）

- 载体：`Tests/Fixtures/S1-01~03/` 只读引用；Stage2Tests 原生解析 JSON，不复制第二套测试数据；
- 流程：读夹具 → 调 Swift Core → 生成结果 → Codable 编码 → 规范化 JSON → 与 Stage 1 基线深比较 → 报告差异；
- 必比维度（沿用 Gap-Review §6.2）：S1-01 类型/实现/版本/五态/Profile/证据等级/告警；S1-02 候选数量/来源/顺序/路线/校验位/状态/歧义/选中来源/告警；S1-03 路线/目录各位/软链状态与匹配位/告警；
- 排除：`generatedAt` 时间差异；B 阶段 `plugins` 不比较（属 2.2-C）；`unknownItems / warnings` 全比较；
- 候选/告警顺序按夹具固定顺序比较，不在测试内无序排序兜底；除允许变化字段外逐字段深比较；
- 基线期望固化位置与比较工具形态（测试内 helper vs 共享辅助目标）属 D12。

## 8. 待拍板决策清单（B1 授权前完成）

| # | 决策项 | 选项 |
|---|---|---|
| D1 | G-B1 前向字段 `parsedVersion / sources` 是否进入首版契约 | A 不纳入（最小对齐基线）/ B 纳入并标注当前夹具无覆盖 |
| D2 | `VersionReadiness` 是否序列化进信封 JSON | A 入信封（深比较容忍基线缺失为 nil）/ B 运行时瞬态不导出 |
| D3 | 告警载体 | 统一 `[ReportWarning]`（建议）/ 沿用 `[String]` |
| D4 | 候选状态类型与取值集 | A 字符串状态保留六态（建议，同 ValidationReport）/ B 强枚举完整覆盖六态 / C 提案四态合并（不建议，丢区分） |
| D5 | 候选 `route` 类型 | A `String`（建议，兼容 rootful）/ B 扩展 `JailbreakType` 加 rootful（须单独枚举评审） |
| D6 | 候选校验位字段集 | 对齐基线 `nameValid/exists/structureMatch/readable/realpath`；`checksumValid` 首版不纳入 |
| D7 | 未知来源兼容 | 强枚举 `unknown` 兜底 + 保留原始串；或来源用 String + 已知映射 |
| D8 | 旧 `jbrootCandidates: [String]` 去留 | A 直接替换为新结构 / B 双字段过渡（新结构权威，旧字段派生投影） |
| D9 | 目录状态字段 | 保留基线 `status: String?`；`evidenceLevel` 是否目录级另挂 |
| D10 | 软链字段集 | 保留 `symlinkState` 五值 + `targetMatch`；提案 `targetExists/targetReadable/resolutionSucceeded` 是否增补 |
| D11 | 证据容器落点 | `PathEvidence` / `EnvironmentPaths` 替换范围与映射 |
| D12 | G-B5 基线期望位置与比较工具形态 | 测试内常量 / 夹具基线文件；helper 内联 / 共享辅助目标 |

## 9. 实现组织说明（非契约，B1 授权后再定）

提案 §7 的 Core/Adapter 文件拆分（EnvironmentDetector、JBRootValidator、RootHideEnvironmentAdapter 等）为组织建议；最终须尊重当前工程结构（现有单一 `RootHideAdapter / RootlessAdapter` 实现协议），不为示例大规模移动已有文件。模块目录沿用主规格 §5 骨架。

## 10. 授权边界（本轮保持）

| 事项 | 状态 |
|---|---|
| G-B1~G-B3 契约对齐评审、G-B4 结论、G-B5 设计 | ✅ 本轮产出 |
| 数据契约最终冻结（字段名/类型/枚举取值/兼容策略定稿） | ⏳ 待 D1~D12 拍板 |
| 修改 Models 字段/类型/枚举/解码行为 | ❌ 未授权 |
| 修改 `ElleKitAdapter` 协议 | ❌ 未授权 |
| 编写 B 源码 / 测试代码 | ❌ 未授权 |
| 48 项 Swift 回归执行 | ❌ 未授权 |
| 2.2-C 及以后、进入 2.3 | ❌ 未授权 |
