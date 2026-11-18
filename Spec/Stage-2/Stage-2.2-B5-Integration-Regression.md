# Stage-2.2-B5-Integration-Regression.md — B5 Core/Models 集成回归与独立构建验收规格（冻结）

> 状态：**验收规格冻结（设计层）**。本批次第一步仅完成只读审计与规格冻结；**不修改 B1~B4 源码、不运行 Runner、不执行构建、不进入 2.2-C**。集成测试编写、Pipeline 装配与 Runner 执行须在本规格冻结后单独授权。
> 定位：B5 不增加功能，目标是证明 B1~B4 已实现功能在当前工程中完整编译、71 项冻结回归全绿、与 Stage 1 原始行为无未解释差异、跨批次组合无接口/状态传递错误、双 Adapter 隔离保持。
> 上游基准：`Stage-2.2-B-Data-Contract-Freeze.md`（D1~D12）、`Stage-2.2-B-Environment-Path.md` §8/§9、`Stage-2.2-Core-Models-Migration.md` §6/§11；Stage 1 基线 `Tests/S1-01~03` 的 `resolver.js`/`detector.js`、`run.js`、`report/*.json` 与 `Tests/Fixtures/S1-01~03/`（只读，禁止改动）。

## 1. 审计快照（2026-11-16，开工前只读核对）

### 1.1 源码与测试清单（以仓库现状为准，不采用附件示意目录名）

| 层 | 文件 | 说明 |
|---|---|---|
| Models（5） | `EnvironmentAdvisor.swift`、`EnvironmentModels.swift`、`ModelEnums.swift`、`PluginModels.swift`、`ReportEnvelope.swift` | 公共模型，无路线依赖 |
| Adapters（3） | `ElleKitAdapter.swift`（七方法协议）、`RootHide/RootHideAdapter.swift`、`Rootless/RootlessAdapter.swift` | 双路线桩实现；路线规则封闭在 Adapter 内 |
| Core Environment（3） | `EnvironmentSnapshot.swift`、`VersionParser.swift`、`EnvironmentDetector.swift` | B1 环境识别 |
| Core JBRoot（7） | `JBRootCandidateSnapshot/Collector/NameValidator/StatusClassifier/Validator/DecisionResolver/Resolver.swift` | B2 收集 + B3 校验裁决 |
| Core ElleKit（6） | `ElleKitDirectorySnapshot/PathDeriver/DirectoryValidator/SymlinkInspector/DirectoryResolution/DirectoryResolver.swift` | B4 目录/软链定位 |
| Core 服务轮廓 | `CoreServices.swift`：`EnvironmentService / PathResolutionService / PluginScanService / PluginParseService / OwnershipService / ReportExportService / AdapterResolver` | 仅协议；无具体装配类 |
| Stage2 测试（5） | `ModelsCodableTests.swift`、`EnvironmentDetectionTests.swift`、`JBRootCandidateCollectionTests.swift`、`JBRootValidationTests.swift`、`ElleKitDirectoryTests.swift` | 71 项冻结回归 |

### 1.2 71 项冻结回归映射（逐阶段，不可合并计数）

| 部分 | 测试文件 | 方法数 | 阶段 | Stage 1 基准 |
|---|---|---|---|---|
| B5-1 | `ModelsCodableTests.swift` | 21 | 2.2-A Codable | 模型往返/枚举原始值/旧 JSON 兼容 |
| B5-2 | `EnvironmentDetectionTests.swift` | 7 | B1 环境识别 | S1-01 15 ENV 口径 |
| B5-3 | `JBRootCandidateCollectionTests.swift` | 10 | B2 候选收集 | S1-02 收集层 |
| B5-4 | `JBRootValidationTests.swift` | 18 | B3 校验裁决 | S1-02 18 项 |
| B5-5 | `ElleKitDirectoryTests.swift` | 15 | B4 目录/软链 | S1-03 15 项 |
| **合计** | — | **71** | — | 48 为 Stage 1 原始行为基线数量（ENV/PATH/DIR），与 Swift 回归总数口径不同，不可混用 |

> 附件建议的 `B5IntegrationTests / B5FixtureComparisonTests / B5DeterminismTests` 为示意结构；实际新增测试文件名以执行授权时仓库现有组织为准，不重复创建已存在的测试。

### 1.3 提交链追溯（线性祖先已核对）

