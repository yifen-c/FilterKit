# Stage 2.2-C1：Plugin Enumeration 实现记录（代码冻结，Runner 验收待授权）

- 日期：2026-11-16
- 授权依据：用户附件《现在正式进入 Stage 2.2-C1：Plugin Enumeration（插件枚举器实现）》；冻结契约 `Stage-2.2-C-Enumeration-Models-Contract.md`（G-C1/G-C2）；基线规格 `Stage-2.2-C-Enumeration-Pairing-Parser.md`（C1 门槛 23 例 ENUM）、`Spec/Stage-1/S1-04-Plugin-Enumeration.md`、`Tests/S1-04/enumerator.js`。
- 状态：**Implementation Complete / Local Static Review Passed / Runner Build & Test Verified / Isolation Verified / App Build Verified / C1 Acceptance Passed**。Runner run `43825045361`：`swift build` 18.08s 成功；`swift test` **114 例 0 失败**（既有 91 零损伤 + C1 新增 23）；隔离三向 OK；App 模拟器 BUILD SUCCEEDED、PID 3740 存活复查一致；证据见 `Tests/Stage2/evidence/run-43825045361/RUN-METADATA.md`。

## 1. 本轮授权边界

### 已允许并执行
1. Models 增补冻结的枚举与结构体（G-C1）；
2. Core 新增 Plugin Enumeration 实现（G-C2 快照、分类、证据构建、编排、汇总）；
3. `Package.swift` 必要接线（Core 源登记、测试源登记）；
4. 新增 C1 专属 Swift Tests（基线深比较 + Codable 往返 + 确定性/异常/软链/隐藏/计数）；
5. 本地静态审查。

### 禁止项（本轮均未触碰）
1. 未修改 Stage 1 Fixtures、Harness、`report.json` 与既有测试预期；
2. 未修改七方法 Adapter 协议；
3. 未修改 RootHide / Rootless Adapter 已冻结行为；
4. 未实现 C2 Plugin Pairing、未实现 C3 Filter Parser；
5. 未修改 `ReportEnvelope`；
6. 未进行任何插件文件写入、启停或注入；未执行真机扫描或 GUI 权限探针。

## 2. 文件清单

| 类别 | 路径 | 说明 |
|---|---|---|
| Models 枚举 | `Models/PluginEnumeration/PluginFileKind.swift` | 五值封闭集：`dylib/plist/directory/symlink/other` |
| Models 枚举 | `Models/PluginEnumeration/PluginEntryStatus.swift` | 五值封闭集：`ok/access_denied/metadata_unavailable/read_failed/not_found` |
| Models 证据 | `Models/PluginEnumeration/PluginFileEvidence.swift` | 条目证据结构，14 字段；三态 `Bool?`；`decodeIfPresent`；缺省 `hidden=false`、`entryStatus=.ok` |
| Core 枚举 | `Core/PluginScanner/Enumeration/EnumerationStatus.swift` | 目录级四态：`enumerated/partial/enumeration_failed/unresolved` |
| Core 计数 | `Core/PluginScanner/Enumeration/PluginKindCounts.swift` | 五类计数，与 `PluginFileKind` 一一对应 |
| Core 输入快照 | `Core/PluginScanner/Enumeration/PluginInventoryFixtureSignal.swift` | 夹具 `environment.json` 中性解码；`nested` 仅输入侧使用 |
| Core 分类器 | `Core/PluginScanner/Enumeration/PluginEntryClassifier.swift` | 目录→软链→扩展名（大小写敏感）判定顺序；扩展名提取 |
| Core 证据构建 | `Core/PluginScanner/Enumeration/PluginFileEvidenceBuilder.swift` | 信号 → 证据；三态原样保留；不计算哈希、不解析软链目标 |
| Core 快照 | `Core/PluginScanner/Enumeration/PluginInventorySnapshot.swift` | `EnumerationBlock` + `PluginInventorySnapshot`；首版不进信封 |
| Core 汇总 | `Core/PluginScanner/Enumeration/PluginInventoryBuilder.swift` | 确定性排序、计数、未知条目归集、告警包装；不访问文件系统 |
| Core 编排 | `Core/PluginScanner/Enumeration/PluginDirectoryEnumerator.swift` | 单层枚举编排；目录级状态优先级裁决 |
| 基线测试 | `Tests/Stage2/PluginEnumerationTests.swift` | S1-04 13 组夹具深比较 + 3 例合成用例 + 10 项专项口径 |
| Codable 测试 | `Tests/Stage2/PluginInventoryCodableTests.swift` | 枚举原始值、往返、三态保留、缺省解码、未知键忽略、计数累加 |
| 接线 | `Package.swift` | Core 登记 8 个枚举器源；Stage2Tests 登记 2 个 C1 测试源 |

