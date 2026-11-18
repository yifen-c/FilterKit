# Stage 2.2-C2-B：Plugin Pairing Key / Index / Engine 实现记录（代码冻结，Runner 验收待授权）

- 状态：**Implementation Complete / Local Static Review Passed**；**Runner Build & Test 未执行**（本机 Linux 无 Swift 工具链；编译、C2-A Codable 与既有/S1-05 回归统一纳入 C2-D Runner 验收）。既有 114 例（B 91 + C1 23）与 Stage 1 基线未改动。
- 依据：C1 验收提交 `5b481e6`、G-C3 契约冻结 `7dbac87`、C2-A 模型冻结 `cc5c98e`、`Stage-2.2-C2-Pairing-Contract.md` PC1~PC12。
- 批次定位：C2-B 将 C1 `PluginInventorySnapshot` 纯计算转换为 C2 `PluginPairingSnapshot`；只做文件名级文件关联，不读 plist 内容、不接服务装配、不改 Adapter。C2-C 集成证据、C2-D 完整回归不在本批。

## 1. 本轮授权边界

### 已允许并执行

- `PluginPairingKeyBuilder`：配对键生成（精确后缀剥离、大小写敏感、空键排除）。
- `PluginPairingIndex` / `PluginPairingIndexBuilder`：同目录作用域候选分组索引，多候选全量保留、按路径排序。
- `PluginPairingClassifier`：五态归类决策。
- `PluginPairingEngine`：索引→分类→记录→归集→快照编排（纯计算）。
- `PluginPairingSnapshotBuilder`：五桶计数、目录级状态解析、unknownItems/warnings 归集。
- 合成夹具专项测试：Key 11 例、Index 5 例、Engine 21 例；`Package.swift` 登记新源与测试源。

### 禁止项（本轮均未触碰）

- 未修改 C2-A 冻结 Models（6 源）、C1 枚举器/Models、七方法协议、RootHide/Rootless Adapter、Stage 1 fixtures/harness、既有通过测试。
- 未接入 `PluginScanService` / `AdapterResolver`；未实例化任何具体 Adapter；未跨目录/跨快照合并，未引入 `/var/jb` 回退。
- 未编译、未跑 Runner、未扫描真机；无插件文件读写、软链改动、注入配置修改或启停。
- 未进入 C2-C；快照未进 `ReportEnvelope`，未组装最终 `Plugin`，未推断 loaded/configured/installed。

## 2. 文件清单

| 文件 | 模块 | 职责 |
|---|---|---|
| `Core/PluginPairing/Key/PluginPairingKeyBuilder.swift` | Core | 键生成：仅 `.dylib`/`.plist` 精确后缀；空键返回 nil；不 lowercase/不模糊匹配/不读内容 |
| `Core/PluginPairing/Index/PluginPairingIndex.swift` | Core | 两张 `[String: [PluginFileEvidence]]` 字典；键集合有序访问 |
| `Core/PluginPairing/Index/PluginPairingIndexBuilder.swift` | Core | 由库存快照分组建索引；候选按 `path ?? name` 字母序；非候选类型不入索引 |
| `Core/PluginPairing/Engine/PluginPairingClassifier.swift` | Core | 归类决策：受限优先 uncertain → 多候选 ambiguous → 数量规则 paired/missing/orphan |
| `Core/PluginPairing/Engine/PluginPairingEngine.swift` | Core | 纯计算编排；未决/失败目录短路不建记录；空键条目归集 unknownItems |
| `Core/PluginPairing/Engine/PluginPairingSnapshotBuilder.swift` | Core | 计数、目录级四态解析、告警归集（`inventory_unresolved`/`partial_pairing`） |
| `Tests/Stage2/PluginPairingKeyTests.swift` | Test | 键专项 11 例 |
| `Tests/Stage2/PluginPairingIndexTests.swift` | Test | 索引专项 5 例 |
| `Tests/Stage2/PluginPairingEngineTests.swift` | Test | 引擎专项 21 例 |

## 3. 契约落地对照（PC1~PC12）

| 编号 | 落地情况 |
|---|---|
| PC1 | Engine 唯一输入为 `PluginInventorySnapshot`；`unknownItems` 原样透传，不并入候选 |
| PC2 | 索引仅收 `.dylib`/`.plist`；`.directory/.symlink/.other` 留 C1 归集；软链按文件名参与，身份证据在证据位保留、不跟随目标 |
| PC3 | `hasSuffix(".dylib"/".plist")` 精确匹配；大小写敏感；键保留原始大小写/空格/隐藏前缀 |
| PC4 | 文件名恰为后缀（空键）不进索引，归集 `unknownItems`，`reason=empty_pairing_key`，`sourceStage=stage2.2-c2` |
| PC5 | Engine 只消费单个已定位快照；无跨快照合并接口；不引入外目录回退路径 |
| PC6 | 五桶互斥；paired/missing_plist/orphan_plist 映射既有 `Pairing` 四值；ambiguous/uncertain `pairing=nil` |
| PC7 | 同键多 dylib 或多 plist → ambiguous；全候选入 `candidates`，不取 first；`basis=ambiguous_multi_candidate` |
| PC8 | 任一侧 `entryStatus != .ok` → uncertain；留置两侧候选；`reason` 承载 entryStatus 原值；`pairing=nil` |
| PC9 | 目录级四态 `enumerated/partial/enumeration_failed/unresolved`，原始值对齐 S1-05 |
| PC10 | 计数按记录组数；五桶之和 = `records.count`；`total` 为五数之和 |
| PC11 | 依据用封闭枚举 `PairingEvidenceBasis`；证据块复用 `EvidenceBlock`，无自由字符串证据数组 |
| PC12 | 键集合字母序遍历；候选按路径排序；相同输入重复执行与打乱枚举顺序输出一致（测试锁定） |

