# Stage-2.2-B-Gap-Review.md — G-B1~G-B5 设计评审（设计层）

> 状态：**设计评审稿，未授权落地**。本轮仅完成信息对照、缺口分析与最小增补方案草案；未修改 Models、`ElleKitAdapter` 协议、源码、测试代码与 Stage 1 基线。
> 授权依据：2026-11-16 用户确认——B 子规格为**有条件冻结基线**；允许开展 G-B1~G-B3 独立 Models 增补设计评审、G-B4 协议充分性评审、G-B5 Swift Fixture 深比较设计；B1–B5 实现暂不授权。
> 上游：`Stage-2.2-B-Environment-Path.md`（有条件冻结草案）、`Stage-2.2-Core-Models-Migration.md`（主规格 §3/§4/§7/§8）。

## 0. 评审结论摘要

| 编号 | 问题 | 评审方向 | 是否需要改 Models / 协议 | 本轮是否落地 |
|---|---|---|---|---|
| G-B1 | 版本识别五态（parsed / not_installed / unreadable / unparsable / conflicted）无结构化承载 | 倾向新增只读状态结构；备选复用 `ValidationReport`；告警串方案不建议 | 可能需要 Models 增补（待拍板） | ❌ 未落地 |
| G-B2 | `jbrootCandidates: [String]` 丢失候选来源/校验位/裁决状态 | 倾向新增候选结构类型替换字符串数组 | 需要 Models 类型增补（待拍板） | ❌ 未落地 |
| G-B3 | `tweakInject / dynamicLibraries: String?` 丢失存在/可读/可枚举/结构/软链证据 | 倾向新增路径证据结构与软链子结构 | 需要 Models 类型增补（待拍板） | ❌ 未落地 |
| G-B4 | `resolvePaths()` 无参是否充分 | **保留无参**；Adapter 路线封闭，环境在 Adapter 选择阶段传入；列触发协议演进的条件 | 本轮不改协议 | ❌ 未落地 |
| G-B5 | Swift 离线夹具读取与确定性深比较载体 | Swift 测试读 `Tests/Fixtures/S1-01~03` JSON，与 Stage 1 基线深比较，排除 `generatedAt` | 仅测试设计；测试代码未授权编写 | ❌ 未落地 |

> 评审原则（对齐提案）：不为让 B1 快速通过而把结构化证据压进告警字符串；模型增补须先经独立评审、评估 JSON Schema 兼容、双路线隔离与既有 Codable 测试影响，通过后再单独授权改 Models。

## 1. 评审基线与方法

### 1.1 Stage 1 原始信息来源（只读，不改）

- 报告基线：`Tests/S1-01/report/S1-01-report.json`（15）、`Tests/S1-02/report/S1-02-report.json`（18）、`Tests/S1-03/report/S1-03-report.json`（15）；
- 夹具输入：`Tests/Fixtures/S1-01~03/<kind>/environment.json + metadata.json`；
- 导出基线：`Tests/S1-08/exporter.js` 与 `Tests/S1-08/report/S1-08-report.json`（最终信封 JSON 形态）。

### 1.2 现有 Models 基线（现文件，唯一基准）

- `JailbreakEnvironment`：`jailbreakType / ellekitImplementation? / ellekitVersion? / profileId / jbroot? / jbrand? / iosVersion? / architecture? / evidenceLevel / pathEvidence`；
- `PathEvidence`：`tweakInject: String? / dynamicLibraries: String? / jbrootCandidates: [String]`；
- `EnvironmentPaths`（Adapters）：`jbroot? / tweakInject? / dynamicLibraries? / warnings: [ReportWarning]`；
- 既有证据/告警类型：`EvidenceBlock`、`ValidationReport(status: String, warnings, skippedFields)`、`ReportWarning(code,message,sourceStage)`、`UnknownItem`；
- 既有枚举：`JailbreakType / EvidenceLevel / Pairing / Confidence` 等（主规格 §3.1），无版本五态、候选状态、路径状态枚举。

### 1.3 评审步骤（逐项）

列出现有字段表达能力 → 列出 Stage 1 原始信息 → 标出无法表达项 → 给最小增补草案 → 评估 JSON Schema 兼容、双路线影响、2.2-A Codable 测试影响 → 登记待拍板项。

---

## 2. G-B1：版本识别五态承载评审

### 2.1 Stage 1 原始信息（S1-01）

