# Stage-2.2-B4-Directory-Symlink-Resolution.md — B4 ElleKit 目录与软链定位落地记录

> 状态：**本地静态核对通过（方案 B），Runner 证据延后 B5 集中归档；未标记正式闭环**。B4 代码冻结点 `6bbd64f`（开工锚点 `1803c2e`）；本地静态核对记录见 `Tests/Stage2/evidence/run-local-b4/LOCAL-REVIEW.md`。
> 状态标记：Implementation ✅ Complete；Local Static Review ✅ Passed；Local Test Execution ⏸ Not run（本机无 Swift 工具链）；CI Runner ⏸ Deferred；Independent Build ⏸ Pending；Final Acceptance ⏸ Pending。
> 授权：用户授权执行 Stage 2.2-B4（ElleKit Directory & Symlink Resolution：目录路径定位、目录状态校验、DynamicLibraries 软链五态与目标一致性核对、裁决编排）；严格依据 `Stage-2.2-B-Data-Contract-Freeze.md` §5（D9/D10/D11、D3）、`Stage-2.2-B-Environment-Path.md` §9 B4 行与 S1-03 原始行为基线（`Tests/S1-03/resolver.js`、`run.js`、`report/S1-03-report.json`）。
> 边界：只做路径定位与证据采集，不做插件枚举（归 2.2-C）；不改 B2 收集规则、B3 六态优先级与裁决语义；不改 `ElleKitAdapter` 七方法协议；不新增 Core 服务协议；不装配 Pipeline、不写入 `EnvironmentPaths`/导出信封（归 B5）；不改 Stage 1 Fixtures/harness/报告；不创建/删除软链，不改注入配置，不启停插件，不碰 dpkg，不做 GUI 私有扫描器/权限探针。

## 1. 授权范围

| 允许落地 | 落点 |
|---|---|
| 离线输入快照（upstream.route/jbroot、fs.tweakInject、fs.dynamicLibraries 信号解码） | `Core/PathResolver/ElleKit/ElleKitDirectorySnapshot.swift` |
| 路线 → 目录路径推导（rootless/rootful/roothide/未知） | `Core/PathResolver/ElleKit/ElleKitPathDeriver.swift` |
| TweakInject 目录状态校验（unresolved/not_found/partial/confirmed） | `Core/PathResolver/ElleKit/ElleKitDirectoryValidator.swift` |
| DynamicLibraries 软链五态检查与 targetMatch 词法比较 | `Core/PathResolver/ElleKit/ElleKitSymlinkInspector.swift` |
| 裁决结果结构（Core 内部，复用 Models 冻结证据结构） | `Core/PathResolver/ElleKit/ElleKitDirectoryResolution.swift` |
| 编排器（路径推导 → 目录校验 → 软链检查 → 裁决；不重扫 JBROOT） | `Core/PathResolver/ElleKit/ElleKitDirectoryResolver.swift` |
| S1-03 15 项 Swift 回归 + 确定性/ID 不一致/分层/三态/路线覆盖/兼容用例 | `Tests/Stage2/ElleKitDirectoryTests.swift` |
| 契约 §5.1/§5.2 两个证据结构（纯追加，不改既有字段/枚举/协议） | `Models/EnvironmentModels.swift` |

| 禁止项 | 执行情况 |
|---|---|
| 修改 B2 候选收集语义、来源顺序、去重规则、多来源保留 | ✅ 未改；B4 不接触收集层 |
| 修改 B3 六态优先级、单项校验与多候选裁决语义 | ✅ 未改；B4 上游路线/jbroot 由快照提供，B5 才接 B3 结果 |
| 修改七方法协议 / Adapter 私有规则 / 既有 Models 字段与枚举 | ✅ 未改 `ElleKitAdapter`、双 Adapter、`CoreServices.swift`；Models 仅纯追加两个结构 |
| 插件枚举、dylib 列表、plist/Filter 解析、配对、归属 | ✅ 未触碰（归 2.2-C / 后续批次） |
| B5 Pipeline 装配、服务协议新增、结果写入 `EnvironmentPaths`/导出信封 | ✅ 未接线；裁决结果为 Core 内部结构，装配归 B5 |
| 修改 Stage 1 Fixtures / harness / 报告 | ✅ 未改；测试只读引用 `Tests/Fixtures/S1-03/` |
| 真机写入、软链增删、注入配置修改、插件启停、dpkg 改动、GUI 扫描/权限探针 | ✅ 未接入；事实全部来自离线夹具信号，不访问真实文件系统 |
| 三态位把 `nil` 转成 `false` | ✅ 未转；未验证位保持 `nil`，仅裁决时按 `!= true` 参与基线判定 |
| 2.2-A 21 例 / B1 7 例 / B2 10 例 / B3 18 例既有回归被破坏 | 本地未改既有测试与 Models 字段语义；回归执行待 B5 runner 确认 |

