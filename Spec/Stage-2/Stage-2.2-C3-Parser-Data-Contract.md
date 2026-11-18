# Stage-2.2-C3-Parser-Data-Contract.md — Filter plist 解析快照 / 结果 / 错误分类数据契约冻结

> 批次：Stage 2.2-C3 第一步（C3-A，前置设计评审）。输入基线：C2 验收提交 `59ee5f8`、S1-06 离线基线（`Tests/Fixtures/S1-06/`、`Tests/S1-06/parser.js`、`run.js`、`report/`）、C2 配对契约 `Stage-2.2-C2-Pairing-Contract.md`、迁移总规格 `Stage-2.2-Core-Models-Migration.md` §5/§6/§7。
> 状态：**契约冻结（设计层）**；本文件只定义字段、类型、Optional 语义、归类口径、路线规则与 Codable/确定性要求，**未落地 Swift 代码**；C3-B 起逐批单独授权。
> 审计事实见 [Stage-2.2-C3-A-Preflight-Audit.md](./Stage-2.2-C3-A-Preflight-Audit.md)。

## 1. 冻结总则

1. C3 只解析 **C2 已成功配对** 的 plist；不重新寻找 plist、不重新配对、不补列未配对条目。C2 职责到此为止。
2. C3 是纯规则层：输入 C2 配对快照 + Reader 层注入的 plist 内容信号，输出解析中间快照；不重新访问文件系统（离线夹具除外），不向 C2 回写字段，不组装最终 `Plugin`，首版解析快照不进 `ReportEnvelope`。
3. 双路线规则独立实现、互不调用；禁止把 Rootless Codable 口径套到 RootHide 严格校验，反之亦然。未知/rootful 路线不自动套用任一开放路线规则。
4. 五态互斥：同一插件条目在任一结果中只落入一个解析状态；计数总和与明细一致；读取失败、解析失败、类型不符、未配对四类原因不得合并或降级。
5. 只读边界：不改写 plist 字节、不写插件文件、不执行 dpkg、不调用注入接口、不扫描真实越狱目录、不读取未配对 plist；解析成功 ≠ 已配置生效 ≠ 已加载。
6. 中间结果优先复用既有冻结类型；确需新增的内部类型按 §5 给出字段与口径冻结后再实现，不在编码中临时新增枚举值或改变既有状态语义。

## 2. 决策定稿表（PC3-1 ~ PC3-14）

| 编号 | 决策点 | 定稿口径 |
|---|---|---|
| PC3-1 | 输入边界 | 唯一上游为 `PluginPairingSnapshot`（`route/sourceDirectory/status/records/unknownItems/counts/warnings`）；Reader 层额外注入 plist 内容信号（路径/格式/读取状态/解码对象） |
| PC3-2 | 解析候选 | 仅 `category == .paired`（`pairing == .paired`）记录进入解析管线；其余四桶与歧义/不确定记录原样进 `notParsed`，保留上游 `reason/basis/candidates` |
| PC3-3 | 目录未定位 | 快照 `status == .unresolved` 或 `sourceDirectory == nil` → 空解析模型 + 告警 `inventory_unresolved`；禁止回退扫描其他路线目录 |
| PC3-4 | 状态枚举 | 内部五态 `FilterParseStatus`：`valid / parse_failed / type_mismatch / read_failed / not_parsed`，原始值与 S1-06 报告逐字一致；是否提升为公共 Models 枚举留 C3-B 评审（G-C3-1） |
| PC3-5 | 规则载体 | 解析成功复用既有 `FilterRule`（`bundles/classes/executables/coreFoundationVersion/otherKeys`）；不重定义重复规则模型；`FilterRule` 仅在 `valid` 时非空 |
| PC3-6 | 跳过字段证据 | 内部 `SkippedField` 记录 `key/reason/expectedType/observedType/route/index?`；它是**错误证据**，不是「跳过错误字段后仍然有效」；RootHide 类型错误整份 `type_mismatch`，不得解读为部分 valid |
| PC3-7 | otherKeys | 按路线识别键集合收集未覆盖键名，去重排序；只读记录，不臆测语义；Rootless 的 `Classes/CoreFoundationVersion/IsTweakManager` 入 `otherKeys`，不判解码失败 |
| PC3-8 | 路线选择 | `route=roothide` → RootHide 严格 Parser；`route=rootless` → Rootless Codable Parser；`rootful/unknown/nil` → 不选边，条目入 `notParsed`/不确定线索并标注 `unknown` |
| PC3-9 | 读取级失败 | 读取受限/失败 → `read_failed`，`readStatus` 保留原因；不判 `parse_failed`、不判不存在；条目保留，`filter=null` |
| PC3-10 | 解析级失败 | 字节不构成合法属性列表（XML 破损/Binary 损坏/空文件）→ `parse_failed`，`reason=invalid_plist`；Rootless Codable 解码失败按 Rootless 口径记 `parse_failed` |
| PC3-11 | 结构级/字段级失败 | 根/Filter/字段类型不符本路线规则 → `type_mismatch`，reason 细分 `root_type/filter_missing/filter_type/field_type/versions_type`；观测类型与期望类型入 `SkippedField` |
| PC3-12 | 单条隔离 | 单插件解析失败不中断整轮；损坏条目进失败归类，兄弟条目照常解析；未配对条目不删除 |
| PC3-13 | 确定性与不可变性 | 相同 plist 重复解析，规则数组、归类、计数、`otherKeys`、跳过字段深比较一致；解析不修改输入快照与证据；数组按稳定序输出 |
| PC3-14 | 模块目录 | 沿用迁移总规格 §5：`Core/PlistParser/`（输入/读取/解码/双路线 Parser/结果/引擎分层）；不另建 `Core/PluginParser/` 平行结构 |

