# Stage 2.2-C3-Engine-C-Audit：S1-06 双路线基线覆盖审计（设计层，代码冻结）

- 审计依据：Engine-A 冻结契约（`78365be`）、Engine-B 实现（`6bb34f8`）、Stage 1 S1-06 原始基线（`Tests/S1-06/report/S1-06-report.json` 22 例、`parser.js`、`run.js`、`Tests/Fixtures/S1-06/` 16 组夹具）。
- 本轮性质：**只读审计 + 规格冻结**。未修改任何源码 / Models / Adapters / 七方法协议 / Stage 1 fixtures / harness；未编译、未运行 Runner、未扫描真机。
- 边界：本审计不宣布 C3 双路线集成验收完成；Engine-C1 基线映射实现、Engine-C2 完整集成回归均待独立授权。

## 1. 基线盘点口径

### 1.1 基线构成

- 报告 `total=22, passed=22, failed=0`；路线覆盖 `roothide / rootless`；互泄计数 0。
- 16 组磁盘夹具（`environment.json` 上游/配对/plist 根信号 + `metadata.json` 期望），5 组 `run.js` 合成样本（root-type / filter-type / mixed-type / determinism / route-isolation）；PARSE 编号存在一对多展开（001/002 同夹具、009 两夹具、011 两夹具、012 三例、016 两例、005 两例），**22 是行为覆盖数，不是 22 个独立文件**。
- 比较维度对齐 `run.js compareResult`：`route / sourceDirectory / status / counts / statusByBase / filterByBase / otherKeysByBase / skippedFieldsByBase`；`base` 对应 Engine `pairingKey`。

### 1.2 覆盖分类图例

| 标记 | 含义 |
|---|---|
| 专项已覆盖 | 既有 XCTest 对该行为有直接断言；C1 仅补夹具 / Engine 级基线映射与快照维度断言 |
| 部分覆盖 | 相关断言存在，但缺基线维度（规则字段组合、otherKeys、告警、结构化证据、快照级状态） |
| 缺失 | 既有测试无对应断言，C1 须新增 |
| 待 Runner | 行为依赖 C3-C2（#151）或 Engine-B Runner 出证；审计阶段不判通过，不把 Engine 测试通过记为 Parser 验收 |

### 1.3 既有测试基线（Runner 已出证 / 待出证分列）

| 模块 | 测试源 | Runner 状态 |
|---|---|---|
| C3-B Reader / Decoder | `PlistReaderTests` 6 + `PlistDecoderTests` 9 + `PlistValueKindTests` 11 | ✅ run `43889143343`，236 例 0 失败 |
| C3-C1 RootHide Parser | `RootHideFilterParserTests` 32 + `FilterParseResultTests` 7 | ✅ run `43993649974`，275 例 0 失败 |
| C3-C2 Rootless Parser | `RootlessFilterParserTests` 22 | 🟡 代码冻结，#151 待 Runner |
| Engine-B 编排 | `FilterParseEngineTests` 19 | 🟡 代码冻结，待 Runner |
| C1/C2/B 链路 | 枚举 / 配对 / S1-05 / Environment / JBROOT / Directory 既有回归 | ✅ 历史 Runner 验收通过 |

## 2. 22 项逐条覆盖矩阵

