# Stage-2.2-C-Enumeration-Models-Contract.md — 枚举证据 / 清单快照数据契约冻结（G-C1 / G-C2 定稿）

> 状态：**2.2-C 第二步数据契约冻结（设计层）**。本文定稿 G-C1 插件文件证据模型、G-C2 枚举清单快照模型的字段、类型、Optional 语义、枚举原始值、Codable 兼容策略与 C1/C2/C3 数据流边界；**不含任何 Swift 源码实现，未落地 Models/Core 代码**。
> 生效条件：C1 编码、Models 增补落地、协议修改、测试代码编写均仍未授权；C1 实现阶段必须以本文契约为准。
> 依据：`Stage-2.2-C-Audit.md`（G-C1~G-C6 缺口）、`Stage-2.2-C-Enumeration-Pairing-Parser.md`（C1~C4 批次与门槛）；Stage 1 基线 `Tests/S1-04/enumerator.js`、`Tests/Fixtures/S1-04/`、`Tests/S1-04/report/S1-04-report.json`（23/23）；现有 Models/Core/协议现文件。

## 1. 冻结总则

1. **只增补，不改语义**：现有 `Plugin / FilterRule / Pairing / UnknownItem / ReportWarning / ValidationReport` 等既有字段名称、类型、原始值、解码行为不变；新模型与新字段一律 `Optional` 或带基线缺省值，不改变既有 91 例回归口径。
2. **三态校验**：事实位 `Bool?` 中 `true`=已验证通过、`false`=已验证失败、`nil`=未验证；未验证不得填 `false`，不留空串冒充已知。
3. **过程证据与最终模型分离**：枚举阶段产生的条目证据挂独立中间模型，不塞进最终 `Plugin`；避免在位/可读/真实路径等过程信号在后续配对、解析环节丢失或被反推补齐。
4. **事实与规则分离**：模型只记录事实（路径、分类、软链、元数据、条目状态、告警）；枚举分类/排序/路线规则只在 Core 枚举器与各自 Adapter 内实现，模型内不出现路线判断代码。
5. **未知不丢信息**：开放取值（`symlinkState`、`route`）用 `String` 原样保留；封闭取值集见 §3/§4；非已知值原样入库并附告警，不在解码期静默改写。
6. **唯一权威**：每个事实只允许一个权威数据源；`PluginCandidate`（Adapter 协议 DTO）与本批中间快照各司其职，不维护第二套可独立变更的条目状态。
7. **只读边界**：本批模型不承载加载结论；`loaded` 不在 C1 出现；不递归、不跟随软链、不丢弃访问受限条目。

## 2. 决策定稿表（DC1~DC12）