| 阶段 | 提交 | 说明 |
|---|---|---|
| B1 落地 | `ad24c15` | 环境识别本地落地 |
| B1 修复 | `148b58a`、`175e27f` | build/test 失败修复 |
| B1 runner 归档 | `2ed2380` | run-43793314782，28 例 0 失败 |
| B2 落地 | `035db7f` | 候选收集本地落地 |
| B2 微调 | `a3a8c7a` | 精确重复先判重再告警 |
| B2 runner 归档 | `bde210c` | run-118584150452，38 例 0 失败 |
| B3 代码冻结 | `3e878cb` | B3 校验裁决本地落地（B5 追溯锚点） |
| B3 归档 | `8043372`、`1803c2e` | 本地验收归档与补记 |
| B4 开工锚点 | `1803c2e` | B4 开工前工作区 |
| B4 代码冻结 | `6bbd64f` | B4 目录/软链本地落地 |
| B4 归档补记 | `4d0a165` | 补记冻结点；归档间源码无变动 |

- 已核对：`3e878cb` 是 `6bbd64f` 的线性祖先；`git diff 3e878cb..6bbd64f` 变更范围为 B4 六个 Core 文件、Models 纯追加两结构、Package 接线、B4 测试与规格/记录文档；未触及 B2/B3 源码、Adapters、Stage 1 基线。
- B5 须证明：B3 锚点 `3e878cb` 入链；B4 未改 B3 六态优先级；B4 未改 B2 收集规则（顺序/去重/多来源保留/未知告警）。

### 1.4 Stage 1 基线完整性（只读未改）

| 基准 | harness | 夹具组数 | 报告口径 |
|---|---|---|---|
| S1-01 | `detector.js` / `run.js` | 6 | 15/15，0 失败 |
| S1-02 | `resolver.js` / `run.js` | 10 | 18/18，0 失败 |
| S1-03 | `resolver.js` / `run.js` | 11 | 15/15，0 失败；三路线覆盖；fallbackLeakCount=0；layerViolationCount=0 |

自 `bde210c` 以来 `Tests/S1-01~03`、`Tests/Fixtures/S1-01~03` 无改动。

### 1.5 CI 能力现状（`.github/workflows/filterkit-build.yml`，手动触发）

现有六个 Job：`environment`（工具链版本记录）→ `build`（`swift build` 非界面层）→ `test`（整包 `swift test`）→ `isolation`（隔离脚本）→ `app-build`（xcodegen → xcodebuild iOS Simulator → 安装启动 → 存活复查 + 截图）→ `artifact`（元数据归档）。

- 现状缺口：`test` Job 执行整包 `swift test`，**未按 B5-1~B5-5 分阶段过滤出证**；B5 执行时须补充分阶段 `--filter` 记录（测试类名以仓库实际为准）。
- 本机 Linux 无 `swift`/`swiftc`/`xcodebuild`，本机结论只作静态核对，不作为编译/测试通过证据。

## 2. B5 验收六部分

| 部分 | 验收内容 | 通过条件 | 计入 71 |
|---|---|---|---|
| B5-1 | Models / Codable | 21/21，旧 JSON 缺可选字段可解码，nil 与 false 严格区分 | 是 |
| B5-2 | Environment | 7/7，五态/冲突/未安装口径与 S1-01 一致 | 是 |
| B5-3 | JBROOT Candidate Collection | 10/10，候选数量/顺序/来源/路线/规范化/去重与 S1-02 收集层一致 | 是 |
| B5-4 | JBROOT Validation / Decision | 18/18，命名校验/校验位/六态/多候选裁决/三态证据与 S1-02 一致 | 是 |
| B5-5 | ElleKit Directory / Symlink | 15/15，路径推导/目录四态/软链五态/六档裁决优先级/证据层级与 S1-03 一致 | 是 |
| B5-6 | 集成、隔离、独立构建 | 跨批次集成场景全过；三向隔离通过；Core 经抽象依赖；`swift build` 成功；App Build 成功并存活 | 否（附加验收） |

前五部分为 71 项冻结回归；第六部分为附加集成验收，**不得把 71 项改成 81 项**。

## 3. 两条验证线

### 3.1 验证线 A：逐批次回归

`ModelsCodableTests → EnvironmentDetectionTests → JBRootCandidateCollectionTests → JBRootValidationTests → ElleKitDirectoryTests`，每层独立运行并保留结果；不允许只看总套件 `Executed 71 tests, 0 failures` 即宣称通过。

