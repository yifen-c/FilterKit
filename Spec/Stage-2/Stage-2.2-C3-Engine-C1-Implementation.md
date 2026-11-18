# Stage 2.2-C3-Engine-C1：S1-06 基线映射测试实现记录

- 基线提交链：`1aa35c0`（C1-A 模型/加载器/注册表）→ `1b3c872`（C1-B 比较器/Parser 基线/PARSE-010）→ `6d29a09`（C1-C Engine 管线/快照不变量）。
- 授权边界：仅测试 Target 与测试配置；未改 Core / Models / Adapters / 七方法协议 / C1/C2/C3-B/C3-C1/C3-C2/Engine-B 冻结源码与 Stage 1 fixtures。
- 工具链状态：本机 Linux 无 Swift 工具链，本批未编译、未跑 Runner；下列"映射/断言"为静态落地结论，通过与否以外部 Runner 实际结果为准。

## 1. 交付文件清单（`Tests/Stage2/`，测试目标内部）

| 文件 | 职责 |
|---|---|
| `EngineC1-BaselineModels.swift` | 测试层路线/五态/规则/字段证据/来源描述模型；不进生产 Models |
| `EngineC1-BaselineLoader.swift` | 只读解码 `environment/metadata.json`，构造 `PluginPairingSnapshot` 与 plist 桩输入 |
| `EngineC1-BaselineRegistry.swift` | 22 项执行基线注册表（PARSE 一对多展开 `-A/-B/-C`），自校验 22 且唯一 |
| `EngineC1-ResultComparator.swift` | 全维度比较器：五态、顶层 reason、规则三数组与 CFV、otherKeys、字段证据、告警子集；规则期望装配 |
| `EngineC1-ParserBaselineTests.swift` | Parser 层 RootHide 夹具/合成基线、组合规则、确定性、PARSE-010 专项；Rootless 样本挂 pending |
| `EngineC1-EngineStubs.swift` | 路径协调 Reader/Decoder 桩；双 Parser 计数包装委托真实实现 |
| `EngineC1-EngineBaselineTests.swift` | Engine 管线基线、短路隔离、双记录计数不变量、上游保留与不可变、快照确定性 |

`Package.swift` Stage2Tests sources 追加上述 7 文件；Core sources 未变。

## 2. 22 项基线映射状态

| 矩阵 # | PARSE-ID | 路线 | 测试落点 | 状态 |
|---|---|---|---|---|
| 1 | PARSE-003 | roothide | Parser + Engine 夹具基线 | 已映射，run 44106064051 通过 |
| 2 | PARSE-006 | roothide | Parser + Engine；Bundles not_array 证据 | 已映射，run 44106064051 通过 |
| 3 | PARSE-007 | roothide | Parser + Engine；Classes element_type index 0 | 已映射，run 44106064051 通过 |
| 4 | PARSE-016 | roothide | Parser + Engine；确定性深比较 | 已映射，run 44106064051 通过 |
| 5 | PARSE-011 | roothide | Parser + Engine；空规则合法 | 已映射，run 44106064051 通过 |
| 6 | PARSE-008 | roothide | Parser + Engine；Executables not_array | 已映射，run 44106064051 通过 |
| 7 | PARSE-013 | roothide | Engine；Decoder 失败短路 parse_failed/invalid_plist | 已映射，run 44106064051 通过 |
| 8 | PARSE-011 | roothide | Parser + Engine；稀疏字段容忍 | 已映射，run 44106064051 通过 |
| 9 | PARSE-005 | roothide | Parser + Engine；Filter filter_missing | 已映射，run 44106064051 通过 |
| 10 | PARSE-012 | roothide | Parser + Engine；3 bundles / 2 classes / 2 exec 组合规则 | 已映射，run 44106064051 通过 |
| 11 | PARSE-014 | roothide | Engine；Good valid + Bad parse_failed，partial 归集 | 已映射，run 44106064051 通过 |
| 12 | PARSE-015 | rootless | Parser + Engine 样本；挂起已解除 | ✅ run 44106064051 通过 |
| 13 | PARSE-009 | roothide | Parser + Engine；CFV range 1500-1700 | 已映射，run 44106064051 通过 |
| 14 | PARSE-009-B | roothide | Parser + Engine；versions_type 保留，不归 field_type；观测类型词/下标口径待独立复核 | ⏸ pending_independent_review |
| 15 | PARSE-001 | roothide | Parser + Engine；全字段 + CFV max 1600 + TWM false | 已映射，run 44106064051 通过 |
| 16 | PARSE-002 | roothide | Engine；重复样本计数不重复累加 | 已映射，run 44106064051 通过 |
| 17 | PARSE-012 | roothide | Engine；unresolved 空快照 + inventory_unresolved，零调用 | 已映射，run 44106064051 通过 |
| 18 | PARSE-004 | roothide | Parser 合成；root_type，(root) object/string | 已映射，run 44106064051 通过 |
| 19 | PARSE-005 | roothide | Parser 合成；filter_type，Filter object/array | 已映射，run 44106064051 通过 |
| 20 | PARSE-010 | roothide | **专项补缺**；Bundles not_array + Classes element_type index 0 同时在位 | 已映射，run 44106064051 通过 |
| 21 | PARSE-016 | roothide | Parser 合成；重复解析深比较一致 | 已映射，run 44106064051 通过 |
| 22 | PARSE-012 | unknown | Engine；未知路线 notParsed unknown_route，下游零调用 | 已映射，run 44106064051 通过 |

## 3. 分组覆盖

- **Parser 层**：RootHide 夹具与合成样本逐条对照注册表 + metadata；组合规则（multi-rule、xml 全字段）；重复解析等值；输入根不被改写由既有 C3-C1 专项保持。
- **PARSE-010 混合类型证据**：整份 `type_mismatch`、`rule == nil`、顶层 `field_type`；两条字段证据全量保留并核对 key/reason/expected/observed/index；CFV `versions_type` 语义未被重新解释。
- **Engine 层**：快照状态、五桶计数、条目归集、otherKeys、告警子集；非 paired / 未知路线 / unresolved 零调用矩阵基线核对；Reader 失败、Decoder 失败短路；上游 unknownItems 原样保留；上游快照不可变；两次解析快照深比较一致；集成校验器不变量全过。
- **Rootless**：PARSE-015 组合样本 `XCTSkipIf` 挂起已解除；run `44106064051` 实际执行并通过（C-G2 已出证）。

## 4. 计数纪律（报告口径，Runner 回填）

- S1-06 基线执行项：**22**（不增不减；PARSE 编号一对多展开）。
- XCTest 实际执行数、专项断言数、集成场景数：由 Runner 结果分列填入，不与 22 相加。
- 既有回归（Models/Environment/JBROOT/Directory/Enumeration/Pairing/Reader-Decoder/双 Parser/Engine-B）无本批改动，回归结论归 Engine-C2 集中验证。

## 5. 观察与待复核项

- PARSE-009-B（CFV 字符串元素）字段证据的观测类型词与元素下标口径，与基线报告粗粒度记录存在待复核差异；本批只冻结 key / reason / expectedType，观测类型/下标留待 Runner 对照。
- C-G1（Engine-B Runner）、C-G2（C3-C2 Runner #151）未出证前，不进入 Engine-C2 完整集成回归，不宣布双路线集成验收。
- 未决沿用：G-E2 Snapshot/Counts 归属、G-C3-1 五态枚举归属、G-C3-2 skippedFields 结构化提升、G-C3-4 Adapter 签名演进、G-C3-5 UnloadAfter 导出归属。