| # | 决策项 | 定稿选择 | 理由 | Stage 1 基线影响 | 兼容策略 |
|---|---|---|---|---|---|
| DC1 | 证据模型落点 | 新增独立 `PluginFileEvidence`（Models 增补侧），不并入最终 `Plugin` | 枚举过程信号须完整保留，供 C2 配对与 D 阶段导出复用；直接塞入 `Plugin` 会丢失在位/可读/软链/元数据细分 | 对应 S1-04 `items[]` 逐条字段；不改 `Plugin` 现有字段 | 新类型无既有信封回退要求；字段缺省按 §3.3 |
| DC2 | 快照模型 | 新增 `PluginInventorySnapshot`（Core 输出中间层），承载一次完整枚举结果 | 清单是 C2 的输入边界，须先冻结稳定结构，避免 C1 返工与 C2 输入漂移 | 对应 S1-04 报告顶层 `route/sourceDirectory/enumeration/items/unknownItems/counts/warnings` | 快照首版不进 `ReportEnvelope`（DC10） |
| DC3 | 文件类型表达 | 封闭枚举 `PluginFileKind` 五值：`dylib/plist/directory/symlink/other`，原始值逐字对齐基线 | 分类是封闭集；强枚举避免自由串漏配；与 `Pairing` 等现有 Models 枚举先例一致 | 五值与 `enumerator.js classify()` 输出逐字一致 | 解码沿用现有 Models 枚举的合成 Codable 口径 |
| DC4 | 条目状态表达 | 封闭枚举 `PluginEntryStatus` 五值：`ok/access_denied/metadata_unavailable/read_failed/not_found` | 条目级异常分层是 S1-04 §6 冻结口径；合并会丢失诊断 | 五值对齐 S1-04 §6；夹具出现 `ok/access_denied/metadata_unavailable`，`read_failed/not_found` 为规格封闭集预留 | 未知状态按 §6 口径记录，不抛解码错误 |
| DC5 | 软链字段 | `isSymlink: Bool?` 三态；`symlinkTarget: String?`、`symlinkState: String?`；不跟随目标继续枚举 | 软链标志与扩展名分类正交；目标缺失/循环/受限须独立记录 | 对齐 S1-04 `isSymlink/symlinkTarget/symlinkState`；`false`（已确认非软链）与 `nil`（未检查）不得混同 | 缺省 `nil`；不跟随、不解析目标内文件 |
| DC6 | 路径字段 | 原始完整路径 `path`、解析真实路径 `realpath`、原始后缀 `extension` 分列 | 三类信息语义不同：路径身份、真实位置、扩展名分类不可互相替代 | 对齐 S1-04 `path/realpath/extension`；`extension` 保留大小写 | 信号缺失 `nil`；不反推、不留空串 |
| DC7 | 哈希首版口径 | 保留 `hash: String?` 证据位；**C1 不实现哈希计算**，只承载离线夹具/ Adapter 提供的信号；真机可取性留 2.5 | ENUM-010 基线要求失败条目 `hash=null` 且不阻断；首版不引入摘要计算复杂度 | 对齐 S1-04 `hash` 字段；不可获取 = `nil` | 缺省 `nil`；不补空串 |
| DC8 | 元数据首版范围 | 保留 `size: Int?`；**不新增**修改时间、权限位、inode、UID/GID 等基线外字段 | S1-04 基线元数据仅 `size/hash/realpath`；首版不扩大证据面 | 对齐 S1-04 `size`；不可获取 = `nil` | 缺省 `nil` |
| DC9 | Codable 兼容 | 新结构 `Codable, Equatable`；可选字段 `decodeIfPresent`；缺省仅用于有基线缺省口径的字段；未知键忽略；**不改变既有 Models 解码行为** | 沿用 B1~B4 增补范式；2.2-A R6 未知枚举默认解码行为仍未实测，本批不新增静默默认 | 既有 21 项 Models Codable 测试与 91 例回归保持原样 | 新 JSON 显式输出；旧信封不涉及本批新类型 |
| DC10 | 信封隔离 | 快照首版**不进入** `ReportEnvelope`；C1 不产出最终 `Plugin`；向 `Plugin` 骨架的映射归 C2/2.2-D | 归属、配置、导出结论不在枚举阶段形成；提前入信封会诱导状态越界 | S1-08 导出形态不变；本批结构为中间产物 | — |
| DC11 | 输入信号快照 | Core 侧新增中性夹具信号结构，镜像 `environment.json` 的 `upstream/fs.entries`；只读解码，不读 `metadata.json`，不访问真实文件系统 | 沿用 B2/B4 输入快照先例（`JBRootCandidateSnapshot`/`ElleKitDirectorySnapshot`）；离线可测 | 对应 S1-04 夹具 `environment.json` 结构 | 信号缺失按未提供处理，不反推补齐 |
| DC12 | 告警载体 | 清单级告警统一 `[ReportWarning]`；条目级异常经 `entryStatus` 表达，首版不另造条目告警数组 | 与现有 D3 告警口径一致；条目失败原因由状态枚举承载 | 对齐 S1-04 `warnings` 与 `entryStatus` 分层 | 缺省 `[]` |

## 3. G-C1 定稿模型：插件文件证据（Models 增补侧）

### 3.1 类型枚举（封闭集，原始值冻结）

```
enum PluginFileKind: String, Codable, Equatable {
    case dylib
    case plist
    case directory
    case symlink
    case other
}

enum PluginEntryStatus: String, Codable, Equatable {
    case ok
    case accessDenied = "access_denied"
    case metadataUnavailable = "metadata_unavailable"
    case readFailed = "read_failed"
    case notFound = "not_found"
}
```

- `PluginFileKind` 五值与 `enumerator.js classify()` 输出逐字一致；扩展名匹配大小写敏感：仅全小写 `.dylib` 归 `dylib`、`.plist` 归 `plist`；`.DYLIB`/`.Dylib` 归 `other`。
- `PluginEntryStatus` 五值与 S1-04 §6 条目级分类逐字一致；夹具实见 `ok/access_denied/metadata_unavailable`，`read_failed/not_found` 为规格封闭集预留。

### 3.2 证据结构（增补，未落地为 Swift 代码）