## 2. 证据模型（契约 §5.1 / §5.2，纯追加）

### 2.1 `PathLocationEvidence`（D9 目录路径证据）

| 字段 | 口径 |
|---|---|
| `requestedPath: String?` | 请求/推导路径；无法推导时 `nil`（不填空串冒充已知） |
| `resolvedPath: String?` | 对应基线 realpath |
| `exists / readable / enumerable / structureMatch: Bool?` | 三态事实位；`nil`=未验证，不填 `false` |
| `status: String?` | 目录裁决状态（D9），独立于 `EvidenceLevel`，不用证据等级替代 |
| `warnings: [ReportWarning]` | 统一告警载体（D3） |

### 2.2 `SymlinkEvidence`（D10 软链证据）

| 字段 | 口径 |
|---|---|
| `isSymlink: Bool?` | 三态：`false`=已检查确认非软链；`nil`=未检查；二者不得混同 |
| `targetPath: String?` | 对应基线 symlinkTarget |
| `realpath: String?` | 实际解析路径 |
| `symlinkState: String?` | 五态封闭集：`resolved / broken / loop / denied / not_symlink` |
| `targetMatch: Bool?` | 软链目标是否符合预期；独立于五态，不并入状态位 |
| `warnings: [ReportWarning]` | 统一告警载体（D3） |

- 首版不纳入 `targetExists / targetReadable / resolutionSucceeded / structureValid` 等基线外布尔位。
- D11 容器侧车 `ElleKitPathSidecar` 按契约 §5.3 暂缓，本批次不落地。

## 3. 路径推导（对齐 resolver.js `tiPath` / `dlPath`）

后缀常量：TweakInject `/usr/lib/TweakInject/`；DynamicLibraries `/Library/MobileSubstrate/DynamicLibraries`。

| 路线 | TweakInject 路径 | DynamicLibraries 路径 |
|---|---|---|
| `rootless` | `/var/jb` + TI 后缀 | `/var/jb` + DL 后缀 |
| `rootful` | TI 后缀（仅诊断参照） | DL 后缀 |
| `roothide` | 上游已确认 jbroot + TI 后缀；jbroot 未定位 → `nil` | 同构 |
| 未知 | `nil`（不反推） | `nil` |

红线：RootHide jbroot 未定位时**禁止回退** `/var/jb` 或 `/`；rootless 路径是独立路线规则，不作 RootHide 备用路径。

## 4. 目录状态与软链检查

### 4.1 目录状态（D9，优先级对齐基线）

1. 路径无法推导 → `unresolved` + `directory_unresolved`
2. `exists != true` → `not_found` + `directory_not_found`
3. `readable != true || enumerable != true` → `partial` + `access_limited`
4. 存在且可读、可枚举 → `confirmed`

分层红线：`readable` 与 `enumerable` 独立记录；`readable=false` 不得推断 `enumerable=true`，反之亦然；路径存在不等于可读/可枚举；realpath 成功不等于可读。

### 4.2 软链五态与 targetMatch（D10）

- `symlinkState` 缺省 `not_symlink`；五态外取值原样保留状态串，不映射、不丢弃。
- `targetMatch`：仅 `resolved` 且同时有目标串与预期目录路径时，经 `JBRootCandidateCollector.normalizeLexical`（复用 B2 既有词法规范化，不另起一套）规范化后比较；其余状态为 `false`。
- 软链告警：

| 状态/条件 | 告警 code |
|---|---|
| `broken` | `symlink_broken` |
| `loop` | `symlink_loop` |
| `denied` | `symlink_target_denied` |
| `not_symlink` 且存在 | `not_a_symlink` |
| `resolved` 且有预期路径但目标不符 | `structure_conflict` |

