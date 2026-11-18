# Stage 2.2-C3-Engine-B：Dual-Route Filter Parse Engine 实现记录（代码冻结，Runner 验收待授权）

- 基线前置：Engine-A 设计层冻结提交 `78365be`（Interface Audit / Data Contract / Test Plan）；已验收 C3-B Reader/Decoder、C3-C1 RootHide Parser、C2/C1/B 链路；C3-C2 Rootless Parser 代码冻结待 Runner。
- 本地环境：Linux 云主机，无 Swift / Xcode 工具链。本轮 **未编译、未跑 Runner**；编译与测试结论以外部 macOS Runner 出证为准，本文不宣称编译通过或测试通过。
- 批次拆分：B1（`9b14ce8` 路线归一与协议接缝）→ B2（`9194342` Pipeline 编排与状态映射）→ B3（本批 Snapshot/Counts/Builder/Validator + 专项测试 + 接线）。

## 1. 本轮授权边界

### 已允许并执行（本地离线）

1. 内部 `FilterParseRoute` 归一（`roothide / rootless / unknown`），Resolver 唯一消费 `PluginPairingSnapshot.route`。
2. Engine 输入适配与 Stage 0~5 短路编排：目录检查 → 非 paired 检查 → 未知路线检查 → Reader → Decoder → 对应 Parser。
3. RootHide / Rootless 独立 Parser 调用；无跨路线 fallback、失败重试或自动选边。
4. 统一 `FilterParseSnapshot / FilterParseCounts`、非配对/未知路线 → `UnknownItem` 归集、五态语义与计数不变量落地。
5. 完整性 Validator、调用次数测试、路线隔离测试、状态映射测试、证据保留与输入不可变测试。

### 禁止项（本轮均未触碰）

- 未修改 C3-C2 Rootless Parser 源码；未替 C3-C2 补测试或修缺陷。
- 未修改 C2 配对模型与既有配对语义；未修改 Stage 1 fixtures / harness / report。
- 未修改七方法 Adapter 协议；未增加 GUI 私有解析逻辑。
- 未扫描真机；未修改越狱文件、插件文件、plist 或注入配置；未做启停 / 安装 / 卸载 / 任何写操作。
- 未实现 Engine-C 的 S1-06 22 项基线映射与完整集成验收；未做服务层装配 / Adapter 实例化。
- 未推断 `loaded`；归属识别与统一 JSON 导出属后续 Stage 2.2-D。

## 2. 文件清单

### Core 新增（`Core/PlistParser/`）

| 文件 | 职责 | 批次 |
|---|---|---|
| `Engine/FilterParseRoute.swift` | 内部路线封闭枚举（无 rootful/auto/fallback） | B1 |
| `Engine/FilterParsing.swift` | Parser 内部注入协议；双路线 Parser 经 Engine 目录扩展声明接入，未改其源文件 | B1 |
| `Engine/FilterParseRouteResolver.swift` | 无状态纯函数路线归一；不访问文件系统 / 不读 plist / 不实例化 Adapter | B1 |
| `Engine/PluginFilterParseEngine.swift` | 只读解析编排：Stage 0~5 短路、信号投影、单条失败不中断整轮 | B2 |
| `Result/FilterParseCounts.swift` | 五桶计数（`valid / parse_failed / type_mismatch / read_failed / not_parsed`）与不变量 | B2 |
| `Result/FilterParseSnapshot.swift` | 统一解析快照（route/sourceDirectory/status/parsed/notParsed/counts/warnings） | B2 |
| `Engine/FilterParseSnapshotBuilder.swift` | 计数、目录级状态、去重告警汇总；纯计算 | B3 |
| `Engine/FilterParseIntegrationValidator.swift` | C3B-001~007 完整性校验与结果类型 | B3 |

### 测试新增（`Tests/Stage2/`）

| 文件 | 覆盖 |
|---|---|
| `FilterParseEngineTests.swift` | E-B1~E-B6 六组专项测试；Reader/Decoder/Parser 经协议注入只读桩并记录调用次数 |

### 接线

- `Package.swift`：Core sources 追加上述 8 个源；Stage2Tests sources 追加 `FilterParseEngineTests.swift`。

## 3. 流水线映射对照（Engine-A 契约 §3）

| 阶段 | 判断 | 输出 | 下游调用 |
|---|---|---|---|
| Stage 0 | `snapshot.status == .unresolved` 或 `sourceDirectory == nil` | 空快照 + `inventory_unresolved`，状态 `unresolved` | Reader/Decoder/Parser 全 0 |
| Stage 1 | `record.category != .paired` | 归集 `UnknownItem`（`missing_plist / missing_dylib / ambiguous / uncertain` 原因对齐基线） | Reader/Decoder/Parser 全 0 |
| Stage 2 | 路线 `.unknown`（含 rootful / nil / 开放串） | 归集 `UnknownItem`，原因 `unknown_route` | Reader/Decoder/Parser 全 0 |
| Stage 3 | Reader 非 success（notFound/accessDenied/readFailed/路径缺失） | `read_failed`；readStatus 映射 `access_denied / read_failed`，reason 同 readStatus 词 | Decoder/Parser 0 |
| Stage 4 | Decoder `parseFailed` | `parse_failed`，reason `invalid_plist`，plistFormat `unknown` | Parser 0 |
| Stage 5 | 唯一可信路线 Parser | 五态直传不改写；无跨路线重试 | 对应路线 1，另一路线 0 |

