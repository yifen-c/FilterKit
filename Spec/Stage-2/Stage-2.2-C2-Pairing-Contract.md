# Stage-2.2-C2-Pairing-Contract.md — 配对快照 / 记录 / 计数数据契约冻结（G-C3 定稿）

> 批次：Stage 2.2-C2 第一步（前置设计评审）。输入基线：C1 验收提交 `5b481e6`、代码冻结提交 `b6b4cef`、S1-05 离线基线（`Tests/Fixtures/S1-05/`、`Tests/S1-05/pairing.js`、`run.js`、`report/S1-05-report.json`）、C1 枚举契约 `Stage-2.2-C-Enumeration-Models-Contract.md`。
> 状态：**契约冻结（设计层）**；本文件只定义字段、类型、Optional 语义、归类口径与 Codable 要求，**未落地 Swift 代码**；C2-A 起逐批单独授权。

## 1. 冻结总则

1. C2 只做**文件名级文件关联**：把 C1 清单中的 dylib/plist 精确配对；不读取 plist 内容、不解析 Filter、不判断安装/加载/运行状态、不改文件、不增删软链、不改注入配置。
2. 公共 `Pairing` 枚举维持冻结四值，**不新增** `ambiguous`/`uncertain`/`conflicted` 等取值；歧义与不确定由配对快照记录分类、`UnknownItem` 与既有证据结构承载。
3. 配对是纯规则层：输入 C1 `PluginInventorySnapshot`，输出 C2 配对中间快照；不重新访问文件系统，不向 C1 回写字段，不产出最终 `Plugin`，首版快照不进 `ReportEnvelope`。
4. 所有归类互斥：同一栈条目在任一记录中只落入一个五态桶；计数总和与记录明细一致。
5. 三态事实位沿用 C1 口径：`nil`=未验证，不转 `false`；受限/不可读 ≠ 不存在，不据此判缺失或孤儿。

## 2. 决策定稿表（PC1~PC12）

| 编号 | 决策点 | 定稿口径 |
|---|---|---|
| PC1 | 输入边界 | 仅消费 C1 `PluginInventorySnapshot`（`route/sourceDirectory/enumeration/items/unknownItems/counts/warnings`）；不要求 C1 补基线外字段；`unknownItems` 原样透传，不并入配对候选 |
| PC2 | 候选范围 | 仅 `kind == .dylib` / `.plist` 进入配对索引；`.directory/.symlink/.other` 留快照 `unknownItems`，不参与配对；软链仍按文件名参与配对，身份证据在 `PluginFileEvidence` 内保留，不跟随目标 |
| PC3 | 配对键 | 键 = 文件名剥离精确后缀 `.dylib` / `.plist`；后缀与文件名比较均**大小写敏感**；不 `lowercased()`、不模糊包含、不用内容推断；隐藏前缀保留在键内（`.hidden.dylib` → `.hidden`） |
| PC4 | 空键边界 | 文件名恰为后缀（键为空串）的条目不参与配对，归集 `unknownItems`，`reason=empty_pairing_key`，避免空键跨条目合并 |
| PC5 | 目录作用域 | 配对限定在同一 `sourceDirectory` 作用域；不按全局 basename 跨目录/跨快照配对；foreign 陷阱条目在 C1 已排除/归集，C2 不再引入回退路径 |
| PC6 | 五态桶 | 互斥五桶：`paired / missing_plist / orphan_plist / ambiguous / uncertain`；前三个映射到既有 `Pairing` 四值，后两个以记录分类独立承载，不写进 `Pairing` 枚举 |
| PC7 | 歧义表达 | 同键多 dylib 或多 plist → `ambiguous`：全量候选入 `candidates`，不任选其一；记录 `pairing = nil`，分类标 `.ambiguous`；归集条目 `sourceStage="stage2.2-c2"` |
| PC8 | 不确定表达 | 任一侧 `entryStatus != .ok` → `uncertain`：留置对应候选不消费，不判 `missing_plist`/`orphan_plist`；`reason` 承载原始 `entryStatus` 值；记录 `pairing = nil` |
| PC9 | 目录级状态 | 独立 `PairingStatus` 四态，原始值与 S1-05 基线逐字一致：`enumerated / partial / enumeration_failed / unresolved`；不采用 `completed/failed` 新词汇；`uncertain > 0` → `partial`，否则 `enumerated` |
| PC10 | 计数口径 | `PluginPairingCounts` 五桶按**记录组数**计数（与基线 `counts` 一致）；`candidates` 明细数不等同计数；`unresolved` 是目录级状态，不单列条目桶计数 |
| PC11 | 证据复用 | 记录内不新增自由字符串 `[String] evidence`；匹配依据用封闭码 `basis`，条目证据直接引用 `PluginFileEvidence`；需要证据块时复用既有 `EvidenceBlock` |
| PC12 | 排序确定性 | 记录按 `pairingKey` 字母序、再按 `path` 字母序确定性排序；索引键字典遍历结果排序后再归类；重复配对深比较一致 |

