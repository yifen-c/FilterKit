# S1-04 Plugin Enumeration — 插件文件枚举子规格

- 状态：**Stage 1 子规格，设计冻结，等待离线测试授权**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-04，不进入 S1-05（配对）；**本轮仅规格设计与用例拆解，不写代码、不建实际夹具、不建正式工程、不编译**。
- 前置：S1-01 环境识别、S1-02 JBROOT 定位、S1-03 ElleKit 目录定位均已离线验收归档；本项输入为 S1-03 Directory Report。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.1、[Research/R&D 0.2/Path-Resolution.md](../../Research/R&D%200.2/Path-Resolution.md)。
- 运行上下文：Stage 1 CLI / 越狱 shell 只读探测；**枚举到文件 ≠ 存在有效插件 ≠ 已安装/已配置/已加载 ≠ Adapter 兼容 ≠ GUI 进程有权限**。

## 1. 测试目标

依据 S1-03 已确认的 TweakInject 目录，非递归枚举目录内条目，产出原始文件清单（Plugin Inventory），供 S1-05 配对、S1-06 解析、S1-07 来源识别使用。

- 只做**文件发现与元数据记录**；不做 dylib/plist 配对（S1-05）、不解析 plist/Filter（S1-06）、不判断来源（S1-07）、不推断加载状态。
- 单条目异常不中断整轮枚举；目录级不可枚举时给出全局告警与空清单说明。

### 1.1 源码扫描口径（源码确认）

| 项 | 口径 | 源码依据 |
|---|---|---|
| 扫描方式 | `scandir` 单层目录，**非递归**，不进入子目录 | `roothide-ellekit-src/injector/injector.c:366-374`；`ellekit-src/injector/injector.c:254-256` |
| 注入候选过滤 | 仅按扩展名 `.dylib`（`filter_dylib`），不解析文件内容 | `injector.c:29-32` |
| 排序 | `alphasort` 字母序，保证清单确定性 | `injector.c:371,373` |
| plist 发现 | injector 运行时由 dylib 名派生同名 `.plist` 校验；本规格为配对需要，把目录内 `.plist` 也独立列入清单 | `injector.c:89-92,389` |
| 扫描失败 | `scandir` 返回 -1 时记录错误并返回，不中断进程 | `injector.c:375-378` |

> 上游 injector 只把 `.dylib` 纳入注入候选；FilterKit 清单同时记录 `.plist` 与其他条目，是为离线配对/诊断留痕，不代表 injector 会加载 plist 文件本身。

## 2. 输入模型（只读）

| 输入 | 来源 | 说明 |
|---|---|---|
| S1-03 Directory Report | 上游产物 | `route`、`tweakInject.value`、`tweakInject.status`、`readable/enumerable` |
| 目录条目信号 | 只读 scandir / stat / lstat / realpath / 读取大小 | 离线夹具以信号模拟，不访问真实文件系统 |
| 条目元数据信号 | 大小、类型、软链目标、可选哈希 | 不可获取时独立记录失败，不阻断枚举 |

> 信号结构沿用 S1-01~S1-03 的 `{ value, present, readability, source, raw }` 口径；离线夹具 `source=fixture`。

## 3. 输出模型（Plugin Inventory）

```json
{
  "route": "roothide",
  "sourceDirectory": "<jbroot>/usr/lib/TweakInject/",
  "enumeration": {
    "recursive": false,
    "status": "enumerated",
    "warnings": []
  },
  "items": [
    {
      "path": "<jbroot>/usr/lib/TweakInject/Example.dylib",
      "name": "Example.dylib",
      "extension": "dylib",
      "kind": "dylib",
      "exists": true,
      "readable": true,
      "isSymlink": false,
      "symlinkTarget": null,
      "realpath": "/private/var/.../Example.dylib",
      "size": 20480,
      "hash": null,
      "hidden": false,
      "entryStatus": "ok"
    }
  ],
  "unknownItems": [
    { "path": ".../README.txt", "name": "README.txt", "reason": "unknown_extension" }
  ],
  "counts": { "dylib": 1, "plist": 0, "directory": 0, "symlink": 0, "other": 0 },
  "warnings": []
}
```

字段口径：

| 字段 | 含义 / 未知口径 |
|---|---|
| `sourceDirectory` | 枚举根目录，取自 S1-03；上游目录未定位 = `null` |
| `enumeration.recursive` | 固定 `false`；禁止为方便而递归子目录 |
| `enumeration.status` | `enumerated / partial / enumeration_failed / unresolved` |
| `items[].kind` | `dylib / plist / directory / symlink / other`；软链标志与扩展名分类正交 |
| `items[].name` | 原始文件名原样保留，不改写大小写、不修剪空格/尾字符 |
| `items[].extension` | 最后一个 `.` 之后的**原始后缀**（保留大小写，不转小写）；无扩展名 = `null`。匹配按源码 `strcmp` 大小写敏感，`.DYLIB`/`.Dylib` 不归类为 dylib |
| `items[].exists/readable` | 条目存在性、可读性；与元数据获取结果独立 |
| `items[].isSymlink` | lstat 是否软链；软链记录自身，不跟随目标继续枚举 |
| `items[].size` | 可获取的文件大小；不可获取 = `null` |
| `items[].hash` | 只读计算摘要；本阶段可选，失败 = `null` 并在条目记 `metadata_unavailable`，不阻断 |
| `items[].hidden` | 文件名以 `.` 开头；隐藏文件默认列入并标记，不静默排除 |
| `items[].entryStatus` | `ok / access_denied / metadata_unavailable / read_failed / not_found` |
| `unknownItems[]` | 无法归类条目（其他扩展名、目录、异常条目）及原因 |