### 3.2 验证线 B：跨批次集成（附加，不计入 71）

组合链：Environment → B2 Candidate Collection → B3 Validation & Decision → B4 Directory Resolution → Integrated Result。重点核对：

- 输入输出类型匹配；证据正确传递；未确认状态保留；告警不丢失；路线不发生错误切换；相同输入确定性可重复。

建议集成场景（INT-001~010，执行时以现有真实接口落地，不为示意代码重构冻结 Core）：

| 编号 | 输入场景 | 预期 |
|---|---|---|
| INT-001 | 一个有效 RootHide 候选 | B3 确认 JBROOT，B4 据确认 jbroot 推导目录路径 |
| INT-002 | 两个有效 RootHide 候选 | B3 `ambiguous`，不选边；B4 不得擅自选用任一候选 |
| INT-003 | RootHide 候选不存在 | B4 不得回退 `/var/jb` 或 `/` |
| INT-004 | Rootless 路线 | 使用独立 `/var/jb` 路径，不混入 RootHide 规则 |
| INT-005 | Rootful 路线 | 仅诊断参照，不获得管理 Profile 资格 |
| INT-006 | JBROOT 校验失败 | 不生成已确认的 TweakInject 路径 |
| INT-007 | TweakInject 不存在 | 保留 `not_found`，不升级为可读/可枚举 |
| INT-008 | DynamicLibraries 软链损坏 | 保留 `broken` 状态与 `symlink_broken` 告警 |
| INT-009 | 软链权限拒绝 | 保留 `denied` 状态与 `symlink_target_denied` 告警 |
| INT-010 | 未验证字段 | 三态位保持 `nil`，不得变成 `false` |

### 3.3 现状衔接面（执行时核对，不在审计阶段改码）

- B2：`JBRootCandidateCollector.collect(_: JBRootCandidateSnapshot) -> JBRootCandidateCollectionResult`。
- B3：`JBRootResolver.resolve(_: JBRootCandidateSnapshot) -> JBRootResolutionResult`；结果字段 `jbroot / jbrand / realpath / ambiguous / outcome / selectedSource / candidateCount / candidates / warnings`。
- B4：`ElleKitDirectoryResolver.resolve(_: ElleKitDirectorySnapshot) -> ElleKitDirectoryResolution`；快照 `upstream { route, jbroot }`，结果 `route / tweakInject / dynamicLibraries / dynamicLibrariesPath / outcome / warnings`。
- **衔接缺口（执行授权时界定）**：B3 结果无顶层 `route` 字段，路线保留在 `candidates[].route`；B4 上游需 `route + jbroot`。集成映射须明确：`jbroot` 取自 B3 确认结果；`route` 取自环境或选中候选；B3 非 `resolved`（ambiguous / no_candidate / partial / 拒绝 / 失败）时不得向 B4 注入已确认 jbroot。
- **装配范围待授权**：现有 Core 仅有服务协议与桩 Adapter；`AdapterResolver` 具体实现与两服务装配是否在 B5 落地，须在执行授权时单独拍板。本规格不默认 B5 新增 Pipeline 服务类，也不借集成测试扩大功能范围。

## 4. Stage 1 Fixture 深比较（行为基准，不另写一套预期）

以原始 fixture + 原始预期为基准，Swift 实现输出与之比较；不得为通过而修改 fixture、`resolver.js`/`detector.js` 或原始预期。

| 批次 | 必比维度 |
|---|---|
| B1 | 环境识别结果、版本状态、冲突状态、未安装状态、证据等级 |
| B2 | 候选数量、候选顺序、来源保留、路线映射、规范化路径、重复项去重 |
| B3 | 命名校验、校验位、六态分类、多候选裁决、三态证据 |
| B4 | 路径推导、目录四态、软链五态、六档裁决优先级、证据层级、RootHide/Rootless 路线隔离 |

B4 六档裁决顺序（不可调换）：`unresolved → not_found → structure_conflict → rootful_diagnostic → resolved → partial`。

## 5. JSON / Codable 兼容核对

1. 旧 JSON 缺少新增 Optional 字段时可正常解码；
2. 新增字段为 `nil` 时正确表达，不补空串/默认值；
3. `nil` 与 `false` 严格区分；
4. `PathLocationEvidence` 往返全等；
5. `SymlinkEvidence` 往返全等；
6. `targetMatch` 独立保留，不并入五态；
7. 五态软链状态使用冻结原始值 `resolved / broken / loop / denied / not_symlink`；
8. 目录状态（D9 `status`）与 `EvidenceLevel` 独立保存，互不替代。