## 3. 输入边界（C2 → C3）

### 3.1 复用的既有类型（不修改）

| 既有类型 | C3 用途 |
|---|---|
| `PluginPairingSnapshot` | 唯一上游快照；`route/sourceDirectory/status/records/unknownItems/counts/warnings` 原样透传 |
| `PluginPairingRecord` | 逐条配对记录；`pairingKey/dylib/plist/candidates/reason/basis/evidence/warnings` |
| `PluginFileEvidence` | 两侧条目证据原样引用；plist 路径取 `plist.path` |
| `FilterRule` / `CoreFoundationVersion` / `CoreFoundationMode` | 成功规则与版本约束载体 |
| `ReportWarning` / `EvidenceBlock` / `UnknownItem` | 告警、证据块、归集条目载体 |
| `PairingCategory` / `PairingStatus` / `Pairing` | 五桶分类、目录级状态、公共配对四值，原始值冻结 |

### 3.2 Reader 层内容信号（离线注入；后续只读读取层承载）

| 信号 | 取值 | 说明 |
|---|---|---|
| `plistPath` | `String?` | 与记录 `plist.path` 对齐 |
| `plistFormat` | `xml / binary / unknown` | 仅记录格式，不据此判断内容合法性 |
| `readStatus` | `ok / access_denied / read_failed` | 读不出内容与解析失败区分 |
| `payloadInvalid` | `Bool` | 字节无法构成属性列表 → `parse_failed` |
| `root` | `[String: Any]?`（解码对象） | 解码成功后的顶层字典；非法字节为 `nil` |

> 内容信号不扩写进 `PluginFileEvidence`；该证据结构在 C3 保持冻结（G-C3-3）。

## 4. 路线规则冻结（对齐 S1-06 §4 与 parser.js）

### 4.1 RootHide（严格规则）

| 字段 | 位置 | 期望类型 | 缺失 | 类型不符处置 |
|---|---|---|---|---|
| 根节点 | 顶层 | 字典 | — | 根非字典 → `type_mismatch`（`root_type`） |
| `Filter` | 顶层 | 字典 | 缺失 → `type_mismatch`（`filter_missing`） | 非字典 → `type_mismatch`（`filter_type`） |
| `IsTweakManager` | 顶层 | 布尔 | 缺失 = `false`，可容忍 | 出现且非布尔 → `type_mismatch`（`field_type`） |
| `Bundles` | Filter | 字符串数组 | 缺失 = `[]`，可容忍 | 非数组/元素非字符串 → `type_mismatch`；空指针元素容忍 |
| `Classes` | Filter | 字符串数组 | 缺失 = `[]`，可容忍 | 非数组/元素非字符串/空指针元素 → `type_mismatch` |
| `Executables` | Filter | 字符串数组 | 缺失 = `[]`，可容忍 | 非数组/元素非字符串/空指针元素 → `type_mismatch` |
| `CoreFoundationVersion` | Filter | 数字数组（长度 1 或 2） | 缺失 = `null`，可容忍 | 非数组/元素非数字 → `type_mismatch`（`versions_type`）；长度 0/3 记 `unsupported_length` 线索 |
| 其他键 | Filter/顶层 | — | — | 记入 `otherKeys`，不判失败 |