## 4. 枚举规则

### 4.1 范围与分类

1. 只枚举 S1-03 确认的 `sourceDirectory` 单层内容；不扫描 `/var/jb`、`/`、`Library/MobileSubstrate` 等其他目录。
2. 按扩展名初分类（大小写敏感，对齐 `filter_dylib` 的 `strcmp`）：`.dylib` → `dylib`；`.plist` → `plist`；目录条目 → `directory`；软链条目另置 `isSymlink=true`；其余 → `other` 并进入 `unknownItems`。
3. 条目以**完整路径**为身份键，不用基名合并；不同路径的同名条目分别保留。
4. 排序按文件名字母序（对齐 `alphasort`），相同输入清单顺序确定。

### 4.2 软链处理

- 记录软链条目自身（`isSymlink=true`、`symlinkTarget`、`realpath`、解析状态）；不跟随软链目标把目标内文件再枚举一遍。
- 软链目标缺失/循环/受限按 S1-03 口径记录 `broken / loop / denied`，不把软链本身误判为普通文件。

### 4.3 元数据与哈希

- `size`、`realpath` 等元数据逐项获取；单项失败记 `metadata_unavailable`，不影响其他条目。
- 哈希为只读可选摘要；计算失败记 `read_failed`/`metadata_unavailable`，`hash=null`，不判文件不存在。
- 本阶段不解析 Mach-O 头、不校验签名、不读取 plist 内容。

### 4.4 状态边界（三层状态不越界）

- `installed`：本项**不产出**；dylib 在位可读只作为文件层证据，最终 `installed` 由后续模型结合规则判定。
- `configured`：本项**不产出**；plist 存在不等于 Filter 可解析。
- `loaded`：本项一律 `unknown`；禁止由 dylib/plist 在位推断已加载。

## 5. 路线隔离红线

- 枚举根目录只能来自 S1-03；S1-03 目录 `unresolved / not_found / enumeration_failed` 时，本项 `sourceDirectory=null`、清单为空并保留上游原因，**禁止**自行回退到 `/var/jb`、`/` 或其他路线目录。
- Rootless/Rootful 样本结论不互相套用；Rootful 清单仅作诊断，不映射 Profile。
- 上游 JBROOT 未定位（S1-02 未裁决）时，不在本项猜测根前缀。

## 6. 异常分类

对齐计划 §2.3，枚举异常分层记录，不直接算整轮硬失败：

| 层级 | 情况 | 归类 | 记录口径 |
|---|---|---|---|
| 目录级 | 目录不可枚举（EACCES/EPERM/ENOTDIR） | 枚举受限 | `enumeration.status=enumeration_failed`，全局告警 `enumeration_failed`，清单为空并附原因 |
| 目录级 | 上游目录未定位/不存在 | 未定位 | `status=unresolved`，告警 `directory_unresolved` |
| 目录级 | 部分条目可访问、部分受限 | 部分受限 | `status=partial`，全局告警 `partial_enumeration` |
| 条目级 | 条目不存在（竞态消失） | 未发现 | `entryStatus=not_found`，不进入有效清单 |
| 条目级 | 存在但不可读（EACCES/EPERM） | 访问受限 | `entryStatus=access_denied`，保留路径记录 |
| 条目级 | stat/元数据不可获取 | 元数据不可用 | `entryStatus=metadata_unavailable`，`size/realpath=null` |
| 条目级 | 读取内容/哈希失败 | 读取失败 | `entryStatus=read_failed`，`hash=null` |
| 条目级 | 软链目标缺失/循环/受限 | 软链异常 | 软链状态字段独立记录，不并入普通文件 |

> 文件访问失败 ≠ 文件不存在：`access_denied / metadata_unavailable / read_failed` 与 `not_found` 必须区分。

## 7. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。

```
Tests/Fixtures/S1-04/
├── rh-mixed/            # dylib + plist + 其他扩展名混合
├── rh-orphan-plist/     # plist 无配对 dylib（配对留 S1-05，本项只记录）
├── rh-orphan-dylib/     # dylib 无配对 plist
├── rh-dir-entry/        # 含子目录条目，验证不递归
├── rh-symlink-valid/    # 软链条目指向 dylib，正常解析
├── rh-symlink-broken/   # 软链断链
├── rh-hidden-file/      # 点开头隐藏文件，列入并标记
├── rh-other-extension/  # .deb/.txt 等未知扩展名 → unknownItems
├── rh-bad-permission/   # 单条目访问受限，不中断整轮
├── rh-metadata-missing/ # 存在但元数据不可获取
├── rh-enum-failed/      # 目录整体不可枚举 → 全局告警空清单
├── rootless-mixed/      # Rootless 路线合成样本
└── route-guard/         # S1-03 目录未定位，禁止扫描回退根
```

