# Stage-2.2-B-Environment-Path.md — 2.2-B Environment / Path 迁移子规格（**有条件冻结基线**）

> 状态：**有条件冻结（2026-11-16 确认）**。冻结项：B1–B5 阶段划分、48 项测试基线、四模块职责、双 Adapter 隔离原则、七方法协议唯一基准；**未冻结项**：G-B1~G-B5 数据契约与协议承载，按 `Stage-2.2-B-Gap-Review.md` 评审结论另行拍板。本文不含实现代码，不改 Models / 协议 / Stage 1 基线。
> 上游基准：`Stage-2.2-Core-Models-Migration.md`（冻结主规格）；Stage 1 基线：`Tests/S1-01`、`Tests/S1-02`、`Tests/S1-03` 报告与 `Tests/Fixtures/S1-01~03`。
> 起草日期：2026-11-16。

## 1. 目标与非目标

### 1.1 目标

将 Stage 1 已离线验证的三个环节迁移到 Swift Core / Adapter 只读实现：

| Stage 1 环节 | 迁移内容 | Swift 落点 |
|---|---|---|
| S1-01 Environment Detection | 越狱类型、ElleKit 实现/版本、Profile、证据等级识别；多证据冲突保留 | `Core/Environment/` + Adapter `getEnvironment()` |
| S1-02 JBROOT Resolution | 五类候选收集、命名/存在/结构/可读/realpath 校验、去重与裁决（唯一确认 / 多候选歧义 / 仅未确认 / 无候选） | `Core/PathResolver/` + Adapter `resolvePaths()` |
| S1-03 ElleKit Directory | TweakInject / DynamicLibraries 目录定位、软链状态、结构校验与告警；Rootful 仅诊断参照 | `Core/PathResolver/` + Adapter `resolvePaths()` / `resolvePath(_:)` |

输出环境快照与路径证据交给 2.2-C（枚举/配对/解析）使用；B 阶段不提前实现插件枚举。

### 1.2 非目标（B 不做）

- 不实现 `scanPlugins / readPlugin / validatePlugin / parseFilter`（2.2-C）；
- 不做归属识别与导出（2.2-D）；
- 不接入真机文件系统扫描、不做 GUI 权限探针（2.4）；
- 不修改 Models 字段/枚举/原始值/解码行为，不修改 `ElleKitAdapter` 协议（缺口见 §7，须单独评审授权）；
- 不新增平行接口（`resolveJBRoot()`、`resolveElleKitDirectory()` 等不得作为第二套协议出现）；
- 不把 fixture 通过写成 Rootless 真机兼容；不把模拟器启动/存活证据当作越狱文件访问权限证据。

## 2. 当前进度与准入条件

### 2.1 已完成基线

- Stage 1：八阶段离线闭环 135/135（S1-01 15、S1-02 18、S1-03 15、S1-04 23、S1-05 15、S1-06 22、S1-07 14、S1-08 13）。
- Stage 2.1：已授权闭环（第七轮 run 43736107678）；观察项 O1–O5 归档 2.4 / 后续真机。
- 2.2-A：第八轮 run 43741322151 复验通过，Stage2Tests 21 例 0 失败；R6（未知枚举默认解码行为）未实测、未修改，留待后续评审。

### 2.2 B 准入核对

| 准入项 | 现状 | 结论 |
|---|---|---|
| 2.2-A 回归保持通过 | 21 例 0 失败（第八轮） | ✅ 满足 |
| 现有 Models / 协议为唯一基准 | 见主规格 §3、§4 | ✅ 满足 |
| B 阶段缺口已识别并登记 | 见本文 §7 | ⚠ 实现前须先拍板缺口处置方式 |
| 真机 / 权限前提 | 无 Rootless 设备；GUI 权限未探针 | 不阻塞离线 fixture 迁移；真机结论留后续 |

## 3. Stage 1 → 2.2-B 回归归属矩阵

### 3.1 用例总数

