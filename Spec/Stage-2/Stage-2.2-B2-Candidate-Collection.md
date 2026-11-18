# Stage-2.2-B2-Candidate-Collection.md — B2 JBROOT 候选收集落地记录

> 状态：**runner 验收通过**（run-118584150452：build 通过、38 例测试 0 失败、隔离三向 OK、App 构建启动存活截图归档；见 §6）。
> 授权：用户授权执行 Stage 2.2-B2（JBROOT Candidate Collection）；严格依据 `Stage-2.2-B-Data-Contract-Freeze.md`（D4/D5/D6/D7/D8）、`Stage-2.2-B-Environment-Path.md` §9 B2 行与 S1-02 原始行为基线（`Tests/S1-02/resolver.js`、`run.js`、`report/S1-02-report.json`）。
> 边界：不改 `ElleKitAdapter` 七方法协议；不进入 B3/B4/B5 与 2.2-C；不改 Stage 1 Fixtures/harness/报告；不做真机写入、插件启停或 GUI 权限探测。

## 1. 授权范围

| 允许落地 | 落点 |
|---|---|
| `JBRootValidationBits` 三态校验位结构（G-B2 §4.1，D6） | `Models/EnvironmentModels.swift` |
| `JBRootCandidate` 候选结构（G-B2 §4.2，D4/D5/D7） | `Models/EnvironmentModels.swift` |
| `PathEvidence` 权威候选详情 `jbrootCandidateDetails` + 派生投影 `jbrootCandidates`（D8 双字段过渡） | `Models/EnvironmentModels.swift` |
| 候选信号快照 `JBRootCandidateSignal / JBRootCandidateSnapshot` | `Core/PathResolver/JBRoot/JBRootCandidateSnapshot.swift` |
| 候选收集器 `JBRootCandidateCollector`（规范化/来源/路线/顺序/去重/未知告警） | `Core/PathResolver/JBRoot/JBRootCandidateCollector.swift` |
| S1-02 收集层 Swift 回归 | `Tests/Stage2/JBRootCandidateCollectionTests.swift` |

| 禁止项 | 执行情况 |
|---|---|
| 最终候选裁决 / 提前确认 JBROOT（六态终判、jbrand、selectedSource、outcome） | ✅ 未实现；候选 `status` 留 `nil`，结果不携带选中结论 |
| 命名/存在/结构/可读/realpath 校验裁决（归 B3） | ✅ 未实现；`nameValid` 留 `nil`；其余位只原样记录夹具信号事实 |
| 修改七方法协议 | ✅ 未改 `ElleKitAdapter` |
| 进入 B3 校验裁决 / B4 目录软链定位 / B5 Pipeline 集成 | ✅ 未触碰；未注册新的 Core 服务协议 |
| 修改 Stage 1 Fixtures / harness / 报告 | ✅ 未改；测试只读引用 `Tests/Fixtures/S1-02/` |
| 真机写入、插件启停、GUI 文件扫描、权限探针 | ✅ 未接入 |
| 2.2-A 既有 21 例 Codable / B1 既有 7 例环境识别回归被破坏 | ✅ runner 回归保持 0 失败（21 + 7）；新增字段可选 + 旧 JSON 兼容解码 |

## 2. Models 落地（契约 §4）

### 2.1 `JBRootValidationBits`（D6 三态）

- 字段：`nameValid: Bool?`、`exists: Bool?`、`structureMatch: Bool?`、`readable: Bool?`、`realpath: String?`；不含 `checksumValid`（契约 §10.1 暂缓）。
- 三态口径：`true`=已验证通过、`false`=已验证失败、`nil`=未验证；未验证不填 `false`。
- B2 收集阶段：`exists / structureMatch / readable / realpath` 原样记录信号已提供事实；`nameValid` 命名校验归 B3，一律 `nil`。

### 2.2 `JBRootCandidate`（D4/D5/D7）

