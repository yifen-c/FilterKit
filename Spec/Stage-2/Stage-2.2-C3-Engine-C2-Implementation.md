# Stage 2.2-C3-Engine-C2-A~C：集成测试实现记录（测试层，Runner 验收待授权）

- 前置依据：`Stage-2.2-C3-Engine-C2-Audit.md` 接口事实表与去重矩阵、`Stage-2.2-C3-Engine-C2-Implementation-Spec.md` 批次规格。
- 提交链：`515b19f`（C2-A）→ `2434c60`（C2-B）→ `03b1756`（C2-C）→ `da90c39`（D1）→ `113d296`（D2）→ `dbc2315`（D3）→ `f22d00e`（D4）。
- 本地环境：Linux 云主机无 Swift / Xcode 工具链；本轮**未编译、未跑 Runner**，编译与通过结论以外部 macOS Runner 出证为准。
- 授权范围：C2-A~C 测试实现 + C2-D1~D4 测试代码落地（待 Runner 复验）；**C2-E（全量回归/隔离/归档）未启动**。

## 1. 文件清单（`Tests/Stage2/`，测试目标内部）

| 文件 | 职责 | 批次 |
|---|---|---|
| `EngineC2-TestSupport.swift` | 按路径受控 Reader/Decoder 桩；双 Parser 计数包装（委托真实实现）；快照/记录/证据/根对象构造器；Engine 装配入口 | A 共享 |
| `EngineC2-EndToEndTests.swift` | C2-A 双路线端到端：真实 RootHide 链路、Rootless 对称端到端（D2 解除挂起）、非 paired/未知路线零调用 | A |
| `EngineC2-BatchIsolationTests.swift` | C2-B 五态传递、混合五插件批次、失败隔离、顺序稳定、状态不可转换、规则载体归属 | B |
| `EngineC2-SnapshotWarningsTests.swift` | C2-C 三层追溯、上游保留、告警合并顺序、计数一致、确定性、输入不可变 | C |

`Package.swift` Stage2Tests sources 追加上述 4 文件；Core sources 未变。

## 2. 测试映射（16 例；run `44106064051` 复验通过）

### C2-A 端到端（6 例）

| 测试 | 覆盖要点 |
|---|---|
| `testRootHideSingleValidEndToEnd` | 单插件真实 Parser  valid；规则三数组、路线、身份/路径透传；Reader/Decoder/Hide 各 1、Less 0；Validator 全过 |
| `testRootHideMultiPluginValidEndToEnd` | 三插件全 valid；逐条身份/路径/规则对齐，不跨插件串线；Hide 3、Less 0 |
| `testRootHideMultiPluginMixedStatusEndToEnd` | 两 valid + 一 type_mismatch；计数 2/1；mismatch reason `field_type`、filter nil |
| `testRootlessSymmetricEndToEnd` | Rootless 对称端到端；D2（`113d296`）解除 `XCTSkipIf` 挂起，待 Runner 复验 |
| `testNonPairedNeverEntersReader` | orphanPlist 非配对：下游全 0，归集 `missing_dylib` |
| `testUnknownRouteNeverEntersDownstream` | `rootful` 未知路线：下游全 0，归集 `unknown_route` |

### C2-B 五态与失败隔离（4 例）

| 测试 | 覆盖要点 |
|---|---|
| `testMixedFivePluginSingleBatch` | 单次批次 A valid / B read_failed / C type_mismatch / D not_parsed / E valid；计数 2/0/1/1/1、total 5；parsed 4、notParsed 1；顺序 `[A,B,C,E]`；逐条状态/原因/路径关联 |
| `testFailureDoesNotStopFollowingPlugins` | 首条 read_failed，后续两条继续处理；顺序不变；Reader 3、Hide 2 |
| `testStatesTransferWithoutConversion` | type_mismatch 不转 parse_failed；accessDenied→read_failed 不转 parse_failed；Decoder 失败→parse_failed/`invalid_plist`；非配对 not_parsed；Hide 仅 1 |
| `testStatesAreMutexAndFilterOwnedByValidOnly` | 五态互斥；规则载体仅 valid 非空（C3B-004 复核） |