- 版本映射：长度 1 且为数字 → `{mode: max, max: v0}`；长度 2 且均为数字 → `{mode: range, min: v0, max: v1}`；其余不构造版本约束。
- 识别键：顶层 `Filter / IsTweakManager`；Filter 内 `Bundles / Classes / Executables / CoreFoundationVersion`。
- 类型判定必须独立建辅助谓词；不得只依赖 `is Bool / is NSNumber` 简单判断，须覆盖 Bool 与 NSNumber 桥接陷阱、整数/浮点边界、空数组、非数字元素、长度 0/1/2/3 等用例（C3-C 测试清单 §6）。

### 4.2 Rootless（Swift Codable 模型为准）

| 字段 | 位置 | 期望类型 | 缺失 | 类型不符处置 |
|---|---|---|---|---|
| 根节点 | 顶层 | 字典（Codable 解码前提） | — | 非字典/解码失败 → `parse_failed`（`root_type` 线索） |
| `Filter` | 顶层 | 字典 | 缺失 → `parse_failed`（`filter_missing`） | 非字典 → `parse_failed`（`filter_type`） |
| `Bundles` | Filter | `[String]?` | 缺失 = `[]` | 元素非字符串 → 解码失败 `parse_failed`（`field_type`） |
| `Executables` | Filter | `[String]?` | 缺失 = `[]` | 元素非字符串 → 解码失败 `parse_failed`（`field_type`） |
| `UnloadAfter` | 顶层 | `Bool?` | 缺失 = `null` | 非布尔 → 解码失败 `parse_failed`（`field_type`，记录类型证据） |
| `Classes / CoreFoundationVersion / IsTweakManager` | — | 模型未覆盖 | 出现即记入 `otherKeys` | 不判失败；不写入 Codable 模型字段 |

- 取值规范化：`Bundles / Executables` 输出 `lowercased()`；原始值由内容信号保留，双份证据在离线比较时可追溯。
- `IsTweakManager` 在 Rootless 结果为 `null`（模型无此键），不入规则布尔字段。
- 识别键：顶层 `Filter / UnloadAfter`；Filter 内 `Bundles / Executables`。
- C injector 宽松行为仅作兼容性风险记录，不进入本 Adapter；Rootless 真机实现路径待运行时取证。

### 4.3 空配置区分

| 情形 | 记录口径 |
|---|---|
| 字段缺失 | 数组类 `[]`、版本类 `null`，告警 `field_missing` |
| 空数组 | `[]`，告警 `empty_array` |
| 空字典 | `Filter={}`，各规则为空，告警 `empty_filter` |
| 空值元素 | 字符串数组空串保留并告警 `empty_element`，不静默剔除 |

## 5. 新增内部类型（Core 中间层，不进公共 Models / ReportEnvelope）

> 以下为 C3 内部结果形态；字段、Optional 与 Codable 口径在本批冻结。是否将 `FilterParseStatus` / `SkippedField` 提升为公共 Models 类型，留 C3-B/C3-D 评审（G-C3-1、G-C3-2）。

### 5.1 `FilterParseStatus`（封闭五态）

```swift
public enum FilterParseStatus: String, Codable, Equatable {
    case valid
    case parseFailed = "parse_failed"
    case typeMismatch = "type_mismatch"
    case readFailed = "read_failed"
    case notParsed = "not_parsed"
}
```

### 5.2 `SkippedField`（结构化错误证据）

| 字段 | 类型 | 说明 |
|---|---|---|
| `key` | `String` | 字段名；根节点级用 `(root)` |
| `reason` | `String` | 封闭原因词：`root_type/filter_missing/filter_type/field_type/not_array/null_element/element_type/codable_type/versions_type/unsupported_length` |
| `expectedType` | `String` | 期望类型词：`object/string[]/string/boolean/number[]/number[1|2]` 等 |
| `observedType` | `String` | 观测类型词：`object/array/string/number/boolean/null/missing/number[N]` |
| `route` | `String` | 归属路线（`roothide/rootless/unknown`） |
| `index` | `Int?` | 数组元素级证据的位置；非元素级为 `nil` |

### 5.3 `PlistReadResult`（Reader 产出）

| 字段 | 类型 | 说明 |
|---|---|---|
| `plistPath` | `String?` | 与配对记录对齐 |
| `format` | `String` | `xml/binary/unknown` |
| `readStatus` | `String` | `ok/access_denied/read_failed` |
| `payloadInvalid` | `Bool` | 字节非法标记 |
| `decodedRoot` | `[String: Any]?` | 解码成功的顶层字典；非法/读失败为 `nil` |

