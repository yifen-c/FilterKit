# Stage-2.2-C-Audit.md — 2.2-C 前置只读核对审计（Enumeration / Pairing / Parser）

> 状态：**只读审计（设计层）**。本轮仅读取与分析，**不修改源码、Models、Adapters、七方法协议、Stage 1 Fixtures、Harness 或测试文件**；不编译、不运行 Runner、不扫描真机、不进入插件写入与启停开发。
> 授权口径：用户附件《这次 B5 可以正式收尾了…》§7「授权 Stage 2.2-C 第一步：只读审计与实现规格冻结」。C1~C4 编码、Models/协议演进与 Runner 执行均须在本规格冻结后单独授权。
> 上游基准：`Stage-2.2-Core-Models-Migration.md` §4/§6/§7/§9/§10、`Stage-2.2-B5-Integration-Regression.md`（B5 已验收通过，run `43817618222`，91 例 0 失败）；Stage 1 基线 `Tests/S1-04~06` harness、`Tests/Fixtures/S1-04~06/`、`Tests/S1-04~06/report/*.json`（只读，禁止改动）。

## 1. 审计快照（2026-11-16，开工前只读核对）

### 1.1 仓库现状（HEAD `b3ea6f6`）

| 层 | 现状 | 说明 |
|---|---|---|
| Models（5 文件） | `EnvironmentAdvisor.swift`、`EnvironmentModels.swift`、`ModelEnums.swift`、`PluginModels.swift`、`ReportEnvelope.swift` | 公共模型，无路线依赖；2.2-A 21 项 Codable 回归冻结 |
| Adapters（3 文件） | `ElleKitAdapter.swift`（七方法协议）、`RootHide/RootHideAdapter.swift`、`Rootless/RootlessAdapter.swift` | 双路线桩实现；路线规则封闭在 Adapter 内；隔离三向已通过 |
| Core（20 Swift） | Environment 3、JBRoot 7、ElleKit 6、Pipeline 3、`CoreServices.swift` 1 | B1~B5 已落地；`Core/PluginScanner/`、`Core/PluginPairing/`、`Core/PlistParser/`、`Core/OwnershipResolver/`、`Core/ReportExporter/` 仅 `.gitkeep` 占位 |
| Stage2 测试（8 文件，91 例） | ModelsCodable 21 / Environment 7 / CandidateCollection 10 / Validation 18 / Directory 15 / B5Integration 10 / FixtureComparison 4 / Determinism 6 | 71 冻结回归 + 20 B5 附加；C 阶段新增测试不得改动这 8 个文件的既有方法与断言 |
| CI | `.github/workflows/filterkit-build.yml` 六 Job（environment→build→test→isolation→app-build→artifact），`workflow_dispatch` 手动触发 | test Job 现为整包 `swift test`，未分阶段 `--filter` 出证 |

### 1.2 Stage 1 C 段基线（60 项，全部离线通过）

| Stage | harness | 夹具组数 | 报告口径 | 编号前缀 | 归属批次 |
|---|---|---:|---|---|---|
| S1-04 Plugin Enumeration | `enumerator.js` / `run.js` | 13 | 23/23，0 失败 | `ENUM-001~015`（含 3 例 synthetic） | 2.2-C1 |
| S1-05 Plugin Pairing | `pairing.js` / `run.js` | 13 | 15/15，0 失败 | `PAIR-001~013`（含 2 例 synthetic） | 2.2-C2 |
| S1-06 Plist/Filter Parsing | `parser.js` / `run.js` | 16 | 22/22，0 失败 | `PARSE-001~017`（含 5 例 synthetic） | 2.2-C3 |
| **合计** | — | **42** | **60/60** | — | C4 集成回归复验 |

- 基线完整性：`Tests/S1-04~06` 与 `Tests/Fixtures/S1-04~06/` 自 Stage 2.1 骨架提交 `74e2738` 以来无改动；本轮审计未触碰。
- 夹具形态：每组 `environment.json`（输入信号，只读）+ `metadata.json`（`expected` 基线 + `expectedWarnings`）；S1-06 另有 `plists[]` 内容信号与 `pairing` 上游快照。

