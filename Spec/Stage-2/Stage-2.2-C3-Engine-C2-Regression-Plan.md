# Stage 2.2-C3-Engine-C2：完整集成回归与最终验收计划（设计冻结，待门禁开启）

- 上游依据：`Stage-2.2-C3-Engine-C-Audit.md` 门禁表、`Stage-2.2-C3-Engine-C1-Test-Spec.md` 基线映射规格。
- 定位：C2 **不重新实现** Reader/Decoder/Parser/Engine，只做完整链路验证：双路线解析链对 Stage 1 原始行为的保持、既有行为无回归、计数与证据自洽。
- 前置硬门禁：**C-G1 Engine-B Runner 通过**、**C-G2 C3-C2 Rootless Runner 通过** 均满足后，方可进入 C2；任一未过，不开启完整集成验收。

## 1. 回归范围矩阵

| 模块 | 既有测试源（`Tests/Stage2/`） | 历史 Runner 基线 | C2 核对点 |
|---|---|---|---|
| Models Codable | `ModelsCodableTests`、`PluginInventoryCodableTests`、`PluginPairingCodableTests` | 既有回归通过 | 模型往返、枚举原始值、nil/缺失/空数组编码无损伤 |
| Environment | `EnvironmentDetectionTests` | B1 验收通过 | 环境识别与路线上游透传不改写 |
| JBROOT 候选/校验 | `JBRootCandidateCollectionTests`、`JBRootValidationTests` | B2/B3 验收通过 | 候选收集、五项三态校验、歧义裁决无回归 |
| Directory / Symlink | `ElleKitDirectoryTests` | B5 验收通过 | 目录定位与软链证据口径保持 |
| Enumeration | `PluginEnumerationTests` | C1 run `43825045361` 114 例 | 条目中性证据、三态事实位无回归 |
| Pairing | `PluginPairingKeyTests`、`IndexTests`、`EngineTests`、`IntegrationTests`、`PluginPairingS105FixtureTests` | C2-D2 run `43857670397` 210 例；S1-05 15 例独立过滤 0 失败 | 五桶归类、同目录作用域、S1-05 15 项映射无回归 |
| Reader / Decoder | `PlistReaderTests`、`PlistDecoderTests`、`PlistValueKindTests` | C3-B run `43889143343` 236 例 | 读取四态、解码两态、XML/Binary、类型识别无回归 |
| RootHide Parser | `RootHideFilterParserTests`、`FilterParseResultTests` | C3-C1 run `43993649974` 275 例 | 严格类型、CFV 模式、otherKeys、证据保留无回归 |
| Rootless Parser | `RootlessFilterParserTests` | ✅ C-G2 passed，run `44106064051` 22 例 0 fail / 0 skip | Codable 字段、小写规范化、otherKeys、失败语义无回归 |
| Engine-B 编排 | `FilterParseEngineTests` | ✅ C-G1 passed，run `44106064051` 19 例 0 fail / 0 skip | 短路矩阵、双路线隔离、五桶计数、不可变口径无回归 |
| S1-06 基线 | `EngineC1-ParserBaselineTests`、`EngineC1-EngineBaselineTests` | ✅ run `44106064051` 15 例 0 fail / 0 skip；PARSE-015 挂起已解除并复验通过 | 22 项逐条对照 `metadata.json`；Rootless 全链路用例已转真实执行 |
| C2-D 集成 | `EngineC2BaselineIntegrationTests`、`EngineC2RouteSymmetryTests`、`EngineC2EvidenceTraceTests`、`EngineC2CombinedScenarioTests` | ✅ run `44106064051` 21 例（D1 2 / D2 6 / D3 8 / D4 5）0 fail / 0 skip | 基线完整链路、双路线对称、错误证据三层追溯、组合场景与不变量；不与基线覆盖数相加 |

## 2. 计数口径（避免重复累加）

最终报告必须分列以下五类数字，不得把基线覆盖数与 XCTest 总数相加：

1. **XCTest 实际执行数量**：测试 target 编译后实际运行的用例数。
2. **S1-06 基线覆盖数量**：22 项 PARSE 行为覆盖（一对多展开按基线条目计），不等于用例数。
3. **各模块专项数量**：Reader/Decoder、RootHide、Rootless、Engine 等专项用例分别列示。
4. **既有回归数量**：C1/C2/B 链路历史验收用例，按 Runner 记录口径核对无失败。
5. **静态检查数量**：编译 error/warning、协议/源码边界核对、隔离三向检查项。