### C2-C Snapshot / Warnings（6 例）

| 测试 | 覆盖要点 |
|---|---|
| `testParserResultTracesBackToRecordAndSnapshot` | Parser 直调结果 ↔ Engine 条目 ↔ Snapshot 身份路径；status/reason/规则/otherKeys/isTweakManager/skippedFields 逐维对齐 |
| `testUpstreamWarningsAndUnknownItemsPreserved` | 上游两条告警原样保留；上游 unknownItem 归集末尾，不被覆盖 |
| `testWarningMergeOrderDedicated` | 合并顺序：上游 → 条目级 → Engine 追加（`partial_parsing`）；同 code 去重；无重复告警 |
| `testCountsMatchInputRecords` | 3 paired + 1 上游 unknown；valid 3、notParsed 1、total 4；total == parsed + notParsed |
| `testSnapshotDeterminismDeepEqual` | 相同输入两次独立 Engine 运行，快照 `Equatable` 深比较相等 |
| `testInputSnapshotNotMutated` | 原始快照解析前后深比较相等；records/unknownItems/warnings 不改写 |

## 3. 桩与真实实现边界

- **真实 Parser**：RootHide 端到端与混合状态均委托 `RootHideFilterParser()`；Rootless 包装持有 `RootlessFilterParser()` 但仅在挂起结构内实例化，不产出正式通过结论。
- **受控故障注入**：Reader 桩按路径回灌 `success / notFound / accessDenied / readFailed`；Decoder 桩按路径回灌根对象或 `parse_failed`；桩不冒充 Parser 成功结果。
- **复用既有资产**：Engine / Resolver / Builder / Validator / 既有协议接缝全部复用，未新增生产专用测试接口；配对输入复用 `PluginPairingSnapshot / PluginPairingRecord / PluginFileEvidence / UnknownItem / ReportWarning`。

## 4. 待 Runner 出证与静态核对遗留

- 本机无工具链，16 例均未编译执行；括号平衡、协议签名、类型引用已静态核对，编译 error/warning 与断言通过以 Runner 为准。
- Rootless 链路（含 PARSE-015、Rootless 多插件端到端）待 C-G2（#151）出证后解除挂起。
- PARSE-009-B CFV 字符串元素观测类型词/下标口径未在本轮改动 Parser 或期望；按 Audit §3 独立对照方案留待 Runner 复核。
- 未决沿用：G-E2 Snapshot/Counts 归属、G-C3-1 五态枚举归属、G-C3-2 skippedFields 结构化提升、G-C3-4 Adapter 签名演进、G-C3-5 UnloadAfter 导出归属。

## 5. 计数纪律（报告口径，Runner 回填）

- 本轮新增静态测试落点 16 例；XCTest 实际执行数以 Runner 输出为准。
- 不与 S1-06 基线 22 项、Engine-B 19 例、Engine-C1 15 例、C3-B/C3-C1/C3-C2 专项及既有回归数相加；最终报告按五类分列（XCTest 总数 / C2 新增专项 / 基线映射 / 各模块回归 / 静态与隔离检查）。

## 6. 边界留痕

- 未修改 Core 生产逻辑、Models、Adapters、七方法协议、既有冻结 Parser 与 Stage1 fixtures / harness。
- 未实例化 Adapter、未接服务装配；未扫真机；未改插件文件 / plist / 注入配置；未做启停 / 装卸 / 写入；未推断 `loaded`。
- C-G1、C-G2 未通过前不启动 C2-D 完整双路线集成验收，不宣布双路线集成完成。

## 7. Runner 三轮对账（2026-11-17，本地修复待下一轮复验）

