# Stage 2.2-C3-Engine-A：Engine 数据契约与流水线状态映射冻结

> 批次定位：C3-C3 第一批（C3-Engine-A）设计层冻结。基线提交 `12bcd73`。
> 状态：**契约冻结（设计层）**；本文件定义 Engine 内部类型、输入边界、路线归一、流水线状态映射、快照/计数口径与证据透传规则，**未落地 Swift 代码**。Engine-B 实现、Engine-C 基线回归待逐批独立授权。
> 上游依据：[Stage-2.2-C3-Parser-Data-Contract.md](./Stage-2.2-C3-Parser-Data-Contract.md) PC3-1~14、§5.4/5.6/5.7/§10.1；审计事实见 [Stage-2.2-C3-Engine-A-Interface-Audit.md](./Stage-2.2-C3-Engine-A-Interface-Audit.md)。

## 1. 范围与分层

### 1.1 Engine 职责边界

- Engine 是纯编排组件：接收 C2 配对快照，按路线调度 Reader / Decoder / 对应路线 Parser，汇总为解析中间快照。
- Engine **不重新实现**解析规则：不做类型核对、不做 Codable 解码、不做规则映射；这些归 RootHide / Rootless Parser。
- Engine 不访问文件系统以外的资源；不重扫目录、不重新配对、不补列未配对条目；不回写 C2 记录；不组装最终 `Plugin`；首版解析快照不进 `ReportEnvelope`。

### 1.2 建议组件目录（沿用契约 §10.1 `Core/PlistParser/Engine/`）

| 组件（建议名，落地文件待 Engine-B） | 职责 |
|---|---|
| `FilterParseRoute` | Engine 内部路线归一枚举；不进公共 Models |
| `FilterParseRouteResolver` | 由 `snapshot.route` 字符串归一为内部路线；纯函数，不读文件系统 |
| `PluginFilterParseEngine` | 单条记录解析 + 整份快照编排；依赖经协议注入 |
| `FilterParseSnapshotBuilder` | 汇总 `parsed / notParsed / counts / warnings`，目录级状态计算 |
| `FilterParseIntegrationValidator` | 快照完整性校验（计数不变量、证据保留、路线一致性） |

> 文件命名与内部可见性在 Engine-B 实现时复核；本批不创建源文件。

## 2. 路线类型与归一

### 2.1 内部枚举（Core 中间层）

```swift
/// Engine 内部路线归一类型；证据 route 字段仍为 String? 基线词汇。
public enum FilterParseRoute: String, Codable, Equatable {
    case rootHide = "roothide"
    case rootless
    case unknown
}
```

- 原始值与 S1-06 基线、Parser `routeName` 逐字一致：`roothide / rootless / unknown`。
- 枚举仅在 Engine 内部使用；`FilterParseResult.route` 保持 `String?`，不把枚举类型泄漏进单条结果或公共 Models。

### 2.2 Resolver 映射表（唯一可信来源：`snapshot.route`）

| `snapshot.route` 原值 | 归一结果 | 后续行为 |
|---|---|---|
| `"roothide"` | `.rootHide` | 交 RootHide Parser |
| `"rootless"` | `.rootless` | 交 Rootless Parser |
| `nil` | `.unknown` | 不选边，条目 `not_parsed` |
| `"rootful"` | `.unknown` | 不选边；rootful 不属 C3 双路线支持范围（G-E5） |
| `"unknown"` 或其他开放字符串 | `.unknown` | 不选边，不猜路线 |

### 2.3 路线安全硬约束（红线）

1. 不根据插件路径（含 `/var/jb`、`.jbroot-*` 等片段）认定路线。
2. 不根据文件名、dylib/plist 来源或软件包名认定路线。
3. 不根据 plist 内容（字段集合、键名）反推路线。
4. 未知 Profile 不自动降级到 Rootless，也不套用 RootHide 规则。
5. RootHide 解析失败后不重试 Rootless；Rootless 解析失败后不重试 RootHide。
6. 路线判定在读取文件之前完成；Unknown 路线下 Reader / Decoder / 任一 Parser 调用次数为 0。

## 3. 输入边界

### 3.1 快照级输入

- 唯一上游：`PluginPairingSnapshot`（`route / sourceDirectory / status / records / unknownItems / counts / warnings`）。
- 依赖注入（Engine-B 接缝）：
  - `reader: PlistDataReading`（既有协议，C3-B 验收）；
  - `decoder: PlistDecoding`（既有协议，C3-B 验收）；
  - 双路线 Parser 接缝协议（G-E1，Engine-B 评审抽取）。
