# S1-07 Plugin Source Identification — 插件来源识别子规格

- 状态：**Stage 1 子规格，设计冻结，等待离线测试授权**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-07，不进入 S1-08（统一模型 JSON 导出）；**本轮仅规格设计与用例拆解，不写代码、不建实际夹具、不建正式工程、不编译**。
- 前置：S1-01~S1-06 均已离线验收归档；本项输入为 S1-06 Parsed Plugin Model（携带 S1-05 配对身份与路径）。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.2（Plugin）、§2.4（Ownership）、§4（SourceType / OwnershipStatus / WritablePolicy 枚举）。
- 职责边界：**S1-06 判断 Filter 规则表达了什么；S1-07 回答“这个插件由谁安装、由谁管理、FilterKit 是否有权管理它”；S1-08 统一导出。** S1-07 只做只读归属判断，不修改 dpkg 数据库、不修改插件文件、不做启停授权。

## 1. 测试目标

依据上游产物中的插件路径，只读核对包管理器清单与本地管理标记，判定每个插件（及其 dylib/plist 分文件）的来源与归属，产出 Source Report，供 S1-08 统一模型导出使用。

- 只做**只读归属识别**：读 dpkg `status` 与 `info/<pkg>.list`、读 FilterKit/导入标记信号；不写 dpkg、不删改文件、不推断加载状态。
- 来源识别与管理授权**严格分开**：识别为某类来源，不等于 FilterKit 已获管理授权；可写策略由归属结论与后续操作门禁共同决定。
- 归属证据不足时保留 `unknown`，不以位置、文件名或缺失记录猜测归属。

### 1.1 已核对的归属口径（源码/资料确认）

| 项 | 口径 | 依据 |
|---|---|---|
| dpkg 状态库 | RootHide `<JBROOT>/var/lib/dpkg/status`（realpath 可能映射 `<JBROOT>/Library/dpkg/status`）；Rootless `/var/jb/var/lib/dpkg/status`；Rootful `/var/lib/dpkg/status` | `Research/R&D 0.2/Dopamine-Roothide-Bootstrap.md` §5；`Research/Validation/RootHide-Device-Verification.md` C5；旧 PoC `reference/0.1.18-src/Sources/Core/FKDPKGAnalyzer.m`（参考实现，非新基线） |
| 包文件清单 | `info/<package>.list` 逐行记录包安装的逻辑路径；归属以**精确路径命中**为准，不以文件名猜测 | FKDPKGAnalyzer.m:230-257；Device-Report 两样本 `.list` 精确命中 |
| 包状态计入归属 | 仅 `install ok installed`（installed）状态计入包归属；unpacked / half-configured / reinstreq 等非稳态不构成稳固归属 | FKDPKGAnalyzer.m:53-72,225-228 |
| 多包同路径 | 同一逻辑路径被多个包清单列出 → 归属冲突，全部记录，不任选其一 | FKDPKGAnalyzer.m:412-417 |
| 前端不参与归属 | Sileo / Zebra 只是不同前端，底层同为 dpkg；dpkg 记录不含前端信息，**不能凭前端标签判定所有权**；前端不可识别时记 `unknown` | 任务约束；数据模型 §4 |
| 路径规范化 | 包清单逻辑路径与插件物理路径分开保存；RootHide jbroot 前缀、`/var/jb` 前缀按路线规范化后再比对；不做跨路线套用 | FKDPKGAnalyzer.m:73-94 |

> 旧 PoC 的 md5sums 完整性核对属另一职责（文件完整性），**不在 S1-07 范围**；本项只判断来源与归属，不校验内容完整性。

## 2. 输入模型（只读）

| 输入 | 来源 | 说明 |
|---|---|---|
| S1-06 Parsed Plugin Model | 上游产物 | `route`、`sourceDirectory`、`parsed[]`（`base`、`dylibPath`、`plistPath`、`parseStatus`）、`notParsed[]` |
| dpkg 清单信号 | 离线夹具注入 | `status` 记录（Package/Version/Architecture/Status）、各包 `.list` 逻辑路径、数据库可读状态；离线不访问真实 dpkg 库 |
| 本地管理标记信号 | 离线夹具注入 | FilterKit 自管标记、用户导入标记的存在性/完整性；标记格式与注册表细节在工程阶段定稿，本阶段以信号模拟 |

> 只消费上游已识别条目；本项不重新扫描目录、不补列缺失条目。上游解析失败/未配对条目仍携带路径进入归属判断，保留其 S1-06/S1-05 状态。