### 1.3 附件示意与仓库现状的差异核对

附件 §3 给出的结构为**拟议设计示意**（附件 §3 自述「尚未实际读取 ZIP 内源码，不是当前仓库已存在的文件或可直接复制的 API 契约」）。逐项核对结论：

| 附件示意 | 仓库现状 | 处置口径 |
|---|---|---|
| `Core/PluginScanner/Enumeration/PluginEnumerator.swift`、`DylibEnumerator.swift`、`PlistEnumerator.swift` | 占位目录 `Core/PluginScanner/`（仅 `.gitkeep`）；迁移规格 §5 规划 `PluginEnumerator` 单文件编排 | 文件细分以 C1 实现子规格为准；枚举规则以 S1-04 `enumerator.js` 为唯一行为基准，不采用附件示意的 dylib/plist 双枚举器拆分 |
| `EnumerationResult { dylibFiles, plistFiles, unknownItems, warnings }` | Stage 1 清单为 `items[]`（五类 `kind`：dylib/plist/directory/symlink/other）+ `unknownItems[]` + `counts` | 中间结果须承载完整条目证据（路径/名/扩展名/分类/软链/元数据/条目状态），不能只分 dylib/plist 两列；目录/软链/其他经 `unknownItems` 保留 |
| `Pairing { paired, missing_plist, orphan_plist, missing_dylib }` 四态 | 冻结 `Pairing` 枚举即此四值（`ModelEnums.swift:73-78`），2.2-A 测试锁定原始值 | **不新增** `ambiguous`/`uncertain` 配对枚举值；歧义/不确定按 S1-05 口径落中间报告 `ambiguous[]`/`uncertain[]`，最终模型经 `UnknownItem.reason` 承载（对齐 `exporter.js:147-151`） |
| C2 测试「多候选 ambiguous / evidence」 | S1-05 `PAIR-010` 五态互斥计数含 `ambiguous`、`uncertain` | 中间报告保留五态；公共 `Pairing` 枚举四值不变；映射口径在 C2 子规格冻结 |
| `RootlessFilterData { Bundles, Executables, UnloadAfter }` | 迁移规格 §6.2：解码中间结构为 Parser 内部类型，不进入公共 Models | Rootless Codable 中间类型内部化；公共结果映射到现有 `FilterRule`；字段命名以仓库 Models 与 S1-06 夹具为准 |

## 2. 现有 Models 承载核对（C 段所需 vs 现有）

### 2.1 可直接复用的冻结类型

| 现有类型 | 字段 | C 段用途 |
|---|---|---|
| `FilterRule` | `bundles/classes/executables: [String]`、`coreFoundationVersion: CoreFoundationVersion?`、`otherKeys: [String]` | C3 解析结果规则载体，与 S1-06 `filter` 结构同构 |
| `CoreFoundationVersion` | `mode: CoreFoundationMode`（max/range）、`min/max: Int?` | C3 版本约束；缺失 `nil` |
| `Pairing` | `paired / missing_plist / orphan_plist / missing_dylib` | C2 公共配对分类；原始值冻结，不可增删 |
| `UnknownItem` | `path/base/reason/sourceStage/detail: [String:String]` | 枚举其他类条目、配对歧义/不确定、解析未解析条目归集 |
| `ReportWarning` | `code/message/sourceStage` | 各阶段告警统一载体（D3 口径） |
| `ValidationReport` | `status: String`、`warnings: [String]`、`skippedFields: [String]` | C3 校验报告骨架；结构化证据缺口见 §3.2 |
| `PluginCandidate`（Adapter 层） | `base/dylibPath/plistPath/readable/warnings` | 七方法协议 `scanPlugins()` 返回类型；C1/C2 候选传递的现有契约 |

### 2.2 现有 Models 缺口（本轮只记录，不修改）