| Stage | 报告总数 | 归属批次 | 说明 |
|---|---|---|---|
| S1-01 | 15（`ENV-001`~`ENV-015`） | 2.2-B | 环境识别五态全覆盖 |
| S1-02 | 18（fixture 驱动，`pathId`） | 2.2-B | 候选五来源 + 裁决四类 |
| S1-03 | 15（fixture 驱动，`DIR-`） | 2.2-B | 目录定位 / 软链 / 结构校验；本阶段无枚举用例 |
| **B 合计** | **48** | | 主规格 §10 B 行“38 项”为笔误，应为 **48**（与 §9 矩阵 15+18+15 一致），属文案订正，不改行为基线 |

### 3.2 S1-01 分组（15）

| 版本状态（Stage 1 口径） | 用例 | Swift 落位口径 |
|---|---|---|
| `parsed` | ENV-001、ENV-002、ENV-013、ENV-015 | 解析成功且无冲突；`jailbreakType` 落现有枚举，证据等级按内省口径 |
| `not_installed` | ENV-003、ENV-004、ENV-005、ENV-007、ENV-011 | 无相关文件；路线 `unknown` / `rootful` 诊断，Profile 保守 |
| `unreadable` | ENV-012 | 文件存在但不可读；证据降级，不猜内容 |
| `unparsable` | ENV-006、ENV-010、ENV-014 | 内容无法解析；`ValidationReport` 口径的状态 + 告警 |
| `conflicted` | ENV-008、ENV-009 | 多来源互相冲突；不选边，冲突落告警/证据 |

> 五态是 Stage 1 harness 的识别状态概念；现有公共枚举中没有对应五态枚举值（见 G-B1），B 实现不得新增枚举，先按 §7 评审结论落位。

### 3.3 S1-02 分组（18）

| 裁决结果 | 覆盖口径 |
|---|---|
| `resolved`（唯一确认） | bootstrap / scan 等来源候选，校验通过且唯一 |
| `partial` | 候选存在但可读/结构证据不全 |
| `ambiguous`（多候选歧义） | 两个及以上无法排除的有效候选，全量保留不选边 |
| `resolve_failed` | 候选校验未通过（坏名 / 坏软链 / 结构不符） |
| `cross_route_only` | 仅出现他路线候选，不套用本路线规则 |
| `no_candidate` | 无候选；路径字段 `nil` + 告警，**禁止**回退 `/var/jb` 或 `/` |

候选来源覆盖：`api / scan / bootstrap / rootless / rootful` 五类（S1-02 summary `sourcesCovered`）。

### 3.4 S1-03 分组（15）

| 路线 / 结果 | 用例口径 |
|---|---|
| RootHide `resolved` | 已确认 JBROOT 下 TweakInject 定位成功 |
| RootHide `partial` | 软链 broken / loop / target-denied / not-a-symlink / access-limited |
| RootHide `not_found` / `unresolved` / `structure_conflict` | 目录缺失、未解析、结构不符；告警保留 |
| Rootless `resolved` | `/var/jb` 前缀路径；携带证据与待验证标记，不标真机兼容 |
| Rootful `rootful_diagnostic` | 仅诊断参照，不进入可执行 Profile |

> 提案提示“S1-03 若含枚举用例留给 C”：经核对 S1-03 报告 15 例全部为目录定位/软链/结构口径，无枚举条目；枚举归属 S1-04（2.2-C）。

## 4. 现有契约基准（唯一基准，不得平行造接口）

### 4.1 公共 Models（`Models/` 现文件）

B 阶段直接复用，不新增字段/枚举：

- `JailbreakEnvironment`：`jailbreakType / ellekitImplementation? / ellekitVersion? / profileId / jbroot? / jbrand? / iosVersion? / architecture? / evidenceLevel / pathEvidence`；
- `PathEvidence`：`tweakInject: String? / dynamicLibraries: String? / jbrootCandidates: [String]`；
- `EvidenceLevel`：`verified / partial / unverified`（二手内省不得 `verified`）；
- `JailbreakType`：`roothide / rootless / unknown`；
- 告警与失败证据：`ReportWarning`、`ValidationReport`、`UnknownItem`、`EvidenceBlock`。

### 4.2 Adapter 协议（`Adapters/ElleKitAdapter.swift`，七方法冻结）