红线：路径存在不等于软链；软链解析成功不等于目标正确；目标一致性独立于五态记录。

## 5. 裁决优先级（对齐 resolver.js `resolveDirectory`，顺序不可调换）

| 条件 | outcome |
|---|---|
| 1. `tiPath == nil` | `unresolved` |
| 2. 目录状态 `not_found` | `not_found` |
| 3. `dlState == resolved` 且 `targetMatch != true` | `structure_conflict` |
| 4. 路线 `rootful` | `rootful_diagnostic`（仅诊断，不进可执行 Profile） |
| 5. 目录 `confirmed` 且 `dlState == resolved` 且 `targetMatch == true` | `resolved` |
| 6. 其余 | `partial` |

- 顶层告警合并目录与软链告警，按 `code + message` 去重；`rootful` 路线附加 `rootful_route_not_profile`。
- 结果结构 `ElleKitDirectoryResolution { route, tweakInject: PathLocationEvidence?, dynamicLibraries: SymlinkEvidence?, dynamicLibrariesPath: String?, outcome, warnings: [ReportWarning] }`；`dynamicLibrariesPath` 对应基线 `dynamicLibraries.value`。

## 6. 测试映射（S1-03 15 项回归；只读夹具）

测试文件 `Tests/Stage2/ElleKitDirectoryTests.swift`；累计目标 **71 例** = 21 ModelsCodable + 7 EnvironmentDetection + 10 CandidateCollection + 18 Validation + **15 Directory/Symlink**。

| 测试方法 | 基线用例 | 核对维度 |
|---|---|---|
| `testRhValidResolved` | DIR-001/004/005（rh-valid） | 目录 confirmed + 软链 resolved 且匹配 → `resolved`；目标与目录路径一致 |
| `testRhMissingNotFound` | DIR-002（rh-missing） | 不存在 → `not_found`；`directory_not_found` |
| `testRhUnreadablePartialLayered` | DIR-003（rh-unreadable） | 不可读/不可枚举 → `partial`；readable/enumerable 均 false 独立分层；软链 resolved 匹配 |
| `testRhBrokenLinkPartial` | DIR-006（rh-broken-link） | `broken` → `partial`；`symlink_broken` |
| `testRhLoopPartial` | DIR-007（rh-loop） | `loop` → `partial`；`symlink_loop` |
| `testRhTargetDeniedPartial` | DIR-008（rh-target-denied） | `denied` → `partial`；`symlink_target_denied` |
| `testRhNotSymlinkPartial` | DIR-009（rh-not-symlink） | 非软链且存在 → `partial`；`not_a_symlink` |
| `testRootlessValidResolved` | DIR-001（rootless-valid） | 独立 `/var/jb` 路径 → `resolved` |
| `testRootfulDiagnostic` | DIR-001（rootful-valid） | 仅诊断参照 → `rootful_diagnostic`；`rootful_route_not_profile` |
| `testRouteFallbackGuardNoLeak` | DIR-010（route-fallback-guard） | roothide 缺 jbroot 不推导路径；不回退 `/var/jb` 或 `/`；`unresolved`；`directory_unresolved` |
| `testStructureConflict` | DIR-011（structure-conflict） | resolved 目标不符 → `structure_conflict`；`structure_conflict` |
| `testDeterminismDIR012` | DIR-012 | 相同信号重复解析 Equatable 全等 |
| `testIdMismatchDIR013` | DIR-013 | fixtureId 不一致不影响解析；结果非 nil |
| `testEvidenceCodableRoundTrip` | D3/D9/D10 兼容 | 目录/软链证据 Codable 往返全等 |
| `testThreeStatePreservedAndRouteCoverage` | D6/路线覆盖 | 未验证位保持 nil 不转 false；夹具并集覆盖 roothide/rootless/rootful |

> 15 项为 S1-03 完整回归目标；分层核对、回退越界核对、三态保留、确定性、路线覆盖覆盖在上述用例内。B5 再做 71 项逐阶段深比较与全量复跑（48 为 Stage 1 原始行为基线数量，非 Swift 回归总数）。

## 7. 验收状态（方案 B：本地验收，Runner 延后 B5）