## 6. 架构隔离核对（三向，沿用 `scripts/check-adapter-isolation.sh`）

1. `RootHideAdapter` 不引用 Rootless 类型/规则（`Rootless|rootless|UpstreamElleKit`）；
2. `RootlessAdapter` 不引用 RootHide 类型/规则（`RootHide|roothide|jbroot()|RootHideProfile`）；
3. Core 不直接实例化具体 Adapter（`RootHideAdapter()` / `RootlessAdapter()`），仅经 `ElleKitAdapter` 抽象协议；
4. 路线差异留在 Adapter；Core 共享模型、服务接口与业务流程，不混合双路线路径判断。

- 脚本为静态文本检查（先剥注释再扫描），不能替代编译期依赖分析；B5 执行时与 `swift build` 配合复核，并覆盖 B3/B4 新增文件。
- 运行时隔离属后续阶段，本批次只做静态 + 编译层核对。

## 7. Runner 执行顺序与证据归档

建议 Job 顺序（对齐现有 workflow，失败按 Job 独立归因）：

`Environment（工具链）→ Core Build（Models/Adapters/Core 编译）→ Regression（71 项分阶段）→ Fixture Comparison（Stage 1 深比较 + 确定性）→ Architecture Isolation（三向 + Core 抽象依赖）→ Independent App Build（模拟器构建/启动/存活/截图）→ Evidence Archive`。

- Core Build 或回归失败时，不得把后续 App Build 失败简单归为 B5 集成问题；每个 Job 独立状态。
- 测试命令以 `Package.swift` 实际 testTarget 为准；分阶段过滤类名以仓库实际测试类型为准（附件 `--filter` 名为示意）。
- 证据：分阶段测试日志、深比较结果、隔离脚本输出、`swift build` 日志、App 构建日志、启动存活记录、截图、runner 元数据，统一归档到 `Tests/Stage2/evidence/` 对应轮次目录。

## 8. 最终验收门槛

| 验收项 | 通过条件 |
|---|---|
| 71 项冻结回归 | 71/71，分阶段出证 |
| Stage 1 原始行为 | 无未解释差异 |
| Codable 兼容 | 第 5 节 8 项全过 |
| 三态语义 | 无 `nil → false` |
| B2 → B3 → B4 集成 | INT-001~010 全过 |
| RootHide / Rootless 隔离 | 三向通过 |
| Core 抽象依赖 | 不实例化具体 Adapter |
| Core Build | 成功 |
| App Build | 成功（仅证明工程构建与基础启动） |
| Runner 证据 | 完整归档 |
| Git 追溯 | 提交链完整，B3 锚点入链，冻结代码未被集成过程悄悄修改 |

## 9. 边界与不得宣布的结论

- B5 不重写 B1~B4 实现；发现缺陷时：保留失败证据 → 定位所属批次 → 记录问题 → 单独评审修复范围 → 修复后重跑受影响测试 → 重跑完整 71 项回归；不得为通过而修改 Stage 1 原始基线。
- B5 不进入 2.2-C（插件枚举/配对/解析），不做真机写入、软链增删、注入配置修改、插件启停、dpkg 改动、GUI 私有扫描器/权限探针。
- App Build 成功只证明工程构建与基础启动，**不证明** RootHide GUI 具备越狱目录访问权限；离线/模拟器通过不代表真机兼容。
- B5 通过后方可宣布：Stage 2.2-A 完成、Stage 2.2-B1~B5 完成、Core/Models Migration 达到 B5 验收标准。
- B5 通过后仍**不得**宣布：RootHide GUI 权限已验证、Rootless 真机兼容、插件已成功注入、插件启停功能可用（属后续阶段）。

## 10. 本批次（规格冻结）未执行项

- 未编写集成测试与 Pipeline 装配代码；未改动 B1~B4 源码、Models 冻结面、七方法协议、Stage 1 基线与夹具；
- 未运行 Runner、未执行 `swift build`/`swift test`、未做独立 App Build；
- 待执行授权后：按 §3.2 落地集成测试、按 §7 顺序在 runner 取证、按 §8 门槛回填验收结论。