```
struct PluginFileEvidence: Codable, Equatable {
    let path: String?                  // 完整路径（原始身份键）
    let name: String                   // 原始文件名，原样保留
    let `extension`: String?            // 最后一个 '.' 后原始后缀，保留大小写；无扩展名 nil
    let kind: PluginFileKind
    let exists: Bool?                  // 三态：nil 未验证
    let readable: Bool?                // 三态；不可读 ≠ 不存在
    let isSymlink: Bool?               // 三态：nil 未检查；不跟随目标
    let symlinkTarget: String?
    let symlinkState: String?          // 开放字符串口径，首版不强枚举
    let realpath: String?
    let size: Int?
    let hash: String?
    let hidden: Bool                   // 名以 '.' 开头；缺省 false
    let entryStatus: PluginEntryStatus // 缺省 .ok
}
```

### 3.3 字段对照与规则

| 字段 | 类型 | Optional / 缺省 | Stage 1 字段 | 规则口径 |
|---|---|---|---|---|
| `path` | `String?` | `nil`=信号缺失 | `path` | 由 `sourceDirectory` 与 `name` 拼接；上游目录未定位时可为 `nil`；完整路径为身份键，不按基名合并 |
| `name` | `String` | 必填 | `name` | 原始文件名原样保留；不改写大小写、空格、尾字符或扩展名 |
| `extension` | `String?` | `nil`=无扩展名 | `extension` | 取最后一个 `.` 之后的原始后缀，保留大小写；点开头且无第二段点号（如 `.plist`）→ `nil` |
| `kind` | `PluginFileKind` | 必填 | `kind` | 分类器产出；软链标志与扩展名分类正交；目录先于软链判定，软链先于扩展名判定（对齐 `classify()`） |
| `exists` | `Bool?` | `nil`=未验证 | `exists` | 三态；不得由 `readable`/`kind` 反推 |
| `readable` | `Bool?` | `nil`=未验证 | `readable` | 三态；`access_denied` 条目保留在清单，不删除、不记 `not_found` |
| `isSymlink` | `Bool?` | `nil`=未检查 | `isSymlink` | 三态；记录自身，不跟随目标继续枚举；断链独立记录 |
| `symlinkTarget` | `String?` | `nil` | `symlinkTarget` | 目标信号；不为获取目标而解析跟随 |
| `symlinkState` | `String?` | `nil` | `symlinkState` | 开放字符串（`resolved/broken/loop/denied/not_symlink` 口径）；首版不抽枚举，值原样保留 |
| `realpath` | `String?` | `nil` | `realpath` | 解析真实路径；元数据不可获取 `nil`，不反推补齐 |
| `size` | `Int?` | `nil` | `size` | 文件大小；不可获取 `nil`（DC8） |
| `hash` | `String?` | `nil` | `hash` | 只读摘要信号；C1 不计算哈希（DC7）；失败 `nil` 且不阻断枚举 |
| `hidden` | `Bool` | `false` | `hidden` | 文件名以 `.` 开头；隐藏文件列入清单并标记，不静默排除 |
| `entryStatus` | `PluginEntryStatus` | `.ok` | `entryStatus` | 条目级异常分层；目录级状态归 §4 快照，不在条目内重复 |

> 首版**不纳入**：修改时间、权限位、inode、UID/GID、`loaded/configured/installed` 等运行层或基线外字段。

## 4. G-C2 定稿模型：枚举清单快照（Core 中间层）

### 4.1 状态枚举与计数结构

```
enum EnumerationStatus: String, Codable, Equatable {
    case enumerated
    case partial
    case enumerationFailed = "enumeration_failed"
    case unresolved
}

struct PluginKindCounts: Codable, Equatable {
    var dylib: Int = 0
    var plist: Int = 0
    var directory: Int = 0
    var symlink: Int = 0
    var other: Int = 0
}
```

- `EnumerationStatus` 四态对齐 S1-04 §6 目录级分类：`enumerated`（完整）/ `partial`（部分条目受限）/ `enumeration_failed`（目录不可枚举）/ `unresolved`（上游目录未定位）。
- `PluginKindCounts` 五类计数与 `items[].kind` 一一对应；计数与清单条目一致，无重复归属。

### 4.2 清单快照结构（增补，未落地为 Swift 代码）