判定口径：基线 22 项全部映射且通过（C-G3）；双路线隔离通过（C-G4）；五态与 Counts 不变量通过（C-G5）；既有回归全部通过（C-G6）；App Build 成功且架构隔离通过（C-G7）。

## 3. C2 执行检查项

### 3.1 链路行为

- 上游 `PluginPairingSnapshot` → Engine → Reader/Decoder → 路线 Parser → `FilterParseSnapshot` 全链路状态传递正确。
- 路线唯一来源 `snapshot.route`；无第二路线判断系统；未知/rootful/nil 归 `.unknown`，不跨路线兜底。
- 五态直传不改写：`valid / parse_failed / type_mismatch / read_failed / not_parsed`；`not_parsed` 不计失败；`valid` 不推断 loaded。
- 计数不变量：`valid + parseFailed + typeMismatch + readFailed == parsed.count`；`notParsed == notParsedItems.count`；五桶和 == 条目总数。

### 3.2 隔离与边界

- 双路线 Parser 互不调用；RootHide 失败不试 Rootless，反之亦然。
- 未实例化 Adapter、未接服务层装配；七方法 Adapter 协议未演进。
- 无 GUI 私有解析逻辑；未扫真机；未修改插件文件 / plist / 注入配置；无启停、安装、卸载、dpkg、软链改动。
- 公共 Models 未被 Engine 中间层类型污染；Snapshot/Counts 停留 Core 中间层（G-E2 留待后续评审）。

### 3.3 App 与工程

- Core 三库 Build 0 error / 0 warning；测试 target 编译通过。
- App Simulator Build 成功并启动存活（参照既有 evidence 截图归档范式）。
- 隔离三向检查：Core 不反向依赖 App/Service；测试桩不进生产；夹具只读。

## 4. 证据归档结构（参照既有 `Tests/Stage2/evidence/`）

```
Tests/Stage2/evidence/run-<run-id>-acceptance/
  RUN-METADATA.md          # run id / 检出 SHA / 基线提交 / 时间 / 环境 SDK
  app-build/               # Build 日志、存活截图
  test/                    # XCTest 输出、分组通过/失败统计
  metadata/                # 计数五类分列、门禁 C-G1~G7 逐项结论
  isolation/               # 隔离三向与协议边界核对记录
  environment/             # Runner 环境信息
```

归档前核对：报告数字与测试输出逐文件一致；未通过项明确标注阻塞门禁；观察项（R6 未知枚举解码、iOS17 兼容、Rootless 真机、CFV 浮点语义等）单列，不混入通过结论。

E4 已落地最终验收骨架 `Tests/Stage2/evidence/engine-c2-final/`：`RUN-METADATA.json`（未执行字段 `null`）、`source/`、`build/`、`tests/`、`isolation/`、`fixtures/`、`acceptance/`；Runner 授权后按本结构填充，骨架不产生已通过结论。

## 5. 最终验收序列

1. C-G1：Engine-B Runner 全绿（Build、E-B1~E-B6、既有回归、S1-05、App Build、隔离）。
2. C-G2：C3-C2 Rootless Runner 全绿（22 例专项、既有回归无损伤）。
3. C1 落地：22 项基线映射测试并入测试 target。
4. C2 集中回归：全量 XCTest + 22 基线对照 + 静态/隔离检查。
5. 证据归档与迁移表回填：本计划门禁状态、Runner 元数据、未决观察项。
6. C3 最终验收结论仅在 C-G1~G7 全过后给出；任一硬门禁未过，保持「待验收」，不宣布双路线集成完成。

### 5.1 E5 最终 Runner 验收清单（run `44106064051` 已执行归档）

> 清单口径沿用冻结版；本轮由外部 Runner 实际执行，数值以 Runner 日志为准并归档至
> `evidence/run-44106064051-acceptance/`。未执行计数在归档前保持 `null`，不以 0 填充。

