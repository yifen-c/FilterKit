# Stage-2.2-C-Enumeration-Pairing-Parser.md — 2.2-C 插件枚举 / 配对 / Filter 解析实现规格（冻结）

> 状态：**实现规格冻结（设计层）**。本批次第一步仅完成只读审计（`Stage-2.2-C-Audit.md`）与本规格冻结；**不修改源码、Models、Adapters、七方法协议、Stage 1 Fixtures、Harness 或测试文件**，不编译、不运行 Runner、不扫描真机。C1~C4 编码、Models/协议演进与 Runner 执行须在本规格冻结后逐批单独授权。
> 定位：把 Stage 1 已验证的 S1-04/S1-05/S1-06 离线逻辑迁入共享 Core / Adapter / Models，CLI 与 GUI 共用同一套核心；行为保持重构，输出模型、分类口径、告警与不确定状态必须与 Stage 1 夹具预期一致。
> 上游基准：`Stage-2.2-Core-Models-Migration.md` §4/§6/§7/§9/§10；`Stage-2.2-B5-Integration-Regression.md`（B5 已验收，91 例 0 失败）；Stage 1 基线 `Tests/S1-04~06` harness、`Tests/Fixtures/S1-04~06/`、`Tests/S1-04~06/report/*.json`（只读）。

## 1. 批次拆分（细化迁移规格 §10 的 2.2-C 行）

迁移规格 §10 将 2.2-C 定义为单一批次（S1-04 23 + S1-05 15 + S1-06 22 = 60 项）；本规格按附件 §2 建议细化为四个子批次，逐批独立验收，问题可定位到枚举/配对/解析环节。

| 子批次 | 内容 | 覆盖回归 | 前置门禁 |
|---|---|---|---|
| **C1 Plugin Enumeration** | dylib/plist 独立枚举、文件类型区分、软链身份记录、元数据/哈希失败保留、枚举异常分层、确定性排序 | S1-04 23 例（ENUM-） | B5 已闭环；G-C1/G-C2 Models 增补评审冻结 |
| **C2 Plugin Pairing** | dylib/plist 配对、大小写敏感精确匹配、缺失/孤儿/歧义/不确定识别、跨目录排除、配对确定性 | S1-05 15 例（PAIR-） | C1 验收通过；G-C3 配对快照契约已冻结（`Stage-2.2-C2-Pairing-Contract.md`） |
| **C3 Filter Parser** | RootHide 严格 Parser、Rootless Codable Parser、类型核对、FilterRule 生成、五态解析异常处理 | S1-06 22 例（PARSE-） | C2 验收通过；G-C4/G-C5 解析模型评审冻结 |
| **C4 Integration Regression** | 完整插件处理链（清单→配对→解析）、Stage 1 夹具深比较、双 Adapter 隔离、Core/App Build 与证据归档 | 60 例 + 既有 91 例保持通过 + 附加集成/确定性/隔离用例 | C3 验收通过 |

> 子批次划分不改变迁移规格 §10 的批次门槛语义：门槛未达成不进入下一批次；发现行为与 Stage 1 预期不符，先冻结问题、回退对应夹具核对，不在编码中放宽规则。

## 2. 数据流与模块边界

### 2.1 数据流（只读，离线可测）

```
S1-03 目录定位报告（route / sourceDirectory / 可读可枚举证据）
        │  C1 Core/PluginScanner
        ▼
PluginInventory（items[] 五类分类 + unknownItems + counts + 目录级状态 + warnings）
        │  C2 Core/PluginPairing（只消费 C1 清单，不读 plist 内容）
        ▼
PairingReport（pairs / missingPlist / orphanPlist / ambiguous / uncertain + counts + status）
        │  C3 Core/PlistParser（仅 paired 条目进入解析；其余原样携带 notParsed）
        ▼
ParseReport（parsed[]: FilterRule + 五态状态 + 证据；notParsed[]；counts；warnings）
        │  2.2-D 再接 OwnershipResolver / ReportExporter
        ▼
Plugin 骨架（dylibPath/plistPath/pairing/filter/validation；归属/版本/导出留 D）
```