| # | PARSE-ID | 来源 | 路线 | base | 预期状态 / 关键证据 | 既有覆盖 | C1 缺口与备注 |
|---|---|---|---|---|---|---|---|
| 1 | PARSE-003 | 夹具 `parse-binary` | roothide | Bin | `valid`；format `binary`；bundles `[com.bin.app]`；counts valid=1 | 部分 | Engine-B 仅断言 binary 格式信号透传到 Parser 入参；缺夹具级 valid 规则字段断言 |
| 2 | PARSE-006 | 夹具 `parse-bundles-wrong` | roothide | BadBundles | `type_mismatch`；reason `field_type`；skipped `Bundles` `not_array`（期望 `string[]`，观测 `string`）；快照 `partial` + 告警 `field_type` | 专项已覆盖 | RootHide `testBundlesNotArrayIsTypeMismatch`；缺快照级 status/counts/告警映射 |
| 3 | PARSE-007 | 夹具 `parse-classes-wrong` | roothide | BadClasses | `type_mismatch`；reason `field_type`；skipped `Classes` `element_type` index 0（观测 `number`） | 部分 | RootHide 元素类型用例存在；index 0 与观测类型基线证据待 C1 逐条核对 |
| 4 | PARSE-016 | 夹具 `parse-determinism` | roothide | Delta | `valid`；bundles `[com.delta.app]`、executables `[DeltaApp]` | 部分 | 重复解析等值与单类数组接受用例存在；多字段组合规则缺 |
| 5 | PARSE-011 | 夹具 `parse-empty-filter` | roothide | Empty | `valid`；空规则（bundles/classes/exec 均空） | 专项已覆盖 | RootHide `testEmptyFilterIsValidWithEmptyRule`；夹具级映射缺 |
| 6 | PARSE-008 | 夹具 `parse-executables-wrong` | roothide | BadExec | `type_mismatch`；reason `field_type`；skipped `Executables` `not_array`（观测 `string`） | 部分 | Executables 元素错误有断言；`not_array` 分支待 C1 核对补全 |
| 7 | PARSE-013 | 夹具 `parse-invalid-plist` | roothide | Broken | `parse_failed`；reason `invalid_plist`；Decoder 失败短路，Parser 零调用；快照 `partial` + 告警 `invalid_plist` | 专项已覆盖 | Engine-B `testDecoderFailureShortCircuitsParser`；夹具元数据级 counts/告警映射缺 |
| 8 | PARSE-011 | 夹具 `parse-missing-fields` | roothide | Sparse | `valid`；稀疏字段容忍，空规则合法 | 部分 | 空规则合法有断言；缺稀疏字段容忍基线用例 |
| 9 | PARSE-005 | 夹具 `parse-missing-filter` | roothide | NoFilter | `type_mismatch`；reason `filter_missing`；skipped `Filter`（期望 `object`，观测 `missing`） | 专项已覆盖 | RootHide `testFilterMissingIsTypeMismatch` / `testFilterNullIsTreatedAsMissing`；夹具级缺 |
| 10 | PARSE-012 | 夹具 `parse-multi-rule` | roothide | Multi | `valid`；bundles `[com.a.app, com.b.app, com.c.app]`、classes `[ClassX, ClassY]`、executables `[ProcP, ProcQ]` | 部分 | 单类数组接受有断言；三字段组合规则缺 |
| 11 | PARSE-014 | 夹具 `parse-partial-corrupt` | roothide | Good / Bad | Good `valid`（bundles `[com.good.app]`）；Bad `parse_failed`；counts valid=1、parse_failed=1；快照 `partial` + `partial_parsing` | 部分 | Engine-B 五桶混合计数有断言；双记录 good/corrupt 夹具与告警映射缺 |
| 12 | PARSE-015 | 夹具 `parse-rootless-model` | rootless | RL | `valid`；bundles `[com.example.app]`、executables `[rlapp]`（小写规范化）；otherKeys `[Classes, CoreFoundationVersion, IsTweakManager]`；`isTweakManager=null`；classes 恒空、CFV 恒 null | 部分 + 待 Runner | C3-C2 `testUnknownRouteFieldsGoToOtherKeysNotJudged` 同根同期望已断言；Engine/夹具级映射缺；#151 未出证前不判通过 |
| 13 | PARSE-009 | 夹具 `parse-versions` | roothide | Range | `valid`；CFV `{mode: range, min: 1500, max: 1700}` | 专项已覆盖 | RootHide `testCFVLengthTwoMapsToRangeMode`；具体数值断言夹具级缺 |
| 14 | PARSE-009 | 夹具 `parse-versions-wrong` | roothide | BadVer | `type_mismatch`；reason `versions_type`；skipped `CoreFoundationVersion`（观测 string 元素） | 专项已覆盖 | RootHide `testCFVStringElementIsTypeMismatch` reason `versions_type`；快照级缺。口径已核对：CFV 错误顶层 reason 保留 `versions_type`，不归 `field_type` |
| 15 | PARSE-001 | 夹具 `parse-xml-valid` | roothide | Example | `valid`；bundles `[com.example.app]`、classes `[ExampleClass]`、executables `[ExampleApp]`；CFV `{mode: max, max: 1600}`；`isTweakManager=false` | 部分 | 各单项（数组/CFV max/TWM false）有断言；组合基线缺 |
| 16 | PARSE-002 | 夹具 `parse-xml-valid` | roothide | Example | 同 15 重复样本；计数不重复累加 | 部分 | Parser 重复等值有断言；Engine 快照级深比较缺 |
| 17 | PARSE-012 | 夹具 `route-guard` | roothide | —（目录未定位） | `unresolved`；`sourceDirectory=null`；空模型；告警 `inventory_unresolved`；下游零调用；不回退扫描 | 专项已覆盖 | Engine-B `testUnresolvedSnapshotCallsNothing`；夹具元数据级映射缺 |
| 18 | PARSE-004 | 合成 `root-type` | roothide | RootType | `type_mismatch`；reason `root_type`；skipped `(root)`（期望 `object`，观测 `string`） | 专项已覆盖 | RootHide `testRootArrayIsTypeMismatch` / `testRootStringIsTypeMismatch`；合成构造级用例缺 |
| 19 | PARSE-005 | 合成 `filter-type` | roothide | FilterType | `type_mismatch`；reason `filter_type`；skipped `Filter`（观测 `array`） | 专项已覆盖 | RootHide `testFilterNonDictionaryIsTypeMismatch`；合成构造级用例缺 |
| 20 | PARSE-010 | 合成 `mixed-type` | roothide | Mixed | `type_mismatch`；reason `field_type`；skipped 同时含 `Bundles not_array` 与 `Classes element_type` index 0；错误证据全量保留 | **缺失** | 既有无组合错误证据用例；C1 须新增，断言两类 skippedField 同时在位 |
| 21 | PARSE-016 | 合成 `determinism` | roothide | Delta | `valid`；相同 plist 重复解析：规则、归类、计数、otherKeys、skippedFields 深比较一致 | 部分 | Parser 重复等值有断言；Engine 快照级深比较缺 |
| 22 | PARSE-012 | 合成 `route-isolation` | nil / unknown | — | 空结果；不读 plist、不调任一 Parser、不改快照；下游调用全 0 | 专项已覆盖 | Engine-B 未知路线与双路线隔离用例；合成基线级断言缺 |