| 编号 | 缺口 | Stage 1 基准 | 现状承载 | 评审要求（实现批次前补设计） |
|---|---|---|---|---|
| G-C1 | 枚举条目证据模型 | S1-04 `items[]`：`path/name/extension/kind/exists/readable/isSymlink/symlinkTarget/symlinkState/realpath/size/hash/hidden/entryStatus` | `PluginCandidate` 仅 `base/dylibPath/plistPath/readable/warnings`，无扩展名/分类/软链/元数据/隐藏/条目状态 | **已冻结**：`PluginFileEvidence` + `PluginFileKind`/`PluginEntryStatus`，见 `Stage-2.2-C-Enumeration-Models-Contract.md` §3 |
| G-C2 | 枚举清单中间报告 | S1-04 `PluginInventory`：`route/sourceDirectory/enumeration{recursive,status,warnings}/items/unknownItems/counts/warnings` | 无对应快照类型；`CoreServices.PluginScanService.candidates() -> [PluginCandidate]` 仅返回扁平候选 | **已冻结**：`PluginInventorySnapshot` + `EnumerationStatus`/`PluginKindCounts` + 输入信号快照，见契约 §4 |
| G-C3 | 配对中间报告 | S1-05 `PairingReport`：`pairs/missingPlist/orphanPlist/ambiguous/uncertain/counts/status/warnings` | 无对应快照类型；`Pairing` 枚举不含 `ambiguous/uncertain` | **已冻结**：`PluginPairingSnapshot` + `PluginPairingRecord`/`PairingCategory`/`PairingStatus`/`PluginPairingCounts`，五态互斥、歧义/不确定不扩 `Pairing` 枚举，见 `Stage-2.2-C2-Pairing-Contract.md` |
| G-C4 | 解析五态与结构化字段证据 | S1-06 `parseStatus` 五态 `valid/parse_failed/type_mismatch/read_failed/not_parsed`；`reason`；`plistFormat`；`readStatus`；`isTweakManager`；`skippedFields[]{key,reason,expectedType,observedType,index?}`；`notParsed[]` | `ValidationReport.status` 为自由字符串；`skippedFields: [String]` 为降级文本；无解析报告快照、无五态封闭集表达 | C3 子规格评审：是否新增强类型解析状态枚举（取值与 Stage 1 报告逐字一致）与结构化跳过字段模型；旧 `skippedFields: [String]` 的 Codable 兼容口径须按 2.2-A R6 谨慎处理，缺省解码不报错、不补空串 |
| G-C5 | Rootless 解析中间模型 | S1-06 §4.3：`Bundles/Executables [String]?`、`UnloadAfter Bool?`；取值 lowercased；未覆盖键入 `otherKeys` | 公共 Models 无 Rootless 专用结构 | 按迁移规格 §6.2，Codable 中间结构为 Parser 内部类型，不进公共 Models；C3 子规格冻结内部结构与 `FilterRule` 映射 |
| G-C6 | 哈希/元数据口径 | S1-04：`size/hash` 不可获取 = `null`，失败记 `metadata_unavailable`/`read_failed`，不阻断枚举 | 现有模型无 `size/hash/realpath` 条目位 | 随 G-C1 条目结构一并评审；离线夹具为合成信号，真机可取性留 2.5 |

## 3. 协议与 Core 服务轮廓核对

### 3.1 七方法协议（冻结基准，本轮不改）

`Adapters/ElleKitAdapter.swift:64-75`：`getEnvironment() -> JailbreakEnvironment`、`resolvePaths() -> EnvironmentPaths`、`scanPlugins() -> [PluginCandidate]`、`readPlugin(_:) -> Plugin?`、`validatePlugin(_:) -> ValidationReport`、`parseFilter(_:) -> FilterRule?`、`resolvePath(_:) -> AbsolutePath`。

- 服务轮廓（`Core/CoreServices.swift`）：`EnvironmentService / PathResolutionService / PluginScanService / PluginParseService / OwnershipService / ReportExportService / AdapterResolver`。
- 职责边界（对齐附件 §4 与迁移规格 §2）：**Adapter** = 路线相关环境与文件访问；**Core** = 枚举/配对/解析业务编排与规则；**Models** = 统一数据结构；**GUI** = 只展示 Core 返回数据。Core 不直接操作文件系统、不另写扫描器；CLI 与 GUI 共用同一套 Core。