### 2.2 职责边界（对齐迁移规格 §2 与附件 §4）

| 模块 | 职责 | 禁止事项 |
|---|---|---|
| Adapter | 路线相关环境与文件访问（条目信号、plist 字节/读取状态）；双路线 Parser 规则封闭在各自路线实现路径 | 不复用对方规则代码；不暴露写入接口；不被 Core 直接实例化 |
| Core | 枚举/配对/解析业务编排与纯规则；离线注入夹具适配器可测 | 不直接操作文件系统；不另写 GUI 专用扫描器；不散落路线 if/else |
| Models | 统一数据结构、枚举原始值、Codable 兼容 | 不承载路线特有分支字段；不临时新增枚举值或改变既有状态语义 |
| GUI | 展示 Core 返回的数据 | 不自行实现第二套扫描/配对/解析逻辑 |

## 3. 文件规划（实现批次以本规划为准；附件示意目录名不直接采用）

### 3.1 Core 新增（占位目录已存在）

| 目录 | 规划文件 | 职责 | 对应 harness |
|---|---|---|---|
| `Core/PluginScanner/` | `PluginInventory.swift`（清单/条目快照，待 G-C1/G-C2 评审）、`PluginEnumerator.swift`（单层非递归枚举、分类、排序、异常保留） | S1-04 枚举规则 | `enumerator.js` |
| `Core/PluginPairing/` | `PairingReport.swift`（配对快照，按 G-C3 契约 `Stage-2.2-C2-Pairing-Contract.md`）、`PluginPairer.swift`（基名派生、精确匹配、五态归类、歧义/不确定保留） | S1-05 配对规则 | `pairing.js` |
| `Core/PlistParser/` | `ParseReport.swift`（解析快照/五态，待 G-C4 评审）、`FilterParser.swift`（编排双路线）、`RootHideFilterParser.swift`（严格校验）、`RootlessFilterParser.swift`（Codable 口径，中间结构内部化） | S1-06 解析规则 | `parser.js` |

### 3.2 测试规划（归入 `Tests/Stage2/`，更新 `Package.swift` testTarget sources）

| 子批次 | 规划测试文件 | 覆盖 |
|---|---|---|
| C1 | `PluginEnumerationTests.swift` | ENUM-001~015 共 23 例 + 清单快照 Codable 往返 + 确定性 |
| C2 | `PluginPairingTests.swift` | PAIR-001~013 共 15 例 + 配对快照 Codable 往返 + 确定性 |
| C3 | `FilterParserTests.swift` | PARSE-001~017 共 22 例 + 双路线隔离 + 解析快照 Codable 往返 + 确定性 |
| C4 | `CIntegrationTests.swift`、`CFixtureComparisonTests.swift`（命名以实现批次仓库组织为准） | 三模块链集成、夹具深比较、既有 91 例保持通过 |

> 既有 8 个测试文件（71 冻结回归 + 20 B5 附加）与其中方法、断言保持原样；新增测试为独立文件，不并入既有冻结文件。

### 3.3 Models / 协议待评审项（实现前冻结，本轮不改）

见审计报告 §2.2 G-C1~G-C6 与 §3.2。任何新增中间结果类型须先在对应子批次子规格给出字段、Codable 口径与 Stage 1 对照，经评审冻结后再编码；七方法协议演进须走协议评审，无写入方法。

## 4. 60 项回归映射（逐阶段，不可合并计数）

### 4.1 C1 · S1-04 枚举 23 例