## 3. 输入边界（C1 → C2）

### 3.1 复用的既有类型（不修改）

| 既有类型 | C2 用途 |
|---|---|
| `PluginInventorySnapshot` | 唯一输入；`route/sourceDirectory/enumeration.status/items/unknownItems/counts/warnings` |
| `PluginFileEvidence` | 配对两侧条目证据原样引用（`path/name/extension/kind/exists/readable/isSymlink/symlinkTarget/symlinkState/realpath/size/hash/hidden/entryStatus`） |
| `Pairing` | 公共配对分类四值：`paired / missing_plist / orphan_plist / missing_dylib`；原始值冻结 |
| `UnknownItem` | 非候选、空键、歧义/不确定归集条目载体（`path/base/reason/sourceStage/detail`） |
| `ReportWarning` | 快照级告警载体（`code/message/sourceStage`） |
| `EvidenceBlock` | 可选证据块（`sourceStages/evidenceType/evidenceLevel`）；不平行新建证据协议 |

### 3.2 输入前置判定

1. `sourceDirectory == nil`（上游未定位）→ 快照状态 `unresolved`，`records=[]`、计数全 0，告警 `inventory_unresolved`；不回退 `/var/jb` 或任何文件根。
2. `enumeration.status == .unresolved` → 同上 `unresolved`；`enumeration.status == .enumerationFailed` → 状态 `enumeration_failed`，空记录，告警 `inventory_unresolved`。
3. 清单可枚举但无 dylib/plist 候选 → `enumerated`，五桶计数全 0；空目录不判失败。

## 4. G-C3 定稿模型（增补，未落地为 Swift 代码）

### 4.1 记录分类枚举（五桶封闭集）

```swift
public enum PairingCategory: String, Codable, Equatable {
    case paired
    case missingPlist = "missing_plist"
    case orphanPlist = "orphan_plist"
    case ambiguous
    case uncertain
}
```

- 与既有 `Pairing` 的映射：
  - `.paired` ↔ `Pairing.paired`
  - `.missingPlist` ↔ `Pairing.missingPlist`（`missing_plist`）
  - `.orphanPlist` ↔ `Pairing.orphanPlist`（`orphan_plist`）
  - `.ambiguous` / `.uncertain` → `pairing: Pairing? = nil`，**不**写入任何 `Pairing` 取值。
- 既有 `Pairing.missingDylib`（`missing_dylib`）保持冻结不动；C2 孤儿 plist 记录以 `reason="missing_dylib"` 文本口径承载，不在分类枚举中重复造值。

### 4.2 目录级配对状态（四态封闭集）

```swift
public enum PairingStatus: String, Codable, Equatable {
    case enumerated
    case partial
    case enumerationFailed = "enumeration_failed"
    case unresolved
}
```

判定优先级（与 C1 状态纪律一致）：`unresolved`（目录未定位）→ `enumeration_failed`（清单不可枚举）→ `partial`（存在 uncertain 记录）→ `enumerated`（完整配对）。

### 4.3 配对记录结构