- 字段：`path: String`、`source: String`、`route: String`、`validation: JBRootValidationBits`、`status: String?`、`warnings: [ReportWarning]`。
- `source` 原样保留原始来源串；已知集 `api / scan / bootstrap / rootless / rootful`；非已知值不映射、不丢弃，附 `unknown_candidate_source` 告警。
- `route` 封闭集 `roothide / rootless / rootful`；未知来源不反推路线，`route` 保守留空串。
- `status` 六态（`confirmed / partial / cross_route / rejected_invalid / rejected_missing / resolve_failed`）由 B3 裁决填充；B2 为 `nil`；`pending` 仅内部初始态，不导出。

### 2.3 `PathEvidence` 双字段过渡（D8）

- 权威：`jbrootCandidateDetails: [JBRootCandidate]`；投影：`jbrootCandidates: [String]`，由权威结构 `path` 派生，构造点同步。
- 解码兼容：旧信封仅含 `jbrootCandidates` 投影时，权威列表解码为 `[]`，投影保留，不报错、不补候选；新信封两字段同源派生。
- 既有 `tweakInject / dynamicLibraries` 字段名称、类型、解码行为不变。

## 3. Core 收集器（离线只读，无文件系统访问）

### 3.1 输入快照

- `JBRootCandidateSignal`：`root / source / exists / structureMatch / readable / realpath / symlinkState` 中性载体；信号缺失按未提供处理。
- `JBRootCandidateSnapshot`：`fixtureId / fixtureKind / signals.candidates`，对齐 S1-02 `environment.json` 解码形态。

### 3.2 收集规则（对齐 resolver.js 收集口径）

1. **顺序保留**：候选按夹具/信号输入顺序归集，不在收集层排序兜底。
2. **词法规范化**（PATH-004，纯字符串）：折叠重复分隔符 `/`；解析 `.` / `..`（超出根停在根，不越界）；去尾斜杠；空串/空路径返回 `nil` 并附 `candidate_path_invalid` 告警、不入库；纯根返回 `/`。规范化结果不代表路径已存在或可解析。
3. **来源 → 路线映射**：`rootless→rootless`、`rootful→rootful`、`api/scan/bootstrap→roothide`；未知来源 `route=""` + `unknown_candidate_source` 告警（原始来源串在 `source` 保留）。
4. **去重**：同一规范化路径 + 同一来源的精确重复条目只保留首条，重复条目附 `duplicate_candidate_removed` 告警；**同一路径来自不同来源时两条均保留**，不丢弃第二来源证据。
5. **校验位记录**：信号提供的存在/结构/可读/realpath 事实入 `validation`；`nameValid` 未验证留 `nil`；`status` 未裁决留 `nil`。
6. **告警**：统一 `[ReportWarning] {code,message,sourceStage}`（D3）；按 `code + message` 去重，保留不同原始来源串。

### 3.3 结果结构

- `JBRootCandidateCollectionResult { candidates: [JBRootCandidate], warnings: [ReportWarning] }`，`candidateCount` 为派生计数；不携带 `jbroot / jbrand / realpath(选中) / ambiguous / outcome / selectedSource` 等裁决字段（归 B3）。

## 4. 测试映射（S1-02 收集层；只读夹具）

| 测试方法 | 基线用例 | 核对维度 |
|---|---|---|
| `testFixtureCandidateCollection` | PATH-001/002/003/005/006/007/008/009/010 十组夹具 | 候选数量（对齐基线 `candidateCount`）、输入顺序、`source` 原样保留、`route` 映射、规范化路径、校验位事实镜像、`nameValid/status` 留空、D8 投影一致 |
| `testFiveKnownSourcesCovered` | 五种来源覆盖核对 | 夹具并集来源 == `api/scan/bootstrap/rootless/rootful` |
| `testPATH004LexicalNormalization` | PATH-004 | `.`/`..`/重复分隔符/尾斜杠/纯根/越界边界 |
| `testPATH011Determinism` | PATH-011 | 相同输入重复收集结果确定（Equatable 全等） |
| `testPATH012IdMismatchDoesNotAffectCollection` | PATH-012 | metadata/environment ID 不一致不影响收集 |
| `testUnknownSourcePreservedAndWarned` | D7 未知来源样例 | 原始来源保留、路线不反推、未知告警 |
| `testMultiSourceSamePathRetainedAndExactDuplicateDropped` | 去重/多来源 | 同路径不同来源保留；精确重复去重 + 告警 |
| `testInvalidPathWarnedAndSkipped` | 异常分类（收集层） | 空/非法路径告警且不入库 |
| `testCandidateCodableRoundTrip` | G-B2 模型往返 | 候选结构 Codable 编码/解码全等 |
| `testLegacyPathEvidenceDecodesProjectionOnly` | D8 旧 JSON 兼容 | 仅投影字段解码不报错、权威列表为空 |