| # | 编号 | 夹具/来源 | 断言要点 |
|---:|---|---|---|
| 1 | ENUM-001 | `rh-mixed` | 全部 `.dylib` 列入 `items`，`kind=dylib` |
| 2 | ENUM-001 | `rh-orphan-dylib` | 单 dylib 列入清单 |
| 3 | ENUM-002 | `rh-mixed` | 全部 `.plist` 独立列出，不与 dylib 合并 |
| 4 | ENUM-002 | `rh-orphan-plist` | 单 plist 独立列出 |
| 5 | ENUM-003 | `rh-dir-entry` | 目录条目独立分类 |
| 6 | ENUM-003 | `rh-other-extension` | 未知扩展名归 `other` |
| 7 | ENUM-004 | `rh-mixed` | 文件名原样保留，不改写大小写/空格/扩展名 |
| 8 | ENUM-005 | `rh-hidden-file` | 点开头文件列入且 `hidden=true`，不排除 |
| 9 | ENUM-006 | `rh-dir-entry` | 子目录只记条目，不递归；`recursive=false` |
| 10 | ENUM-007 | `rh-symlink-valid` | 软链条目与目标区分记录 |
| 11 | ENUM-007 | `rh-symlink-broken` | 断链记 `symlinkState=broken`，不误判普通文件 |
| 12 | ENUM-008 | `rh-bad-permission` | 条目 `access_denied`；目录 `partial`，不混 `not_found` |
| 13 | ENUM-008 | `rh-enum-failed` | 目录级 `enumeration_failed`，清单为空附原因 |
| 14 | ENUM-009 | `rh-mixed` | 可获取条目记录 `size` |
| 15 | ENUM-009 | `rh-metadata-missing` | `size/realpath=null`，记 `metadata_unavailable` |
| 16 | ENUM-010 | `rh-mixed` | 成功条目带 `hash` |
| 17 | ENUM-010 | `rh-metadata-missing` | `hash=null` 且不阻断枚举 |
| 18 | ENUM-011 | `synthetic:path-identity` | 同名两条目路径不同，均保留，不按基名合并 |
| 19 | ENUM-012 | `rh-bad-permission` | 单条目异常不中断整轮，其余条目仍入清单 |
| 20 | ENUM-013 | `rootless-mixed` | Rootless 路线清单独立 |
| 21 | ENUM-013 | `route-guard` | 上游未定位 → `unresolved`，空清单，不回退 `/var/jb` |
| 22 | ENUM-013 | `synthetic:route-isolation` | 未出现 `/var/jb` 回退路径 |
| 23 | ENUM-014 | `synthetic:determinism` | 重复枚举清单、顺序、计数深比较一致 |

### 4.2 C2 · S1-05 配对 15 例

| # | 编号 | 夹具/来源 | 断言要点 |
|---:|---|---|---|
| 1 | PAIR-001 | `pair-valid` | `Example.dylib` ↔ `Example.plist` 记 `paired` |
| 2 | PAIR-002 | `pair-missing-plist` | dylib 记 `missing_plist`，不造 plist |
| 3 | PAIR-003 | `pair-orphan-plist` | plist 记 `orphan_plist`，`reason=missing_dylib` |
| 4 | PAIR-004 | `pair-multi` | 多组配对分别建立，计数一致 |
| 5 | PAIR-005 | `pair-case-mismatch` | 大小写不同不配对，分记 `missing_plist`/`orphan_plist` |
| 6 | PAIR-006 | `pair-cross-path` | 跨目录同名不配对、不合并，路径分别保留 |
| 7 | PAIR-007 | `pair-hidden` | `.hidden.dylib` ↔ `.hidden.plist` 配对，保留隐藏标记 |
| 8 | PAIR-008 | `pair-symlink` | 软链身份保留并参与配对 |
| 9 | PAIR-009 | `pair-other-ext` | `.txt/.deb/.DYLIB` 不进入配对候选 |
| 10 | PAIR-010 | `pair-duplicate` | 同基名多候选记 `ambiguous`，列出候选，不任选 |
| 11 | PAIR-011 | `pair-access-denied` | 受限条目进 `uncertain`，留置对应 plist，不判缺失/孤儿 |
| 12 | PAIR-012 | `route-guard` | 上游未定位 → `unresolved` 空报告，不回退扫描 |
| 13 | PAIR-013 | `pair-determinism` | 相同清单重复配对结果确定 |
| 14 | PAIR-013 | `synthetic:determinism` | 配对关系、归类、计数深比较一致 |
| 15 | PAIR-006 | `synthetic:route-isolation` | 未出现跨路线/回退路径配对 |

### 4.3 C3 · S1-06 解析 22 例