```swift
public struct PluginPairingRecord: Codable, Equatable {
    /// 五态分类（封闭集）。
    public var category: PairingCategory
    /// 映射到既有 Pairing 四值；ambiguous/uncertain 为 nil。
    public var pairing: Pairing?
    /// 配对键（剥离后缀的基名）；空键不产生记录（PC4）。
    public var pairingKey: String?
    /// dylib 侧证据；missing_plist/ambiguous 之外按需存在。
    public var dylib: PluginFileEvidence?
    /// plist 侧证据；orphan_plist/ambiguous 之外按需存在。
    public var plist: PluginFileEvidence?
    /// 歧义全量候选（含两侧）；非歧义桶为空数组。
    public var candidates: [PluginFileEvidence]
    /// 不确定原因（uncertain 承载 entryStatus 原始值）；孤儿 plist = "missing_dylib"。
    public var reason: String?
    /// 匹配依据封闭码：exact_filename_match / no_opposite_candidate / ambiguous_multi_candidate / uncertain_access / held_against_uncertain。
    public var basis: String
    /// 可选证据块；复用 EvidenceBlock，不新增自由字符串证据数组。
    public var evidence: EvidenceBlock?
    /// 记录级告警。
    public var warnings: [ReportWarning]
}
```

字段口径：
- `dylib`/`plist` 为可选中立证据；`nil` 表示该侧未列入，不反推补齐路径或占位名。
- `candidates` 仅 `.ambiguous` 非空；列出全部候选，不排序后取首项。
- `reason` 原始值取自 C1 `PluginEntryStatus`（`access_denied / metadata_unavailable / read_failed / not_found`）或基线 `missing_dylib`；不翻译、不合并成 `failed`。
- `basis` 为封闭码集合；集合外延须在 C2-A 实现评审时冻结，不得在记录内塞自由文本结论。

### 4.4 计数结构

```swift
public struct PluginPairingCounts: Codable, Equatable {
    public var paired: Int          // 缺省 0
    public var missingPlist: Int    // 原始键 missing_plist
    public var orphanPlist: Int     // 原始键 orphan_plist
    public var ambiguous: Int       // 歧义组数
    public var uncertain: Int       // 不确定条数
}
```

- 五个计数与 `records` 五桶一一对应；`paired + missingPlist + orphanPlist + ambiguous + uncertain == records.count`（互斥不重不漏）。
- 原始 JSON 键沿用 S1-05：`paired / missing_plist / orphan_plist / ambiguous / uncertain`。

### 4.5 配对快照结构

```swift
public struct PluginPairingSnapshot: Codable, Equatable {
    public var route: String?
    public var sourceDirectory: String?
    public var status: PairingStatus
    public var records: [PluginPairingRecord]
    public var unknownItems: [UnknownItem]
    public var counts: PluginPairingCounts
    public var warnings: [ReportWarning]
}
```

- `unknownItems`：透传 C1 非候选条目 + 本轮空键归集；歧义/不确定的明细以 `records` 为准，不在 `unknownItems` 双写一份路径清单，避免两套计数不一致。
- 首版不进 `ReportEnvelope`，不组装最终 `Plugin`；`loaded/configured/installed` 等运行层结论不由本层推导。

## 5. 配对键与索引规则

### 5.1 键生成

1. 仅 `.dylib` / `.plist` 条目尝试取键；其他类别跳过。
2. 后缀必须精确匹配：`name.hasSuffix(".dylib")` 或 `name.hasSuffix(".plist")`；大小写敏感（`.DYLIB`/`.PLIST` 已在 C1 归为 `.other`，本层不二次纠正）。
3. 键 = 去掉后缀后的剩余部分；剩余为空串 → 空键，按 PC4 归集。
4. 键保留原始大小写、空格、点号与隐藏前缀；不做 trim、不规范化 Unicode、不转小写。

### 5.2 索引

- 两张字典：`[key: [PluginFileEvidence]]` 分别收 dylib、plist；同键多条目全部保留为数组。
- 索引只消费快照 `items`；foreign/外目录陷阱条目不在索引内。
- 归类前先对键集合排序，保证索引遍历确定性（PC12）。

## 6. 归类决策表（五态互斥）

设同键 dylib 集合 D、plist 集合 P（均来自同一 `sourceDirectory` 作用域）：

| 条件 | 归类 | 记录要点 |
|---|---|---|
| D 数 = 1 且 P 数 = 1，两侧 `entryStatus == .ok` | `paired` | `pairing=.paired`，两侧证据入记录，`basis=exact_filename_match` |
| D 数 = 1，P 数 = 0，dylib `entryStatus == .ok` | `missing_plist` | `pairing=.missingPlist`，不造 plist；`basis=no_opposite_candidate` |
| D 数 = 0，P 数 = 1，plist `entryStatus == .ok` | `orphan_plist` | `pairing=.orphanPlist`，`reason="missing_dylib"`；`basis=no_opposite_candidate` |
| D 数 > 1 或 P 数 > 1 | `ambiguous` | 全候选入 `candidates`，不选边；`pairing=nil`，`basis=ambiguous_multi_candidate` |
| D 或 P 任一侧 `entryStatus != .ok` | `uncertain` | 留置对应候选不消费；`reason=entryStatus` 原值；`pairing=nil`，`basis=uncertain_access` |
| 配对后未被消费的 plist 且 `entryStatus != .ok` | `uncertain` | 同上，不记 `orphan_plist` |
| 配对后未被消费的 plist 且 `entryStatus == .ok` | `orphan_plist` | 同孤儿规则 |

