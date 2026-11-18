# Stage 2.2-B5 第二步：集成测试落地与 B3→B4 衔接实现记录

- 日期：2026-11-16
- 授权依据：用户附件《下一步建议进入 B5 第二步：集成测试落地与 B3→B4 衔接实现》；冻结规格 `Stage-2.2-B5-Integration-Regression.md`（提交 `f8896dd`）。
- 状态标记（方案 B 口径）：**Implementation Complete / Local Static Review Passed / Runner Build & Test Verified / Isolation Verified / Independent App Build Verified / B5 Final Acceptance Passed**。Runner run `43817618222`：`swift build` 成功、`swift test` 91 例 0 失败、隔离三向通过、App 模拟器构建启动存活；详见 §4C 与 `Tests/Stage2/evidence/run-43817618222/RUN-METADATA.md`。

## 1. 本轮授权边界

### 允许
1. 新增 INT-001~010 跨批次集成测试；
2. 实现 B3→B4 必要结果映射与 Pipeline 衔接；
3. 新增 Stage 1 fixture 深比较与确定性测试所需代码；
4. 必要时调整 `Package.swift` 测试接线；
5. 只读静态检查与代码审查。

### 禁止（本轮均未触碰）
1. 未修改 B1~B4 冻结行为与 Stage 1 基线（`Tests/Fixtures`、`Tests/S1-01~03` harness/报告零改动）；
2. 未修改七方法 Adapter 协议，未扩展 Models 冻结字段；
3. 未修改 RootHide / Rootless Adapter 既有隔离边界；
4. 未执行 Runner、独立构建或正式验收；
5. 未进入 2.2-C、插件枚举或 GUI 开发；
6. 未进行真机扫描、写入、插件启停。

## 2. 文件清单

| 类别 | 路径 | 说明 |
|---|---|---|
| Core 衔接 | `Core/PathResolver/Pipeline/JBRootToDirectoryBridge.swift` | B3 裁决结果 → B4 上游衔接输入的纯映射（内部结构 + 桥接器） |
| Core 衔接 | `Core/PathResolver/Pipeline/EnvironmentRouteMapper.swift` | B1 环境结果 → 路线信号纯函数映射（第三步新增） |
| Core 编排 | `Core/PathResolver/Pipeline/ElleKitDirectoryPipeline.swift` | 组合 B2/B3 编排器、桥接器、B4 编排器；输出四层证据复合结果 |
| 集成测试 | `Tests/Stage2/B5IntegrationTests.swift` | INT-001~010（10 例，附加，不计入 71） |
| 深比较测试 | `Tests/Stage2/B5FixtureComparisonTests.swift` | S1-01/B2 收集/B3 裁决/B4 目录四组夹具深比较（4 例） |
| 确定性测试 | `Tests/Stage2/B5DeterminismTests.swift` | 重复裁决确定 + 衔接输入 Codable 往返与编码稳定（5 例） |
| 接线 | `Package.swift` | Core 登记 2 个 Pipeline 源；Stage2Tests 登记 3 个 B5 测试源 |

未新增 Models 类型、未新增 Adapter、未新增服务协议实现。

## 3. 接口映射（B3 → 衔接层 → B4）

### 3.1 衔接输入结构 `ElleKitDirectoryPipelineInput`（Core 内部，Codable/Equatable）

| 字段 | 来源 | 规则 |
|---|---|---|
| `route: String?` | 显式 `environmentRoute` 优先；仅 `resolved` 场景由选中候选回填；否则 `nil` | 桥接层不猜测路线；`nil` 交 B4 按未知路线处理 |
| `jbroot: String?` | B3 `JBRootResolutionResult.jbroot` | 仅 `outcome == "resolved"` 且 jbroot 非空时转发；其余 outcome 一律 `nil` |
| `jbrootOutcome: String?` | B3 `outcome` 原样保留 | 证据保留，不向下游重新分类 |
| `ambiguous: Bool` | B3 `ambiguous` 原样保留 | 歧义不进入确认路径解析 |
| `warnings: [ReportWarning]` | B3 顶层告警原样保留 | 告警不丢失 |

### 3.2 三条硬规则落地位置

