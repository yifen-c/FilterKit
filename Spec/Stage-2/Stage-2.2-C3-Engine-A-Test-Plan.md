# Stage 2.2-C3-Engine-A：测试计划与 S1-06 基线映射冻结

> 批次定位：C3-C3 第一批（C3-Engine-A）设计层。基线提交 `12bcd73`。
> 状态：**测试计划冻结（设计层）**；本文件只规定测试分组、依赖桩设计、调用次数矩阵与 22 项基线映射口径，**不落地测试代码**。测试实现归 Engine-B / Engine-C 独立授权。
> 依据：[Stage-2.2-C3-Engine-A-Data-Contract.md](./Stage-2.2-C3-Engine-A-Data-Contract.md)、[Stage-2.2-C3-Parser-Data-Contract.md](./Stage-2.2-C3-Parser-Data-Contract.md) §6；基线 `Tests/S1-06/parser.js`、`run.js`、`report/S1-06-report.json`、`Tests/Fixtures/S1-06/`。

## 1. 测试目标与分层

1. **单条记录解析逻辑**可独立测试：配对门禁、路线门禁、读取 / 解码 / 解析短路与五态映射。
2. **整份快照编排**可独立测试：汇总、计数、目录级状态、告警归集、证据保留与不可变性。
3. **下游调用次数**可证明：Engine 没有重复解析、错误回退或跨路线兜底。
4. 测试挂既有 `Stage2Tests` target；夹具加载器复用 `S105FixtureLoader.swift` 范式（测试目标内部，不进正式 App / Core）；不修改、不复制、不覆盖 Stage 1 基线 fixtures 与 harness。

## 2. 测试分组（五组 + 调用次数硬约束）

| 组 | 覆盖内容 | 主要断言 |
|---|---|---|
| A Route | Resolver 三态归一；`roothide / rootless / nil / rootful / unknown / 开放串` 映射；无路径 / 文件名 / 内容猜测 | 归一结果与 §2.2 映射表逐格一致；未知路线下游零调用 |
| B Pipeline | Reader → Decoder → Parser 全链；各阶段失败短路；依赖注入桩替换 | 阶段间信号透传（plistPath / plistFormat / readStatus / pairingKey / dylibPath）；失败条目不阻断兄弟条目 |
| C State | 五态映射逐格；读取失败不降级解析失败；解码失败归 `parse_failed`；`not_parsed` 不计失败；解析成功不推断 loaded | 状态互斥；非 `valid` 结果 `filter == nil`；`isTweakManager` 路线口径正确 |
| D Snapshot | Counts 不变量；稳定排序；证据保留；`unknownItems` / C2 warnings 不丢；目录状态 `unresolved / partial / enumerated`；输入不可变 | §5.2 计数等式；前后深比较输入快照未改；告警按 code 去重 |
| E Baseline | S1-06 22 项原始基线映射（§4 表） | route / sourceDirectory / status / counts / statusByBase / filterByBase / otherKeysByBase / skippedFieldsByBase 与基线一致 |

附加边界用例（沿用契约 §6）：Foundation Bool / NSNumber 类型边界由路线 Parser 既有专项覆盖；Engine 层补充未知路线、未定位目录、空清单、重复解析确定性、输入数据不变性。

## 3. 下游调用次数矩阵（协议注入桩）

> 目的：证明 Engine 只在授权阶段调用下游，且不跨路线兜底。桩经内部解析协议注入（G-E1，Engine-B 抽取）；**不为正式 Core 增加调试开关或公开计数属性**。Reader / Decoder 复用既有 `PlistDataReading / PlistDecoding` 协议桩。