## 3. 覆盖结论

### 3.1 已具备的基础

- 双路线 Parser 层行为：RootHide 严格类型、Rootless Codable 字段与 otherKeys、CFV 模式映射、重复解析等值、输入根不被改写，均有专项断言。
- Engine 层短路：非 paired / 未知路线 / unresolved 零调用、Reader/Decoder 失败短路、双路线不互调、五桶计数与不可变口径，Engine-B 19 例已固化。
- 基线夹具与 harness 只读可用：16 组 `environment/metadata.json` 与 `run.js` 比较维度可直接作为 C1 测试期望来源，不需要为通过测试另造相似夹具。

### 3.2 主要缺口（C1 待实现，详见 C1 测试规格）

1. **夹具/Engine 级映射缺失**：22 例中绝大多数停留在 Parser 单项断言，未经 `PluginFilterParseEngine` 走完整管线并对照 `metadata.json` 全维度比较。
2. **组合规则与组合错误**：多字段合法规则（#10/#15）、双记录 good/corrupt（#11）、混合类型错误证据（#20）无既有断言。
3. **快照级维度**：目录级 `status`（enumerated/partial/unresolved）、counts 五桶、`partial_parsing / inventory_unresolved` 告警、`otherKeysByBase / skippedFieldsByBase` 归集，缺基线级对照。
4. **Rootless 基线依赖**：#12（PARSE-015）专项断言已就位，但须等 #151 Runner 出证；C1 测试可先行落地，验收结论挂起。

### 3.3 审计阶段确认的口径（无偏差）

- CFV 字符串元素错误顶层 reason 为 `versions_type`（不归 `field_type`），与基线 PARSE-009-wrong 一致。
- Rootless `UnloadAfter` 仅内部解码保留，不入规则、不进 otherKeys（G-C3-5）；PARSE-015 otherKeys 三项不含 `UnloadAfter`。
- `not_parsed` 不是失败；`valid` 不推断 `loaded`；路线唯一来源 `snapshot.route`，不从路径/文件名/来源/plist 内容猜路线。

## 4. Runner 依赖与验收门禁（C-G1 ~ C-G7）

| 门禁 | 通过条件 | 当前状态 |
|---|---|---|
| C-G1 | Engine-B 外部 Runner 全部通过（Core Build 0 error/0 warning、E-B1~E-B6、既有回归、S1-05、App Build 与隔离） | 🟡 待 Runner |
| C-G2 | C3-C2 Rootless Parser Runner 通过（22 例专项 + 既有回归无损伤） | 🟡 #151 待 Runner |
| C-G3 | S1-06 22 项全部映射到 Swift XCTest，逐项对照基线期望 | ⬜ 待 Engine-C1 授权实现 |
| C-G4 | RootHide / Rootless 双路线隔离通过：失败不跨路线重试，未知路线零调用 | 🟡 Engine-B 专项已固化，待 C1 基线级复核 |
| C-G5 | 五态与 Counts 不变量通过（四桶和==parsed.count；notParsed==条目数；五桶和==总数） | 🟡 Engine-B Validator 已固化，待基线级复核 |
| C-G6 | 既有回归全部通过（Models / Environment / JBROOT / Directory / Enumeration / Pairing / Reader-Decoder / 双 Parser / Engine） | 🟡 待 Engine-C2 集中回归 |
| C-G7 | App Build 成功，架构隔离检查通过（无 GUI 私有解析、无服务装配泄漏、七方法协议未演进） | ⬜ 待 Engine-C2 Runner |

**硬门禁**：C-G1、C-G2 未通过前，不进入 Engine-C2 完整集成回归，不宣布 C3 双路线集成验收完成；即使 Rootless 相关 C1 测试通过，也不能替代 C-G2。

## 5. 未决与观察项（沿用 Engine-A/B）

- G-E2：Snapshot/Counts 归属 Core 中间层还是公共 Models（当前 Core，未提升）。
- G-C3-1：五态枚举落 Models 还是 Core 内部（当前 Core 中间层）。
- G-C3-2：公共 `ValidationReport.skippedFields` 是否结构化提升。
- 观察项：R6 未知枚举默认解码未真机实测；iOS17/Deployment Target 兼容；Rootless 无真机；Runner SDK 26.5 不作 Theos 16.5 兼容证据；真机 plist 格式/字段分布待只读取证；CFV 浮点版本号基线语义待复核。
- 本机 Linux 无 Swift 工具链：本审计所有"覆盖"判断基于源码与既有测试静态核对，不代表编译或测试通过。