| 原始字段 | 取值 / 结构 | 覆盖用例 |
|---|---|---|
| `ellekitVersionStatus` | `parsed`(4) / `not_installed`(5) / `unreadable`(1) / `unparsable`(3) / `conflicted`(2) | 15 例全覆盖 |
| `outcome` | `profile_candidate / partial / unknown / conflict_no_profile / unsupported_profile` | 裁决归类 |
| `bootstrap` | `{ name, version }` | 引导器证据 |
| `adapterProfile` | `String?` | Profile 建议 |
| `evidence.<field>` | 逐字段 `{ value, status, evidenceType, evidenceSource }` | 字段级证据 |
| `warnings` | 如 `route_signal_conflict`、`impl_version_conflict` | 冲突告警 |

### 2.2 现有承载缺口

- `JailbreakEnvironment` 只有 `ellekitVersion? / ellekitImplementation? / evidenceLevel / profileId`；**无版本读取状态、无 outcome、无逐字段证据位**；
- `evidenceLevel`（`verified/partial/unverified`）是证据等级，不等同五态读取状态，不能互相替代；
- 五态若压成 `ReportWarning` 字符串，GUI 候选/详情展示、冲突判断、确定性 JSON 比较都无法结构化进行（提案已否该方案）。

### 2.3 增补方案草案（未冻结，待评审拍板）

**方案 G-B1-A（倾向）：新增只读版本就绪状态结构**

```
// 草案示意，非冻结类型；取值原始值对齐 S1-01 五态字符串
enum EllekitVersionStatus: String, Codable, Equatable {
    case parsed, notInstalled = "not_installed", unreadable, unparsable, conflicted
}

struct VersionReadiness: Codable, Equatable {
    var status: EllekitVersionStatus?      // 未取到 = nil，不留空串冒充已知
    var outcome: String?                    // 对齐 S1-01 outcome 口径（弱类型字符串，沿用 ValidationReport 先例）
    var warnings: [ReportWarning]
}
```

- 作为 `JailbreakEnvironment` 的**可选增补字段**（如 `versionReadiness: VersionReadiness?`），默认 `nil`；
- 五态原始值与 S1-01 报告逐字一致；不把 `conflicted` 折叠成 `unknown`；
- 逐字段证据位（`evidence.<field>`）若 B 阶段不进入公共 Model，先落 `EvidenceBlock`/告警；是否增补字段级证据结构列入后续评审。

**方案 G-B1-B（备选）：复用 `ValidationReport` 承载**

- `ellekitVersionStatus` → `ValidationReport.status` 字符串；`warnings` 复用既有数组；不新增类型；
- 代价：状态为弱类型字符串，编译期不约束五态取值，深比较需靠报告基线校验。

**方案 G-B1-C（不建议）：仅告警代码串**

- 信息不可结构化比较，不满足 §8 深比较要求；记录为否决项。

### 2.4 JSON Schema 兼容性

- S1-08 导出信封当前**未持久化** `versionStatus / outcome / bootstrap`（`exporter.buildEnvironment` 只输出主规格 §3.2 列字段）；
- 若增补 `VersionReadiness` 进入公共 Model，须先拍板：Codable 导出时该字段是**序列化进信封 JSON**（则需同步 S1-08 导出口径与回归基线），还是**运行时瞬态、不参与导出**；
- 向后兼容：增补字段必须为可选且有默认值，旧 JSON（无该字段）解码不报错；不改变既有字段原始值。

### 2.5 双路线与既有测试影响

- 五态为环境通用口径，不含路线分支字段；RootHide/Rootless 差异走 `jailbreakType` 与 Adapter 内部规则；
- 对 2.2-A 现有 21 例 Codable 测试：可选增补字段不破坏既有往返；若采用方案 A，后续授权时需补该字段往返/缺失解码用例；现有断言不依赖被删改字段。

### 2.6 待拍板

1. 选 G-B1-A / B / C；2. 增补字段是否进入信封导出 JSON；3. 是否需要字段级证据结构（延后评审还是 B 内一并设计）。

---

## 3. G-B2：JBROOT 候选结构评审

### 3.1 Stage 1 原始信息（S1-02）

候选对象字段（10 项）：

