# Stage-2.2-B3-Validation-Adjudication.md — B3 JBROOT 校验与裁决落地记录

> 状态：**本地验收通过（方案 B），Runner 证据延后 B5 集中归档；未标记正式闭环**。基准提交 `3e878cb`；本地静态核对记录见 `Tests/Stage2/evidence/run-local-b3/LOCAL-REVIEW.md`。
> 状态标记：Implementation ✅ Complete；Local Static Review ✅ Passed；Local Test Execution ⏸ Not run（本机无 Swift 工具链）；CI Runner ⏸ Deferred；Independent Build ⏸ Pending；Final Acceptance ⏸ Pending。
> 授权：用户授权执行 Stage 2.2-B3（JBROOT Validation：候选校验、六态分类、多候选裁决）；严格依据 `Stage-2.2-B-Data-Contract-Freeze.md`（D3/D4/D5/D6/D7/D8）、`Stage-2.2-B-Environment-Path.md` §9 B3 行与 S1-02 原始行为基线（`Tests/S1-02/resolver.js`、`run.js`、`report/S1-02-report.json`）。
> 边界：不改 B2 收集语义/来源顺序/去重规则；不改 `ElleKitAdapter` 七方法协议；不进入 B4 目录/软链定位、B5 Pipeline 集成与 2.2-C；不改 Stage 1 Fixtures/harness/报告；不做 GUI 权限探针、真机写入、插件启停或注入配置修改；不检查 TweakInject（归 B4）。

## 1. 授权范围

| 允许落地 | 落点 |
|---|---|
| 容器命名校验器（前缀/16 hex/非零/校验位异或；jbrand 大写解析） | `Core/PathResolver/JBRoot/JBRootNameValidator.swift` |
| 单项校验器（回填五项三态位、配对软链信号） | `Core/PathResolver/JBRoot/JBRootValidator.swift` |
| 六态分类器（基线优先级顺序不可调换） | `Core/PathResolver/JBRoot/JBRootStatusClassifier.swift` |
| 多候选裁决器（eligible/歧义/唯一确认/失败/跨路线/无候选） | `Core/PathResolver/JBRoot/JBRootDecisionResolver.swift` |
| 编排器（B2 收集 → 校验分类 → 裁决；不改收集规则） | `Core/PathResolver/JBRoot/JBRootResolver.swift` |
| S1-02 18 项 Swift 回归 + 三态/多候选/路线冲突/确定性/兼容用例 | `Tests/Stage2/JBRootValidationTests.swift` |

| 禁止项 | 执行情况 |
|---|---|
| 修改 B2 候选收集语义、来源顺序、去重规则、多来源保留 | ✅ 未改；编排器只调用既有 `JBRootCandidateCollector` 输出，不另起规范化/去重 |
| 修改七方法协议 / Adapter 私有规则 | ✅ 未改 `ElleKitAdapter` 与双 Adapter 实现 |
| B4 目录/软链定位、TweakInject 检查、DynamicLibraries 软链 | ✅ 未触碰 |
| B5 Pipeline 装配、服务协议新增、结果写入 `EnvironmentPaths` | ✅ 未接线；裁决结果为 Core 内部结构，装配归 B5 |
| 修改 Stage 1 Fixtures / harness / 报告 | ✅ 未改；测试只读引用 `Tests/Fixtures/S1-02/` |
| 真机写入、插件启停、注入配置修改、GUI 文件扫描/权限探针 | ✅ 未接入；校验事实全部来自离线夹具信号，不访问真实文件系统 |
| 三态位把 `nil` 转成 `false` | ✅ 未转；未验证位保持 `nil`，仅裁决时按 `!= true` 参与基线判定 |
| 2.2-A 21 例 / B1 7 例 / B2 10 例既有回归被破坏 | 本地未改既有测试与 Models 字段语义；回归执行待 B5 runner 确认 |

## 2. 五项三态校验位（D6，复用冻结模型，不另造重复结构）

复用 B2 已落地的 `JBRootValidationBits { nameValid, exists, structureMatch, readable, realpath }`，不新增 `checksumValid`。

| 位 | B3 口径（对齐 resolver.js） |
|---|---|
| `nameValid` | 仅 `route == roothide` 时做命名校验；其余路线留 `nil`（未验证，不填 false）。命名规则：前缀 `.jbroot-`、后缀恰 16 位 hex（大小写均可）、数值非零、校验位通过（位移 8/16/24/32/40/48/56 异或，低 8 位相等） |
| `exists` | 信号存在事实原样保留三态；裁决时 `true` 才算存在，`false`/`nil` 按不存在 |
| `structureMatch` | 信号结构事实原样保留三态；基线状态裁决不以结构位为分支条件，仅作证据记录 |
| `readable` | 信号可读事实原样保留三态；`true` 才算可读；realpath 成功不等于可读 |
| `realpath` | 软链失败（broken/loop）置 `nil`；其余沿用信号 realpath；不通过 realpath 反推路线 |

## 3. 六态分类（D4，优先级严格对齐基线）

分类器 `JBRootStatusClassifier.classify(...)` 按以下顺序判定，顺序不可调换：