> 附件建议（验收先行、不直接进入 C2-D）与本规格门禁顺序一致：C2-A~C Runner 验收 → C-G1 / C-G2 独立核实 → C2-D1~D4 → C2-E 全量回归。本轮仅做证据对账与测试层修复，未启动 C2-D 实现。

### 7.1 三轮 Runner 记录（证据归档于 `Tests/Stage2/evidence/`）

| 轮次 | 作业 / 检出 SHA | 阶段 | 结果 | 本地修复提交 |
|---|---|---|---|---|
| 首轮 | `run-f5e97c82-build-failure`，SHA `4b3e71c0` | Core build | 2 处编译错误 + 2 处未使用告警 | `31a0f48` |
| 次轮 | `run-9270f2b6-test-failure`，SHA `672b8562` | Stage2Tests emit-module | 8 处实参顺序 + 4 处默认参数引用 `key` | `66a7db7` |
| 三轮 | `run-a62bf4cf-test-failure`，SHA `7f91ed41` | 编译通过，测试执行 | 347 例，3 skipped，3 failures（0 unexpected） | `d417965` |

三轮均在外部 macOS Runner（`macos-26-arm64`，runner 2.338.2，westus / MacCloud）；本机 Linux 无工具链，编译与通过结论以下一轮 Runner 复验为准。

### 7.2 C2 新增 16 例（第三轮 Runner 套件结果，检出修复前基线）

| 批次 / 套件 | 例数 | skip | fail | 备注 |
|---|---|---|---|---|
| C2-A `EngineC2EndToEndTests` | 6 | 1 | 0 | 5 例通过；`testRootlessSymmetricPendingRunner` 为 `XCTSkipIf`，待 #151 / C-G2，不计通过 |
| C2-B `EngineC2BatchIsolationTests` | 4 | 0 | 0 | 混合五插件批次计数 valid 2 / parse_failed 0 / type_mismatch 1 / read_failed 1 / not_parsed 1 / total 5；失败不中断后续；五态互斥；规则仅 valid 持有 |
| C2-C `EngineC2SnapshotWarningsTests` | 6 | 0 | 0 | 三层追溯、上游 warnings/unknownItems 保留、合并顺序与同 code 去重、计数一致、深比较确定性、输入快照不可变 |

接线口径：Reader / Decoder 为按路径受控桩；双 Parser 由 `EngineC2CountingParser` 包装委托真实 `RootHideFilterParser()` / `RootlessFilterParser()`，真实解析行为不被桩成功结果冒充。

### 7.3 门禁与既有回归分列（第三轮 Runner）

| 分类 | 套件 | 例数 | skip | fail | 状态 |
|---|---|---|---|---|---|
| C-G1 Engine-B | `FilterParseEngineTests` | 19 | 0 | 2 | 失败为桩未回显上游路径（测试桩保真缺陷，非生产逻辑）；`d417965` 已修，**待下一轮 Runner 复验**，C-G1 未关闭 |
| C-G2 Rootless 专项 | `RootlessFilterParserTests` | 22 | 0 | 0 | 隔离套件全绿；#151 完整 Runner 验收证据仍待外部调度，C-G2 **未关闭** |
| C1 基线 | `EngineC1ParserBaselineTests` | 8 | 1 | 1 | 失败为比较器对未冻结下标强制 nil；`d417965` 改为可选断言，待复验；PARSE-009-B 元素级口径差异保留待独立复核 |
| C1 Engine 基线 | `EngineC1EngineBaselineTests` | 7 | 1 | 0 | PARSE-015-A 挂起待 C-G2 |
| 既有回归 | B5 三套件 / ElleKit / Environment / JBRoot×2 / ModelsCodable / Inventory & Pairing Codable / Reader·Decoder·ValueKind / Enumeration / Pairing 五套件 / S105 夹具 / RootHide Parser / FilterParseResult | 余下列 | 0 | 0 | 第三轮 0 failure；待 `d417965` 后全量复验确认无回归 |

### 7.4 判定纪律（沿用回归计划 §2 五类分列）