### 5.4 `PluginParseInput`（单条解析输入）

| 字段 | 类型 | 说明 |
|---|---|---|
| `record` | `PluginPairingRecord` | 上游配对记录原样引用 |
| `route` | `String?` | 快照路线原值透传 |
| `read` | `PlistReadResult?` | Reader 产出；无内容信号时按 `read_failed` 线索构造 |

### 5.5 `FilterParseResult`（单条解析结果）

| 字段 | 类型 | 说明 |
|---|---|---|
| `pairingKey` | `String?` | 上游配对键透传 |
| `dylibPath` | `String?` | 上游 dylib 路径透传 |
| `plistPath` | `String?` | 上游 plist 路径透传 |
| `route` | `String?` | 路线原值 |
| `status` | `FilterParseStatus` | 五态互斥 |
| `reason` | `String?` | 状态细分原因；`valid` 为 `nil` |
| `filter` | `FilterRule?` | 仅 `valid` 非空；其余为 `nil` |
| `isTweakManager` | `Bool?` | RootHide 缺失 = `false`；Rootless 恒 `nil` |
| `skippedFields` | `[SkippedField]` | 错误证据；`valid` 为空数组 |
| `otherKeys` | `[String]` | 去重排序的未覆盖键名 |
| `warnings` | `[ReportWarning]` | 条目级告警，`sourceStage="stage2.2-c3"` |
| `plistFormat` | `String` | 透传 Reader 格式信号 |
| `readStatus` | `String` | 透传读取状态 |

### 5.6 `FilterParseSnapshot`（整轮解析中间快照）

| 字段 | 类型 | 说明 |
|---|---|---|
| `route` | `String?` | 上游原值 |
| `sourceDirectory` | `String?` | 上游原值；未定位为 `nil` |
| `status` | `String` | 目录级口径沿用上游词汇：`enumerated/partial/unresolved`；存在任一失败态 → `partial` |
| `parsed` | `[FilterParseResult]` | 进入解析管线的条目（含各失败态） |
| `notParsed` | `[UnknownItem]` | 上游未配对/歧义/不确定条目原样归集 |
| `counts` | `FilterParseCounts` | 五桶互斥计数（见 §7） |
| `warnings` | `[ReportWarning]` | 快照级告警 |

### 5.7 `FilterParseCounts`（五桶互斥计数）

`valid / parse_failed / type_mismatch / read_failed / not_parsed` 五个 `Int`，按结果组数计数；`parsed[]` 内四态计数 + `notParsed[]` 条数与 `counts` 一一对应；不把候选数/跳过字段数计入桶计数。

## 6. 测试分组与基线映射（C3-C 落地，本批仅冻结计划）

- 原始基线：S1-06 PARSE-001 ~ PARSE-017（22 例执行），16 组夹具；Swift 回归挂现有 `Stage2Tests` target，测试 target 内独立 loader（范式参照 `S105FixtureLoader.swift`），不进入正式 App/Core。
- 分组建议：A 根节点/Filter 字典；B IsTweakManager 类型；C Bundles/Classes/Executables；D CoreFoundationVersion；E Rootless Codable；F otherKeys/skippedFields；G 五态互斥；H 错误与证据保留。
- 附加边界用例：Foundation Bool/NSNumber 类型边界、空数组、缺失键、未知键、未知路线、未确认 Profile、确定性、输入数据不变性。
- 计数纪律：原始 22 项基线与 C3 新增专项分别统计，不重复计数；前序 B/C1/C2 回归保持通过。

## 7. 错误分类与互斥口径

| 层级 | 情况 | 归类 | 记录口径 |
|---|---|---|---|
| 读取级 | 条目访问受限/读取失败 | `read_failed` | `readStatus` 保留原因；不判不存在、不判解析失败 |
| 解析级 | 字节非法属性列表 | `parse_failed`，`reason=invalid_plist` | 保留 plist 路径与读取状态 |
| 解析级 | Rootless Codable 解码失败 | `parse_failed`，reason 按字段线索 | 不套 RootHide 严格规则 |
| 结构级 | 根非字典 | `type_mismatch`，`root_type` | 记录观测类型 |
| 结构级 | Filter 缺失/非字典 | `type_mismatch`，`filter_missing/filter_type` | 与字段缺失区分 |
| 字段级 | 数组非数组/元素类型不符 | `type_mismatch`，`field_type` | `SkippedField` 记录键/期望/观测类型 |
| 字段级 | 版本字段非数字数组 | `type_mismatch`，`versions_type` | 记录长度与元素类型 |
| 条目级 | 上游未配对/不确定/歧义 | `not_parsed` | 保留上游 `pairing` 与原因，不删除 |
| 路线级 | 目录未定位/清单未枚举 | 空模型 + `inventory_unresolved` | 禁止回退扫描 |