```
var route: String
func getEnvironment() -> JailbreakEnvironment
func resolvePaths() -> EnvironmentPaths
func scanPlugins() -> [PluginCandidate]
func readPlugin(_ candidate: PluginCandidate) -> Plugin?
func validatePlugin(_ plugin: Plugin) -> ValidationReport
func parseFilter(_ plugin: Plugin) -> FilterRule?
func resolvePath(_ relative: String) -> AbsolutePath
```

B 阶段只落地前两个环境/路径方法与 `resolvePath(_:)`；其余方法保持骨架返回。

### 4.3 Core 编排协议（`Core/CoreServices.swift` 现轮廓）

- `EnvironmentService.environment() -> JailbreakEnvironment`
- `PathResolutionService.paths(for environment:) -> EnvironmentPaths`
- `AdapterResolver.resolveAdapter(for:) -> ElleKitAdapter?`（识别失败返回 `nil`，保守只读；未知 Profile 不扫描）

Core 只编排 Adapter 调用与模型聚合，不写路线特有规则，不散落路线 if/else。

## 5. 模块划分与流程映射

### 5.1 模块 → 现有目录 / 协议方法

| 提案模块名 | B 落位（现有目录） | 编排协议 | 委托 Adapter 方法 |
|---|---|---|---|
| EnvironmentDetector | `Core/Environment/` | `EnvironmentService` | `getEnvironment()` |
| JBRootResolver | `Core/PathResolver/` | `PathResolutionService` | `resolvePaths()`（JBROOT 部分） |
| ElleKitPathResolver | `Core/PathResolver/` | `PathResolutionService` | `resolvePaths()`（目录部分）、`resolvePath(_:)` |
| EnvironmentPipeline | Core 组合根（`AdapterResolver` + 上述两服务） | `AdapterResolver` → 服务装配 | 协议方法经 Adapter 实例调用 |

> 提案中的 `JBRootCandidate / JBRootResolution / DirectoryResolutionResult` 均为算法结构示意名，不进入公共 Models；实现时按主规格 §3.3 重映射到现有类型（缺口见 §7）。

### 5.2 流程（只读）

```
AdapterResolver 按环境选择 Adapter（失败 → nil 保守只读）
        │
        ▼
EnvironmentDetector → getEnvironment() → JailbreakEnvironment
        │
        ▼
JBRootResolver → resolvePaths() 候选收集 → 校验 → 去重 → 裁决
        │
        ▼
ElleKitDirectoryResolver → 按已确认 JBROOT / 路线规则定位 TweakInject、DynamicLibraries
        │
        ▼
EnvironmentPaths + PathEvidence 交付 2.2-C
```

### 5.3 双路线隔离

- RootHide / Rootless 规则分别实现于各自 Adapter 路径，互不调用、互不引用；
- Core 只经协议方法调用，不感知路线；
- 未知 Profile 不进入扫描；Rootful 路径仅诊断记录；
- 隔离静态检查沿用 `scripts/check-adapter-isolation.sh` 三向口径。

## 6. 环节设计要点

### 6.1 S1-01 环境识别

- 多证据来源（JBROOT 特征、ElleKit 实现标识、版本文件）交叉核对；单一特征不推断整环境；
- 来源互相冲突 → 保留冲突告警，不选边；
- 未取到显式值留 `nil`，不留空串冒充已知；
- 二手内省证据等级上限 `partial`，不得标 `verified`；
- `rootful` 作为诊断 Profile，不生成可执行扫描 Adapter。

### 6.2 S1-02 JBROOT 候选解析（四条铁律，沿用 Stage 1）

1. **不允许无依据回退**：找不到 JBROOT 不自动回退 `/var/jb` 或 `/`；
2. **多候选不随意选择**：两个无法排除的有效候选保留歧义与全量候选；
3. **非法校验位必须拒绝**：沿用 Stage 1 命名（`.jbroot-<jbrand>`）、存在、结构、可读、realpath 校验规则；
4. **候选不等于确认**：路径字符串存在不代表有效 JBROOT；`name-only`、坏软链、结构不符均拒绝或降级。