**环境与构建**
1. ✅ Runner 环境信息（macOS 26.7.2 / Xcode 26.6 / Swift 6.3.3 / SDK 26.5）归档至 `environment/`。
2. ✅ Core Build：`swift build` 0 error / 0 warning（`Build complete! (8.44s)`），日志归档 `core-build/core-build.log`。
3. ✅ App Build：xcodegen → xcodebuild iOS Simulator `** BUILD SUCCEEDED **`，模拟器存活复查 PID 3508 与截图归档 `app-build/`。

**测试分组（Runner 实际执行后分列，不相加）**
4. ✅ Stage1 基线回归：Environment / JBROOT / Directory / Enumeration / Pairing / Reader-Decoder；S1-05 15 项夹具映射独立过滤；S1-06 22 项基线对照。
5. ✅ Engine-B（C-G1）：`FilterParseEngineTests` 19 例，0 fail / 0 skip；既有回归无损伤。
6. ✅ C3-C2（C-G2）：`RootlessFilterParserTests` 22 例专项 0 fail / 0 skip；既有回归无损伤。
7. ✅ Engine-C1：`EngineC1ParserBaselineTests` 8 / `EngineC1EngineBaselineTests` 7，22 项基线链路复验通过；PARSE-015-A 挂起解除后实际执行。
8. ✅ Engine-C2 A～C：`EngineC2EndToEndTests` 6 + `EngineC2BatchIsolationTests` 4 + `EngineC2SnapshotWarningsTests` 6（共 16 例），0 fail / 0 skip。
9. ✅ Engine-C2 D：`EngineC2BaselineIntegrationTests` 2 + `EngineC2RouteSymmetryTests` 6 + `EngineC2EvidenceTraceTests` 8 + `EngineC2CombinedScenarioTests` 5（共 21 例），本轮取得新 Runner 证据，0 fail / 0 skip。
10. ✅ 全量 `swift test` 379 例 0 fail / 0 skip；`--filter PluginPairingS105FixtureTests` 独立过滤 15 例 0 failure。

**隔离与边界**
11. ✅ 三向隔离静态检查：RootHide→Rootless、Rootless→RootHide、App→Core 私有扫描/解析；脚本由 CI `isolation` job 实际执行，输出归档 `isolation/isolation-report.txt`。
12. ✅ 七方法 `ElleKitAdapter` 协议签名未演进；Core 未实例化具体 Adapter；测试桩未进生产目标。
13. ✅ 夹具完整性：Stage1 fixtures/harness 未改；冻结 Parser / Models / Adapters 未改；PARSE-009-B 保持独立挂起。

**通过判据**
14. ✅ Skipped = 0；未运行 / 跳过 / 待验收未计入通过。
15. ✅ 报告数字与测试输出逐文件一致；未过项无；观察项单列（见归档 §5）。
16. ✅ 最终结论写入 `evidence/engine-c2-final/acceptance/final-acceptance.md`；C-G1～G7 全部 `passed`，结论为 Runner 证据口径通过，等待最终人工确认。

> 门禁进度（2026-11-17，第五轮统一验收 Runner `44106064051`，检出 SHA `f4629f268e680bc0e25e911997d03959457263ec`）：**C-G1～G7 全部 passed**。全量 **379 tests，0 failures，0 skipped**；Core Build 0 error / 0 warning；App BUILD SUCCEEDED，PID 3508 存活；隔离脚本由 CI `isolation` job 实际执行，六项 OK；S1-05 独立过滤 15 例 0 failure。分组：Engine-B 19、Rootless 22、C1 基线 15（Parser 8 + Engine 7）、C2-A～C 16、C2-D1～D4 21、E 组织自校验 11、既有回归 275。第四轮 3 例 `XCTSkipIf` 对应用例本轮实际执行通过；PARSE-015 挂起已解除。证据归档 `Tests/Stage2/evidence/run-44106064051-acceptance/`，最终结论 `evidence/engine-c2-final/acceptance/final-acceptance.md`。PARSE-009-B 保持独立挂起；本轮证据为 CI / Simulator 口径，不构成真机权限或真实加载证据。

## 6. 本轮（Audit）未执行事项

- 未落地 C1/C2 任何测试或生产代码；未编译、未跑 Runner。
- 未修改 Stage 1 fixtures / harness / report；未改 Models / Adapters / 协议 / 既有冻结源码。
- Engine-C1 编码、Engine-C2 回归执行均待独立授权；C3-C2 与 Engine-B Runner 证据由外部调度出证。