| 字段 | 类型 / 取值 | 含义 |
|---|---|---|
| `root` | String | 候选根路径 |
| `source` | `api / scan / bootstrap / rootless / rootful` | 候选来源 |
| `route` | `roothide / rootless / rootful` | 归属路线 |
| `nameValid` | Bool? | `.jbroot-<jbrand>` 命名合法位 |
| `exists` | Bool | 目录存在位 |
| `structureMatch` | Bool | 结构匹配位 |
| `readable` | Bool | 可读位 |
| `realpath` | String? | 解析后 realpath（软链失败为 null） |
| `status` | `confirmed / partial / rejected_invalid / rejected_missing / resolve_failed / cross_route / pending` | 候选裁决位 |
| `warnings` | [String] | 候选级告警 |

顶层结果：`jbroot / jbrand / realpath / ambiguous / outcome / selectedSource / candidateCount / candidates / warnings`。
导出基线（S1-08）候选子集：`{ source, path }`。

### 3.2 现有承载缺口

- `PathEvidence.jbrootCandidates: [String]` 只存路径字符串：**来源、路线、四个校验位、裁决状态、候选告警全部丢失**；
- 顶层 `ambiguous / selectedSource / candidateCount` 无落点；歧义只能靠告警串，无法结构化区分"唯一确认 / 多候选歧义 / 仅未确认 / 无候选"；
- 主规格 §7.2 已登记该缺口，本节给出具体结构草案。

### 3.3 增补方案草案（未冻结）

**倾向：新增候选结构，替换字符串数组**

```
// 草案示意，非冻结类型
struct JBRootCandidate: Codable, Equatable {
    var root: String
    var source: String            // 对齐 S1-02 source 五值字符串口径
    var route: String
    var nameValid: Bool?
    var exists: Bool?
    var structureMatch: Bool?
    var readable: Bool?
    var realpath: String?
    var status: String            // 弱类型状态串，沿用 ValidationReport.status 先例；强类型枚举另评
    var warnings: [ReportWarning]
}

// PathEvidence.jbrootCandidates 类型草案：[String] → [JBRootCandidate]
```

- 顶层裁决落位：`jbroot / jbrand / realpath` 入 `JailbreakEnvironment` / `EnvironmentPaths` 现有字段；`ambiguous` 与多候选不选边，全量候选保留在 `jbrootCandidates`；`selectedSource` 仅在唯一确认时落字段，歧义/无候选为 `nil`；
- 校验位缺失时按 `nil` 表达"未校验"，不补 `false` 冒充已校验失败；
- 候选状态取值沿用 S1-02 报告口径；是否升级为强类型枚举（同 G-B1 评审决策）。

### 3.4 JSON Schema 兼容性

- 类型变更（`[String]` → `[JBRootCandidate]`）属于 Models 类型修改，**必须单独授权**；
- 解码兼容：S1-08 导出候选仅 `{source, path}`，结构须容忍缺失校验位（可选 + 默认值）；`path` ↔ `root` 字段命名映射须在评审中对齐 Stage 1 导出键集；
- 不得在公共模型加入路线私有规则字段；来源/路线以字符串承载，沿用 `ProfileRef.route` 先例。

### 3.5 双路线与既有测试影响

- 候选结构为公共证据容器；RootHide/Rootless 各自填充本路线候选，互不引用（隔离检查沿用 `check-adapter-isolation.sh`）；
- 2.2-A 往返测试若后续使用候选数组字面量，需随类型增补同步更新；既有不依赖该数组的断言不受影响。

### 3.6 待拍板

1. 候选结构字段集与命名（对齐 S1-08 导出键还是 S1-02 报告全量键）；2. 候选状态用字符串还是强类型枚举；3. 顶层 `ambiguous/selectedSource` 落点字段；4. 该类型变更的 Models 授权口径。

---

## 4. G-B3：目录路径证据结构评审

### 4.1 Stage 1 原始信息（S1-03）

`TweakInject` 路径对象（7 键）：`value / exists / readable / enumerable / realpath / structureMatch / status`。

`DynamicLibraries` 路径对象（6 键）：`value / isSymlink / symlinkTarget / realpath / symlinkState / targetMatch`；`symlinkState` ∈ `resolved / broken / loop / target_denied / not_symlink`。

顶层：`route / outcome / warnings`；`outcome` ∈ `resolved / partial / not_found / unresolved / structure_conflict / rootful_diagnostic`。
导出基线（S1-08）：`tweakInject: {path, exists, readable?}`；`dynamicLibraries: {symlink, target}` 或 `null`。

### 4.2 现有承载缺口

- `tweakInject / dynamicLibraries: String?` 只存路径：存在、可读、可枚举、结构匹配、realpath、目录状态，以及软链目标/状态/匹配位全部无落点；
- 软链 broken / loop / target-denied / not-a-symlink 是不同维度告警，压缩成字符串后无法深比较，也无法支撑后续 GUI 目录状态展示。