| # | 编号 | 夹具/来源 | 断言要点 |
|---:|---|---|---|
| 1 | PARSE-001 | `parse-xml-valid` | XML 合法样本 `parseStatus=valid` |
| 2 | PARSE-002 | `parse-xml-valid` | `plistFormat=xml`，按字典解析 |
| 3 | PARSE-003 | `parse-binary` | `plistFormat=binary`，合法样本解析通过 |
| 4 | PARSE-004 | `synthetic:root-type` | 根非字典 → `type_mismatch`（root_type） |
| 5 | PARSE-005 | `parse-missing-filter` | Filter 缺失 → `type_mismatch`（filter_missing） |
| 6 | PARSE-005 | `synthetic:filter-type` | Filter 非字典 → `type_mismatch`（filter_type） |
| 7 | PARSE-006 | `parse-bundles-wrong` | Bundles 非字符串数组 → `type_mismatch`，记期望/观测类型 |
| 8 | PARSE-007 | `parse-classes-wrong` | Classes 元素非字符串 → `type_mismatch` |
| 9 | PARSE-008 | `parse-executables-wrong` | Executables 非字符串数组 → `type_mismatch` |
| 10 | PARSE-009 | `parse-versions` | 数字数组合法 |
| 11 | PARSE-009 | `parse-versions-wrong` | 非数字数组 → `type_mismatch`（versions_type） |
| 12 | PARSE-010 | `synthetic:mixed-type` | 多字段不符记 `type_mismatch`，`skippedFields` 保留字段与类型 |
| 13 | PARSE-011 | `parse-empty-filter` | 空字典标注，不与缺失/空数组混类 |
| 14 | PARSE-011 | `parse-missing-fields` | 可选字段缺失容忍，分别标注 |
| 15 | PARSE-012 | `parse-multi-rule` | 多 Bundles/Classes/Executables 全部保留，顺序确定 |
| 16 | PARSE-013 | `parse-invalid-plist` | 字节非法 → `parse_failed`（invalid_plist），条目不删除 |
| 17 | PARSE-014 | `parse-partial-corrupt` | 单条失败不影响兄弟条目；良条目 `valid` |
| 18 | PARSE-015 | `parse-rootless-model` | Rootless 按 Codable 模型解析；未覆盖键入 `otherKeys`，不套严格规则判失败 |
| 19 | PARSE-016 | `parse-determinism` | 相同 plist 重复解析归类/规则/计数一致 |
| 20 | PARSE-016 | `synthetic:determinism` | 规则数组、归类、计数、`otherKeys` 深比较一致 |
| 21 | PARSE-012 | `route-guard` | 上游未定位 → `unresolved` 空模型，`inventory_unresolved` |
| 22 | PARSE-012 | `synthetic:route-isolation` | 未出现回退扫描；未配对/不确定/歧义条目落 `not_parsed` |

### 4.4 前序回归保持

- C 各批次执行时，既有 71 项冻结回归 + 20 项 B5 附加必须保持通过；Stage 1 S1-01~03 行为口径不被 C 改动影响。
- 测试编号保留 Stage 1 前缀以便回溯；每个原始 fixture 有明确 Swift 用例对应。

## 5. 规则冻结口径（不可在迁移中放宽或合并）

### 5.1 枚举（C1）

单层非递归；扩展名大小写敏感，仅 `.dylib`/`.plist` 归类；文件名字母序确定性排序；软链记录自身不跟随；隐藏文件保留标记；目录/软链/其他进 `unknownItems`；目录级四态 `enumerated/partial/enumeration_failed/unresolved`；条目级 `ok/access_denied/metadata_unavailable/read_failed/not_found`；访问失败 ≠ 不存在；单条目异常不中断整轮；`loaded` 恒 `unknown`。

### 5.2 配对（C2）

dylib 驱动；剥离 `.dylib` 派生 `<base>.plist`；同目录精确文件名、大小写敏感；五态互斥 `paired/missing_plist/orphan_plist/ambiguous/uncertain`；多候选不选边；受限条目进 `uncertain` 并留置对应 plist；跨目录陷阱条目排除；不读 plist 内容、不模糊匹配、不 lowercase fallback；公共 `Pairing` 枚举维持四值，`ambiguous/uncertain` 经配对快照与 `UnknownItem.reason` 承载。

