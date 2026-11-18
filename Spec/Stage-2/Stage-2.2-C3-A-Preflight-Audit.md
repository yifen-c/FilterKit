# Stage-2.2-C3-A：Filter Parser 前置只读审计报告

> 批次定位：Stage 2.2-C3 第一步（前置设计评审）。基线提交 `59ee5f8`（Stage 2.2-C 验收通过）。
> 状态：**只读审计完成 / 契约待冻结**；本文件只记录审计事实、复用面、缺口与待评审项，**未落地 Swift 代码**；C3-B 起逐批单独授权。
> 关联规格：[S1-06-Plist-Filter-Parsing.md](../Stage-1/S1-06-Plist-Filter-Parsing.md)、[Stage-2.2-C3-Parser-Data-Contract.md](./Stage-2.2-C3-Parser-Data-Contract.md)、[Stage-2.2-Core-Models-Migration.md](./Stage-2.2-Core-Models-Migration.md)、[Stage-2.2-C2-Pairing-Contract.md](./Stage-2.2-C2-Pairing-Contract.md)。

## 1. 本轮授权边界

### 已允许并执行

- 只读审计 Stage 1 S1-06 规格、22 项 PARSE 基线、16 组离线夹具、Node harness（`Tests/S1-06/parser.js`、`run.js`、`report/`）。
- 只读核对现有 `Models/`、`Core/PluginPairing/`、`Adapters/` 协议与既有测试结构，梳理 C3 输入衔接面与可复用类型。
- 撰写本审计报告与 C3 Parser 数据契约冻结规格（设计层）。

### 禁止项（本轮均未触碰）

- 未修改任何源码、`Models/`、`Adapters/`、七方法协议、Stage 1 fixtures/harness/metadata 及既有 Swift 测试。
- 未编译、未执行 GitHub Actions Runner、未扫描真机、未读取未配对 plist、未修改任何 plist 或插件文件。
- 未进入插件启停、归属识别（S1-07/C3 之后批次）、服务层装配与 GUI。

## 2. S1-06 基线事实（权威行为基线，C3 迁移不得放宽）

### 2.1 基线规模

- 验收结论：Synthetic Fixture Validation Passed（2026-11-15，离线合成样本）。
- 用例：PARSE-001 ~ PARSE-017，**22 例执行**（部分编号含合成/双样本展开）；夹具 16 组落 `Tests/Fixtures/S1-06/`，输入 `environment.json` 与预期 `metadata.json` 分离，解析器不读 metadata。
- 回归保持：S1-01 15、S1-02 18、S1-03 15、S1-04 23、S1-05 15 全部 passed。
- harness：`Tests/S1-06/parser.js`（双路线解析）、`run.js`（用例编排与计数）、`report/S1-06-report.json`、`S1-06-acceptance.md`。Node harness 仅为行为基线参照，不迁入 App 运行时。

### 2.2 五态分类（封闭集，互斥）

| parseStatus | 含义 | 典型 reason |
|---|---|---|
| `valid` | 结构与类型通过本路线规则 | — |
| `parse_failed` | 字节不是合法属性列表；Rootless Codable 解码失败 | `invalid_plist` / `filter_missing` / `filter_type` / `field_type`（Rootless 解码失败口径） |
| `type_mismatch` | 结构在，但字段类型不符本路线规则 | `root_type` / `filter_missing` / `filter_type` / `field_type` / `versions_type` |
| `read_failed` | 文件读取失败/受限；与解析失败、不存在严格区分 | 上游 `readStatus` 原值（`access_denied` / `read_failed`） |
| `not_parsed` | 上游未配对/不确定/歧义，本次未解析 | 上游 `pairing` 与原因原样保留 |

> 读取失败 ≠ 解析失败 ≠ 插件不存在；四类原因互斥，计数与清单条目一致，`mutualLeakCount=0`。

### 2.3 RootHide 严格规则（parser.js `parseRootHide`）