- `XCTSkipIf` / pendingRunner 只记 skipped，不计通过；未执行不算通过也不算失败。
- C2 新增 16 例、Engine-B 19 例、C1 基线、Rootless 22 例、既有回归分别列示，不与 XCTest 总数相加。
- 下一轮 Runner 必须在 `d417965`（或更新提交）上检出；验收通过前 C2-D1~D4、C2-E 保持阻塞，不宣布双路线集成完成。
- PARSE-009-B 观测类型词 / 元素下标差异另出独立缺陷报告，独立授权后再决定改 Parser 还是补登基线；本轮未改冻结 Parser 与 Stage1 夹具期望。

### 7.5 第四轮 Runner 验收（2026-11-17，C-G1 / C-G2 关闭）

证据归档：`Tests/Stage2/evidence/run-44021119037-acceptance/`；workflow run `44021119037`，branch `C2-C3`，检出 SHA `ad443b151d9fddaa57dfac86ea58bbc33be8b8e1`（本地基线 `767c3f5`）。

| 分类 | 套件 | 例数 | skip | fail | 结论 |
|---|---|---:|---:|---:|---|
| C2 新增 | EndToEnd 6 / Batch 4 / Snapshot 6 | 16 | 1 | 0 | ✅ 0 failure；Rootless 对称 1 例挂起 |
| C-G1 Engine-B | `FilterParseEngineTests` | 19 | 0 | 0 | ✅ 关闭（第三轮桩回显路径缺陷修复后复验通过） |
| C-G2 Rootless 专项 | `RootlessFilterParserTests` | 22 | 0 | 0 | ✅ 关闭；Core Build / 既有回归 / S1-05 / App Build / 隔离复查均满足 C3-C2 §7 出证口径 |
| C1 基线 | Parser 8 / Engine 7 | 15 | 2 | 0 | ✅ 0 failure；2 例 PARSE-015 挂起 |
| 既有回归 | 其余套件 | 236 | 0 | 0 | ✅ 0 失败，无回归 |

- 全量：Executed 347 tests，3 skipped，0 failures（0 unexpected）；Core 三库 `Build complete! (5.97s)`，0 error / 0 warning；S1-05 独立过滤 15 例 0 failure；隔离三向 OK；App `BUILD SUCCEEDED`，PID 10662 存活，骨架首页截图归档。
- 3 例 `XCTSkipIf`（PARSE-015-A、PARSE-015、Rootless 对称）仍只记 skipped / pending，不计通过；属完整 Engine 链路 Rootless 用例，归 C2-D2 阶段解除挂起。
- 门禁开放范围：C2-D1（22 项基线接入完整 Engine）可启动；C2-D2 双路线对称、C2-D3 证据追溯、C2-D4 组合场景按批次提交、分批 Runner 验收；C2-E 全量回归归档未启动。PARSE-009-B 口径差异继续挂起，本轮不改冻结 Parser 与 Stage1 期望。

### 7.6 C2-D1~D4 分批代码落地（2026-11-17；第五轮 Runner 复验通过）

第四轮 Runner 关闭 C-G1 / C-G2 后，按建议附件拆分 D1~D4 分批落地测试，每批单独提交；本机 Linux 无 Swift 工具链，编译与通过结论以下一轮外部 Runner 为准，验收前不宣布 C2-D 完成。