补充纪律：
- 大小写变体（`A.dylib` vs `a.plist`）互不为候选：分别落 `missing_plist` / `orphan_plist`。
- 断链/目标受限软链：身份证据在 `PluginFileEvidence`；条目 `entryStatus != .ok` 时进 `uncertain`，不记 `paired`。
- 单条受限不中断整轮：其余条目照常归类，目录级状态按 §4.2 记 `partial`。

## 7. 目录作用域与路径身份

- 配对键比较在文件名层；成立前提是两侧同属快照 `sourceDirectory`。快照内不混合第二个目录身份；未来多目录导入须显式携带目录身份，本版不开放跨目录基名配对。
- 记录保留两侧 `path`（原始身份键）；不按基名合并不同路径的同名条目。
- `pair-cross-path` 陷阱：foreign 条目（C1 标记外路线/外目录）不进索引；结果路径不得出现 `/var/jb` 回退前缀。

## 8. Codable 兼容与确定性口径

1. 新结构均为 `Codable, Equatable`；可选字段经 `decodeIfPresent` 解码；缺省：计数 `0`、`records/unknownItems/candidates/warnings=[]`、`status=.enumerated`、`pairing=nil`。
2. 未知键按合成解码器默认忽略；不新增严格未知键抛错；不新增静默默认枚举值（2.2-A R6 观察项沿用，实际解码表现待 C2 Runner 轮记录）。
3. `null` 与字段缺失语义保持：缺可选 = `nil`，不补空串/空数组冒充已知；三态位不填 `false`。
4. 排序确定性：`records` 按 `pairingKey`（nil 兜底 `path`）字母序；`candidates` 按 `path` 字母序；相同快照重复配对，关系、归类、计数、顺序深比较一致。
5. 既有 Models 字段、`Pairing` 原始值、既有 Codable 测试不变；本批增补不并入既有冻结断言。

## 9. S1-05 原始 15 例映射（C2 回归基线）

| # | 编号 | 夹具/来源 | 归类断言 | 计数要点 |
|---:|---|---|---|---|
| 1 | PAIR-001 | `pair-valid` | `Example.dylib` ↔ `Example.plist` → `paired` | paired 1 |
| 2 | PAIR-002 | `pair-missing-plist` | dylib → `missing_plist`，不造 plist | missing_plist 1 |
| 3 | PAIR-003 | `pair-orphan-plist` | plist → `orphan_plist`，`reason=missing_dylib` | orphan_plist 1 |
| 4 | PAIR-004 | `pair-multi` | 多组分别建立，计数一致 | paired 3（Alpha/Beta/Gamma） |
| 5 | PAIR-005 | `pair-case-mismatch` | 大小写不同不配对，分记 `missing_plist`/`orphan_plist` | 双侧各 1 |
| 6 | PAIR-006 | `pair-cross-path` | 跨目录同名不配对、不合并，路径分别保留 | 同目录 paired 1；foreign 排除 |
| 7 | PAIR-007 | `pair-hidden` | `.hidden.dylib` ↔ `.hidden.plist`，隐藏标记保留 | paired 1，键 `.hidden` |
| 8 | PAIR-008 | `pair-symlink` | 软链身份保留并参与配对；断链/受限进 `uncertain` | paired 1（ok 软链） |
| 9 | PAIR-009 | `pair-other-ext` | `.txt/.deb/.DYLIB` 不进入配对候选 | 五桶全 0，入 unknownItems |
| 10 | PAIR-010 | `pair-duplicate` | 同基名多候选 → `ambiguous`，列全候选不任选 | ambiguous 1（基名 Case） |
| 11 | PAIR-011 | `pair-access-denied` | 受限条目 → `uncertain`，留置对应 plist，不判缺失/孤儿 | uncertain 1，状态 `partial`，告警 `partial_pairing` |
| 12 | PAIR-012 | `route-guard` | 上游未定位 → `unresolved` 空报告，不回退扫描 | 全 0，告警 `inventory_unresolved` |
| 13 | PAIR-013 | `pair-determinism` | 相同清单重复配对结果确定 | paired 1 / missing_plist 1 |
| 14 | PAIR-013 | `synthetic:determinism` | 配对关系、归类、计数深比较一致 | 两轮快照全等 |
| 15 | PAIR-006 | `synthetic:route-isolation` | 无 `/var/jb` 回退路径；无跨路线配对 | `sourceDirectory=nil` 时不泄漏路径 |

