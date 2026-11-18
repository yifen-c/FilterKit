# Stage 2.2-C3-Engine-C2：完整集成回归实施规格（设计冻结，待门禁与独立授权）

- 上游依据：`Stage-2.2-C3-Engine-C2-Audit.md` 接口事实表与去重矩阵；`Stage-2.2-C3-Engine-C2-Regression-Plan.md` 回归范围与归档结构；`Stage-2.2-C3-Engine-C1-Implementation.md` 22 项基线与比较器。
- 状态：**实施规格冻结**。本轮不写 C2 测试代码；C2 实现须在 C-G1 / C-G2 门禁与独立授权后按批次落地。
- 真实 API 一律以 Audit §1 表为准；本文件出现的类型名均为仓库现有类型，不新增第二套配对模型或规则模型。

## 1. 实施总原则

1. **复用既有模型**：测试输入直接构造 `PluginPairingSnapshot` / `PluginPairingRecord` / `PluginFileEvidence`；不在 Engine 测试里手工重新配对，不引入 C2 专用配对结构。
2. **复用 C1 基线资产**：22 项注册表 `EngineC1BaselineRegistry.all`、比较器 `EngineC1ResultComparator`、夹具加载器 `EngineC1FixtureLoader`、桩协调器范式在 C2 测试目标内复用/扩展；C2 不另写一套基线期望。
3. **依赖注入**：Reader / Decoder / 双 Parser 经 `PlistDataReading / PlistDecoding / FilterParsing` 接缝注入；集成批次用真实 `RootHideFilterParser()` / `RootlessFilterParser()`，桩 Reader/Decoder 回灌解码根对象；隔离批次可用计数桩记录调用次数与入参。
4. **不改动生产排序语义**：确定性与顺序断言基于既有稳定序；不为通过测试改生产模型排序、归类或告警口径。
5. **上游不重分类**：上游 `warnings` / `unknownItems` 原样归集；Engine 新增告警只追加并按 code 去重，不覆盖、不删除、不改写上游告警。
6. **五态直传**：Engine 不做状态转换；读取失败不归解析失败，解码失败不归类型不符，类型不符不归解析失败。

## 2. 批次拆分（C2-A ~ C2-E）

| 批次 | 对应场景 | 内容 | 阻塞条件 |
|---|---|---|---|
| C2-A | C2-01 双路线端到端 | 真实 Parser 多插件端到端；路线选边对称；非 paired / 未知路线零调用复核 | C-G1；Rootless 部分待 C-G2 |
| C2-B | C2-02 五态传递 + C2-03 多插件失败隔离 | 不可转换矩阵；单次混合 5 条批次；首条失败后续继续；计数与顺序 | C-G1 |
| C2-C | C2-04 Snapshot / Counts / Warnings | 告警合并与去重；确定性字段级顺序；输入不可变；计数不变量复核 | C-G1 |
| C2-D | C2-05 22 项基线完整链路集成 | 三层追溯关联；基线在完整 Engine 链路保持；PARSE-015 待 C-G2 | **C-G1 + C-G2** |
| C2-E | C2-06 回归 / 隔离 / 证据归档 | 全量既有回归；源码隔离；GUI/协议边界；Runner 证据归档与报告 | C-G1~G7 齐备 |

## 3. 分组实施规格

### 3.1 C2-A：双路线端到端（C2-01）

**输入**
- Hide 快照：`route="roothide"`、`sourceDirectory="/dir"`、`status=.enumerated`，≥2 条 `.paired` 记录（dylib/plist 证据齐备，`basis=.exactFilenameMatch`）。
- Less 快照：`route="rootless"` 同构 ≥2 条；该快照在 C-G2 通过前以 `XCTSkipIf` 挂起，不记通过。
- 对照样本：非 `.paired` 记录（missingPlist / orphanPlist）与 `route="rootful"` 未知路线 paired 记录。

**断言**
- Hide 快照：Reader/Decoder 各按条目数调用；RootHide Parser 调用数 == paired 条目数；Rootless Parser 调用 0；每条 `result.route == "roothide"`。
- Less 快照（解锁后）：对称；Rootless Parser 调用数 == 条目数；RootHide 0；`result.route == "rootless"`。
- 非 paired：Reader/Decoder/双 Parser 全 0；条目进 `notParsed`，原因对齐类别。
- 未知路线：下游全 0；`notParsed` 原因 `unknown_route`。
- 端到端规则内容与 C1 Parser 层结果一致（经比较器复核 bundles/classes/executables/CFV/otherKeys）。