## 3. 输出模型（Source Report）

```json
{
  "route": "roothide",
  "sourceDirectory": "<jbroot>/usr/lib/TweakInject/",
  "status": "enumerated",
  "sources": [
    {
      "base": "Example",
      "dylibPath": "<dir>/Example.dylib",
      "plistPath": "<dir>/Example.plist",
      "sourceType": "dpkg",
      "ownership": "owned_package",
      "packageID": "z.weifeng",
      "packageVersion": "1.5",
      "architecture": "iphoneos-arm64e",
      "listPath": "<JBROOT>/var/lib/dpkg/info/z.weifeng.list",
      "fileOwnership": {
        "dylib": { "owners": ["z.weifeng"], "match": "exact" },
        "plist": { "owners": ["z.weifeng"], "match": "exact" }
      },
      "confidence": "exact_record",
      "writablePolicy": "read_only",
      "markers": { "filterkit": "absent", "manual": "absent" },
      "conflicts": [],
      "notes": []
    }
  ],
  "unresolved": [
    { "base": "Unknown", "path": "<dir>/Unknown.dylib", "reason": "no_dpkg_owner", "sourceType": "unknown", "ownership": "unknown" }
  ],
  "counts": { "owned_package": 1, "filterkit_managed": 0, "manual_import": 0, "unknown": 0, "conflict": 0, "dpkg_unavailable": 0 },
  "warnings": []
}
```