- 根节点必须字典；`Filter` 必须存在且为字典。
- `IsTweakManager` 顶层可选；出现时必须布尔；缺失按 `false`。
- `Bundles / Classes / Executables` 必须字符串数组；`Bundles` 空指针元素容忍，`Classes / Executables` 空指针元素判不符。
- `CoreFoundationVersion`：数字数组；长度 1 → `{mode: max, max}`；长度 2 → `{mode: range, min, max}`；长度 0/3 或非数字元素 → 类型不符/长度线索。
- 任一类型不符 → **整份 plist `type_mismatch`**，不按字段静默跳过；不符字段保留期望/观测类型证据。
- 识别键：顶层 `Filter / IsTweakManager`；Filter 内 `Bundles / Classes / Executables / CoreFoundationVersion`；其余键入 `otherKeys`。

### 2.4 Rootless Codable 规则（parser.js `parseRootless`）

- 模型字段：`Filter.Bundles: [String]?`、`Filter.Executables: [String]?`、顶层 `UnloadAfter: Bool?`。
- 解码失败 → `parse_failed`；不套用 RootHide 严格类型规则。
- `Bundles / Executables` 输出统一 `lowercased()`；原始值由 plist 内容信号保留。
- `Classes / CoreFoundationVersion / IsTweakManager` 模型未覆盖，出现即入 `otherKeys`，不判解码失败；模型内不新增这些字段。
- 识别键：顶层 `Filter / UnloadAfter`；Filter 内 `Bundles / Executables`。
- C injector 宽松行为仅作兼容性风险记录，不进入本 Adapter；Rootless 真机实际走哪套实现属运行时取证事项。

### 2.5 空配置与证据口径

- 字段缺失：数组类 = `[]`、版本类 = `null`，告警 `field_missing`；空数组标注 `empty_array`；空字典 `Filter={}` 标注 `empty_filter`；空串元素保留并标注 `empty_element`，不静默剔除。
- `otherKeys`：未识别键名去重排序，只读记录，不臆测语义。
- 单插件失败不中断整轮；损坏条目进失败归类，兄弟条目照常 `valid`。
- 状态边界：`configured` 仅 `valid` 可在导出层映射；`loaded` 一律 `unknown`；不判来源归属。

### 2.6 基线告警/原因词表（parser.js 实际出现）

`root_type`、`filter_missing`、`filter_type`、`field_type`、`not_array`、`null_element`、`element_type`、`codable_type`、`versions_type`、`unsupported_length`、`versions_length_unhandled`、`invalid_plist`、`inventory_unresolved`、`partial_parsing`；观测类型词 `object / array / string / number / boolean / null / missing`。

## 3. 现有 Models 复用清单（冻结，C3 不改）

| 既有类型 | 位置 | C3 用途 |
|---|---|---|
| `FilterRule` | `Models/PluginModels.swift` | 解析成功的规则载体：`bundles / classes / executables / coreFoundationVersion / otherKeys`；**不重定义重复模型** |
| `CoreFoundationVersion` / `CoreFoundationMode` | 同上 / `ModelEnums.swift` | 版本约束 `max / range`，`min?/max?` |
| `ReportWarning` | `PluginModels.swift` | 条目级/快照级告警：`code / message / sourceStage` |
| `EvidenceBlock` | 同上 | 证据块复用；不新增自由字符串证据协议 |
| `UnknownItem` | 同上 | 未配对/归集条目载体：`path/base/reason/sourceStage/detail` |
| `PluginFileEvidence` | `Models/PluginEnumeration/` | 配对两侧条目证据原样引用（`path/name/extension/kind/exists/readable/.../entryStatus`） |
| `PluginPairingSnapshot` | `Core/PluginPairing/` | C3 唯一上游快照：`route/sourceDirectory/status/records/unknownItems/counts/warnings` |
| `PluginPairingRecord` | 同上 | 单条配对记录：`category/pairing/pairingKey/dylib/plist/candidates/reason/basis/evidence/warnings` |
| `PairingCategory` / `PairingStatus` / `Pairing` | 同上 / `ModelEnums.swift` | 五桶分类、目录级状态、公共配对四值，原始值冻结 |

## 4. 上游衔接面核对（C2 → C3）