```
struct PluginInventorySnapshot: Codable, Equatable {
    let route: String?
    let sourceDirectory: String?
    let enumeration: EnumerationBlock
    let items: [PluginFileEvidence]
    let unknownItems: [UnknownItem]
    let counts: PluginKindCounts
    let warnings: [ReportWarning]

    struct EnumerationBlock: Codable, Equatable {
        let recursive: Bool            // 固定 false
        let status: EnumerationStatus
        let warnings: [String]
    }
}
```

| 字段 | 类型 | Optional / 缺省 | Stage 1 字段 | 规则口径 |
|---|---|---|---|---|
| `route` | `String?` | `nil`=未知 | `route` | 开放路线串原样保留；未知不套用任一开放路线规则 |
| `sourceDirectory` | `String?` | `nil`=未定位 | `sourceDirectory` | 枚举根目录，取自上游目录定位报告；`nil` 时快照为 `unresolved` 空清单 |
| `enumeration.recursive` | `Bool` | 固定 `false` | `enumeration.recursive` | 单层非递归；嵌套条目不进入清单 |
| `enumeration.status` | `EnumerationStatus` | 必填 | `enumeration.status` | 目录级四态；与条目 `entryStatus` 分层表达 |
| `enumeration.warnings` | `[String]` | `[]` | `enumeration.warnings` | 目录级告警码（`partial_enumeration`/`enumeration_failed`/`directory_unresolved`） |
| `items` | `[PluginFileEvidence]` | `[]` | `items` | 全部顶层条目（含受限、隐藏、软链、其他类）；按文件名字母序（大小写敏感）确定性排序 |
| `unknownItems` | `[UnknownItem]` | `[]` | `unknownItems` | `directory/symlink/other` 类条目归集；`reason` 取 `kind`，`sourceStage="S1-04"`，`detail` 保留原始文件名；不删除、不并入 dylib/plist 清单 |
| `counts` | `PluginKindCounts` | 五类 `0` | `counts` | 五类计数；与 `items`/`unknownItems` 一致 |
| `warnings` | `[ReportWarning]` | `[]` | `warnings` | 清单级统一告警载体（D3 口径） |

### 4.3 输入信号快照（Core 中性结构，离线解码）

```
struct PluginInventoryFixtureSignal: Codable, Equatable {
    let fixtureId: String?
    let fixtureKind: String?
    let upstream: UpstreamSignal?
    let fs: FsSignal?

    struct UpstreamSignal: Codable, Equatable {
        let route: String?
        let sourceDirectory: String?
    }

    struct FsSignal: Codable, Equatable {
        let enumerable: Bool?
        let enumerationError: String?
        let entries: [EntrySignal]?
    }

    struct EntrySignal: Codable, Equatable {
        let name: String?
        let type: String?                // file/directory（夹具原始类型信号）
        let exists: Bool?
        let readable: Bool?
        let isSymlink: Bool?
        let symlinkTarget: String?
        let symlinkState: String?
        let realpath: String?
        let size: Int?
        let hash: String?
        let hidden: Bool?
        let entryStatus: String?
        let nested: Bool?                // harness 非递归过滤标记，不进入输出证据
    }
}
```

- 信号结构只做中性解码；分类、排序、状态裁决在 Core 枚举器完成。
- `nested` 为夹具/harness 内部过滤标记，仅输入侧使用，**不输出**到 `PluginFileEvidence`。

## 5. C1 / C2 / C3 数据流边界

```
B4 目录定位报告（route / sourceDirectory / 可读可枚举证据）
        │  Adapter 提供条目信号（离线夹具注入；Core 不另建文件访问机制）
        ▼
C1 PluginEnumerator ── PluginInventorySnapshot（本批冻结边界）
        │  仅消费 items 中 dylib/plist 条目；unknownItems 原样保留
        ▼
C2 PluginPairer ── PairingSnapshot（G-C3 已冻结，见 `Stage-2.2-C2-Pairing-Contract.md`）
        │  仅 paired 条目进入解析；其余携带为 notParsed
        ▼
C3 FilterParser ── ParseReport（G-C4/G-C5，C3 前置评审冻结）
```

- **C1 输入**：上游目录定位结果 + Adapter/夹具条目信号；输出 §4.2 快照。
- **C2 输入边界**：本批冻结的 `PluginInventorySnapshot.items` 字段集；C2 不得要求 C1 补基线外条目字段。
- **C3 输入边界**：C2 配对快照 + plist 内容信号；枚举快照不向 C3 传递文件内容结论。
- `PluginCandidate`（现有 Adapter 协议 DTO）与本批中间快照的衔接方式，在 C1 实现授权时按协议评审口径界定；本轮不改七方法协议。