- **不提供**与 `snapshot.route` 并行的外部 route 覆盖参数，避免双重事实来源。

### 3.2 记录级字段投影

| Engine 信号 | 取值 | 缺失口径 |
|---|---|---|
| `pairingKey` | `record.pairingKey` | `nil` 透传，不反推 |
| `dylibPath` | `record.dylib?.path` | `nil` 透传 |
| `plistPath` | `record.plist?.path` | `nil` 时按读取级失败处理（§4 Stage 3） |
| 记录告警 / 证据 | `record.warnings`、`record.evidence` | 原样保留进结果与归集条目 |

- 不扩写 `PluginFileEvidence`；不把 Reader 信号回写进上游证据结构（契约 §3.2 注）。

## 4. 流水线状态映射（权威表）

> 顺序自上而下；任一阶段短路后不再进入下游。单条隔离：失败条目进对应归类，兄弟条目照常解析。

| 阶段 | 判定条件 | 结果状态 | 下游调用 | 证据 / 备注 |
|---|---|---|---|---|
| Stage 0 目录未定位 | `snapshot.status == .unresolved` 或 `sourceDirectory == nil` | 空解析快照；条目桶全 0 | Reader / Decoder / Parser 全 0 | 快照告警 `inventory_unresolved`；禁止回退扫描其他路线目录（PC3-3） |
| Stage 1 配对门禁 | `record.category != .paired`（missing_plist / orphan_plist / ambiguous / uncertain） | `not_parsed` | Reader / Decoder / Parser 全 0 | 记录映射为 `UnknownItem`，保留 `reason / basis / candidates / warnings`（§6） |
| Stage 2 路线门禁 | 归一 `route == .unknown` | `not_parsed` | Reader / Decoder / Parser 全 0 | 先于文件读取判定；不猜 Profile；不改写快照 |
| Stage 3 读取 | `plistPath == nil`，或 Reader `notFound / accessDenied / readFailed` | `read_failed` | Decoder / Parser 0 | `readStatus` 保留读取分类；`filter = nil`；不判不存在、不降级 `parse_failed`（PC3-9） |
| Stage 4 解码 | Decoder `parseFailed`（破损 XML / Binary / 空数据 / 异常对象） | `parse_failed`，`reason = invalid_plist` | 对应路线 Parser 0 | 保留 plist 路径与读取状态（PC3-10） |
| Stage 5 路线解析 | `.rootHide` → RootHide Parser；`.rootless` → Rootless Parser | Parser 返回五态直传 | — | Engine 不改写 reason、不互换路线归类；RootHide 类型不符 `type_mismatch`，Rootless Codable 失败 `parse_failed`（PC3-11、C3-C2 口径） |

补充口径：

- paired 记录在读取时文件消失（notFound）仍为 `read_failed`，不是 `not_parsed`。
- Reader 成功但 Decoder 失败：Reader 调用 1、Decoder 调用 1、Parser 调用 0。
- 解码成功对象交 Parser 前不做业务类型预核对；类型规则归各路线 Parser。

## 5. 快照与计数契约

### 5.1 `FilterParseSnapshot`（对齐契约 §5.6，Core 中间层）

| 字段 | 类型 | 说明 |
|---|---|---|
| `route` | `String?` | 上游原值透传；不归一改写 |
| `sourceDirectory` | `String?` | 上游原值；未定位为 `nil` |
| `status` | `String` | 目录级口径：`enumerated / partial / unresolved`（§5.3） |
| `parsed` | `[FilterParseResult]` | 进入解析管线的条目（含各失败态） |
| `notParsed` | `[UnknownItem]` | 非配对四桶 + C2 `unknownItems` 归集 |
| `counts` | `FilterParseCounts` | 五桶互斥计数（§5.2） |
| `warnings` | `[ReportWarning]` | 快照级告警（§5.3） |

### 5.2 `FilterParseCounts`（对齐契约 §5.7）

| 字段 | 类型 | 基线原始值 |
|---|---|---|
| `valid` | `Int` | `valid` |
| `parseFailed` | `Int` | `parse_failed` |
| `typeMismatch` | `Int` | `type_mismatch` |
| `readFailed` | `Int` | `read_failed` |
| `notParsed` | `Int` | `not_parsed` |

计数不变量（必须进入 XCTest）：

```
counts.valid + counts.parseFailed + counts.typeMismatch + counts.readFailed == parsed.count
counts.notParsed == notParsed.count
counts 五桶之和 == parsed.count + notParsed.count
```