- C3 输入为 C2 `PluginPairingSnapshot`；仅 `category == .paired`（`pairing == .paired`）记录进入解析管线；`missing_plist / orphan_plist / ambiguous / uncertain` 原样透传 `notParsed`，保留上游 `reason / basis / candidates`，C3 不重新配对、不补列、不升级归类。
- plist 路径取自记录 `plist.path`；plist 字节、格式（xml/binary/unknown）、读取状态由 Reader 层经离线夹具/后续只读读取注入；枚举证据结构本身不在 C3-A 扩展。
- 目录未定位（快照 `status == .unresolved` 或 `sourceDirectory == nil`）→ 空模型 + `inventory_unresolved` 告警，禁止回退扫描其他路线目录。
- 现有 Core 编排轮廓 `CoreServices.PluginParseService` 仅为接口轮廓；服务实现挂 `Core/PlistParser/`，不直接实例化具体 Adapter。

## 5. 缺口与待评审项（实现批次前补设计，本轮不决策改 Models/协议）

| 编号 | 缺口 | 现状 | C3-A 处置 |
|---|---|---|---|
| G-C3-1 | 解析失败三态/五态的强类型表达 | `ValidationReport.status` 为自由 `String`；无解析状态枚举 | 契约提案内部 `FilterParseStatus` 五态封闭枚举；落 Models 还是留 Core 内部，C3-B 实现前评审（对齐迁移总规格 §7.2「解析失败三态内部表达」缺口） |
| G-C3-2 | 结构化跳过字段证据 | `ValidationReport.skippedFields: [String]`；Stage1 证据为 `{key, reason, expectedType, observedType, index?}` | 契约提案内部 `SkippedField` 结构；是否扩展公共 `ValidationReport` 延后到 C3-D 协议/Models 评审，本轮不改 |
| G-C3-3 | plist 内容信号载体 | `PluginFileEvidence` 无 payload/format/readStatus 字符串字段 | Reader/输入层承载内容信号；不在 C3-A 扩枚举证据结构 |
| G-C3-4 | Adapter 解析签名证据载体 | `parseFilter(_:) -> FilterRule?` 仅返回规则，无状态/告警/跳过字段载体 | 列入协议演进缺口；C3-D 前提交评审，本轮不改七方法协议 |
| G-C3-5 | Rootless `UnloadAfter` 归属 | 公共 `FilterRule` 无 `unloadAfter` 字段 | 作为路线特有线索由内部结果/`otherKeys` 承载；不扩公共 `FilterRule`，待导出层评审 |
| G-C3-6 | 模块目录命名 | 迁移总规格 §5 用 `Core/PlistParser/`；外部建议 `Core/PluginParser/` | 定稿沿用迁移总规格 `Core/PlistParser/`，避免平行结构 |

## 6. 代码面只读核对结果

- 仓库内无既有 Swift Filter Parser 实现；`Core/` 现有解析相关代码仅 `Environment/VersionParser.swift`（版本号解析，与 plist Filter 无关）。
- `Adapters/ElleKitAdapter.swift` 七方法协议冻结；`RootHideAdapter / RootlessAdapter` 为骨架，未实现 `parseFilter`。
- 既有 Stage2 测试 210 例（B 回归 91 + C1 23 + C2-A 12 + C2-B 37 + C2-C 32 + S1-05 映射 15）保持 Runner 验收通过；C3 新增测试挂现有 `Stage2Tests` target，不另建 Swift target。

## 7. 未决观察项（沿用，不在 C3 收口）

- 2.2-A R6 未知枚举原始值默认解码行为未真机实测。
- 真机 plist 格式（XML/Binary 占比）、Filter 字段真实分布与非常规键、RootHide 严格规则与既有插件兼容性、Rootless Codable 解码失败分布、受限 plist 读取表现、进程内命中行为，均待真机只读取证；离线为合成样本。
- Deployment Target / iOS 17 兼容、Rootless 无真机、Runner SDK 版本不作为 Theos 16.5 兼容证据。

## 8. 后续授权待办（C3-B 及以后，本轮不启动）

- C3-B：Plist Reader / Decoder 与读取/解码测试。
- C3-C：RootHide / Rootless Parser 与 S1-06 22 项基线映射测试（测试 target 内独立 loader，范式参照 `S105FixtureLoader.swift`）。
- C3-D：Parser 集成、Adapter 签名/Models 缺口评审、Runner 全量回归。
- 归属识别（S1-07）、统一导出（S1-08）、GUI、权限探针、真机验证均在 C3 之后，须另行授权。