1. **不从任意候选重新挑选 JBROOT**：桥接只读取 B3 结果 `jbroot`；回填路线时按 `result.jbroot` 在 `candidates` 中定位选中候选，不遍历其它候选选边。
2. **ambiguous 不进入确认路径解析**：`ambiguous`（及其它非 `resolved` outcome）下 `jbroot` 置 `nil`，路线不回填；B4 收到未确认上游。
3. **B4 不补充/猜测 route**：路线只来自显式环境信号或已确认选中候选；未知留 `nil`，B4 `ElleKitPathDeriver` 未知路线返回 `nil`，不反推 `/var/jb` 或 `/`。

### 3.3 编排复合结果 `IntegratedDirectoryResolution`

| 层 | 类型 | 说明 |
|---|---|---|
| B3 | `JBRootResolutionResult` | 含全部候选证据与告警 |
| 衔接 | `ElleKitDirectoryPipelineInput` | 桥接后上游输入 |
| B4 | `ElleKitDirectoryResolution` | 目录/软链定位结果 |

`ElleKitDirectoryPipeline.resolve(jbrootSnapshot:directoryFs:environmentRoute:)` 为离线组合根：fs 信号由离线快照注入，不实例化具体 Adapter，不访问真实文件系统。

## 4. 测试映射

### 4.1 验证线 A：71 项冻结回归（原样保留，未重写、未并入）

| 测试文件 | 方法数 | 批次 |
|---|---:|---|
| `ModelsCodableTests.swift` | 21 | 2.2-A |
| `EnvironmentDetectionTests.swift` | 7 | B1 |
| `JBRootCandidateCollectionTests.swift` | 10 | B2 |
| `JBRootValidationTests.swift` | 18 | B3 |
| `ElleKitDirectoryTests.swift` | 15 | B4 |
| **合计** | **71** | — |

### 4.2 验证线 B：INT-001~010（`B5IntegrationTests.swift`）

| 编号 | 场景 | 夹具组合（B3 / B4） | 核心断言 |
|---|---|---|---|
| INT-001 | 有效 RootHide 候选 | rh-valid / rh-valid | B3 `resolved`；jbroot 转发；路线 roothide；B4 `resolved`；TI 路径 = 确认 jbroot + 后缀；DL targetMatch |
| INT-002 | 两个有效 RH 候选 | rh-multiple / rh-valid | `ambiguous`；jbroot/路线均 `nil`；B4 `unresolved`；无确认 TI 路径 |
| INT-003 | RH 无有效 JBROOT | rh-badname / rh-valid（envRoute roothide） | `no_candidate`；jbroot `nil`；B4 `unresolved`；不回退 `/var/jb` 或 `/` |
| INT-004 | Rootless 路线 | rootless-varjb / rootless-valid（envRoute rootless） | `cross_route_only`；jbroot `nil`；路线 rootless；B4 `resolved`；TI `/var/jb/usr/lib/TweakInject/` |
| INT-005 | Rootful 路线 | rootful-root / rootful-valid（envRoute rootful） | `cross_route_only`；B4 `rootful_diagnostic`；告警 `rootful_route_not_profile` |
| INT-006 | JBROOT 校验失败 | rh-badname / rh-valid（envRoute roothide） | jbroot `nil`；无确认 TI 路径；B4 `unresolved` |
| INT-007 | TI 不存在 | rh-valid / rh-missing | B4 `not_found`；TI 状态 `not_found`；告警 `directory_not_found` |
| INT-008 | DL 损坏软链 | rh-valid / rh-broken-link | 软链 `broken`；targetMatch false；告警 `symlink_broken`；B4 `partial` |
| INT-009 | 软链权限拒绝 | rh-valid / rh-target-denied | 软链 `denied`；targetMatch false；告警 `symlink_target_denied`；B4 `partial` |
| INT-010 | 未验证字段 | rh-valid + 手工 TI 信号（exists true，其余 nil） | exists=true；readable/enumerable/structureMatch 保持 `nil`；TI 状态 `partial` |

### 4.3 深比较（`B5FixtureComparisonTests.swift`）

| 用例 | 批次 | 比较维度 |
|---|---|---|
| `testS102CollectorDeepComparison` | B2 | 候选顺序/来源保留、路线映射、规范化路径非空 |
| `testS102FixturesDeepComparison` | B3 | outcome / jbroot / ambiguous / candidateCount / 告警集合 |
| `testS103FixturesDeepComparison` | B4 | route / tiPath / exists/readable/enumerable / tiStatus / dlState / targetMatch / outcome / 告警集合 |
| `testS101FixturesDeepComparison` | B1 | jailbreakType / 版本状态 / outcome |