### 信号词汇（基线逐字一致）

- `readStatus`：`ok / access_denied / read_failed`；Reader `success→ok`、`accessDenied→access_denied`、`notFound|readFailed→read_failed`。
- `plistFormat`：`xml / binary / unknown`；Decoder `.xml→xml`、`.binary→binary`、其余（含 openStep）→ `unknown`。
- 路线证据字段 `FilterParseResult.route` 保持 `String?` 基线词汇；内部枚举不泄漏进单条结果或公共 Models。

## 4. 计数不变量（C3B-001~003）

- `valid + parseFailed + typeMismatch + readFailed == parsed.count`
- `notParsed == notParsedItems.count`
- 五桶和 == `parsed.count + notParsedItems.count`
- `not_parsed` 不是解析失败；`valid` 不推断 `loaded`。

目录级状态：`parsed`/`notParsed` 均空 → `unresolved`；存在任一 `parse_failed / type_mismatch / read_failed` → `partial`（附 `partial_parsing`）；否则 `enumerated`。告警按 code 去重，上游 `warnings` 与 `unknownItems` 原样归集不重分类。

## 5. 测试清单（E-B1～E-B6；run `44106064051` 复验通过）

| 组 | 内容 | 关键断言 |
|---|---|---|
| E-B1 | Route Resolver | `roothide/rootless` 归一；`nil/rootful/unknown/other` → `.unknown`；大小写不敏感；无第二路线判断系统 |
| E-B2 | Pipeline Short Circuit | 非 paired / 未知路线 / unresolved：Reader/Decoder/Parser 全 0；Reader 失败 Reader 1、Decoder 0；Decoder 失败 Reader 1、Decoder 1、Parser 0 |
| E-B3 | Reader/Decoder 映射 | accessDenied→`access_denied`；notFound/readFailed→`read_failed`；Decoder 失败→`invalid_plist`；binary 格式透传 |
| E-B4 | Dual Parser 隔离 | Hide 失败不调 Rootless，反之亦然；Parser 收到快照路线原值 |
| E-B5 | Snapshot/Counts | 五桶计数精确；总和不变量；partial/enumerated 状态与告警；Validator 全过 |
| E-B6 | Evidence/Immutability | 上游快照深比较不变；pairingKey/dylibPath/plistPath/route 透传；上游 unknownItems 保留；篡改计数时 Validator C3B-002 判负 |

调用次数矩阵（测试桩断言）：

| 场景 | Reader | Decoder | RootHide | Rootless |
|---|---|---|---|---|
| 非 paired | 0 | 0 | 0 | 0 |
| 未知路线 | 0 | 0 | 0 | 0 |
| unresolved | 0 | 0 | 0 | 0 |
| Reader 失败 | 1 | 0 | 0 | 0 |
| Decoder 失败 | 1 | 1 | 0 | 0 |
| RootHide 正常 | 1 | 1 | 1 | 0 |
| Rootless 正常 | 1 | 1 | 0 | 1 |

## 6. 偏差与留痕

- Engine 汇总逻辑从编排器抽出至 `FilterParseSnapshotBuilder`，便于计数/状态/告警独立测试；编排器不保留第二份计数实现。
- 未知路线 paired 条目不进入 `parsed[]`，归集到 `notParsed[]`（与非配对条目同一归集通道）；防御性兜底分支不进入任一 Parser。
- G-E1：Parser 注入协议落在 Core 内部，未演进 Adapters 七方法协议；G-E2：Snapshot/Counts 归属 Core 中间层，未提升公共 Models。沿用未决项见 Engine-A Audit §缺口表。

## 7. Runner 出证状态（run `44106064051` 已归档）

- ✅ Core 三库 Build 0 error / 0 warning；E-B1~E-B6 专项 `FilterParseEngineTests` 19 例 0 fail / 0 skip；既有回归与 S1-05 15 例无损伤；App BUILD SUCCEEDED、PID 3508 存活；隔离脚本 CI 实际执行六项 OK。证据 `evidence/run-44106064051-acceptance/`。
- **Engine-B 测试通过不视为 C3-C2 Runner 验收通过**；C3-C2 由 `RootlessFilterParserTests` 22 例专项单独出证（同轮 C-G2 passed）。
- Engine-C（22 项 S1-06 基线映射 + 完整集成验收）同轮复验通过，见 C1 / C2 记录与最终验收结论。

## 8. 未授权边界（沿用）

未改公共 Models / Adapters / 协议 / C1 / C2 / C3-B / C3-C1 / C3-C2 源码与 Stage1 fixtures；未接服务装配；未扫真机；未做写入 / 启停 / 装卸；未做归属识别与统一 JSON 导出。