裁决四类：唯一确认 / 多候选歧义 / 仅未确认候选 / 无候选；候选全量保留在 `PathEvidence`，不提前选边。

### 6.3 S1-03 目录解析

| 路线 | 路径规则 | 证据要求 |
|---|---|---|
| RootHide | 基于**已确认** JBROOT 拼接 `/usr/lib/TweakInject/`；尊重 `jbroot()` 翻译机制，不简化为 Rootless 的 `/var/jb` | 目录存在/可读/可枚举/结构匹配/realpath；软链状态独立记录 |
| Rootless | `/var/jb/usr/lib/TweakInject/` | 携带证据等级、路径来源、验证状态与风险告警；无真机验证，不标兼容 |
| Rootful | `/usr/lib/TweakInject/` | 仅诊断路径，告警 `rootful_route_not_profile` |

- 未确认 JBROOT 不拼接 RootHide 路径；
- 软链 broken / loop / target-denied / not-a-symlink 按 Stage 1 告警口径区分；
- 目录缺失/未解析/结构冲突均保留结果与告警，不静默回退。

## 7. 现有 Models / 协议承载缺口（实现前评审，不在 B 草案内实现）

下列缺口已对照 Stage 1 报告与导出器（`Tests/S1-08/exporter.js`）逐项核对。**处置方式须在 B 实现授权前单独拍板**；未授权前不新增模型字段、不新增枚举、不改协议。

| 编号 | 缺口 | Stage 1 口径 | 现有承载现状 | 评审要求 |
|---|---|---|---|---|
| G-B1 | 版本识别五态（`parsed / not_installed / unreadable / unparsable / conflicted`） | S1-01 结果 `ellekitVersionStatus` 五态全覆盖 | `JailbreakEnvironment` 无对应字段；仅有 `evidenceLevel` 三态；S1-08 导出器当前未持久化该状态 | 先确认 Swift 回归以何载体保留五态：告警/`EvidenceBlock` 映射，或经单独模型评审新增字段；不得在编码中临时加枚举 |
| G-B2 | JBROOT 候选结构 | S1-02 候选对象：`root / source / route / nameValid / exists / structureMatch / readable / realpath / status / warnings` | `PathEvidence.jbrootCandidates: [String]` 仅存路径字符串，校验位与来源丢失 | 对照主规格 §7.2 已登记缺口；若字符串不足以表达校验结果，提交候选结构评审（字段、Codable、Stage 1 对照）后再实现 |
| G-B3 | 目录路径证据结构 | S1-03 路径对象：`value/path / exists / readable / enumerable / realpath / structureMatch / status`；软链 `symlinkTarget / symlinkState / targetMatch` | `EnvironmentPaths` 与 `PathEvidence` 的 `tweakInject / dynamicLibraries` 为 `String?`，状态与软链字段无落点 | 同 G-B2：先评审证据结构落位；告警可先承载部分信息，但不得丢失 Stage 1 校验证据 |
| G-B4 | `resolvePaths()` 入参充分性 | S1-02/03 解析依赖环境/路线上下文 | 冻结协议 `resolvePaths()` 无入参；Adapter 实例已由 `AdapterResolver` 按路线选定，环境在选择阶段传入 | 先确认无入参是否足够：路线规则封闭在 Adapter 内则可；若 Adapter 解析必须回读环境字段，须走协议演进评审（主规格 §4.3），不得新增平行方法 |
| G-B5 | 离线夹具载体 | Stage 1 夹具为 Node harness JSON（`Tests/Fixtures/S1-01~03`） | Swift 测试尚无可复用的夹具读取/深比较载体 | 按主规格 §8 方案在 Stage2Tests 内设计离线读取与深比较；夹具只读引用，不改 Stage 1 基线文件 |

> 关联未决：2.2-A R6（未知枚举默认解码行为）仍未实测未修改；与 B 缺口独立，不并入本批次处理。

## 8. 测试设计（B 实现授权后落地）

### 8.1 文件组织建议（以 `Package.swift` 现有结构为准）