本地静态核对已通过（`Tests/Stage2/evidence/run-local-b4/LOCAL-REVIEW.md`）；独立 CI 构建、`swift test` 执行、隔离 runner 作业、App 构建与截图、产物归档统一延后 **B5 集中执行**，本批次不上传 Runner 证据，B4 不标记正式闭环。

| 检查项 | 门禁 | 本地结果 | Runner 证据 |
|---|---|---|---|
| Core 文件完整性 | 6 个 B4 源文件落地 | ✅ 静态核对通过 | B5 编译确认 |
| 测试文件完整性 | 1 个测试文件、15 方法 | ✅ 计数 15 | B5 执行确认 |
| 21 Codable + 7 B1 + 10 B2 + 18 B3 + 15 B4 | 累计 71 例 0 失败 | ✅ 计数 71 | B5 执行确认 |
| 隔离 | 双 Adapter 三向 OK；Core 不实例化具体 Adapter | ✅ 本地脚本三向 OK | B5 runner 作业复核 |
| 冻结面 | Models 既有字段/枚举/协议、Adapters、服务协议、Stage1 基线未改 | ✅ Models 纯追加；其余无改动 | B5 复核 |
| App Target 构建 + 存活截图 | 只读骨架构建启动 | ⏸ 延后 B5 | B5 app-build |

### 7.1 B5 完整回归口径（71 项，逐阶段映射）

| 阶段 | 数量 | 说明 |
|---|---|---|
| 2.2-A Codable | 21 | Models 冻结面回归 |
| B1 Environment | 7 | 环境识别（15 ENV 口径） |
| B2 Candidate Collection | 10 | 候选收集 |
| B3 JBROOT Validation | 18 | 校验裁决 |
| B4 Directory/Symlink | 15 | S1-03 目录/软链（本批次） |
| **合计** | **71** | 48 为 Stage 1 原始行为基线数量，非 Swift 回归总数 |

B5 须逐阶段映射执行，不能只跑总套件宣称全过；失败时须区分 B3 / B4 / 集成问题。追溯要求见本地验收记录 §5。

## 8. 变更文件清单（本批次）

| 文件 | 变更 |
|---|---|
| `Models/EnvironmentModels.swift` | 纯追加：`PathLocationEvidence`、`SymlinkEvidence`（契约 §5.1/§5.2） |
| `Core/PathResolver/ElleKit/ElleKitDirectorySnapshot.swift` | 新增：离线信号快照与解码 |
| `Core/PathResolver/ElleKit/ElleKitPathDeriver.swift` | 新增：路线 → TI/DL 路径纯函数推导 |
| `Core/PathResolver/ElleKit/ElleKitDirectoryValidator.swift` | 新增：目录状态校验与目录告警 |
| `Core/PathResolver/ElleKit/ElleKitSymlinkInspector.swift` | 新增：软链五态、targetMatch 与软链告警 |
| `Core/PathResolver/ElleKit/ElleKitDirectoryResolution.swift` | 新增：裁决结果结构 |
| `Core/PathResolver/ElleKit/ElleKitDirectoryResolver.swift` | 新增：编排与裁决优先级 |
| `Tests/Stage2/ElleKitDirectoryTests.swift` | 新增：S1-03 15 项回归与辅助场景 |
| `Package.swift` | Core 纳入 6 个 B4 源文件；Stage2Tests 纳入 `ElleKitDirectoryTests.swift` |

未变更：`Adapters/`、`Core/CoreServices.swift`、`Core/Environment/`、`Core/PathResolver/JBRoot/`、B1/B2/B3 既有测试文件、`Tests/S1-03/` 基线与报告、`Tests/Fixtures/S1-03/`。

## 9. 边界与遗留

- B4 结论仅为离线夹具信号下的目录/软链定位；模拟器/离线通过不代表 RootHide GUI App 具备真实 TweakInject 访问权限。
- 裁决结果尚未装配进 `EnvironmentPaths`/导出信封（归 B5 Pipeline）；B5 才做 B3 确认 jbroot → B4 目录定位的串联。
- Rootless/Rootful 结果仅作路线对照，无真机兼容结论；未知路线/来源原样保留待后续证据。
- B5（Pipeline 71 项逐阶段深比较复跑、独立构建、证据归档）、2.2-C（插件枚举）及以后均未授权，待单独拍板逐批验收。
