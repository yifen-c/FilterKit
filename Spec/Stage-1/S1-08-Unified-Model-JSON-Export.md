# S1-08 Unified Model & JSON Export — 统一模型 / JSON 导出子规格

- 状态：**Stage 1 子规格，设计冻结，等待离线测试授权**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-08；**本轮仅规格设计与用例拆解，不写代码、不建实际夹具、不建正式工程、不编译**。
- 前置：S1-01~S1-07 均已离线验收归档；本项输入为前七阶段产物快照。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.0（Report 信封）、§2.1（JailbreakEnvironment）、§2.2（Plugin）、§2.3（FilterRule）、§2.4（Ownership）、§3（loaded 原则）、§4（枚举）、§5（JSON 草图）。
- 职责边界：**S1-07 判断来源与归属；S1-08 把前序结果整合成版本化、确定性、只读的统一模型与 JSON 报告。** S1-08 不重新扫描、不重新解析、不补判归属、不产出操作放行结论。

## 1. 测试目标

汇总 S1-01~S1-07 的只读产物，按 [Plugin-Data-Model.md](../Plugin-Data-Model.md) 公共结构整合为统一数据模型，并导出版本化 JSON 报告，作为未来 GUI 与后续阶段的稳定输入。

- 只做**只读整合与序列化**：不访问真实文件系统、不回写设备、不修改 dpkg / plist / dylib / 软链 / 规则。
- 整合过程不丢弃前序阶段的错误、冲突、路径、原始字段与告警；不确定状态显式保留。
- 导出产物为只读快照；`generatedAt` 之外的字段在相同输入下必须可重复导出。

### 1.1 五项整合原则（不可违反）

1. **不丢失原始证据**：前序阶段的配对异常、解析告警、跳过字段、扩展键、归属冲突、混合来源、备注与清单路径必须在模型中有对应落点；不得为生成规整报告而裁剪。
2. **三层状态严格分离**：`installed`（文件层）、`configured`（关联层）、`loaded`（运行层）不得互相推导；`loaded` 无独立运行时证据时一律 `unknown`。
3. **来源与权限严格分离**：`ownership` / `writablePolicy` 不直接决定 `managementPermission`；管理授权由后续门禁独立评估，本项不产出放行结论。
4. **不确定状态必须保留**：`unknown` / `partial` / `ambiguous` / `conflict` / `heuristic` 等状态显式表达，不强行归类为合法/已管理/已加载。
5. **JSON 必须版本化**：信封携带 `schemaVersion`、`generatorVersion`、`profile`、`generatedAt`；明确参与确定性比较的字段集合，时间戳不纳入一致性比对。

## 2. 输入模型（只读快照）

S1-08 消费前序阶段产物快照；离线夹具以注入快照模拟，不串联真实 harness 进程。

| 输入阶段 | 产物字段（上游结果） | 映射去向 |
|---|---|---|
| S1-01 环境识别 | `jailbreakType`、`architecture`、`iosVersion`、`bootstrap`、`ellekitImplementation`、`ellekitVersion`、`ellekitVersionStatus`、`adapterProfile`、`outcome`、`warnings`、`evidence` | `environment` |
| S1-02 JBROOT 定位 | `jbroot`、`jbrand`、`realpath`、`ambiguous`、`selectedSource`、`candidateCount`、`candidates`、`warnings` | `environment.jbroot` / `jbrand`；候选与歧义入环境证据快照 |
| S1-03 目录定位 | `route`、`tweakInject`、`dynamicLibraries`、`outcome`、`warnings` | `environment` 路径证据；`plugins[].sourceDirectory` 线索 |
| S1-04 插件枚举 | `route`、`sourceDirectory`、`items`（dylib/plist 条目）、`unknownItems`、`counts`、`warnings` | `plugins` 文件层条目；枚举未知项入 `unknownItems` |
| S1-05 插件配对 | `pairs`、`missingPlist`、`orphanPlist`、`ambiguous`、`uncertain`、`counts`、`status` | `plugins[].pairing`；未配对/歧义/不确定入 `unknownItems` |
| S1-06 Plist/Filter 解析 | `parsed[]`（`base`、`dylibPath`、`plistPath`、`parseStatus`、`reason`、`isTweakManager`、`filter`、`skippedFields`、`validation`）、`notParsed[]` | `plugins[].filter` / `validation` / `isTweakManager`；未解析条目入 `unknownItems` |
| S1-07 来源识别 | `sources[]`（`sourceType`、`ownership` 字段、`packageID`、`packageVersion`、`architecture`、`listPath`、`fileOwnership`、`confidence`、`writablePolicy`、`markers`、`conflicts`、`notes`）、`unresolved[]` | `plugins[].source` / `ownership`；冲突/混合/备注入归属证据快照；未决项入 `unknownItems` |