**桩设计**：桩 Reader 回灌成功 `Data`；桩 Decoder 按路径回灌 `PlistDecodedObject(rootObject:format:)`；Parser 用真实实现；计数 Spy 可包一层 `FilterParsing` 记录次数与最后入参（沿用 Engine-B `StubParser` / C1 `EngineC1CountingParser` 范式）。

### 3.2 C2-B：五态传递与多插件失败隔离（C2-02 / C2-03）

**不可转换矩阵（逐条断言状态与 reason）**

| 上游来源 | Engine 结果状态 | 禁止转换 |
|---|---|---|
| RootHide Parser `valid` | `valid` | — |
| RootHide Parser `type_mismatch` | `type_mismatch` | 不得变 `parse_failed` |
| Rootless Parser 失败（Codable） | `parse_failed`（按 Parser 实际语义） | 不得变 `type_mismatch` |
| Reader `accessDenied / notFound / readFailed` | `read_failed` | 不得变 `parse_failed` |
| 非 paired / 未知路线 | `not_parsed` | 不计入失败桶 |

**混合批次样本（单次 Engine 运行，5 条，顺序 A~E）**

| 条目 | 来源桩 | 预期状态 |
|---|---|---|
| A | 真实 Parser valid | `valid` |
| B | Reader `readFailed` | `read_failed` |
| C | 真实 Parser `type_mismatch` | `type_mismatch` |
| D | `.orphanPlist` 非 paired | `not_parsed` |
| E | 真实 Parser valid | `valid` |

断言：`counts.valid=2 / parseFailed=0 / typeMismatch=1 / readFailed=1 / notParsed=1 / total=5`；`parsed.count=4`、`notParsed.count=1`；B、C、D 失败不影响 A、E；`parsed` 与 `notParsed` 保持上游记录顺序；Validator `C3B-001~003` 全过。补充「首条即失败」样本：首条 read_failed，后续条目仍被处理。

### 3.3 C2-C：Snapshot / Counts / Warnings（C2-04）

**计数不变量（复核 Validator 既有实现，不重复造校验器）**
- `valid + parseFailed + typeMismatch + readFailed == parsed.count`
- `notParsed == notParsedItems.count`
- `counts.total == parsed.count + notParsed.count`
- 非 `valid` 条目 `filter == nil`（C3B-004）；快照路线一致（C3B-005）；目录状态与失败桶一致（C3B-006）；unresolved 携带 `inventory_unresolved`（C3B-007）。

**告警与上游保留**
- 构造上游 `warnings: [ReportWarning(code: ...)]` 与 `unknownItems: [UnknownItem]`；Engine 结果中原样保留，code / message / sourceStage 不改写。
- Engine 追加告警（`partial_parsing / invalid_plist / access_denied / read_failed`）不覆盖上游同 code 告警；同 code 重复告警按 Builder 既有去重口径只保留首条；断言去重后顺序：上游在前、条目级次之、Extra 最后（与 `FilterParseSnapshotBuilder.deduplicated` 实现一致）。

**确定性与不可变**
- 同一输入连续两次 `parse`，`FilterParseSnapshot` `Equatable` 深比较相等；字段级顺序核对：记录顺序、UnknownItem 顺序、Warnings 顺序、Counts、SkippedField 顺序、Evidence。
- 输入快照解析前后深比较相等（`PluginPairingSnapshot` Equatable）；若后续模型字段不具备稳定 Codable 往返，降级为字段级比较，不强行要求新增 Equatable 或改生产模型。

### 3.4 C2-D：22 项基线完整链路集成（C2-05）

**三层追溯**（每项基线建立可追踪关联）
1. **Parser 单独结果**：直接调 Parser（C1 Parser 层既有落点）。
2. **完整链路结果**：桩 Reader 成功 → 桩 Decoder 回灌根对象 → 真实 Parser。
3. **Engine Snapshot 最终结果**：经 `PluginFilterParseEngine.parse(snapshot:)` 汇总后的条目结果。

三层状态 / reason / 规则 / otherKeys / 字段证据一致；不一致先记缺陷报告，不改期望迁就实现。

**基线范围**：沿用 `EngineC1BaselineRegistry.all` 22 项；夹具项经 `EngineC1FixtureLoader` 构造真实 `PluginPairingSnapshot`；合成项按注册表 `source` 构造桩输入。PARSE-015（Rootless RL）`pendingRunner` 挂起已解除，run `44106064051` 完整 Engine 链路复验通过。PARSE-009-B 按 Audit §3 独立对照方案处理，不并入本批次断言期望。