## 8. 证据传递与不可变性

- 条目证据直接引用上游 `PluginFileEvidence`；需要证据块时复用 `EvidenceBlock`，不新增自由字符串 `[String] evidence`。
- 告警统一 `ReportWarning`（封闭 code + message + sourceStage）；不散落裸字符串告警。
- 解析过程不修改上游快照、配对记录与夹具输入；输出数组按 `pairingKey`/路径稳定序确定性排序。
- `skippedFields` 仅承载错误证据；任何 `type_mismatch/parse_failed/read_failed` 结果不得附带一个看起来合法的 `FilterRule`。

## 9. 状态边界（三层状态不越界）

- `installed`：C3 不产出新结论；dylib 在位状态沿用 C1/C2 证据。
- `configured`：仅 `status == .valid` 可在后续导出层映射为已配置；其余四态一律不视为已配置。
- `loaded`：C3 一律 `unknown`；即使 Filter 合法且规则解析成功，也禁止推断已注入/已生效。
- C3 不判断来源与归属（后续 Ownership 批次）、不做统一模型 JSON 导出；`FilterRule` 只是配置规则，不代表插件已被注入。

## 10. 模块目录与批次门禁

### 10.1 目录分层（`Core/PlistParser/`）

| 子目录 | 职责 |
|---|---|
| `Input/` | `PluginParseInput`、输入构造（快照 + Reader 信号） |
| `Reader/` | `PlistDataReader`、`PlistReadResult`；读取状态与格式信号 |
| `Decoder/` | `PlistDecoder`、解码中间对象；合法属性列表判定 |
| `RootHide/` | `RootHideFilterParser`（严格类型核对 + 类型谓词辅助） |
| `Rootless/` | `RootlessFilterParser`、`RootlessFilterCodable`（内部解码结构） |
| `Result/` | `FilterParseResult`、`FilterParseSnapshot`、计数与跳过字段类型 |
| `Engine/` | `PluginFilterParseEngine`：路线选择、编排、汇总计数与告警 |

### 10.2 批次门禁

| 批次 | 内容 | 门禁 |
|---|---|---|
| C3-A | Parser Models / 结果数据契约与模块边界冻结（本批） | 契约评审通过；不改源码/Models/协议/夹具/harness；不编译不跑 Runner |
| C3-B | Plist Reader / Decoder | 读取与解码测试通过；读取失败/字节非法/格式识别口径对齐基线 |
| C3-C | RootHide / Rootless Parser | S1-06 22 项原始基线映射通过；双路线隔离；类型边界用例覆盖 |
| C3-D | Parser 集成与 Runner | 全量回归通过；Adapter 签名/Models 缺口评审收口；隔离三向与 App Build 出证 |

> 批次门槛未达成不进入下一批次；发现行为与 Stage 1 预期不符，先冻结问题、回退夹具核对，不在编码中放宽规则。

## 11. 安全边界（C3 全程适用）

1. 不修改任何 plist。
2. 不写入任何插件文件。
3. 不执行 dpkg。
4. 不调用 ElleKit 注入接口。
5. 不扫描真实越狱目录。
6. 不读取尚未成功配对的 plist。
7. 不将解析成功等同于插件已加载。
8. 不将解析结果等同于插件拥有管理权限。

## 12. 待评审缺口与未决项

- G-C3-1：五态强类型枚举落 Models 还是 Core 内部（C3-B 评审）。
- G-C3-2：公共 `ValidationReport.skippedFields` 是否由 `[String]` 扩展为结构化字段（C3-D 评审）。
- G-C3-4：Adapter `parseFilter` 签名是否需要扩展状态/证据载体（协议演进评审，不改七方法协议）。
- G-C3-5：Rootless `UnloadAfter` 在导出层的归属字段（导出批次评审）。
- 真机待验证：plist 格式分布、非常规键、RootHide 严格规则兼容性、Rootless 解码失败分布、受限读取表现、进程内命中行为；离线合成样本不作真机背书。
- 沿用未决：R6 未知枚举原始值默认解码；iOS 17 / Rootless 真机兼容；Runner SDK 版本不作为 Theos 16.5 兼容证据。