> B3 范围（命名合法性、exists/structure/readable/realpath 终判、六态、歧义/仅跨路线/无候选裁决）不在本批次测试内；B5 再做 48 项深比较与 21 Codable + 7 环境识别复跑。

## 5. 变更文件清单（本批次）

| 文件 | 变更 |
|---|---|
| `Models/EnvironmentModels.swift` | 增补 `JBRootValidationBits`、`JBRootCandidate`；`PathEvidence` 增补 `jbrootCandidateDetails` 权威字段与派生投影、自定义 Codable 兼容旧信封 |
| `Core/PathResolver/JBRoot/JBRootCandidateSnapshot.swift` | 新增：候选信号与快照解码载体 |
| `Core/PathResolver/JBRoot/JBRootCandidateCollector.swift` | 新增：规范化、来源/路线映射、顺序保留、多来源保留、精确重复去重、未知来源告警 |
| `Tests/Stage2/JBRootCandidateCollectionTests.swift` | 新增：S1-02 收集层回归 + 未知来源/去重/兼容用例 |
| `Package.swift` | Core 源纳入两个 JBRoot 文件；Stage2Tests 纳入 `JBRootCandidateCollectionTests.swift` |

未变更：`Adapters/`（七方法协议与 Adapter 实现）、`Core/CoreServices.swift`（服务协议）、`Tests/S1-02/` 基线与报告、`Tests/Fixtures/S1-02/`、2.2-A / B1 既有测试文件语义。

## 6. CI 证据（run-118584150452，验收通过）

仓库 `yi-fen/007` @ `1fb25e295a79195114f82d376b770ba058dd0511`；Xcode 26.6（17F113）、Swift 6.3.3、iOS SDK 26.5、Testing Library 1902；明细见 `Tests/Stage2/evidence/run-118584150452/RUN-METADATA.md`。

| Job | 门禁 | 结果 |
|---|---|---|
| environment | Xcode / Swift / SDK 版本记录 | ✅ 无 error |
| build | Models / Adapters / Core 编译通过 | ✅ `Build complete! (6.33s)`，两个 JBRoot 源文件均编译 |
| test | 21 Codable + 7 环境识别 + B2 收集层用例 0 失败 | ✅ **Executed 38 tests, 0 failures**（21 + 7 + 10） |
| isolation | 双 Adapter 隔离三向 OK；Core 不实例化具体 Adapter | ✅ 三向 OK |
| app-build | App Target 构建 + 模拟器启动存活（只读骨架） | ✅ `** BUILD SUCCEEDED **`；PID 9011 存活一致；截图 1206×2622 |
| artifact | 日志/截图/元数据归档 | ✅ build-metadata（14197418118）、test-log（14196922850）上传成功 |

## 7. 边界与遗留

- B2 结论仅为候选集合；候选路径不构成 JBROOT 有效性证据，`.jbroot-` 前缀命中不等于确认。
- Rootless/Rootful 候选仅作路线对照，不填入 RootHide `jbroot`；无真机结论。
- 待 B3 授权后再接入命名/存在/结构/可读/realpath 校验与六态裁决；B4 只使用 B3 确认路径，不重扫 JBROOT。