### 4.3 增补方案草案（未冻结）

```
// 草案示意，非冻结类型
struct PathLocationEvidence: Codable, Equatable {
    var path: String?
    var exists: Bool?
    var readable: Bool?
    var enumerable: Bool?
    var realpath: String?
    var structureMatch: Bool?
    var status: String?          // 对齐 S1-03 目录状态口径
}

struct SymlinkEvidence: Codable, Equatable {
    var isSymlink: Bool
    var target: String?
    var realpath: String?
    var symlinkState: String?    // resolved/broken/loop/target_denied/not_symlink
    var targetMatch: Bool?
}
```

- `PathEvidence` / `EnvironmentPaths` 的 `tweakInject` 草案类型 `PathLocationEvidence?`，`dynamicLibraries` 草案类型 `SymlinkEvidence?`；
- 不存在/不可访问路径保留对象骨架 + `status`/告警，不把路径置空串；软链未使用时 `isSymlink = false`，其余字段 `nil`；
- Rootful 仅诊断参照：经 `status` + 告警 `rootful_route_not_profile` 表达，不进可执行 Profile。

### 4.4 JSON Schema 兼容性

- 同样属 Models 类型增补，须单独授权；解码容忍导出基线的精简键集（`{path,exists,readable}` / `{symlink,target}`），缺失位为 `nil`；
- `value` ↔ `path` 命名映射与 G-B2 一并对齐 S1-08 导出键集；
- 不新增路线分支字段；Rootless 无真机验证结论经证据等级 + 风险告警保留，不在模型内标真机兼容。

### 4.5 双路线与既有测试影响

- 路径证据结构通用；RootHide 基于已确认 JBROOT 拼接，Rootless 走 `/var/jb` 前缀，规则在各自 Adapter；结构容器不混规则；
- 2.2-A 现有往返测试不直接构造路径对象；增补后补对应往返/缺失用例（后续授权）。

### 4.6 待拍板

1. 路径证据结构字段集与命名；2. 软链状态字符串还是枚举；3. 与 G-B2 候选结构是否共用基础路径位（`exists/readable/realpath`）以避免重复定义。

---

## 5. G-B4：`resolvePaths()` 协议充分性评审

### 5.1 现状

冻结协议七方法中路径相关：`getEnvironment() -> JailbreakEnvironment`、`resolvePaths() -> EnvironmentPaths`、`resolvePath(_ relative:) -> AbsolutePath`；均无环境入参。Core 编排协议已有 `AdapterResolver.resolveAdapter(for:) -> ElleKitAdapter?`，环境在**选择 Adapter 阶段**传入。

### 5.2 充分性结论（本轮评审）

**B 阶段保留无参 `resolvePaths()`，不改协议。** 理由：

1. Adapter 实例本身代表确定路线（`route: String`），路线规则封闭在各自 Adapter 内；
2. 环境快照由 `AdapterResolver` 在装配阶段使用，选中的 Adapter 无需再次接收整份环境；
3. 无参接口避免 Core 与 Adapter 重复判断路线、避免把 RootHide 环境传给 Rootless Adapter、避免两侧持有不一致环境状态（与提案判断一致）；
4. S1-01~03 夹具流程中，路径解析所需的 JBROOT/路线信息可由 Adapter 内部状态与已选 Profile 取得，未观察到必须外部回传环境的场景。

### 5.3 触发协议演进评审的条件（出现任一才走 §4.3 评审，不预先改）

- Adapter 解析必须依赖选择后才变化、且 Adapter 内部无法自持的环境快照；
- 两个 Adapter 需要共享 Core 计算出的同一已解析路径；
- `resolvePaths()` 必须响应运行期环境变更而不重新解析/重选 Adapter；
- 现有返回 `EnvironmentPaths` 无法承载 B 阶段必需的解析结果（与 G-B3 结构增补区分：模型承载缺口不等于协议签名缺口）。

### 5.4 约束

- 不得新增 `resolveJBRoot()` / `resolveElleKitDirectory()` 平行接口；
- 任何协议演进须单独评审输入/输出/错误口径，且只允许只读方法；本轮不提交协议改动。

---

## 6. G-B5：Swift Fixture 深比较设计

### 6.1 载体与落点