字段口径（对齐 [Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.4/§4）：

| 字段 | 含义 / 未知口径 |
|---|---|
| `sourceType` | `dpkg`（包管理器安装）/ `filterkit`（FilterKit 自管）/ `manual`（用户导入）/ `unknown`（无法判定） |
| `ownership` | `owned_package` / `filterkit_managed` / `manual_import` / `unknown` |
| `packageID / packageVersion / architecture / listPath` | 命中包的字段；未命中 = `null`；`listPath` 为精确命中依据 |
| `fileOwnership` | dylib、plist 分文件归属；`match` = `exact`（清单精确命中）/ `none`（清单无记录）/ `conflict`（多包命中） |
| `confidence` | `exact_record`（清单/标记明确记录）/ `heuristic`（多信号推断）/ `unknown`（证据不足） |
| `writablePolicy` | `read_only`（包管理/未知）/ `managed`（FilterKit 自管，经门禁可管理）/ `confirmed_managed`（后续确认后开放）/ `forbidden`（禁止管理）；本阶段不产出 `confirmed_managed` |
| `markers` | `filterkit` / `manual`：`present` / `absent` / `corrupt`；标记损坏不提升为有效归属 |
| `conflicts[]` | 同路径多包归属冲突：`{ path, packages: [] }`，不选边 |
| `counts` | 各归属类别与冲突、数据库不可用计数；类别互斥 |

## 4. 归属判定规则

### 4.1 判定顺序（证据优先级）

1. **dpkg 清单精确命中**：dylib 与 plist 分别在命中包 `.list` 中按规范化逻辑路径精确匹配；包状态为 installed → `sourceType=dpkg`、`ownership=owned_package`、`confidence=exact_record`、`writablePolicy=read_only`。
2. **FilterKit 自管标记有效**：dpkg 无归属，且存在完整、可识别的 FilterKit 自管标记 → `sourceType=filterkit`、`ownership=filterkit_managed`、`confidence=exact_record`、`writablePolicy=managed`。
3. **用户导入标记有效**：dpkg 无归属、无 FilterKit 标记，存在完整用户导入标记 → `sourceType=manual`、`ownership=manual_import`、`confidence=exact_record`；`writablePolicy=read_only`，**需后续确认门禁才可管理**，不自动授权。
4. **证据不足**：以上均不成立 → `sourceType=unknown`、`ownership=unknown`、`confidence=unknown`、`writablePolicy=read_only`。

### 4.2 分文件归属与混合来源

- dylib 与 plist **分别**核对归属；两者命中不同包时，插件级记录为混合来源，`fileOwnership` 保留各自 owners，`notes` 标注 `mixed_package_ownership`，不强行合并为单一包。
- 单文件命中多包 → 该文件 `match=conflict`，记入 `conflicts[]`；插件级归属不任选其一，`confidence` 降为 `heuristic`，`writablePolicy=read_only`，待冲突解决。
- 上游 `notParsed` / 配对不确定条目仍保留路径与原状态，归属记 `unknown` 或对应原因，不删除。

### 4.3 标记规则

- 标记存在但格式损坏 / 不可读 → `markers.<kind>=corrupt`，**不**据此判为自管或导入，归属降级 `unknown`。
- FilterKit 标记不能覆盖已有的包管理器归属冲突；冲突优先保留包归属证据，标记作为补充线索。
- 标记缺失本身不构成任何来源结论；不得由“无标记”反推“用户导入”。

### 4.4 三条安全红线（不可违反）

1. **位置不推断归属**：位于 `TweakInject` / `DynamicLibraries` 目录不等于属于 FilterKit。
2. **dpkg 未命中不等于用户导入**：清单查不到归属，只能记 `unknown`，不得直接归类 `manual_import`。
3. **标记不忽略冲突**：存在 FilterKit 标记时，仍须核对实际 package 所有权冲突；冲突未解决前不开放管理。

### 4.5 来源识别 ≠ 管理授权

- `manual_import` / `filterkit_managed` 仅为归属识别结论；是否允许启停、改写、删除，由后续操作门禁（身份、权限、确认流程）独立决定。
- 本项不产出操作放行结论；`writablePolicy` 为默认策略建议，不是授权凭证。

## 5. 路线隔离与数据库可用性

- dpkg 路径按路线取对应根：RootHide 用 `<JBROOT>/var/lib/dpkg/`，Rootless 用 `/var/jb/var/lib/dpkg/`，Rootful 用 `/var/lib/dpkg/`；禁止跨路线套用清单路径。
- 数据库/状态库**缺失或不可读** → 该路线归属整体记 `dpkg_unavailable`，条目归属 `unknown`，告警 `dpkg_unavailable`；不得回退到其他路线清单或按位置猜测。
- 上游目录未定位/清单未枚举 → 空 Source Report，告警 `inventory_unresolved`，不自行扫描。

## 6. 异常分类

| 层级 | 情况 | 归类 | 记录口径 |
|---|---|---|---|
| 数据库级 | dpkg 状态库/info 目录缺失或不可读 | `dpkg_unavailable` | 保留原因；条目归属 `unknown`，不判用户导入 |
| 归属级 | 清单精确命中单包（installed） | `owned_package` | 记录 packageID/version/arch/listPath |
| 归属级 | FilterKit 自管标记有效 | `filterkit_managed` | 记录标记来源；writablePolicy=managed |
| 归属级 | 用户导入标记有效 | `manual_import` | 记录标记来源；默认 read_only，待门禁确认 |
| 归属级 | 无 dpkg 归属且无有效标记 | `unknown` | `confidence=unknown`，read_only |
| 冲突级 | 同路径多包命中 | `conflict` | 全部 owners 记录，不选边；降级 heuristic/read_only |
| 文件级 | dylib/plist 归属不一致 | 混合来源 | `mixed_package_ownership` 备注，分文件保留 |
| 标记级 | 标记损坏/不可读 | 标记 `corrupt` | 不提升归属，降级 unknown |
| 条目级 | 上游解析失败/未配对/不确定 | 携带保留 | 保留上游状态与原因，归属不删除 |

> 数据库不可读 ≠ 无归属；清单无记录 ≠ 用户导入；标记损坏 ≠ 无标记。三类必须区分。

## 7. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。

```
Tests/Fixtures/S1-07/
├── src-dpkg-owned/        # 单包 .list 精确命中，installed → owned_package
├── src-dpkg-multi-file/   # 多包各自命中自己的 dylib/plist
├── src-filterkit-managed/ # 无 dpkg 归属，FilterKit 自管标记有效
├── src-manual-import/     # 无 dpkg 归属，用户导入标记有效
├── src-unknown/           # 无 dpkg 归属、无标记 → unknown（不判导入）
├── src-dpkg-conflict/     # 同路径多包命中 → conflict，不选边
├── src-mixed-ownership/   # dylib 与 plist 分属不同包
├── src-dpkg-unavailable/  # 状态库/info 不可读 → dpkg_unavailable
├── src-marker-corrupt/    # 标记损坏 → corrupt，降级 unknown
├── src-marker-absent/     # 标记缺失，不反推导入
├── src-route-guard/        # 上游未定位，空报告不回退扫描
└── determinism/           # 相同输入重复识别，结果一致（合成）
```

每组分离 `environment.json`（识别器输入，含上游条目快照、dpkg 清单信号、标记信号）与 `metadata.json`（测试预期）；识别器不得读取 metadata。

## 8. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| OWN-001 | `src-dpkg-owned` | 单包精确命中、installed → `owned_package`，记录包名/版本/架构/清单路径 | 必须通过 |
| OWN-002 | `src-dpkg-multi-file` | 多包条目各自精确命中，归属分别正确 | 必须通过 |
| OWN-003 | `src-filterkit-managed` | 无 dpkg 归属 + 有效自管标记 → `filterkit_managed`，writablePolicy=managed | 必须通过 |
| OWN-004 | `src-manual-import` | 无 dpkg 归属 + 有效导入标记 → `manual_import`，默认 read_only，不自动授权 | 必须通过 |
| OWN-005 | `src-unknown` | 无归属无标记 → `unknown`，**不**归类 `manual_import` | 必须通过 |
| OWN-006 | `src-dpkg-conflict` | 同路径多包 → `conflict`，全部 owners 保留，不任选 | 必须通过 |
| OWN-007 | `src-mixed-ownership` | dylib/plist 分属不同包，分文件保留，标注混合来源 | 必须通过 |
| OWN-008 | `src-dpkg-unavailable` | 数据库不可读 → `dpkg_unavailable`，条目 unknown，不猜归属 | 必须通过 |
| OWN-009 | `src-marker-corrupt` | 标记损坏 → `corrupt`，降级 unknown，不判自管/导入 | 必须通过 |
| OWN-010 | `src-marker-absent` | 标记缺失不反推导入；与损坏标记区分 | 必须通过 |
| OWN-011 | `src-route-guard` | 上游未定位时空报告，不回退其他路线清单/目录 | 必须通过 |
| OWN-012 | 相同条目重复识别 | 归属、owners、置信度、策略一致（确定性） | 必须通过 |
| OWN-013 | S1-01~S1-06 回归 | 前序产物保持通过，未被本项改动 | 必须通过 |

### 8.1 断言要点

- 归属以 `.list` 精确路径命中为准；文件名、目录位置不作为归属证据。
- `dpkg / filterkit / manual / unknown` 与 `owned_package / filterkit_managed / manual_import / unknown` 归类互斥，计数与清单一致。
- 冲突条目不选边；混合来源分文件保留；标记损坏不提升归属。
- 不产出操作放行结论；不判断 Filter 规则合法性（S1-06 已完成）；`loaded` 一律 `unknown`。

## 9. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机 dpkg status/info 全量清单与路径规范化 | 归属命中率 | 待真机只读 `dpkg -S` / 清单复核 |
| FilterKit 自管/导入标记的真实格式与存储位置 | 标记有效性判定 | 工程阶段定稿，离线为信号模拟 |
| 多包同路径、混合归属在真机的真实分布 | 冲突/混合场景 | 待真机采样 |
| 数据库不可读/受限条目的真实表现 | `dpkg_unavailable` 归类 | 待真机只读探测 |
| Rootless/Rootful 路线归属口径 | 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| 前端（Sileo/Zebra）与 dpkg 归属的对应关系 | 前端标签可信度 | 离线不臆测，待真机核对 |

## 10. 通过与失败标准

### 10.1 通过条件

- 仅基于上游条目与只读 dpkg 清单/标记信号识别；精确路径命中，不以位置/文件名猜测；
- `owned_package / filterkit_managed / manual_import / unknown` 归类准确，冲突与混合来源如实保留，计数互斥一致；
- 数据库不可读、清单无记录、标记损坏/缺失分别区分；来源结论不附带管理授权；
- 未越界校验内容完整性、判断加载状态或改写设备/dpkg 数据。

### 10.2 失败情形（任一即不通过）

- 因位于 TweakInject/DynamicLibraries 即判 FilterKit 自管；
- dpkg 未命中直接归类用户导入；
- FilterKit 标记忽略既有 package 归属冲突；
- 多包冲突时任选其一，或混合归属被合并为单一包；
- 标记损坏被当作有效标记，或标记缺失被反推为导入；
- 数据库不可读时回退其他路线清单或按位置猜测；
- 把来源识别结论表述为“已授权管理/可启停/已加载”；
- 读取或写入 dpkg 数据库、删除/修改插件文件。

## 11. 设计边界

- S1-07 只产出来源与归属判断；**不做**统一模型 JSON 导出（S1-08）、不做文件完整性校验、不做操作执行。
- 归属识别 ≠ 管理授权 ≠ 插件已配置生效 ≠ 已加载；CLI 归属结果不作为 GUI 进程权限证据。
- 本项离线夹具为合成样本；Rootless/Rootful 无真机背书，不把 RootHide 结论推广到其他路线。
- S1-07 离线测试须单独授权后再创建夹具与代码；在此之前不扩展 S1-08，不创建正式工程。