### 3.5 C2-E：回归、隔离与证据归档（C2-06）

**既有回归清单**（沿用 C2 Regression Plan §1 矩阵）：Models Codable、Environment、JBROOT 候选/校验、Directory、Enumeration、Pairing（键/索引/引擎/集成/S105/Codable）、Reader/Decoder/ValueKind、RootHide Parser、Rootless Parser、Engine-B、C1 基线。逐项核对无失败，按 Runner 记录口径分列。

**架构隔离静态核对**
- Core 不反向依赖 App / Service；测试桩不进生产目标；夹具只读。
- GUI 无私有 Parser；CLI / GUI 共享 Core；七方法 `ElleKitAdapter` 协议未演进（`getEnvironment / resolvePaths / scanPlugins / readPlugin / validatePlugin / parseFilter / resolvePath` 签名冻结）。
- 未实例化 Adapter、未接服务层装配；未推断 `loaded`；归属识别与统一 JSON 导出属 Stage 2.2-D。

**证据归档**：按 Regression Plan §4 结构 `Tests/Stage2/evidence/run-<id>-acceptance/`（RUN-METADATA / app-build / test / metadata / isolation / environment）；报告数字与测试输出逐文件一致；未过项标注阻塞门禁；观察项单列，不混入通过结论。

**E1～E4 落地记录（2026-11-17，Runner 未执行）**
- E1 全量回归矩阵：`Tests/Stage2/EngineC2E-RegressionRegistry.swift`（32 项，编号 / 阶段 / 套件类 / 源文件 / 依赖 / 证据状态）；身份与结构核对测试 `EngineC2E-RegressionPlanTests.swift`。
- E2 历史基线组织：复用既有 XCTest 套件；核对 Stage1 映射、C1 22 项基线、PARSE-015-A 解除挂起、PARSE-009-B 独立挂起在位，不新建重复统计系统。
- E3 三向隔离：扩展 `scripts/check-adapter-isolation.sh`，在既有 Adapter 双向检查上补 Parser 双向交叉扫描与 App→Core 私有扫描/解析扫描；行为隔离断言沿用 Engine-B 既有覆盖，不重复实现。
- E4 证据骨架：`Tests/Stage2/evidence/engine-c2-final/`，元数据 JSON 未执行字段为 `null`；验收报告骨架含 C-G1～G7 门禁表、五类计数分列与 PARSE-009-B 独立记录；不实现报告生成器（统一 JSON 导出属 Stage 2.2-D）。
- E5 清单冻结后由第五轮统一验收 Runner `44106064051`（检出 SHA `f4629f26…`）实际执行：全量 379 例 0 fail / 0 skip，Core Build 0 error / 0 warning，App BUILD SUCCEEDED 且 PID 3508 存活，隔离脚本 CI 实际执行六项 OK；C-G1～G7 全部 passed，证据归档 `evidence/run-44106064051-acceptance/`，结论见 `evidence/engine-c2-final/acceptance/final-acceptance.md`。注册表 32 项状态回填 `runnerVerified`（evidenceRun `44106064051`）。本轮证据为 CI / Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据。

## 4. 计数口径（报告五类分列，不相加）

1. XCTest 实际执行数：Runner 编译后实际运行用例数。
2. S1-06 基线覆盖数：22 项 PARSE 行为覆盖（一对多展开按基线条目计），不等于用例数。
3. 各模块专项数：Reader/Decoder、RootHide、Rootless、Engine 等分列。
4. 既有回归数：C1/C2/B 链路历史验收用例，按 Runner 记录核对无失败。
5. 静态检查数：编译 error/warning、协议/源码边界核对、隔离三向检查项。

## 5. 禁止项（沿用授权边界）

- 不为 C2 新增 Parser、路线识别机制、第二套配对/规则模型。
- 不修改生产 Models / Adapters / 七方法协议 / 既有冻结源码 / Stage1 fixtures / harness。
- 不在门禁未过前宣布双路线集成完成；不把 Engine-C1 测试落地或桩断言记为 C3-C2 验收。
- 不扫真机、不改插件文件 / plist / 注入配置、不做启停 / 装卸 / 写入。
- PARSE-009-B 差异未独立授权前，不调整 Parser 实现或 C2 期望值。