## 3. 契约落地对照

| 契约条目 | 落地位置 | 口径 |
|---|---|---|
| `PluginFileEvidence` 14 字段 | `PluginFileEvidence.swift` | 与契约 §3.3 逐字段一致；`size: Int?`；`hash` 只读信号；`extension` 保留原始大小写 |
| 三态事实位 | 证据构建器 / 证据结构 | `exists/readable/isSymlink` 缺失为 `nil`，不做 `nil → false` 转换 |
| `PluginInventorySnapshot` | `PluginInventorySnapshot.swift` | `route/sourceDirectory/enumeration/items/unknownItems/counts/warnings`；`recursive=false` 固定 |
| 五类计数 | `PluginKindCounts.swift` | dylib/plist/directory/symlink/other 全保留，不只统计 dylib/plist |
| 输入信号快照 | `PluginInventoryFixtureSignal.swift` | 不读 `metadata.json`、不访问真实 FS；信号缺失按未提供处理 |
| 目录级状态优先级 | `PluginDirectoryEnumerator.enumerate(_:)` | 未定位 `unresolved` → 不可枚举 `enumeration_failed` → 部分受限 `partial` → 完整 `enumerated`；空目录不判失败 |
| 未知条目归集 | `PluginInventoryBuilder.assemble(...)` | 非 dylib/plist 进 `UnknownItem`：`reason=kind.rawValue`、`sourceStage="S1-04"`、`detail.name=name` |

## 4. S1-04 23 项回归映射

### 4.1 夹具用例（20 例，`testS104FixturesDeepComparison` 逐组深比较）

| 夹具目录 | ENUM 编号 | 基线要点 |
|---|---|---|
| `rh-mixed` | ENUM-001 / 002 / 004 / 009 / 010 | 2 dylib + 1 plist + 1 other；字母序；计数与未知条目一致 |
| `rh-orphan-plist` | ENUM-002 | 单 plist，无未知条目 |
| `rh-orphan-dylib` | ENUM-001 | 单 dylib，无未知条目 |
| `rh-dir-entry` | ENUM-003 / 006 | 目录条目保留；嵌套 `Plugins/Inside.dylib` 排除（非递归） |
| `rh-symlink-valid` | ENUM-007 | 普通 dylib + 软链；软链目标/状态保留 |
| `rh-symlink-broken` | ENUM-007 | 断链归 `symlink`，不误判普通文件 |
| `rh-hidden-file` | ENUM-005 | `.hidden.dylib` 归 dylib；`.plist` 无扩展名归 other；隐藏标记保留 |
| `rh-other-extension` | ENUM-003 | `.deb/.txt/.DYLIB` 全归 other，进 unknownItems |
| `rh-bad-permission` | ENUM-008 / 012 | 受限条目保留；`readable=false`、`entryStatus=access_denied`；`partial` |
| `rh-metadata-missing` | ENUM-009 / 010 | `realpath/size/hash=nil`；`metadata_unavailable`；`partial` |
| `rh-enum-failed` | ENUM-008 | 目录不可枚举：空清单 + `enumeration_failed` |
| `rootless-mixed` | ENUM-013 | rootless 路线；dylib + plist |
| `route-guard` | ENUM-013 | 上游目录未定位：`unresolved`，空清单，无 `/var/jb` 回退 |