| 批次 | 文件 | 例数 | 提交 | 覆盖口径 |
|---|---|---:|---|---|
| D1 基线链路集成 | `EngineC2BaselineIntegrationTests.swift` | 2 | `da90c39` | 22 项基线经完整 Engine 链路矩阵；RootHide 可达 Parser 项直连 Parser 与 Engine 条目一致性对照；复用 C1 注册表 / 比较器 / 加载器 / 桩协调器 |
| D2 双路线对称 | `EngineC2RouteSymmetryTests.swift` | 6 | `113d296` | 路线选边以快照 `route` 为准（roothide 仅 Hide、rootless 仅 Less），不跨路线回退；RootHide 严格类型 = `type_mismatch`，Rootless Codable 失败 = `parse_failed`；两路线 valid 条目共享公共 `FilterRule` 模型 |
| D3 错误证据追溯 | `EngineC2EvidenceTraceTests.swift` | 8 | `dbc2315` | 各状态身份 / 路径 / 路线透传；Reader 失败不进 Decoder / Parser，Decoder 失败不进 Parser；非 paired 与未知路线归集 `notParsed` 零下游、不计解析失败桶；类型失败保留字段级 skipped 证据；混合批次仅 valid 携带规则 |
| D4 组合场景不变量 | `EngineC2CombinedScenarioTests.swift` | 5 | `f22d00e` | 混合批次五态并存与计数 / 归属自洽（校验器）；双路线隔离；告警合并去重与上游 unknownItems 保留；重复执行确定性深相等；输入快照不可变。组合场景为 Engine 编排层自洽核对，不冒充 PARSE-001~022 基线验收 |

- 挂起解除已在第五轮生效：PARSE-015-A `pendingRunner` 置 `false`；C2-A Rootless 对称用例 `testRootlessSymmetricEndToEnd` 与 C1 Parser 基线 `testRootlessBaselineThroughParser` 转真实执行并通过。
- 第五轮 Runner 实测：D1~D4 新增 21 例全部执行，`XCTSkipIf` / pendingRunner 挂起数为 0；编译 0 error / 0 warning，既有回归无损伤。

### 7.7 第五轮统一验收（2026-11-17，C-G1～G7 全部 passed）

workflow run `44106064051`，branch `D5`，检出 SHA `f4629f268e680bc0e25e911997d03959457263ec`；本地基线 HEAD `1298edc`。证据归档 `Tests/Stage2/evidence/run-44106064051-acceptance/`，最终结论 `evidence/engine-c2-final/acceptance/final-acceptance.md`。

| 分类 | 套件 | 例数 | skip | fail | 结论 |
|---|---|---:|---:|---:|---|
| C2-A～C | EndToEnd 6 / Batch 4 / Snapshot 6 | 16 | 0 | 0 | ✅ 通过 |
| C2-D1～D4 | BaselineIntegration 2 / RouteSymmetry 6 / EvidenceTrace 8 / CombinedScenario 5 | 21 | 0 | 0 | ✅ 通过 |
| C-G1 Engine-B | `FilterParseEngineTests` | 19 | 0 | 0 | ✅ passed |
| C-G2 Rootless 专项 | `RootlessFilterParserTests` | 22 | 0 | 0 | ✅ passed |
| C1 基线 | Parser 8 / Engine 7 | 15 | 0 | 0 | ✅ 通过；PARSE-015 挂起已解除 |
| E 组织自校验 | `EngineC2ERegressionPlanTests` | 11 | 0 | 0 | ✅ 注册表身份 / 结构核对通过 |
| 既有回归 | 其余套件 | 275 | 0 | 0 | ✅ 0 失败，无回归 |

- 全量：Executed 379 tests，0 failures（0 unexpected），0 skipped；Core Build 0 error / 0 warning；S1-05 独立过滤 15 例 0 failure；隔离脚本 CI `isolation` job 实际执行六项 OK；App `BUILD SUCCEEDED`，PID 3508 存活，骨架首页截图归档。
- 边界未变：未改 Core 生产逻辑 / Models / Adapters / 七方法协议 / 冻结 Parser / Stage1 fixtures；未实例化 Adapter、未接服务装配；组合场景结论不记为 C3-C2 验收。PARSE-009-B 继续独立挂起；本轮证据为 CI / Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据。
- 边界未变：未改 Core 生产逻辑 / Models / Adapters / 七方法协议 / 冻结 Parser / Stage1 fixtures；未实例化 Adapter、未接服务装配；组合场景结论不记为 C3-C2 验收。