| 情形 | Reader 调用 | Decoder 调用 | RootHide Parser | Rootless Parser |
|---|---|---|---|---|
| 非 `.paired` 记录（四桶任一） | 0 | 0 | 0 | 0 |
| Unknown Profile（`.unknown`） | 0 | 0 | 0 | 0 |
| Reader 失败（notFound / accessDenied / readFailed / 路径缺失） | 1 | 0 | 0 | 0 |
| Decoder 失败（`parse_failed`） | 1 | 1 | 0 | 0 |
| 正常 RootHide | 1 | 1 | 1 | 0 |
| 正常 Rootless | 1 | 1 | 0 | 1 |
| RootHide 解析失败（type_mismatch） | 1 | 1 | 1 | 0（不重试 Rootless） |
| Rootless 解析失败（parse_failed） | 1 | 1 | 0 | 1（不重试 RootHide） |
| 目录未定位（Stage 0） | 0 | 0 | 0 | 0 |

桩记录调用次数与入参；断言同时覆盖「次数正确」与「入参路径 / 路线正确」，防止以错误参数多调一次冒充通过。

## 4. S1-06 22 项基线映射表

> 基线：`Tests/S1-06/report/S1-06-report.json` 22 例（PARSE-001 ~ PARSE-017，含合成与重复样本展开）。`base` 对应 Engine `pairingKey`（剥离后缀的基名）；比较维度对齐 `run.js` `compareResult`：`route / sourceDirectory / status / counts / statusByBase / filterByBase / otherKeysByBase / skippedFieldsByBase`。

| # | parseId | 来源 | 路线 | 条目（base） | 基线状态 | 映射断言要点 |
|---|---|---|---|---|---|---|
| 1 | PARSE-003 | 夹具 `parse-binary` | roothide | Bin | `valid` | binary 格式信号透传；规则 `bundles=[com.bin.app]`；counts valid=1 |
| 2 | PARSE-006 | 夹具 `parse-bundles-wrong` | roothide | BadBundles | `type_mismatch` | reason `field_type`；skipped `Bundles` `not_array`，期望 `string[]`，观测 `string` |
| 3 | PARSE-007 | 夹具 `parse-classes-wrong` | roothide | BadClasses | `type_mismatch` | reason `field_type`；skipped `Classes` `element_type`，期望 `string`，观测 `number`，index 0 |
| 4 | PARSE-016 | 夹具 `parse-determinism` | roothide | Delta | `valid` | 规则 `bundles=[com.delta.app]`、`executables=[DeltaApp]`；确定性样本 |
| 5 | PARSE-011 | 夹具 `parse-empty-filter` | roothide | Empty | `valid` | 空规则合法；空配置告警口径由 RootHide 既有专项覆盖 |
| 6 | PARSE-008 | 夹具 `parse-executables-wrong` | roothide | BadExec | `type_mismatch` | reason `field_type`；skipped `Executables` `not_array`，期望 `string[]`，观测 `string` |
| 7 | PARSE-013 | 夹具 `parse-invalid-plist` | roothide | Broken | `parse_failed` | reason `invalid_plist`；Decoder 失败短路，Parser 零调用 |
| 8 | PARSE-011 | 夹具 `parse-missing-fields` | roothide | Sparse | `valid` | 缺失字段容忍；空规则合法 |
| 9 | PARSE-005 | 夹具 `parse-missing-filter` | roothide | NoFilter | `type_mismatch` | reason `filter_missing`；skipped `Filter` 期望 `object`，观测 `missing` |
| 10 | PARSE-012 | 夹具 `parse-multi-rule` | roothide | Multi | `valid` | `bundles=[com.a.app, com.b.app, com.c.app]`、`classes=[ClassX, ClassY]`、`executables=[ProcP, ProcQ]` |
| 11 | PARSE-014 | 夹具 `parse-partial-corrupt` | roothide | Good / Bad | `valid` + `parse_failed` | 单条隔离：Good 合法，Bad `invalid_plist`；counts valid=1、parse_failed=1；快照 `partial` + `partial_parsing` |
| 12 | PARSE-015 | 夹具 `parse-rootless-model` | rootless | RL | `valid` | `bundles=[com.example.app]`、`executables=[rlapp]`（小写规范化）；`otherKeys=[Classes, CoreFoundationVersion, IsTweakManager]`；`isTweakManager=null`；classes 恒空、CFV 恒 null |
| 13 | PARSE-009 | 夹具 `parse-versions` | roothide | Range | `valid` | CFV `{mode: range, min: 1500, max: 1700}` |
| 14 | PARSE-009 | 夹具 `parse-versions-wrong` | roothide | BadVer | `type_mismatch` | reason `versions_type`；skipped `CoreFoundationVersion` 期望 `number[]`，观测 `array` |
| 15 | PARSE-001 | 夹具 `parse-xml-valid` | roothide | Example | `valid` | `bundles=[com.example.app]`、`classes=[ExampleClass]`、`executables=[ExampleApp]`；CFV `{mode: max, max: 1600}`；`isTweakManager=false` |
| 16 | PARSE-002 | 夹具 `parse-xml-valid` | roothide | Example | `valid` | 同 15 重复样本；计数不重复累加 |
| 17 | PARSE-012 | 夹具 `route-guard` | roothide | —（目录未定位） | `unresolved` | `sourceDirectory=null`；空模型；告警 `inventory_unresolved`；下游零调用；不回退扫描 |
| 18 | PARSE-004 | 合成 `root-type` | roothide | RootType | `type_mismatch` | reason `root_type`；skipped `(root)` 期望 `object`，观测 `string` |
| 19 | PARSE-005 | 合成 `filter-type` | roothide | FilterType | `type_mismatch` | reason `filter_type`；skipped `Filter` 期望 `object`，观测 `array` |
| 20 | PARSE-010 | 合成 `mixed-type` | roothide | Mixed | `type_mismatch` | reason `field_type`；skipped 同时含 `Bundles not_array` 与 `Classes element_type` index 0；错误证据全量保留 |
| 21 | PARSE-016 | 合成 `determinism` | roothide | Delta | `valid` | 相同 plist 重复解析：规则、归类、计数、otherKeys、skippedFields 深比较一致 |
| 22 | PARSE-012 | 合成 `route-isolation` | `nil` / unknown | — | 空结果 | 未知路线：不读 plist、不调任一 Parser、不改快照；条目归集 `not_parsed`；下游调用全 0 |