1. `route == rootless` → `cross_route` + `rootless_route_not_jbroot`
2. `route == rootful` → `cross_route` + `rootful_route_not_jbroot`
3. 软链失败（broken/loop） → `resolve_failed` + `symlink_resolve_failed`
4. `nameValid == false` → `rejected_invalid` + `invalid_container_name`
5. `exists != true` → `rejected_missing` + `candidate_missing`
6. `readable != true` → `partial` + `access_limited`
7. 其余 → `confirmed`

- 六态封闭集：`confirmed / partial / cross_route / rejected_invalid / rejected_missing / resolve_failed`；`pending` 仅内部初始态，不导出。
- 跨路线候选作为环境冲突证据保留在候选列表，不删除、不调用另一路线 Adapter 私有规则。
- 未知来源/路线原样保留，不反推命名结论或路线。

## 4. 多候选裁决（对齐 resolver.js `resolvePaths`）

### 4.1 口径

- **rhEligible**：`route == roothide` 且状态不在 `rejected_invalid / rejected_missing / resolve_failed`。
- **crossRoute**：`route == rootless || route == rootful`。
- 顶层告警合并全部候选告警，按 `code + message` 去重。

### 4.2 裁决优先级（不可调换，不静默选边）

| 条件 | outcome | 其他字段 |
|---|---|---|
| rhEligible 数量 > 1 | `ambiguous` | `ambiguous=true`；追加 `multiple_candidates`；`jbroot/jbrand/realpath/selectedSource` 均 `nil` |
| rhEligible 数量 == 1 | `resolved`（confirmed）或 `partial` | 取该候选：`jbroot=path`、`jbrand=parseJbrand`、`realpath=validation.realpath`、`selectedSource=source` |
| 存在 `resolve_failed` 候选 | `resolve_failed` | 不选边 |
| 仅有跨路线候选且无任何 roothide 候选 | `cross_route_only` | 跨路线证据保留 |
| 候选为空 | `no_candidate` | 追加 `no_jbroot_candidate` |
| 其余（roothide 候选全部被拒绝等） | `no_candidate` | 失败原因候选证据保留 |

### 4.3 结果结构（Core 内部，字段对齐基线输出）

`JBRootResolutionResult { jbroot: String?, jbrand: String?, realpath: String?, ambiguous: Bool, outcome: String, selectedSource: String?, candidateCount: Int, candidates: [JBRootCandidate], warnings: [ReportWarning] }`。

- 候选状态与最终决策分离：单候选 `confirmed` 不代表多候选可唯一确认；多个有效候选同时存在时整体仍为歧义。
- `jbrand` 只做命名后缀大写归一，不猜测语义；`parseJbrand` 先过命名校验，非法返回 `nil`。

## 5. 测试映射（S1-02 18 项回归；只读夹具）

测试文件 `Tests/Stage2/JBRootValidationTests.swift`；累计目标 **56 例** = 21 ModelsCodable + 7 EnvironmentDetection + 10 CandidateCollection + **18 Validation**。

| 测试方法 | 基线用例 | 核对维度 |
|---|---|---|
| `testRhValidResolved` | PATH-001/002/003/008/009（rh-valid） | 唯一 confirmed → `resolved`；五项位 true；selectedSource=scan；jbrand/realpath 对齐 |
| `testRhMultipleAmbiguous` | PATH-006（rh-multiple） | 两 roothide 有效候选 → `ambiguous`；不选边；`multiple_candidates` |
| `testRhBadNameRejectedInvalid` | PATH-003（rh-badname） | 校验位失败 → `rejected_invalid`；`no_candidate`；`invalid_container_name` |
| `testRhNameOnlyRejectedMissing` | PATH-002（rh-name-only） | 不存在 → `rejected_missing`；`no_candidate`；`candidate_missing` |
| `testRhUnreadablePartial` | PATH-007（rh-unreadable） | 不可读 → `partial`；仍取唯一候选；`access_limited` |
| `testRhBrokenLinkResolveFailed` | PATH-005/007（rh-broken-link） | 软链失败 → `resolve_failed`；realpath 置 nil；`symlink_resolve_failed` |
| `testRootlessCrossRouteOnly` | PATH-010（rootless-varjb） | 跨路线 → `cross_route_only`；`cross_route`；跨路线不做命名校验 |
| `testRootfulCrossRouteOnly` | PATH-010（rootful-root） | 同上，rootful 路线 |
| `testNoCandidate` | PATH-007（no-candidate） | 空候选 → `no_candidate`；`no_jbroot_candidate` |
| `testRealpathPrivateVarResolved` | PATH-005（realpath-privatevar） | bootstrap 来源 roothide；realpath 保留 `/private/var` 前缀；`resolved` |
| `testNameValidationRules` | PATH-002~004 命名口径 | 合法/小写/坏校验位/短后缀/非 hex/全零/缺前缀 |
| `testJbrandParseUppercase` | jbrand 解析 | 大写归一；非法命名/短后缀返回 nil |
| `testPATH004NormalizedNameValidation` | PATH-004 | 沿用 B2 规范化结果做命名校验，不另起规范化 |
| `testPATH011Determinism` | PATH-011 | 相同输入重复裁决 Equatable 全等 |
| `testPATH012IdMismatchDoesNotAffectDecision` | PATH-012 | fixtureId 不一致不影响裁决 |
| `testThreeStateBitsNotCoerced` | D6 三态 | 未验证位保持 nil 不转 false；nil 存在事实按不存在参与裁决 |
| `testMultiCandidateDecisionScenarios` | PATH-006/008/009/010 多候选 | confirmed+拒绝共存、双 confirmed 歧义、全拒绝、跨路线证据保留 |
| `testValidatedCandidateCodableRoundTrip` | D3/D8 兼容 | 校验后候选 Codable 往返全等；旧信封投影解码兼容 |