### 4.4 确定性（`B5DeterminismTests.swift`）

| 用例 | 覆盖 |
|---|---|
| `testJBResolverDeterminism` | B3 同一快照重复裁决全等 |
| `testDirectoryResolverDeterminism` | B4 同一快照重复裁决全等 |
| `testPipelineDeterminism` | 跨批次 Pipeline 重复执行全等 |
| `testBridgeDeterminism` | resolved / ambiguous 两条桥接路径重复执行全等 |
| `testPipelineInputCodableRoundTripAndStableEncoding` | 衔接输入 Codable 往返全等；重复编码字节稳定 |
| `testEnvironmentRouteMapperCasesAndDeterminism` | B1 结果 → 路线五组口径（roothide/rootless/rootful/unknown/冲突）+ 冲突告警保留 + 重复映射确定 |

### 4.5 测试总数口径

- 冻结回归：21 + 7 + 10 + 18 + 15 = **71**（不可被新增测试替代）。
- B5 附加：INT **10** + 深比较 **4** + 确定性/映射 **6** = **20**。
- 当前测试总数预期 **91**（71 + 20）；为预期计数，非已通过数量。本机未编译未执行，Runner 阶段按分组出证。

## 4A. B5 第三步：Runner 前代码完善与静态审查（本轮，方案 B）

> 授权：Runner 前接口审查与必要小范围完善；不上传 Runner、不编译、不运行测试。

### 4A.1 接口缺口审查结论

| 审查项 | 结论 | 本轮处理 |
|---|---|---|
| AdapterResolver 接入边界 | 协议 `AdapterResolver` 已存在，无具体装配；B5 Pipeline 直接组合既有 resolver，离线信号注入，不实例化具体 Adapter | **不落地**具体装配；Core 不创建 RootHide/Rootless Adapter（隔离扫描通过）；服务装配归后续集成授权批次 |
| EnvironmentDetectionResult → route 映射 | 第二步 Pipeline 仅接受显式路线字符串，存在调用方传错风险 | 新增 `EnvironmentRouteMapper` 纯函数映射层；Pipeline 提供 `environment:` 生产入口重载 |
| Bridge 状态传递 | 六类非 resolved 均不得转发确认 jbroot | 复核通过：仅 `outcome == "resolved"` 且 jbroot 非空才转发；`partial/ambiguous/resolve_failed/cross_route_only/no_candidate` 一律 nil |
| Pipeline 编排纯度 | 只组合 B2/B3/B4 既有编排器，不重写业务规则，不访问文件系统 | 复核通过；环境告警、B3 告警、B4 告警分层保留 |
| 90 项测试接线 | 71 冻结 + 附加测试须全部登记 Package | 复核：71 未改；20 附加已登记（含本轮新增映射用例） |

### 4A.2 路线映射规则（`EnvironmentRouteMapper`，跟随 B1 冻结语义）

| B1 `jailbreakType` / outcome | 映射路线 |
|---|---|
| `roothide` | `roothide` |
| `rootless` | `rootless` |
| `rootful` | `rootful` |
| `unknown` | `nil` |
| `conflict_no_profile`（路线/实现冲突） | `nil`，B1 告警原样保留 |

- 不从文件路径、jbroot 格式、`/var/jb` 是否存在反推路线；不覆盖 B1 识别结论。
- Pipeline `environment:` 重载经映射推导路线；`environmentRoute:` 显式重载保留为低层组合入口，生产链路优先前者。

### 4A.3 本轮新增/改动文件

| 路径 | 说明 |
|---|---|
| `Core/PathResolver/Pipeline/EnvironmentRouteMapper.swift`（新增） | B1 结果 → 路线信号纯函数映射 |
| `Core/PathResolver/Pipeline/ElleKitDirectoryPipeline.swift`（改动） | 新增 `environment:` 重载；复合结果补 `environmentWarnings` 分层证据 |
| `Tests/Stage2/B5DeterminismTests.swift`（改动） | 新增路线映射口径与确定性用例 |
| `Tests/Stage2/B5IntegrationTests.swift`（改动） | INT-004/005 改用 `environment:` 生产入口；补环境结果构造辅助 |
| `Package.swift`（改动） | 登记 mapper Core 源 |