### 5.3 解析（C3）

- 五态互斥：`valid / parse_failed / type_mismatch / read_failed / not_parsed`，读取失败、格式非法、类型不符、尚未解析不得合并为一个 `failed`。
- RootHide 严格：根/`Filter` 字典；`IsTweakManager` 出现须 Bool；`Bundles/Classes/Executables` 字符串数组；`CoreFoundationVersion` 数字数组长度 1|2；任一不符整份 `type_mismatch`；跳过字段保留期望/观测类型。
- Rootless Codable：`Bundles/Executables [String]?`、`UnloadAfter Bool?`；解码失败 `parse_failed`；未覆盖键入 `otherKeys` 不判失败；取值 lowercased 并保留原始值线索；不套用 RootHide 严格规则。
- 空配置三分（缺失字段/空数组/空字典）；多规则保留顺序；兄弟条目失败隔离；`rootful/unknown` 路线不自动套用任一规则。

## 6. 验收门槛

### 6.1 子批次门槛

| 批次 | 通过条件 |
|---|---|
| C1 | 23 例 ENUM 回归全绿；清单分类/计数/排序/异常分层与夹具基线一致；非递归与路线隔离无回退；既有 91 例保持通过；Core 编译通过 |
| C2 | 15 例 PAIR 回归全绿；五态互斥无重复归属；大小写敏感/跨目录排除/歧义不选边/受限不确定口径一致；既有回归保持通过；Core 编译通过 |
| C3 | 22 例 PARSE 回归全绿；双路线规则独立；五态区分完整；RH 严格与 RL Codable 差异保留；`otherKeys`/空配置/确定性口径一致；既有回归保持通过；Core 编译通过 |
| C4 | 60 例 C 段回归 + 既有 91 例全绿；三模块链集成输出与 Stage 1 夹具深比较一致；隔离三向通过（RH 不引 Rootless、RL 不引 RootHide、Core 不实例化具体 Adapter）；Models/Adapters/Core 在 Apple 工具链编译通过；App Target 构建启动存活复验；证据按既有 `run-<id>/` 口径归档 |

### 6.2 集成与证据

- 夹具深比较沿用 B5 模式：离线解码 `environment.json` → Core 离线注入适配器 → 与 `metadata.json` 基线及 `report.json` `cases[].result` 深比较（`generatedAt` 除外）；不复制第二份基线，不依赖 Node。
- 确定性：数组稳定序、字典键序稳定；`null` 与字段缺失语义保持，不补空串/空数组冒充已知；除时间戳外内容参与比较。
- CI：沿用六 Job；test Job 是否分阶段 `--filter` 分组出证，在执行授权时确认（B5 遗留观察项）。

## 7. 边界与不得宣布的结论

- C 阶段全程**只读**：不改 plist/dylib、不删插件、不改注入规则、不启停插件、不写 dpkg、不判断插件已 loaded。
- 离线/模拟器通过不代表真机兼容；App 存活仅证明工程构建与基础启动，不证明越狱目录访问权限。
- 本轮及各子批次均不得宣布：RootHide GUI 权限已验证、Rootless 真机兼容、插件已注入/已配置生效、插件启停可用（属后续阶段门禁）。
- 归属识别（S1-07）与统一模型导出（S1-08）归 2.2-D；C 段不产出 Ownership/ReportEnvelope 最终结论。

## 8. 本批次（规格冻结）未执行项

- 未编写 C1~C4 任何实现代码；未新增/修改 Models 字段、枚举、Adapter 协议或 Core 服务实现。
- 未改动 Stage 1 Fixtures、harness、`report.json` 与既有 Stage2 测试。
- 未编译、未运行 Runner、未执行 Swift 回归、未连接真机。
- `AdapterResolver` 具体装配、两服务接入仍延后；C 段 Core 不实例化具体 Adapter。
- 进入 C1 编码须单独授权，并先完成 G-C1/G-C2（C1）、G-C3（C2）、G-C4/G-C5（C3）Models/协议评审冻结。