> 18 项为 S1-02 完整回归目标；三态/多候选/路线冲突/确定性/旧 JSON 兼容覆盖在上述用例内。B5 再做 71 项逐阶段深比较与全量复跑（48 为 Stage 1 原始行为基线数量）。

## 6. 验收状态（方案 B：本地验收，Runner 延后 B5）

本地静态核对已通过（`Tests/Stage2/evidence/run-local-b3/LOCAL-REVIEW.md`，基准提交 `3e878cb`）；独立 CI 构建、`swift test` 执行、隔离 runner 作业、App 构建与截图、产物归档统一延后 **B5 集中执行**，本批次不上传 Runner 证据，B3 不标记正式闭环。

| 检查项 | 门禁 | 本地结果 | Runner 证据 |
|---|---|---|---|
| Core 文件完整性 | 5 个 B3 源文件落地 | ✅ 静态核对通过 | B5 编译确认 |
| 测试文件完整性 | 1 个测试文件、18 方法 | ✅ 计数 18 | B5 执行确认 |
| 21 Codable + 7 B1 + 10 B2 + 18 B3 | 累计 56 例 0 失败 | ✅ 计数 56 | B5 执行确认 |
| 隔离 | 双 Adapter 三向 OK；Core 不实例化具体 Adapter | ✅ 本地脚本三向 OK | B5 runner 作业复核 |
| 冻结面 | Models/Adapters/服务协议/Stage1 基线未改 | ✅ 相对 `bde210c` 无改动 | B5 复核 |
| App Target 构建 + 存活截图 | 只读骨架构建启动 | ⏸ 延后 B5 | B5 app-build |

### 6.1 B5 完整回归口径（71 项，逐阶段映射）

| 阶段 | 数量 | 说明 |
|---|---|---|
| 2.2-A Codable | 21 | Models 冻结面回归 |
| B1 Environment | 7 | 环境识别（15 ENV 口径） |
| B2 Candidate Collection | 10 | 候选收集 |
| B3 JBROOT Validation | 18 | 本批次 |
| B4 Path Resolution | 15 | S1-03 目录/软链（未授权） |
| **合计** | **71** | 48 为 Stage 1 原始行为基线数量，非 Swift 回归总数 |

B5 须逐阶段映射执行，不能只跑总套件宣称全过；失败时须区分 B3 / B4 / 集成问题。追溯要求见本地验收记录 §5。

## 7. 变更文件清单（本批次）

| 文件 | 变更 |
|---|---|
| `Core/PathResolver/JBRoot/JBRootNameValidator.swift` | 新增：命名校验与 jbrand 解析（纯字符串/数值） |
| `Core/PathResolver/JBRoot/JBRootStatusClassifier.swift` | 新增：六态分类与基线状态告警 |
| `Core/PathResolver/JBRoot/JBRootValidator.swift` | 新增：五项三态位回填 + 调用分类器；软链失败 realpath 置 nil |
| `Core/PathResolver/JBRoot/JBRootDecisionResolver.swift` | 新增：裁决结果结构 + 多候选裁决 |
| `Core/PathResolver/JBRoot/JBRootResolver.swift` | 新增：收集→校验→裁决编排，配对原始信号，合并收集层告警 |
| `Tests/Stage2/JBRootValidationTests.swift` | 新增：S1-02 18 项回归与辅助场景 |
| `Package.swift` | Core 源纳入五个 B3 文件；Stage2Tests 纳入 `JBRootValidationTests.swift` |

未变更：`Models/EnvironmentModels.swift`（复用既有候选/校验位结构）、`Adapters/`、`Core/CoreServices.swift`、B2 两个收集层文件语义、`Tests/S1-02/` 基线与报告、`Tests/Fixtures/S1-02/`、2.2-A / B1 / B2 既有测试文件语义。

## 8. 边界与遗留

- B3 结论仅为离线夹具信号下的校验裁决；模拟器/离线通过不代表真机越狱文件访问权限。
- 裁决结果尚未装配进 `EnvironmentPaths`/导出信封（归 B5 Pipeline）；B4 只使用 B3 确认路径定位 TweakInject 与软链，不重扫 JBROOT。
- Rootless/Rootful 候选仅作路线对照，无真机结论；未知路线/来源原样保留待后续证据。
- B4（目录/软链定位，S1-03 15 项）、B5（Pipeline 71 项逐阶段深比较复跑）、2.2-C 及以后均未授权，待单独拍板逐批验收。