> 上游缺失某阶段产物时，对应模型字段显式置 `null` / `unknown`，不得留空串冒充已知；不得用其他阶段结果反推补齐。

## 3. 输出模型（Report 信封）

对齐 [Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.0/§5：

```json
{
  "schemaVersion": "0.1.0",
  "generatorVersion": "0.1.0",
  "profile": { "id": "RootHideProfile_1_2_3", "route": "roothide" },
  "generatedAt": "2026-11-15T01:30:00+08:00",
  "environment": {
    "jailbreakType": "roothide",
    "ellekitImplementation": "roothide/ellekit",
    "ellekitVersion": "1.2-3",
    "profileId": "RootHideProfile_1_2_3",
    "jbroot": "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
    "jbrand": "9C414BB7D5DCECC4",
    "iosVersion": "17.0.2",
    "architecture": "iphoneos-arm64e",
    "evidenceLevel": "partial",
    "pathEvidence": { "tweakInject": {}, "dynamicLibraries": {}, "jbrootCandidates": [] }
  },
  "plugins": [ { "Plugin 模型，见 §3.1" } ],
  "unknownItems": [ { "path": "", "base": "", "reason": "", "sourceStage": "", "detail": {} } ],
  "warnings": [ { "code": "", "message": "", "sourceStage": "" } ]
}
```

### 3.1 Plugin 模型

| 字段 | 层 | 口径 |
|---|---|---|
| `pluginID` | — | 稳定唯一标识：优先 `<packageID>:<base>`，回退 `<base>`；生成规则在 0.2.0 定稿，离线保持确定性 |
| `name` | — | 展示名：dpkg 包名 / plist 基名；无展示名 = `null` |
| `version` | — | 包版本 / 插件版本；无 = `null` |
| `dylibPath` | 文件层 | dylib 绝对路径；缺失 = `null` |
| `plistPath` | 关联层 | plist 绝对路径；缺失 = `null` |
| `pairing` | 文件层 | `paired` / `missing_plist` / `orphan_plist` / `missing_dylib` |
| `source` | — | SourceType：`dpkg_sileo` / `filterkit` / `manual` / `unknown` |
| `ownership` | — | Ownership：`sourceType`、`packageID`、`listPath`、`confidence`、`writablePolicy` |
| `ownershipDetails` | 证据扩展 | `fileOwnership`、`markers`、`conflicts`、`notes`、`packageVersion`、`architecture`（保留 S1-07 细节，不进公共归属字段） |
| `filter` | 关联层 | FilterRule：`bundles`、`classes`、`executables`、`coreFoundationVersion`、`otherKeys`；解析失败 = `null` |
| `isTweakManager` | — | 顶层 `IsTweakManager`；缺失 = `false` |
| `loadCategory` | — | `manager` / `oldabi` / `tweak` / `unknown`（建模用，不等同运行结果） |
| `installed` | 文件层 | dylib 在位可读；仅来自 S1-04 枚举/可读证据，不由 plist 或归属推导 |
| `configured` | 关联层 | plist 存在且 Filter 可解析；仅来自 S1-06 `parseStatus=valid`，不由 `installed` 或 Bundles 命中推导 |
| `loaded` | 运行层 | `unknown` / `loaded` / `not_loaded`；本阶段恒 `unknown`，无运行时证据不置其他值 |
| `validation` | 关联层 | `{ status, warnings, skippedFields }`；保留 S1-06 类型不符/跳过字段证据 |
| `permission` | 门禁分离 | `{ decision: "undetermined", reason: "authorization_gate_not_evaluated" }`；不由 ownership 推导放行 |
| `profileId` | — | 产出该记录的 Profile |
| `evidence` | 证据 | `{ sourceStages: [], evidenceType: "fixture"|"device"|"source", evidenceLevel: "verified"|"partial"|"unverified" }` |

### 3.2 FilterRule / Ownership / Validation

- FilterRule、Ownership 字段严格对齐模型 §2.3/§2.4；未覆盖扩展键入 `otherKeys`，不臆测语义。
- Validation 保留 `skippedFields`（字段、原因、期望/观测类型）与告警；`partial_parsing` 为派生状态，条目级原因须保留。
- Ownership 冲突（`conflicts`）与混合来源（`mixed_package_ownership`）整体进入 `ownershipDetails`，不在公共 `ownership` 字段内合并选边。

## 4. 整合规则

### 4.1 条目归并

- 以 `base` + 规范化路径作为跨阶段对齐键；同一插件的枚举、配对、解析、归属结果合并到一条 `plugins[]`。
- 仅出现在配对/解析/归属侧而无 dylib 枚举记录的条目，仍保留为 Plugin 或 `unknownItem`，不丢弃。
- 归并冲突（多路径/多基名指向同一插件）不强行合并；保留各自记录并在 `warnings` 标注 `pairing_ambiguous`。

### 4.2 状态推导口径（允许与禁止）

| 派生字段 | 允许来源 | 禁止推导 |
|---|---|---|
| `installed` | S1-04 dylib 在位/可读证据 | 禁止由 plist 存在、Bundles 命中、dpkg 归属推导 |
| `configured` | S1-06 `parseStatus=valid` | 禁止由 `installed`、`source=dpkg_sileo` 推导 |
| `loaded` | 独立运行时取证（本阶段无） | 禁止由在位、配置、归属、进程内命中任何条件推导；恒 `unknown` |
| `permission.decision` | 后续授权门禁（本阶段不评估） | 禁止由 `writablePolicy=managed` / `sourceType=filterkit` 推导为可管理 |

### 4.3 证据保留

- S1-06 `otherKeys`、`skippedFields`；S1-07 `fileOwnership`、`markers`、`conflicts`、`notes`；S1-02 候选与歧义；S1-05 未配对/不确定原因，均须序列化到模型对应落点。
- 证据标签沿用既有口径：`[源码确认]` / `[RootHide 真机验证]` / `[Rootless 合成样本验证]` / `[Rootless 真机待验证]` / `[权限待验证]`；本批离线样本一律 `evidenceType=fixture`，不得标真机。

### 4.4 全局告警归并

- 前序 `warnings` 按 `code` 去重合并，保留 `sourceStage`；目录不可读、Profile 未知、软链异常、归属冲突、数据库不可用等全局告警进入顶层 `warnings`。
- 单插件失败不阻断整份报告生成；失败条目进入 `plugins`（保留失败状态）或 `unknownItems`。

## 5. 确定性与版本化

### 5.1 信封版本字段

| 字段 | 口径 |
|---|---|
| `schemaVersion` | 公共数据模型版本（当前 `0.1.0`），结构变更时递增 |
| `generatorVersion` | 导出器实现版本；离线 harness 与未来 Core 共用版本口径 |
| `profile` | `{ id, route }`，记录产出该报告的 Adapter Profile |
| `generatedAt` | ISO 8601 时间戳；**不纳入**确定性比较 |

### 5.2 确定性规则

- `plugins` 按 `pluginID` 排序；`unknownItems` 按 `path`（空则 `base`）排序；`warnings` 按 `code` 排序。
- 对象键顺序固定；数组内容按规则排序后序列化；相同输入两次导出，除 `generatedAt` 外深比较一致。
- 确定性比较字段集合：除 `generatedAt` 外的全部模型字段；`evidence.generatedAt` 类时间戳同样排除。
- 导出不依赖系统目录原始返回顺序、不依赖环境时区显示格式；路径规范化口径沿用前序阶段。

## 6. 异常分类与降级

| 层级 | 情况 | 模型落点 |
|---|---|---|
| 环境级 | 上游环境未识别 / Profile 未知 | `environment.jailbreakType=unknown`、`profileId=unknown-profile`；顶层 `warnings` 记 `profile_unknown` / `environment_unresolved` |
| 目录级 | TweakInject 目录未定位/不可读 | 环境路径证据置 `null`；`warnings` 记 `directory_unreadable`；插件条目保留枚举证据 |
| 配对级 | 缺 plist / 孤儿 plist / 歧义 / 不确定 | 对应 `pairing` 状态；其余入 `unknownItems`，带 `sourceStage=S1-05` |
| 解析级 | 读取失败 / 解析失败 / 类型不符 | `filter=null`、`validation.status` 记录原因；条目保留，不删除 |
| 归属级 | 冲突 / 混合来源 / 数据库不可用 / 标记损坏 | `ownershipDetails` 保留细节；`unknown` 归属显式记录；`warnings` 记对应代码 |
| 导出级 | 单条目整合失败 | 该条目入 `unknownItems`（`reason=export_integration_failed`），不中断整份报告 |

> 上游某阶段整体缺失时，不回退其他阶段结果补齐；相关字段 `null/unknown`，并在 `warnings` 标注缺失阶段。

## 7. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。

```
Tests/Fixtures/S1-08/
├── export-full-roothide/      # 混合：合法包管/自管/导入/未知，环境路径证据完整
├── export-rootless/           # Rootless 路线快照，Profile 与路径口径独立
├── export-partial-failures/    # 解析失败 + 孤儿 plist + 歧义配对，条目不丢失
├── export-conflict-mixed/      # S1-07 冲突 + 混合归属细节完整保留
├── export-dpkg-unavailable/    # 数据库不可用，归属 unknown，证据降级不猜
├── export-unknown-profile/     # ElleKit 版本未识别 → unknown-profile
├── export-missing-upstream/    # 上游目录未定位，空模型 + inventory_unresolved
├── export-evidence-preservation/ # otherKeys/skippedFields/markers/conflicts/notes 全保留
├── export-determinism/         # 相同快照两次导出，除 generatedAt 外一致
└── export-state-separation/    # installed/configured/loaded/permission 互不推导
```

每组分离 `environment.json`（前序快照输入）与 `metadata.json`（模型预期 + 确定性预期）；导出器不得读取 metadata。

## 8. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| EXPORT-001 | `export-full-roothide` | 信封字段齐全；环境/插件/未知项/告警结构符合模型 §3 | 必须通过 |
| EXPORT-002 | `export-rootless` | Rootless Profile 与路径口径独立，不套 RootHide 字段 | 必须通过 |
| EXPORT-003 | `export-partial-failures` | 解析失败/孤儿/歧义条目保留在 `plugins`/`unknownItems`，未被裁剪 | 必须通过 |
| EXPORT-004 | `export-conflict-mixed` | 冲突 owners、混合分文件归属、备注完整进入 `ownershipDetails`，不选边 | 必须通过 |
| EXPORT-005 | `export-dpkg-unavailable` | 归属 `unknown`，`dpkg_unavailable` 告警保留，不猜包名 | 必须通过 |
| EXPORT-006 | `export-unknown-profile` | `profileId=unknown-profile`，`profile_unknown` 告警；未知 Profile 不降级套用路线规则 | 必须通过 |
| EXPORT-007 | `export-missing-upstream` | 上游未定位时空模型/空插件，`inventory_unresolved`；不回退扫描 | 必须通过 |
| EXPORT-008 | `export-evidence-preservation` | `otherKeys`/`skippedFields`/`markers`/`conflicts`/`notes` 全部序列化可比对 | 必须通过 |
| EXPORT-009 | `export-determinism` | 两次导出除 `generatedAt` 外深比较一致；排序确定 | 必须通过 |
| EXPORT-010 | `export-state-separation` | `installed`/`configured` 按允许来源派生；`loaded=unknown`；`permission.decision=undetermined` | 必须通过 |
| EXPORT-011 | 全量快照 | 三层状态与归属/权限互斥：无任何由归属推导权限、由配置推导加载的记录 | 必须通过 |
| EXPORT-012 | 全量快照 | 未取到项显式 `null/unknown`，无空串冒充已知；证据标签全部 `fixture` | 必须通过 |
| EXPORT-013 | S1-01~S1-07 回归 | 前序产物保持通过，未被本项改动 | 必须通过 |

### 8.1 断言要点

- 每条 Plugin 的 `source` 与 `ownership.sourceType` 一致；`ownership.packageID/listPath/confidence/writablePolicy` 与 S1-07 一致。
- `configured=true` 当且仅当 S1-06 `parseStatus=valid`；`loaded` 全部 `unknown`；`permission.decision` 全部 `undetermined`。
- 计数闭合：`plugins[]` + `unknownItems[]` 覆盖上游全部条目；告警去重后与来源阶段对应。
- 确定性：排序规则固定；时间戳排除在一致性比对之外。

## 9. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机一轮完整导出的模型完整性 | 端到端字段覆盖 | 待真机只读采样，离线为合成快照 |
| 真机 Profile 识别与版本映射 | `profileId` 准确性 | 待真机核对 ElleKit 版本 |
| 运行时加载取证接口 | `loaded` 脱离 `unknown` | 后续阶段，本阶段不取证 |
| 管理授权门禁口径 | `permission.decision` 取值 | 后续阶段定义，本项恒 `undetermined` |
| Rootless/Rootful 真机模型适配 | 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| `pluginID` 定稿规则 | 稳定标识 | 0.2.0 定稿，离线按优先级规则生成 |

## 10. 通过与失败标准

### 10.1 通过条件

- 信封与 Plugin/FilterRule/Ownership/Validation 结构符合模型 §2/§3；前序证据无丢失；
- 三层状态与来源/权限分离口径落实；不确定状态显式保留；
- 相同输入可重复导出（除时间戳外一致）；导出为只读产物，不回写设备；
- 全部离线证据标记 `fixture`，不冒充真机验证。

### 10.2 失败情形（任一即不通过）

- 为规整报告丢弃告警、冲突、跳过字段、扩展键、未配对/失败条目；
- 由 `installed`/归属/Bundles 命中推导 `configured` 或 `loaded`；由 `writablePolicy`/来源推导管理放行；
- 未知 Profile 强行套用 RootHide/Rootless 规则；未取到字段留空串冒充已知；
- 两次导出因排序/键序/时间戳处理不一致而不可重复；
- 导出过程读写设备、修改 dpkg/plist/dylib/软链，或执行启停/注入；
- 把离线 fixture 结论标为真机背书。

## 11. 设计边界

- S1-08 只整合与序列化；**不做**重新扫描、重新解析、归属补判、完整性校验、运行时取证或操作执行。
- 本项不创建正式 App 工程、不实现 GUI、不处理 entitlement、不接入进程内 `jbroot()`；离线 harness 非 App 运行时。
- Stage 1 只读 CLI 验证链在本项离线验收后形成闭环；Core/Models/Adapters 的工程化迁移属后续独立授权阶段。
- S1-08 离线测试须单独授权后再创建夹具与代码；在此之前不展开工程骨架与编译。