### 4A.4 Runner 前仍待 Runner 阶段处理（本轮不做）

- CI `test` Job 当前为整包 `swift test`，未分阶段 `--filter` 出证；Runner 阶段按规格 §3.1 分六组（21/7/10/18/15）+ 附加三组（10/4/6）分别执行并归档日志。
- 编译、测试执行、独立 App Build、隔离脚本实跑、证据归档与 B5 正式验收，待下一次单独授权。

## 4B. Runner 首次构建失败与编译错误修复（本地静态，未重跑 Runner）

### 4B.1 失败归属

- Runner 提交：`3c8154a30f744cdc4aaa73b2fda91df4637f2f01`（build Job，macos-26-arm64，Xcode 26.6 / MacOSX 26.5 SDK）；`swift build` 退出码 1。
- 失败范围：仅 Core B3 两个文件的 **Swift 语法写法**，非规则/行为差异；B5 新增 `ElleKitDirectoryPipeline` / `EnvironmentRouteMapper` / `JBRootToDirectoryBridge` 在日志中均通过编译进入 `Emitting module Core`，未报错误。
- 归属分类（按规格 §5 失败归属表）：B3 源码语法问题；未改 B1/B2/B4 业务规则、Models 冻结字段、七方法协议与 Stage 1 基线。

### 4B.2 修复清单

| 文件 | 行 | 报错 | 修复 | 语义影响 |
|---|---|---|---|---|
| `Core/PathResolver/JBRoot/JBRootDecisionResolver.swift` | 126 | `contains({ ... })` 缺少参数标签 `where:` | 改为 `contains(where: { ... })` | 无：谓词与裁决条件不变 |
| `Core/PathResolver/JBRoot/JBRootNameValidator.swift` | 29 | 自由函数 `index(after:)` 被解析为 C 库 `index()`，下标类型不匹配 | 改为 `trimmed[trimmed.index(after: slash)...]` | 无：仍取最后一个 `/` 之后片段，basename 口径不变 |

### 4B.3 位置与接线复核

- 磁盘 Core 20 个 Swift 文件、Tests/Stage2 8 个测试文件、Adapters 3 个源、Models 5 个源，与 `Package.swift` 显式/自动登记逐一核对一致；本轮无文件/目录移动。
- 全量扫描：其余 `contains` 均为元素判断或已带 `where:`；无其它裸 `index(after:)` 调用。
- 限制：本机无 Swift 工具链，修复后未本地编译；Core 模块能否成功 Emitting、测试目标能否编译，待下一次 Runner/独立构建验证。

## 4C. Runner 集中验收通过（run 43817618222，2026-11-16）

### 4C.1 验收快照

- Runner SHA：`7fc5d530ed9650dea483204874f196fc468bea0e`；run `43817618222`；macOS 26.7.2（25G332）/ Xcode 26.6（17F113）/ Swift 6.3.3 / iOS 26.5 SDK；Testing Library 1902。
- 证据目录：`Tests/Stage2/evidence/run-43817618222/`（六 Job 分步日志、test-log、app-build 日志+截图、metadata 快照、`RUN-METADATA.md`）。
- 4B 两处语法修复在本轮 build 中编译通过；`JBRootDecisionResolver.swift`、`JBRootNameValidator.swift` 均进入编译队列无报错。

### 4C.2 §8 门槛逐项结论