### 3.2 现有协议签名与 C 段需求的差距

| 协议方法 | C 段承载 | 差距 |
|---|---|---|
| `scanPlugins() -> [PluginCandidate]` | S1-04 清单 + S1-05 配对候选 | 扁平 `[PluginCandidate]` 不承载目录级状态、五类计数、`unknownItems`、条目软链/元数据证据；是否演进签名列入 C1/C2 协议评审 |
| `readPlugin(_:) -> Plugin?` | S1-05 配对关系 + 在位/可读证据组装 Plugin 骨架 | 输入 `PluginCandidate` 与配对快照的衔接方式待 C2 设计；归属/版本留 2.2-D |
| `validatePlugin(_:) -> ValidationReport` | S1-06 结构/类型校验 | 五态状态与结构化跳过字段缺口见 G-C4 |
| `parseFilter(_:) -> FilterRule?` | S1-06 双路线 Filter 解析 | 返回 `FilterRule?` 不携带 `parseStatus/reason/plistFormat/readStatus/otherKeys` 等证据；失败原因经 `ValidationReport` 表达，缺口见 G-C4 |

### 3.3 协议演进纪律

- 迁移规格 §4.3：协议层以现有 `ElleKitAdapter` 契约为唯一基准，**不平行创建第二套接口**；确需演进的方法列入缺口清单，在对应批次实现前走协议评审，明确输入/输出/错误口径，不得引入任何写入方法。
- `AdapterResolver` 具体实现与两服务装配仍延后（B5 已记录）；C 阶段 Core 不实例化具体 Adapter，隔离三向口径沿用 `scripts/check-adapter-isolation.sh`。

## 4. Stage 1 行为基线抽取（C 段不可改变的规则）

### 4.1 枚举（S1-04，23 例）

- 扫描范围：单层非递归（`recursive=false`），嵌套条目不进入清单；只消费 S1-03 确认目录，上游未定位 → `unresolved` + `directory_unresolved`，禁止回退 `/var/jb` 或文件根。
- 分类：扩展名大小写敏感（`strcmp` 口径），仅 `.dylib` 归 dylib、`.plist` 归 plist；其余归 `other`；目录/软链独立分类；软链标志与扩展名正交。
- 排序：按文件名字母序（大小写敏感），清单确定性；同名条目按完整路径保留，不按基名合并。
- 文件名原样保留，不改写大小写/空格/扩展名；点开头文件列入并标记 `hidden=true`。
- 软链记录自身（`isSymlink/symlinkTarget/symlinkState`），不跟随目标继续枚举；断链独立记录。
- 异常分层：目录级 `enumerated/partial/enumeration_failed/unresolved`；条目级 `ok/access_denied/metadata_unavailable/read_failed/not_found`；单条目异常不中断整轮；访问失败 ≠ 不存在。
- 状态边界：不产出配对/解析/加载结论；`loaded` 一律 `unknown`，不由文件在位推断。

### 4.2 配对（S1-05，15 例）

- 方向：dylib 驱动；剥离 `.dylib` 派生 `<base>.plist`；同目录、精确文件名、大小写敏感匹配；不读 plist 内容、不模糊匹配、不 lowercase fallback。
- 五态互斥：`paired / missing_plist / orphan_plist / ambiguous / uncertain`；计数与条目清单一致，无重复归属（`mutualLeakCount=0`）。
- `ambiguous`：同基名多候选 plist，列出候选路径，不任选；`uncertain`：条目访问/元数据受限或软链断链/目标受限，留置对应 plist，不判缺失或孤儿。
- 跨目录/外目录陷阱条目不参与配对；隐藏文件按规则配对并保留隐藏标记；非标准扩展名（`.txt/.deb/.DYLIB` 等）不进候选。
- 只用 S1-04 清单；上游未定位 → `unresolved` + `inventory_unresolved`；相同清单重复配对结果确定。

### 4.3 解析（S1-06，22 例）