### 4.1 基线比较口径补充

- `filterByBase` 基线投影仅含 `bundles / classes / executables`；Engine 测试对报告 JSON 中保留的 `coreFoundationVersion` 一并断言（例 13、15）。
- `skippedFieldsByBase` 基线按 key 归集；Engine 测试在 key 之外保留 `reason / expectedType / observedType / index` 证据比较（对齐 `SkippedField` 结构）。
- 例 11 混合同清单：`parsed` 两条独立归类，`notParsed` 为空；counts 与 `parsed.count + notParsed.count` 等式成立。
- 例 12 Rootless 路线结论依赖 C3-C2 Runner 出证；Engine-C 标记该例通过前，C3-C2 必须已验收（§5 门禁）。

## 5. 门禁与依赖

| 条件 | 状态（基线 `12bcd73`） |
|---|---|
| C3-C1 RootHide Parser | ✅ 已验收（run `43993649974`，275 例 0 失败） |
| C3-B Reader / Decoder | ✅ 已验收（run `43889143343`，236 例 0 失败） |
| C2 Pairing Snapshot / Record | ✅ 已验收 |
| C3-C2 Rootless Parser | 🟡 代码冻结，22 例专项待 Runner；Engine-C 例 12 与 Rootless 集成结论不得提前标记通过 |
| 既有回归 | Engine-B/C 落地后须保持既有 275 例 + S1-05 15 例零回归；新增 Engine 专项与基线分别统计 |

## 6. 禁止项（测试层）

- 不为通过基线而放宽路线规则、弱化类型核对或跨路线兜底。
- 不在测试中访问真实越狱目录、读取未配对 plist 或修改夹具文件。
- 不把 Engine 测试替身 / 加载器编译进 App target；不演进 Adapters 七方法协议。
- 不将 `valid` 断言为 `loaded` 或已配置；不做归属识别与统一导出断言。