- 计数按结果组数；不按文件条目数、跳过字段数或候选数计入桶计数。
- `not_parsed` 不算失败；`valid` 不推断为已配置 / 已加载。

### 5.3 目录级状态与告警

- `unresolved`：Stage 0 命中；空模型 + 告警 `inventory_unresolved`。
- `partial`：`parsed` 中存在任一 `parse_failed / type_mismatch / read_failed`；附快照告警 `partial_parsing`。
- `enumerated`：无任何失败态（含空清单且目录已定位）。
- 快照告警组成：上游 C2 `warnings` 原样保留 + `inventory_unresolved` / `partial_parsing` + 条目级 validation 告警；同 code 去重（对齐基线 `[...new Set(warnings)]` 口径），`sourceStage` 沿用各产出层标记。

### 5.4 证据透传与不可变性

- 解析过程不修改上游 `PluginPairingSnapshot`、`PluginPairingRecord`、`PluginFileEvidence` 与夹具输入；测试需深比较输入快照前后一致。
- `parsed` 顺序保持 `snapshot.records` 稳定序（C2 已按配对键 / 路径字母序排序）；`notParsed` 保持四桶 + `unknownItems` 的稳定序。
- C2 `unknownItems` 不丢弃；C2 `warnings` 不丢弃；不重新计算 pairing；不删除歧义 / 不确定候选。
- `skippedFields` 仅承载错误证据；任一非 `valid` 结果不得附带看似合法的 `FilterRule`。

## 6. 非配对记录 → `UnknownItem` 映射

| `PairingCategory` | `UnknownItem.reason`（缺省） | 保留线索 |
|---|---|---|
| `missingPlist` | `missing_plist` | `base / pairingKey / dylibPath` 入 `detail`；`path` 取 dylib 侧路径 |
| `orphanPlist` | `missing_dylib`（`record.reason` 优先） | `path` 取 plist 侧路径；`base` 保留 |
| `ambiguous` | `ambiguous` | `candidates` 全量候选入 `detail` 线索；不取 `first` 作为选择 |
| `uncertain` | `record.reason`（缺省 `uncertain`） | `path` 保留；entryStatus 原始线索随 `detail` 保留 |
| C2 `unknownItems` | 原样 | 不重映射、不改写 `reason / sourceStage / detail` |

- `sourceStage` 标记为 C3 编排层归集来源；不覆盖上游既有阶段标记。

## 7. 开放项与待评审缺口

- G-E1：双路线 Parser 内部解析协议接缝（Engine-B 抽取评审）。
- G-E2：Snapshot / Counts 归属 Core 中间层还是公共 Models（沿用 G-C3-1 / G-C3-2）。
- G-E3：Reader/Decoder 落地结果类型 → Engine 信号投影（`plistFormat` / `readStatus` 映射）。
- G-E4：目录级状态计算规则已在 §5.3 冻结；与 C2 `PairingStatus` 类型分离。
- G-E5：`rootful` 条目级告警线索待定；Resolver 行为已冻结为 `.unknown`。
- 沿用未决：G-C3-1（五态枚举归属）、G-C3-2（结构化 skippedFields 提升）、G-C3-4（Adapter 协议演进）、G-C3-5（UnloadAfter 导出归属）。

## 8. 批次门禁

| 批次 | 内容 | 门禁 |
|---|---|---|
| C3-Engine-A（本批） | 前置只读审计、Engine 数据契约冻结、测试计划冻结 | 设计评审通过；不改源码 / Models / Adapters / 协议 / Stage1 fixtures；不编译不跑 Runner |
| C3-Engine-B | Route Resolver、Pipeline 编排、Snapshot/Counts 落地与单元测试 | 待独立授权；依赖 C3-C1 已验收、C3-B 已验收；C3-C2 Runner 状态见 §9 门禁 |
| C3-Engine-C | S1-06 22 项基线映射、集成测试、全量回归与 Runner 证据 | 待独立授权；Engine-B 单元测试通过；C3-C2 Runner 验收通过后方可标记集成完成 |

## 9. C3-C2 未出证期间的依赖门禁

- C3-C1 已正式验收；C3-C2 代码冻结、22 例专项待 Runner 出证。
- Engine-B 可在授权后开始编排骨架与 RootHide 路线联调；Rootless 路线的集成结论必须等 C3-C2 Runner 通过。
- Engine-C 基线测试结果不得掩盖 Rootless Parser 本身缺陷：Rootless 路线失败归因到 C3-C2 Parser 口径，不在 Engine 层放宽规则兜底。
- 本批及 Engine-B 均不做真机扫描、权限探针、归属识别、统一 JSON 导出与 GUI。