- 夹具只读引用 `Tests/Fixtures/S1-01~03/`（`environment.json` + `metadata.json`），不修改 Stage 1 基线文件；
- 基线期望取自 Stage 1 报告 / S1-08 导出 JSON，随 B 测试落地时固化到 `Tests/Fixtures` 或测试内常量（实现授权后确定）；
- 测试落点沿用 B 子规格 §8.1：`EnvironmentDetectionTests / JBRootResolutionTests / ElleKitPathResolutionTests / EnvironmentPipelineTests`，归 `Stage2Tests` target。

### 6.2 深比较维度（不能只比较最终路径是否找到）

| 阶段 | 必须比较的维度 |
|---|---|
| S1-01 | `jailbreakType`、`ellekitImplementation`、`ellekitVersion`、版本五态、`profileId`、`evidenceLevel`、告警代码、字段级证据（若模型承载） |
| S1-02 | 候选数量、来源、**顺序**、归属路线、命名/存在/结构/可读校验位、候选状态、`ambiguous`、`selectedSource`、顶层 outcome、告警 |
| S1-03 | 路线、TweakInject 存在/可读/可枚举/结构/状态/realpath、DynamicLibraries 软链标记/目标/状态/匹配位、顶层 outcome、告警 |

### 6.3 确定性口径

- 测试不访问真实文件系统；全部由离线夹具驱动；
- 候选/告警/未知条目顺序按 Stage 1 夹具固定顺序比较，不在测试内做无序排序兜底；
- 编码→解码归一化后再与基线比较；除 `generatedAt` 等明确允许变化字段外，其余字段逐字段深比较；
- realpath 在夹具中为确定性值，纳入比较；线上真机 realpath 差异属后续真机验证范围，不进离线回归。

### 6.4 与主规格对齐

- 读取/比较流程沿用主规格 §8；用例命名保留 Stage 1 编号（`ENV-008` 等）以便回溯；
- 前序 2.2-A 21 例在 B 阶段保持通过；隔离静态检查三向作为附加回归。

---

## 7. 增补对既有契约的影响评估（汇总）

| 影响面 | 评估 |
|---|---|
| 2.2-A 21 例 Codable 测试 | 可选增补字段 + 默认值不破坏既有往返；类型变更（G-B2/G-B3）需同步后续新增字面量断言，既有不依赖字段不受影响 |
| S1-08 导出 JSON 基线 | 若增补结构序列化进信封，须同步导出口径与 135 项回归基线；若瞬态则不影响导出；该选择属待拍板项 |
| 双路线隔离 | 增补结构为公共证据容器，不含路线规则；规则仍分属各自 Adapter |
| 既有枚举 | 本轮不新增枚举值；五态/候选状态/软链状态先用字符串草案，是否强类型化随 Models 评审一并拍板 |
| Stage 1 基线 | 只读引用，不改 harness、夹具、报告与导出器 |

## 8. 未决决策清单（B1 授权前须完成）

1. **G-B1**：状态承载方案（A/B/C）；增补字段是否进入信封导出；是否需要字段级证据结构；
2. **G-B2**：候选结构字段集/命名；状态字符串 vs 枚举；顶层歧义/选中来源落点；类型变更 Models 授权；
3. **G-B3**：路径证据与软链结构字段集/命名；软链状态字符串 vs 枚举；与 G-B2 是否共用基础路径位；
4. **G-B4**：确认保留无参 `resolvePaths()`；登记协议演进触发条件；
5. **G-B5**：基线期望固化位置；深比较工具形态（测试内 helper vs 共享 XCTest 辅助目标）；
6. 上述评审通过后，再决定是否单独授权 **B1 实现**；B2–B5 仍逐批授权。

## 9. 授权边界（本轮保持）

| 事项 | 状态 |
|---|---|
| B 子规格有条件冻结（阶段划分 / 48 项基线 / 四模块职责 / 隔离原则 / 七方法基准） | ✅ 已确认 |
| G-B1~G-B3 Models 增补**设计评审** | ✅ 本轮产出草案 |
| G-B4 协议充分性评审（不改协议） | ✅ 本轮结论：保留无参 |
| G-B5 Fixture 深比较**设计** | ✅ 本轮产出 |
| 修改 Models 字段 / 类型 / 枚举 / 解码行为 | ❌ 未授权 |
| 修改 `ElleKitAdapter` 协议 | ❌ 未授权 |
| 编写 B 源码 / 测试代码 | ❌ 未授权 |
| 48 项 Swift 回归执行 | ❌ 未授权 |
| 2.2-C 及以后、进入 2.3 | ❌ 未授权 |