```
Tests/
├── Fixtures/S1-01、S1-02、S1-03/   # 只读引用 Stage 1 夹具
└── Stage2Tests/
    ├── EnvironmentDetectionTests.swift   # S1-01 15
    ├── JBRootResolutionTests.swift        # S1-02 18
    ├── ElleKitPathResolutionTests.swift   # S1-03 15
    └── EnvironmentPipelineTests.swift     # B5 编排/隔离/未知 Profile 守卫
```

- 用例命名保留 Stage 1 编号（`ENV-008` 等）以便回溯；
- 夹具读取与深比较口径对齐主规格 §8：除时间戳外确定性可重复；
- 前序 2.2-A 的 21 例 Codable 用例在 B 阶段保持通过。

### 8.2 B 验收重点（沿用主规格 §11 门禁）

1. 48 项对应行为全部通过；
2. 不改变 Stage 1 JSON 语义；未取到显式值为 `nil`，不补空串/默认值；
3. 不增加未经评审的模型状态/枚举值；
4. RootHide 与 Rootless 实现不混合；未知 Profile 不扫描；
5. 不允许无证据路径回退（`/var/jb`、`/`）；
6. 不引入任何插件写入能力；
7. 隔离静态检查三向通过。

## 9. B 内子批次与门禁（B1–B5）

| 子批次 | 工作 | 对应回归 | 门禁 |
|---|---|---|---|
| B1 | Environment Detection：Adapter `getEnvironment()` + `EnvironmentService` 识别逻辑 | S1-01 15 | 五态口径与 Stage 1 一致；冲突不选边；证据等级不越界 |
| B2 | JBROOT 候选收集：五来源候选归集与去重 | S1-02 候选覆盖 | 候选来源完整；不丢候选；不提前裁决 |
| B3 | JBROOT 校验与裁决：命名/存在/结构/可读/realpath 校验 + 四类裁决 | S1-02 18 | 四条铁律通过；歧义/拒绝/无候选口径保持；无固定根回退 |
| B4 | ElleKit 目录解析：TweakInject / DynamicLibraries 定位与软链/结构告警 | S1-03 15 | 三路线规则隔离；Rootless 待验证标记保留；Rootful 仅诊断 |
| B5 | Core Pipeline 集成：`AdapterResolver` + 两服务装配、隔离与守卫回归 | B 全量 48 + 附加隔离/未知 Profile 用例 | 48 项全绿；双路线规则未合并；无路线分支字段泄漏进公共模型 |

> 子批次未达门禁不进入下一批；发现行为与 Stage 1 预期不符，先冻结问题、回退夹具核对，不在编码中放宽规则。
>
> **验收流程调整（方案 B，2026-11-16）**：B3（及后续 B4）允许本地完成并记录，独立 Runner 验收延后 B5 集中执行；B3/B4 在 B5 通过前不标记正式闭环。B5 Swift 回归逐阶段映射为 **71 项** = 21 Codable + 7 B1 + 10 B2 + 18 B3 + 15 B4；表中“48”为 Stage 1 原始行为基线数量（ENV/PATH/DIR），二者口径不同，不可混用。B3 基准提交 `3e878cb`，B5 须证明该提交入链、B4 未改 B3 六态优先级与 B2 收集规则。

## 10. 只读边界与禁止事项（B 全程保持）

禁止：修改 dylib / plist / ElleKit 配置 / 软链接；新增 Bundle ID；插件启停；安装/卸载插件；dpkg 写入；自动修复；常驻 daemon；GUI 权限探针；真机扫描；任何设备写入接口出现在协议或实现中。

协议/实现中不得出现：`enablePlugin / disablePlugin / installPlugin / uninstallPlugin / deletePlugin / modifyFilter` 及同类写入方法。

## 11. 风险与待验证事项