| 验收项 | 结果 | 证据 |
|---|---|---|
| 71 项冻结回归 71/71，分套件出证 | ✅ | ModelsCodable 21 / EnvironmentDetection 7 / JBRootCandidateCollection 10 / JBRootValidation 18 / ElleKitDirectory 15，各套件 0 failures |
| Stage 1 原始行为无未解释差异 | ✅ | 深比较 4 例对 S1-01/02/03 夹具与 metadata 基线全过；夹具/harness/报告零改动 |
| Codable 兼容 §5 八项 | ✅ | 由 Models/B3/B4 Codable 往返、三态与软链五态用例覆盖，全过 |
| 三态语义无 `nil → false` | ✅ | `testThreeStateBitsNotCoerced`、`testThreeStatePreservedAndRouteCoverage`、INT-010 全过 |
| B2→B3→B4 集成 INT-001~010 | ✅ | `B5IntegrationTests` 10/10 |
| 隔离三向 | ✅ | RH 不引 Rootless；RL 不引 RootHide；Core 不实例化具体 Adapter，脚本三项 OK |
| Core 抽象依赖 | ✅ | Core 无 `RootHideAdapter()/RootlessAdapter()` 实例化 |
| Core Build 成功 | ✅ | `Build complete! (7.78s)`，0 error，Models/Adapters/Core 均 emit |
| App Build 成功并存活 | ✅ | `** BUILD SUCCEEDED **`；iPhone 17 Pro 启动 PID 3571，存活复查一致；截图 1206×2622 RGBA，中文渲染正常 |
| Runner 证据完整归档 | ✅ | 本轮 evidence 目录归档六 Job 日志、测试日志、App 产物日志与截图、metadata |
| Git 追溯 | ✅ | runner SHA 入档；metadata 快照与本地一致；B3 锚点 `3e878cb`、B4 `6bbd64f` 在链；71 冻结测试方法数未增删改 |

### 4C.3 测试总账

- 冻结回归 **71/71**；B5 附加 **20/20**（INT 10 + 深比较 4 + 确定性/映射 6）；总计 **91 tests, 0 failures (0 unexpected)**，0 skipped、0 error。
- 测试命令为整包 `swift test`，未分阶段 `--filter`；日志按 Test Suite 分别出计数与结果，符合规格 §7 口径。

### 4C.4 验收后仍不宣布的结论（沿用规格 §9）

- App Build 仅证明工程构建与基础启动，不证明越狱目录访问权限；模拟器/离线通过不代表真机兼容。
- 隔离为静态文本 + 编译层核对，运行时隔离留后续阶段。
- `AdapterResolver` 具体装配、两服务接入、B1 完整字段向服务装配的传递不在 B5；未进入 2.2-C；Rootless 真机兼容、GUI 权限、注入、插件启停均未验证。

## 5. 变更审计（静态）

- `git status` 变更面：`Package.swift` + 2 个 Core Pipeline 文件 + 3 个 B5 测试文件；`Models/`、`Adapters/`、`Tests/Fixtures/`、Stage 1 harness/报告零改动。
- 71 项冻结测试方法数复核：21 / 7 / 10 / 18 / 15 = 71，未增删改。
- 隔离扫描：新 Core 文件仅 `import Foundation / Models`；未实例化 `RootHideAdapter()/RootlessAdapter()`；未引用具体 Adapter 类型。
- 括号配平：5 个新 Swift 文件 `{}` / `()` 差值均为 0（静态文本核对，非编译期校验）。
- 未改：七方法协议、Models 既有字段/枚举原始值、B1~B4 裁决规则、Adapter 隔离边界。

## 6. 未解决问题与延后事项

1. **AdapterResolver 与服务装配**：具体实现、两服务接入与 GUI 选择 Adapter 不在 B5；本轮确认 Pipeline 不实例化具体 Adapter，装配归后续集成授权批次。
2. **B1→Pipeline 路线映射（已补齐，待 Runner 复核）**：新增 `EnvironmentRouteMapper` 与 `environment:` 重载；映射规则跟随 B1 冻结语义，冲突/未识别返回 nil。`EnvironmentDetectionResult` 完整字段（架构/版本/Profile）向服务装配的传递仍随装配批次。
3. **B3 `partial` 口径**：按规格 §3.3，唯一 eligible 但非 confirmed 的 `partial` 不向下游注入确认 jbroot；该口径在 Runner 回归时随 S1-02 夹具一并复核。
4. ~~编译与执行未验证~~（已由 run `43817618222` 复验：`swift build` 成功，`swift test` 91 例 0 失败；见 §4C）。
5. ~~Runner 集中验收延后~~（已完成：71 冻结回归 + INT/深比较/确定性附加 20 例、隔离三向、Core 抽象依赖、独立 App Build 与证据归档均通过，见 §4C）。
6. **既有观察项沿用**：Deployment Target、Bundle ID 占位、SwiftUI 编译渲染层、reference 旧 PoC 与设备私有报告入库决策、Theos 16.5 SDK 兼容、Rootless 无真机等，保持原观察项记录，不在本轮闭环。
