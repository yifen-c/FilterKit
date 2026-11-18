# Stage 2.2-C2-C：C1 Enumeration → C2 Pairing 集成数据契约（设计层冻结）

- 状态：**契约冻结（设计层）**；桥接实现与专项测试见 `Stage-2.2-C2-C-Pairing-Integration-Implementation.md`。
- 依据：C1 验收 `5b481e6`、G-C3 契约 `7dbac87`、C2-A 模型冻结 `cc5c98e`、C2-B 引擎冻结 `35d8d76`。
- 边界：本批只做 Core 内部集成桥接与完整性验证；不接入 `PluginScanService`/`AdapterResolver`，不改七方法协议、不改 Adapter、不改 Models 公共契约、不碰真机与插件文件。完整编译与回归归 C2-D。

## 1. 数据流边界

```
PluginScanner / Enumeration
        ▼
PluginInventorySnapshot（C1，冻结输入）
        │  C1 → C2 转换边界（只读，不重扫、不重读、不重算哈希）
        ▼
PluginPairingInputAdapter（过滤 dylib/plist 视图，原始快照保持完整）
        ▼
PluginPairingPipeline（编排，不新增配对算法）
        ▼
PluginPairingEngine（C2-B，冻结）
        ▼
PluginPairingSnapshot（C2）
        ▼
后续 PluginScanService 集成（C2-C 不接入）
```

- 唯一输入：C1 `PluginInventorySnapshot`；唯一输出：C2 `PluginPairingSnapshot`。
- 桥接层不重新扫描目录、不重新读取文件、不重新计算哈希、不改写 `PluginFileEvidence` 原始字段（路径/文件名/entryStatus/三态位/软链信号原样保留）。
- 过滤只产生"配对所需视图"；C1 原始快照在执行前后保持深比较一致。

## 2. 状态传递矩阵（冻结）

C1 `EnumerationStatus` 与 C2 `PairingStatus` 原始值同名但**语义分属两个阶段**：不共享枚举类型，不通过原始字符串跨阶段判状态。

| C1 EnumerationStatus | C2 行为 | C2 PairingStatus | 记录/告警口径 |
|---|---|---|---|
| `enumerated` | 正常配对；存在 uncertain 条目时降级 partial | `enumerated` / `partial` | uncertain >0 → `partial` + `partial_pairing` |
| `partial` | 保留可用证据并配对 | `partial` | 叠加 uncertain 不重复降级；保留 C1 告警 |
| `enumeration_failed` | 不生成配对记录 | `enumeration_failed` | 保留 C1 unknownItems/warnings；补 `inventory_unresolved` |
| `unresolved` | 不生成配对记录 | `unresolved` | 保留 C1 unknownItems/warnings；补 `inventory_unresolved` |

- 目录身份缺失（`sourceDirectory == nil`）按 unresolved 处理。
- 失败/未决目录**不猜测身份、不构建记录**；五桶计数全 0。
- C2 新增告警追加在 C1 告警之后，不覆盖、不去重合并 C1 原有告警。

## 3. 完整性验收口径（INT-C2-001 ~ 014）

| 编号 | 验收内容 | 通过口径 |
|---|---|---|
| INT-C2-001 | route 原样传递 | 输出 `route` 与输入逐字一致（含 `nil`） |
| INT-C2-002 | sourceDirectory 原样传递 | 输出 `sourceDirectory` 与输入逐字一致（含 `nil`） |
| INT-C2-003 | dylib/plist 证据完整传递 | 输入中全部 dylib/plist 进入配对视图；证据与快照内对应条目 `Equatable` 相等 |
| INT-C2-004 | 非候选文件不进入配对索引 | directory/symlink/other 不出现在任何记录的 dylib/plist/candidates |
| INT-C2-005 | C1 unknownItems 不丢失 | C1 每条 unknownItem 原样包含在输出 unknownItems 内（C2 可追加空键归集，不删原条目） |
| INT-C2-006 | C1 warnings 不丢失 | C1 每条 warning 原样包含在输出 warnings 内（C2 可追加状态告警） |
| INT-C2-007 | entryStatus 不被改变 | 配对视图内每条证据的 `entryStatus` 与 C1 原值一致 |
| INT-C2-008 | `readable=nil` 不被转成 false | 三态位原样保留；视图证据与 C1 证据深比较相等 |
| INT-C2-009 | unresolved 正确处理 | 状态 unresolved、records 0、计数全 0、`inventory_unresolved` 在位 |
| INT-C2-010 | partial 正确处理 | 状态 partial；可用证据保留为记录；C1 告警保留 |
| INT-C2-011 | 五桶计数互斥 | 五桶之和 = `records.count`；`counts.total` 一致；无重复计数 |
| INT-C2-012 | 输入快照执行前后一致 | 执行后 C1 快照与执行前深比较相等（无副作用） |
| INT-C2-013 | 同一输入重复执行结果一致 | 重复执行输出快照 `Equatable` 相等 |
| INT-C2-014 | 路线不交叉转换 | 输出路线不被桥接层改写；RootHide/Rootless 信号互不套用；无跨快照合并 |

## 4. 证据保留纪律

- `PluginFileEvidence` 的 `path/name/extension/kind/exists/readable/isSymlink/symlinkTarget/symlinkState/realpath/size/hash/hidden/entryStatus` 全字段原样透传；桥接层不补默认值、不反推三态位。
- C2 输出不冒充完整 C1 Inventory：非候选证据以 C1 `unknownItems` 为准，不复制到配对记录。
- ambiguous/uncertain 明细以 C2 `records`/`candidates` 为准，不在 `unknownItems` 双写路径清单。
- 集成结果模型为 Core 内部核对辅助结构，**不加入公共 Models、不进入 `ReportEnvelope`、不产出最终 `Plugin`**。

## 5. 非目标

- `PluginScanService` / `AdapterResolver` 装配；七方法协议演进；GUI 展示。
- 真机目录扫描、插件文件修改、软链改动、注入配置修改、启停。
- C3 Filter 解析、S1-07 归属、S1-08 导出；C2-D 完整 Runner 回归。