每组分离 `environment.json`（枚举器输入）与 `metadata.json`（测试预期）；枚举器不得读取 metadata。

## 8. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| ENUM-001 | `rh-mixed` | 全部 `.dylib` 列入 `items`，`kind=dylib` | 必须通过 |
| ENUM-002 | `rh-mixed` | 全部 `.plist` 列入 `items`，`kind=plist`，不与 dylib 合并 | 必须通过 |
| ENUM-003 | `rh-dir-entry` / `rh-other-extension` | 区分普通文件、目录、软链、其他类型 | 必须通过 |
| ENUM-004 | 各夹具 | 文件名原样保留，未改写大小写/空格/扩展名 | 必须通过 |
| ENUM-005 | `rh-hidden-file` | 点开头文件列入清单且 `hidden=true`，未被排除 | 必须通过 |
| ENUM-006 | `rh-dir-entry` | 子目录只记录条目，**不递归**进入；`recursive=false` | 必须通过 |
| ENUM-007 | `rh-symlink-valid/broken` | 软链条目与目标区分记录；断链不误判普通文件 | 必须通过 |
| ENUM-008 | `rh-bad-permission` / `rh-enum-failed` | 区分条目访问受限与目录枚举失败；失败不混为不存在 | 必须通过 |
| ENUM-009 | `rh-mixed` | 可获取条目记录 `size`；不可获取记 `metadata_unavailable` | 必须通过 |
| ENUM-010 | 含哈希信号夹具 | 哈希只读计算；失败记 `read_failed`/`metadata_unavailable`，`hash=null`，不阻断 | 必须通过 |
| ENUM-011 | 同名条目不同路径（合成） | 按完整路径保留，未被基名合并 | 必须通过 |
| ENUM-012 | `rh-bad-permission` 等 | 单条目异常不导致整轮枚举失败，其余条目仍入清单 | 必须通过 |
| ENUM-013 | `route-guard` | 仅枚举 S1-03 确认目录；上游未定位时不扫描回退根 | 必须通过 |
| ENUM-014 | 相同目录信号重复枚举 | 清单条目、顺序、计数确定一致（确定性） | 必须通过 |
| ENUM-015 | S1-01/S1-02/S1-03 回归 | 前序产物保持通过，未被本项改动 | 必须通过 |

### 8.1 断言要点

- 枚举根目录必须来自 S1-03；禁止硬编码跨路线根前缀。
- `exists / readable / metadata` 独立记录；访问失败不记为不存在。
- 非递归：子目录与软链目标内文件不得进入清单。
- 不产出配对结论、不解析内容、不推断 `installed/configured/loaded`。

## 9. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 第三方 App 进程对 TweakInject 的列目录权限 | `enumeration.status` | 待真机；离线不得标可枚举 |
| 真机全量 dylib/plist 条目与命名 | 清单完整性 | 旧报告枚举不全，待真机全量采集 |
| 真机软链条目分布与目标 | 软链分类 | 待真机复核 |
| Rootless / Rootful 真机目录条目 | ENUM 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| 条目真实大小/哈希可取性 | 元数据/哈希字段 | 待真机；离线样本为合成信号 |
| `pkgmirror` 路径性质与条目归属 | 旁路目录排除 | 待真机核实，暂列未知项 |

## 10. 通过与失败标准

### 10.1 通过条件

- 仅枚举 S1-03 确认目录，单层非递归；dylib/plist/目录/软链/其他分类准确；
- 文件名原样保留，条目按完整路径去重，清单顺序确定；
- 存在/可读/元数据分层记录，访问失败与不存在明确区分；
- 单条目异常不中断整轮；目录级受限/未定位有全局告警与空清单说明；
- 未越界产出配对、解析、来源或加载状态结论；全程只读，不修改设备文件。

### 10.2 失败情形（任一即不通过）

- 递归扫描子目录或软链目标；
- 访问受限/元数据失败被记为文件不存在；
- 按基名合并不同路径同名条目，或改写文件名；
- 由 dylib/plist 在位推断 `installed/configured/loaded`；
- 上游目录未定位仍回退扫描 `/var/jb`、`/` 等回退根；
- 单条目异常导致整轮枚举失败。

## 11. 设计边界

- S1-04 只产出文件清单与元数据；**不做**配对（S1-05）、plist/Filter 解析（S1-06）、来源识别（S1-07）、统一模型导出（S1-08）。
- 文件发现成功 ≠ 插件有效 ≠ 配对正确 ≠ Adapter 兼容；CLI 清单不作为 GUI 进程权限证据。
- 本项离线夹具为合成样本；Rootless/Rootful 无真机背书，不把 RootHide 结论推广到其他路线。
- S1-04 离线测试须单独授权后再创建夹具与代码；在此之前不扩展 S1-05，不创建正式工程。