| # | 事项 | 现状 | 归属 |
|---|---|---|---|
| R-B1 | Rootless 无真机；fixture 通过不代表 Rootless 真机兼容 | 仅离线夹具 | 具备设备后真机验证 |
| R-B2 | `jbroot()` 进程内真实调用、沙盒/entitlement 放行未探针 | 模拟器启动/存活不等于权限通过 | 2.4 权限探针 |
| R-B3 | Runner SDK 26.5 不能作为 Theos 16.5 SDK 对 iOS 17 兼容证据 | 编译/模拟器层证据 | 2.5 打包阶段 |
| R-B4 | G-B1~G-B3 模型承载缺口未拍板；强行用字符串承载会丢失 Stage 1 校验证据 | 待评审 | B 实现授权前 |
| R-B5 | 包产品 SPM 默认 iOS 12.0 三元组观察项 | 打包阶段复核 | 2.5 |

## 12. 授权边界（本轮）

| 事项 | 状态 |
|---|---|
| 2.2-A 测试补齐 | ✅ 已通过（第八轮 21/0） |
| 2.2-B 子规格有条件冻结（阶段划分/48 基线/模块职责/隔离/七方法基准） | ✅ 已确认 |
| G-B1~G-B3 Models 增补设计评审、G-B4 协议充分性评审、G-B5 夹具深比较设计 | ✅ 见 `Stage-2.2-B-Gap-Review.md` |
| G-B1~G-B5 数据契约最终冻结 | ⏳ 待评审决策清单（Gap-Review §8）拍板 |
| 2.2-B 源码实现（B1–B5） | ❌ 未授权（数据契约评审完成后再决定 B1） |
| 48 项 Swift 回归执行 | ❌ 未授权 |
| 修改 Models 字段/类型/枚举/解码行为 | ❌ 未授权 |
| 修改 `ElleKitAdapter` 协议 | ❌ 未授权（演进须单独评审） |
| 2.2-C 及以后批次、进入 2.3 | ❌ 未授权 |

## 13. 待拍板事项清单