C2 编码轮回归基线：既有 B 段 91 + C1 23 保持通过；S1-05 15 例逐例对应；另补快照 Codable 往返、空目录、互斥不重不漏、排序确定性附加用例（C2-A/C2-C 授权时细化）。

## 10. C2 / C3 数据流边界

```
C1 PluginInventorySnapshot（已冻结验收）
        │  仅 items 中 dylib/plist；unknownItems 透传
        ▼
C2 PluginPairer ── PluginPairingSnapshot（本批冻结边界）
        │  仅 paired 记录侧进入 C3 解析；其余携带为 notParsed 线索
        ▼
C3 FilterParser ── ParseReport（G-C4/G-C5，C3 前置评审冻结）
```

- C2 不读 plist 字节/内容；plist 内容信号是 C3 输入。
- C2 不向 C3 传递"已安装/已加载"结论；运行层状态留后续阶段。
- `PluginCandidate`（Adapter 协议 DTO）与配对快照的装配衔接，在 C2 实现授权时按协议评审口径界定；本轮不改七方法协议、不改 AdapterResolver。

## 11. 硬门禁自查（契约冻结前逐项核对）

- [x] 未修改既有 Models 字段/枚举/原始值与解码行为；`Pairing` 四值未扩
- [x] 未修改 `ElleKitAdapter` 七方法协议与双路线 Adapter
- [x] 未改动 Stage 1 Fixtures、harness、`S1-05-report.json` 与既有 Stage2 测试
- [x] 五态互斥口径与 S1-05 `pairing.js`/`run.js` 一致；计数总和 = 记录数
- [x] 配对键大小写敏感、无模糊匹配、无 lowercase fallback、无内容推断
- [x] 目录作用域冻结；无跨目录/跨快照基名配对；无 `/var/jb` 回退
- [x] 受限/不确定与缺失/孤儿区分；三态位不转 `false`
- [x] 快照不进 `ReportEnvelope`，不产出最终 `Plugin`，不推断 `loaded`
- [x] 未编译、未运行 Runner、未连接真机；无插件读写、软链改动、注入配置修改或启停

## 12. 暂缓与遗留事项

- `basis` 封闭码外延、`EvidenceBlock` 在记录内的挂载位置：C2-A Models 落地评审时按本契约 §4.3 细化，不新增自由文本证据协议。
- 多目录/多路线混合配对的目录身份模型：本版不开放；留待需要多目录导入的批次单独评审。
- G-C4 解析五态与结构化 `skippedFields`、G-C5 Rootless 内部模型：归 C3 前置评审，本批不展开。
- G-C6 哈希/元数据真机可取性：沿用 C1 契约 §7，留 2.5 只读验证。
- 2.2-A R6（未知枚举原始值默认解码行为）仍未实测未修改；C2 新增枚举解码表现由 C2 Runner 轮记录。

## 13. 授权边界（保持）

- ✅ 已授权：本 G-C3 数据契约冻结文档的撰写与归档；配对快照/记录/计数/状态/分类的字段、类型、Optional、归类与 Codable 口径定稿。
- ❌ 未授权：C2 任何 Swift 编码；Models 增补落地；Core 配对器/索引/编排代码；`Package.swift` 接线变更；新增 Swift 测试；协议演进；Runner 编译/测试；真机扫描；插件读写、软链改动、注入配置修改或启停；进入 C3 解析。
- 下一阶段：C2-A（Pairing Models / Snapshot）须单独授权，且以本契约为准；落地后按 C2 门槛复验 S1-05 15 例 + 既有 114 例回归 + 快照 Codable/确定性附加用例。