## 4. 归类决策口径（含本轮裁定）

决策优先级（对齐 S1-05 `pairing.js` 实际流程与契约 §6）：

1. **受限优先**：D 或 P 任一侧 `entryStatus != .ok` → `uncertain`。受限关系不能裁决为 paired/missing_plist/orphan_plist；两侧候选留置入 `candidates`，`reason=entryStatus` 原始值。
2. **纯多候选**：两侧均 `.ok` 且 D>1 或 P>1 → `ambiguous`，全候选保留。
3. **数量规则**：1+1 `paired`；1+0 `missing_plist`；0+1 `orphan_plist`（`reason="missing_dylib"`）。

### 口径边界（按契约精确条款，未照搬示意代码）

- **`entryStatus` 与 `readable` 三态位分离**：分类只依据 `entryStatus`；`readable == nil`（未验证）在 `entryStatus == .ok` 时不触发 uncertain（测试 `testReadableNilWithOkStatusIsPaired` 锁定）。
- **`not_found`**：属非 ok 受限状态，按 uncertain 留置，不按"不存在"判 missing/orphan（契约 §6 未将 not_found 排除在受限集外）。
- **软链**：C1 证据位记录 `isSymlink/symlinkTarget`；C2 不解析跟随；断链/目标受限由 `entryStatus` 表达，非 ok 进 uncertain。
- **受限与歧义并存**：受限优先于歧义（与基线 JS 第 57 行先判受限 dylib 一致）；该并存组合在现有 S1-05 夹具中无实例，裁定依据已记入本记录，C2-D 回归若发现新夹具需复核。
- **未决/失败目录**：`sourceDirectory == nil` 或枚举状态 `.unresolved`/`.enumerationFailed` 时不构建配对记录（对齐 route-guard 基线：records 0、计数全 0、`inventory_unresolved` 告警）。
- **空键/其他类型**：dylib/plist 空键补登记 unknownItems；directory/symlink/other 由 C1 归集，C2 不重复登记；ambiguous/uncertain 明细以 records 为准，不在 unknownItems 双写路径清单。

## 5. 测试映射（37 例，合成夹具）

### KEY（11 例，`PluginPairingKeyTests.swift`）

| 组 | 覆盖 |
|---|---|
| 后缀剥离 | dylib/plist 精确剥离；`lib` 前缀保留 |
| 大小写 | 大写后缀不匹配；键保留原大小写不 lowercased |
| 空键 | `.dylib`/`.plist` 空键排除 |
| 隐藏前缀 | `.Hidden` 前缀保留 |
| 类型排除 | directory/symlink/other 返回 nil |

### INDEX（5 例，`PluginPairingIndexTests.swift`）

重复候选不覆盖、候选路径排序、键集合有序、非候选类型排除、同 basename 多条目不折叠。

### ENGINE（21 例，`PluginPairingEngineTests.swift`）

| 组 | 覆盖 |
|---|---|
| 五桶 | paired / missing_plist / orphan_plist / ambiguous（多 plist、多 dylib） |
| uncertain | access_denied 双侧留置、read_failed 单侧、not_found；readable nil 不混判 |
| 作用域 | 跨快照不合并（左 missing、右 orphan，不产生 paired） |
| 空目录 | 无条目 → enumerated、records 0、计数 0 |
| 确定性 | 打乱输入顺序记录一致；重复 100 次一致 |
| 计数 | 五桶之和 = records.count，无重复计数 |
| 归集 | C1 unknownItems 透传；空键补登记；other 扩展名不入记录 |
| 状态 | unresolved（目录缺失）、enumeration_failed、partial + `partial_pairing` |
| 不变性 | 输入快照不被改写；`Pairing` 四值映射正确，歧义/不确定 pairing 为 nil，`missing_dylib` 不在分类桶重复造值 |

### 基线回归位置

S1-05 原始 15 例（PAIR-001~013 + 2 合成）的行为回归归 C2-D Runner 统一执行；本批专项测试不替代该基线。既有 114 例未改动、未在本机重跑。

## 6. 静态审查记录与未决项

- 隔离核对：6 个新 Core 源仅 `import Foundation`（另 `import Models`）；无 Adapter/RootHide/Rootless 引用，未实例化 Adapter；`/var/jb` 回退路径未引入。
- 括号平衡、类型引用、初始化参数按既有 C1/C2-A 范式静态核对；本机无 Swift 工具链，**编译结果以 C2-D Runner 出证为准**。
- 2.2-A R6（未知枚举原始值默认解码行为）仍未实测；本批未新增枚举原始值，解码表现留 C2-D 记录。
- 待 C2-C 验证：C1 目录状态透传、不可读文件保留、unknownItems/warnings 完整传递、两侧目录作用域一致、C2 始终不读 plist 内容。
- 若后续发现 C2-A 模型字段无法承载 Engine 需求，须先报告契约冲突，不得直接改冻结模型。

## 7. 非目标（明确不在 C2-B 范围）

- C1→C2 集成链路、证据传递验证（C2-C）。
- 完整 Runner 编译、114 既有 + S1-05 15 回归、隔离/App 构建验收（C2-D）。
- C3 Filter 解析、S1-07 归属、S1-08 导出；真机兼容/权限/注入/启停。

## 8. 下一阶段门槛

- **C2-C 授权前**：本批静态审查通过；C2-A 模型与 C1/协议/Adapter/夹具/既有测试零改动。
- **C2-D Runner 验收门槛**：Swift Build 通过；Swift Test 零失败；既有 114 例不回退；S1-05 15 例通过；五桶计数互斥、三态保留、确定性排序正确；Core 隔离三向通过；App Build 成功；Stage 1 基线不被修改。