### 4.2 合成用例（3 例）

| ENUM 编号 | 测试方法 | 断言 |
|---|---|---|
| ENUM-011 | `testEnum011PathIdentityPreserved` | 同名条目按完整路径保留，不按基名合并；两路径不等 |
| ENUM-014 | `testEnum014DeterministicRepeatedEnumeration` | 相同信号重复枚举，快照逐字段相等 |
| ENUM-013 | `testEnum013RouteIsolationNoFallback` | `sourceDirectory=nil`、0 条目、`unresolved`、无 `/var/jb` 前缀 |

### 4.3 专项口径测试（附加，不替换既有基线）

扩展名大小写敏感（`.DYLIB/.PLIST` → other）；非递归；软链不跟随；权限异常保留；隐藏保留；`readable/isSymlink` 缺失为 nil；哈希只透传不计算；五类计数完整；空目录 `enumerated` 零计数；文件名排序稳定。

## 5. 六个易错点自查

| 项目 | 落地保证 | 状态 |
|---|---|---|
| 扫描深度 | 仅单层；`nested=true` 条目过滤；`enumeration.recursive=false` | ✅ |
| 文件识别 | 扩展名 `strcmp` 口径大小写敏感；目录/软链先于扩展名判定 | ✅ |
| 软链 | 记录自身；不跟随目标；目标/状态独立保留 | ✅ |
| 权限异常 | 受限条目保留在清单；访问拒绝 ≠ 不存在 | ✅ |
| Optional | 三态 `nil` 不转 `false`；信号缺失不反推补齐 | ✅ |
| 快照隔离 | 不进 `ReportEnvelope`；不产出最终 `Plugin`；无配对/解析/加载结论 | ✅ |

## 6. 静态审查记录与未决项

1. **本地无 Swift 工具链**：编码轮仅完成文本级静态审查；编译与回归已由独立 Runner run `43825045361` 完成并通过（见 RUN-METADATA）：`swift build` 成功、`swift test` 114 例 0 失败、C1 23 例与本地源码逐一对应。
2. **未知枚举原始值解码（2.2-A R6 观察项沿用）**：`PluginFileKind/PluginEntryStatus/EnumerationStatus` 沿用现有 Models 枚举合成 Codable 口径；夹具外出现未知原始值的实际解码表现留 Runner 轮记录，本轮不新增静默默认值。
3. **B4 衔接面**：枚举器当前消费 `PluginInventoryFixtureSignal`（离线信号）；`ElleKitDirectoryResolution` → 枚举器的服务装配、`PluginScanService` 协议接入与 AdapterResolver 接线归后续装配授权，本轮未改服务协议。
4. **哈希/元数据真机可取性**：字段位已冻结；真机大小/哈希读取留 2.5 只读验证。
5. **既有回归**：Stage2Tests 既有 8 个测试文件与断言零改动；C1 两个测试文件为独立附加层。

## 7. 非目标（明确不在 C1 范围）

- C2 dylib/plist 配对、五态配对报告、ambiguous/uncertain 归集；
- C3 Filter 解析、五态解析报告、结构化 `skippedFields`、Rootless 内部 Codable 模型；
- S1-07 来源识别、S1-08 统一导出、归属判断、插件启停、注入状态；
- 真机扫描、目录权限探针、任何写入/启停操作。

## 8. 下一阶段门槛（Runner 验收已通过）

Runner run `43825045361` 复核结论：
1. ✅ `swift build` 成功（18.08s），Models/Adapters/Core 无新增编译告警阻断；
2. ✅ `swift test` 既有 91 例 0 失败 + C1 新增 23 例全绿；S1-04 23 例映射逐项通过；
3. ✅ 隔离复核：Core 不实例化具体 Adapter；枚举器不持有路线规则；
4. ✅ 深比较口径与 `metadata.json` 基线一致，未复制第二份基线。

遗留：B4 结果 → 枚举器服务装配、`PluginScanService` 接入与 AdapterResolver 接线归后续装配授权；C2 配对待单独授权。