1. ~~D1~D12~~ **已定稿**：见 `Stage-2.2-B-Data-Contract-Freeze.md`（数据契约冻结）；
2. **B1 已 runner 验收通过**：见 `Stage-2.2-B1-Environment-Detection.md`（run-43793314782，28 例 0 失败、隔离三向 OK）；
3. **B2 候选收集已 runner 验收通过**：见 `Stage-2.2-B2-Candidate-Collection.md`（run-118584150452，38 例 0 失败、隔离三向 OK）；
4. **B3 校验裁决本地验收通过（方案 B）**：见 `Stage-2.2-B3-Validation-Adjudication.md`（基准提交 `3e878cb`，本地静态核对 56 例计数/规则/隔离通过；CI Runner、独立构建与正式闭环延后 B5 集中回归，71 项逐阶段映射）；
5. **B4 目录/软链定位本地静态核对通过（方案 B）**：见 `Stage-2.2-B4-Directory-Symlink-Resolution.md`（本地静态核对 71 例计数/规则/隔离通过；Local Test Execution Not run，CI Runner、独立构建与正式闭环延后 B5）；
6. **B5 集成回归验收规格已冻结（设计层）**：见 `Stage-2.2-B5-Integration-Regression.md`；六部分验收、两条验证线、INT-001~010 集成场景、深比较/Codable/隔离/追溯/Runner 门槛已定稿；集成测试编写、Pipeline 装配与 Runner 执行待单独授权；2.2-C 未授权。
7. **B5 第二步集成落地（方案 B，Runner 延后）**：见 `Stage-2.2-B5-Implementation-Record.md`；B3→B4 桥接与离线组合根、INT-001~010、夹具深比较与确定性测试已落地并接入 Package 接线；本地静态核对通过，Local Test Execution Not run；71 项冻结回归未改；Runner 集中验收、独立构建与正式闭环待下一次授权。
8. **B5 第三步 Runner 前完善（方案 B，未编译未跑测试）**：补 `EnvironmentRouteMapper`（B1 结果→路线，冲突/未知 nil、告警保留、不从路径反推）与 Pipeline `environment:` 生产重载；Bridge 六类非 resolved 不转发确认 jbroot 复核通过；AdapterResolver 具体装配仍延后；CI 分阶段 `--filter` 出证留待 Runner 授权；测试预期 71 + 20 = 91，未执行。
9. **B5 Runner 集中验收通过**：run `43817618222`（runner SHA `7fc5d53`），`swift build` 成功、`swift test` **91 例 0 失败**（冻结 71：21/7/10/18/15；附加 20：INT 10 + 深比较 4 + 确定性/映射 6）、隔离三向通过、Core 不实例化具体 Adapter、App 模拟器构建启动存活并归档截图；证据见 `Tests/Stage2/evidence/run-43817618222/` 与 `Stage-2.2-B5-Implementation-Record.md` §4C。App 存活仅证明工程构建与基础启动，不证明越狱目录访问权限；AdapterResolver 装配、2.2-C、真机兼容/权限/注入/启停仍未授权。
10. **2.2-C 第一步只读审计与规格冻结（设计层）**：见 `Stage-2.2-C-Audit.md`（G-C1~G-C6 缺口）与 `Stage-2.2-C-Enumeration-Pairing-Parser.md`（C1 枚举 23 / C2 配对 15 / C3 解析 22 / C4 集成回归，60 项映射与门槛）。本轮未改源码/Models/协议/夹具/harness/测试，未编译未跑 Runner；C1~C4 编码与 Models/协议演进待逐批单独授权。
11. **2.2-C 第二步 G-C1/G-C2 枚举模型契约冻结（设计层）**：见 `Stage-2.2-C-Enumeration-Models-Contract.md`；定稿 `PluginFileEvidence`（条目证据）、`PluginInventorySnapshot`（清单快照）、`PluginFileKind`/`PluginEntryStatus`/`EnumerationStatus`/`PluginKindCounts` 与输入信号快照的字段、类型、Optional 三态、枚举原始值与 Codable 口径；G-C3 配对快照归 C2 前置评审，G-C4/G-C5 解析模型归 C3 前置评审，G-C6 哈希/元数据真机可取性留 2.5。Models 增补落地与 C1 编码待单独授权。
12. **2.2-C1 Plugin Enumeration 代码冻结（Runner 验收通过）**：见 `Stage-2.2-C1-Enumeration-Implementation.md` 与 `Tests/Stage2/evidence/run-43825045361/RUN-METADATA.md`；枚举器链路（分类器/证据构建/汇总/编排）与快照模型落地，Package 接线完成；Runner run `43825045361`：`swift build` 成功、`swift test` 114 例 0 失败（既有 91 + C1 23）、隔离三向 OK、App 构建存活；S1-04 23 例映射、非递归/大小写敏感/软链不跟随/异常保留/三态 nil/快照不进信封六项自查通过。C2 配对、C3 解析、信封改动与真机操作均未触碰；服务装配接入归后续授权。
13. **2.2-C2 第一步 G-C3 配对数据契约冻结（设计层）**：见 `Stage-2.2-C2-Pairing-Contract.md`；定稿配对快照/记录/计数/目录级状态/五态分类，冻结配对键大小写敏感精确匹配、同 `sourceDirectory` 作用域、歧义多候选不选边、受限条目进 uncertain 且留置候选、五态互斥计数、Codable 与排序确定性口径及 S1-05 15 例映射；`Pairing` 四值不扩，ambiguous/uncertain 由记录分类与既有证据/UnknownItem 承载。未改源码/Models/协议/夹具/harness/既有测试，未编译未跑 Runner；C2-A~C2-D 编码待逐批单独授权。
14. **2.2-C2-A Pairing Models/Snapshot 代码冻结（Runner 验收待授权）**：见 `Stage-2.2-C2-A-Pairing-Models-Implementation.md`；Core 落地 `PairingCategory`/`PairingStatus`/`PluginPairingCounts`/`PairingEvidenceBasis`/`PluginPairingRecord`/`PluginPairingSnapshot` 六源与 12 例 Codable/模型测试，Package 接线完成；`Pairing` 四值未扩，ambiguous/uncertain 记录 `pairing=nil`，歧义候选全量保留不取 first，五桶计数互斥求和；三态 nil 保留、快照不进信封、不产出最终 Plugin。Key/Index/Engine、服务装配与 Adapter 未触碰，本机无工具链未编译未跑 Runner；C2-B/C2-C/C2-D 待逐批授权。
15. **2.2-C2-B Pairing Key/Index/Engine 代码冻结（Runner 验收待授权）**：见 `Stage-2.2-C2-B-Pairing-Engine-Implementation.md`；Core 落地 `PluginPairingKeyBuilder`/`PluginPairingIndex`/`PluginPairingIndexBuilder`/`PluginPairingClassifier`/`PluginPairingEngine`/`PluginPairingSnapshotBuilder` 六源与 37 例专项测试（Key 11/Index 5/Engine 21），Package 接线完成；精确后缀剥离大小写敏感、同目录作用域不跨快照、多候选全保留不取边、受限条目 uncertain 留置候选、键集合与候选路径排序确定性、五桶计数互斥落地；未决/失败目录不建记录。服务装配、Adapter、跨目录合并与真机操作未触碰，本机无工具链未编译未跑 Runner；C2-C/C2-D 待逐批授权。
16. **2.2-C2-C C1→C2 集成桥接代码冻结（Runner 验收待授权）**：见 `Stage-2.2-C2-C-Pairing-Integration-Implementation.md` 与集成契约 `Stage-2.2-C2-C-Pairing-Integration-Contract.md`；Core 落地 `PluginPairingInput`/`PluginPairingInputAdapter`/`PluginPairingPipeline`/`PluginPairingIntegrationResult`/`PluginPairingIntegrationValidator` 五源与 32 例集成测试（A 输入 8/B 状态告警 7/C 行为 9/D 稳定隔离 8），Package 接线完成；C1→C2 状态传递矩阵冻结，INT-C2-001~014 校验 route/目录/证据/归集/告警/状态/计数/不可变性/确定性/路线隔离；适配器只过滤不改写字段，原始快照执行前后一致。服务装配、协议演进、Adapter 与真机操作未触碰，本机无工具链未编译未跑 Runner；C2-D 待独立授权。
17. **2.2-C2-D Runner 验收清单冻结与 C2 只读审计（Runner 未执行）**：见 `Stage-2.2-C2-D-Runner-Acceptance-Checklist.md`；审计确认 Models/Adapters/协议/Stage 1 夹具/既有测试零改动，隔离三向通过；清单冻结七组范围——已有 XCTest 195（B 91/C1 23/C2-A 12/C2-B 37/C2-C 32），F 组 S1-05 15 例原始行为映射当前接入 0、Runner 前须独立批次补齐，G 组双路线隔离/Models 契约/Fixture 完整性/确定性/App Build 检查；四类数字（XCTest 执行/基线映射/新增专项/静态检查）分列不重复计数，十项硬门槛与证据归档结构定稿。Runner 编译回归待独立授权，本批未宣称已通过编译。
18. **2.2-C2-D1 S1-05 原始配对基线映射测试接入（代码冻结，Runner 验收待授权）**：见 `Stage-2.2-C2-D1-S105-Fixture-Mapping-Implementation.md`；测试 target 新增 `S105FixtureLoader.swift` 与 `PluginPairingS105FixtureTests.swift`，13 组夹具逐例独立测试标识 + 2 合成用例（确定性两轮全等、路线隔离无 `/var/jb` 回退）共 15 例；foreign 外路线陷阱条目在加载层按 C1 边界排除，同目录作用域不跨快照合并；未改 Stage 1 fixtures/metadata/harness 与冻结源码，本机无工具链未编译未跑 Runner；完整编译回归与归档归 C2-D2 独立授权。
19. **2.2-C2-D2 Runner 验收前置冻结（Runner 未执行）**：见 `Stage-2.2-C2-D2-Runner-Preflight.md`；本地完成 Loader/测试/Package 静态复核、S1-04/S1-05 夹具完整性与计数一致性校验、三向隔离脚本检查；CI test Job 增补 S1-05 15 例独立过滤执行步骤；静态清点 210 例（冻结回归 114、C2 专项 81、S1-05 映射 15），四类数字分列不混算。本机无 Swift 工具链与远端凭证，`swift build`/全量 `swift test`/App Build 门槛待 macOS Actions 调度出证；本批未宣称编译或回归通过，未进入 C3。