- 只消费 S1-05 已建立的 `paired` 条目；其余条目原样携带为 `notParsed`，保留上游配对原因，不重新配对、不补列。
- 五态互斥且必须区分：`valid`（结构与类型通过本路线规则）/ `parse_failed`（字节不是合法属性列表，`invalid_plist`）/ `type_mismatch`（结构在但类型/字段不符）/ `read_failed`（读不出内容）/ `not_parsed`（上游未配对/不确定/歧义）。读取失败 ≠ 解析失败 ≠ 插件不存在。
- **RootHide 严格规则**：根节点字典；`Filter` 字典；`IsTweakManager` 出现时必须 Bool；`Bundles/Classes/Executables` 字符串数组；`CoreFoundationVersion` 数字数组长度 1 或 2；任一类型不符整份 `type_mismatch`，不按字段静默跳过；跳过字段保留期望/观测类型。
- **Rootless Codable 规则**：`Filter.Bundles/Executables [String]?`、顶层 `UnloadAfter Bool?`；解码失败 → `parse_failed`；未覆盖键（`Classes/CoreFoundationVersion/IsTweakManager` 等）入 `otherKeys`，不判失败；`Bundles/Executables` 取值规范化 lowercased，原始值由信号保留；不套用 RootHide 严格规则。
- 空配置区分：字段缺失、空数组、空字典分别标注，不混为一类；多规则条件全部保留、顺序确定；单条失败不影响兄弟条目。
- 路线隔离：`roothide` → RH 严格；`rootless` → RL Codable；`rootful/unknown` 不自动套用任一规则，结果进不确定线索，不强行选边。
- 状态边界：`configured` 仅由 `parseStatus=valid` 映射（2.2-D 导出阶段）；`loaded` 恒 `unknown`；不判断来源归属（2.2-D）。

## 5. 缺口与待评审事项汇总（实现授权前冻结）

1. **Models 增补评审**（G-C1/G-C2/G-C3/G-C4/G-C6）：新增条目结构、枚举清单快照、配对快照、解析报告/状态模型的字段、Codable 口径与 Stage 1 对照；必须先在 C 子规格评审冻结再编码；不重设计既有 Models，不改变冻结枚举原始值。
2. **协议演进评审**（§3.2）：`scanPlugins/readPlugin/validatePlugin/parseFilter` 是否需要承载中间报告与证据；评审前不改七方法协议；无写入方法。
3. **测试接线**：新增 Swift 测试归入 `Tests/Stage2/`，在批次子规格中更新 `Package.swift` testTarget sources；测试编号保留 Stage 1 前缀（`ENUM-/PAIR-/PARSE-`）以便回溯；既有 8 个测试文件与 91 例保持原样。
4. **CI 分阶段出证**：test Job 整包 `swift test` 的现状沿用；C 批次执行时是否补 `--filter` 分组出证，在执行授权时确认（B5 遗留观察项）。
5. **夹具深比较**：沿用 B5 `B5FixtureComparisonTests` 模式——离线解码 `environment.json`，调用 Core 离线注入适配器，与 `metadata.json` 基线及 `report.json` `cases[].result` 深比较（`generatedAt` 除外）；不复制第二份基线，不依赖 Node。

## 6. 暂停点与后续门禁

- 本轮交付：本审计报告 + `Stage-2.2-C-Enumeration-Pairing-Parser.md` 冻结规格；无源码/Models/协议/夹具/harness/测试改动。
- 后续顺序（须逐批单独授权）：**C1 枚举**（S1-04 23 例）→ **C2 配对**（S1-05 15 例）→ **C3 解析**（S1-06 22 例）→ **C4 集成回归**（三模块链 + 夹具深比较 + 双 Adapter 隔离 + Core/App Build）。
- 批次门槛未达成不进入下一批次；任一批次发现行为与 Stage 1 预期不符，先冻结问题、回退对应夹具核对，不在编码中放宽规则。
- 本轮**不得**宣布：插件可被真机枚举/配对/解析；RootHide GUI 具备越狱目录访问权限；Rootless 真机兼容；插件已配置/已加载；任何写入、启停、注入能力。