## 6. Codable 兼容与未知取值口径

1. 新结构均为 `Codable, Equatable`；可选字段经 `decodeIfPresent` 解码，缺省值仅用于 §3.3/§4.2 有基线缺省口径的字段（`hidden=false`、`entryStatus=.ok`、计数 `0`、各数组 `[]`、`recursive=false`）。
2. 未知键按 Swift 合成解码器默认忽略；不新增严格未知键抛错逻辑。
3. 封闭枚举解码沿用现有 Models 枚举合成 Codable 口径；2.2-A R6（未知枚举默认解码行为）仍未实测未修改——本批不新增静默默认值；夹具外出现未知原始值时，C1 Runner 轮记录实际解码表现，不在契约层假定兼容。
4. 既有 Models 字段、枚举原始值、解码行为与 21 项 Models Codable 测试不变；本批增补不并入既有冻结测试断言。
5. `null` 与字段缺失语义保持：缺可选 = `nil`，不补空串/空数组冒充已知；三态位不填 `false`。

## 7. G-C3 ~ G-C6 归属批次确认

| 缺口 | 本轮处置 | 归属批次 |
|---|---|---|
| G-C3 配对中间报告（五态互斥：`paired/missing_plist/orphan_plist/ambiguous/uncertain`） | **已冻结**：配对快照/记录/计数/状态/分类定稿，见 `Stage-2.2-C2-Pairing-Contract.md` | **C2-A 实现授权**（契约已冻结，编码待单独授权） |
| G-C4 解析五态与结构化 `skippedFields`（`{key,reason,expectedType,observedType,index?}`） | 不在本批展开；现有 `ValidationReport.skippedFields: [String]` 降级文本口径维持现状 | **C3 前置评审** |
| G-C5 Rootless Codable 中间模型 | 不在本批定义；解码中间结构为 Parser 内部类型，不进公共 Models | **C3 前置评审** |
| G-C6 哈希/元数据真机可取性 | 字段位（`size/hash/realpath: nil` 口径）随本批冻结；真机大小/哈希可取性待只读探测 | 字段口径 = 本批；真机证据 = 2.5 真机验证 |

## 8. 硬门禁自查（契约冻结前逐项核对）

- [x] 未修改既有 Models 字段/枚举/原始值与解码行为；
- [x] 未修改 `ElleKitAdapter` 七方法协议；
- [x] 未改动 Stage 1 Fixtures、harness、`report.json` 与既有 Stage2 测试；
- [x] 封闭枚举原始值与 S1-04 基线逐字一致；
- [x] 三态位 `nil`=未验证，无 `nil → false`  coercion；
- [x] 受限/隐藏/软链/其他类条目均保留，不提前配对、不删除孤立文件；
- [x] 快照不进 `ReportEnvelope`，不产出最终 `Plugin`，不推断 `loaded`；
- [x] 单层非递归、软链不跟随、无 `/var/jb` 或文件根回退；
- [x] 未编译、未运行 Runner、未连接真机、无插件读写/启停。

## 9. 暂缓与遗留事项

- 哈希计算实现、文件大小/真实路径的真机可取性：留 2.5 真机只读验证；离线夹具为合成信号。
- `symlinkState` 是否在后续批次抽为强枚举：待 C2/C3 观察实际取值分布后评审，本批保留 `String?`。
- 输入信号快照与 `PluginCandidate`/Adapter 协议方法的装配衔接：C1 实现授权时走协议评审，本轮不界定签名演进。
- 包产品平台三元组、Deployment Target 等既有观察项沿用 2.2-B 记录，不在本批处理。

## 10. 授权边界（保持）

- ✅ 已授权：本数据契约冻结文档的撰写与归档；G-C1/G-C2 模型字段/类型/Optional/枚举原始值/Codable 口径设计定稿。
- ❌ 未授权：C1 枚举器编码；Models 增补落地；Core 快照/枚举器代码；`Package.swift` 接线变更；新增 Swift 测试；协议演进；Runner 编译/测试；真机扫描；任何插件读写、软链改动、注入配置修改或启停。
- 下一阶段：C1 Plugin Enumeration 实现须单独授权，且以本文契约为准；落地后按 C1 门槛复验 S1-04 23 项回归 + 模型 Codable 往返/空目录/顺序确定性/受限保留/软链处理附加用例。
