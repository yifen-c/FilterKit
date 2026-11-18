# S1-03 ElleKit Directory Resolution — ElleKit 目录定位子规格

- 状态：**Stage 1 子规格，设计冻结，等待离线测试授权**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-03，不进入 S1-04（插件枚举）；**本轮仅规格设计与用例拆解，不写代码、不建实际夹具、不建正式工程、不编译**。
- 前置：S1-01 环境识别、S1-02 JBROOT 定位均已离线验收归档；本项输入以上游产物为参考，路径定位不反向替代环境识别或 JBROOT 定位。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.1、[Research/R&D 0.2/Path-Resolution.md](../../Research/R&D%200.2/Path-Resolution.md)、[Research/R&D 0.2/RootHide-ElleKit-1.2-3.md](../../Research/R&D%200.2/RootHide-ElleKit-1.2-3.md)。
- 运行上下文：Stage 1 CLI / 越狱 shell 只读探测；**目录定位成功 ≠ 目录可枚举 ≠ 插件配对正确 ≠ Adapter 兼容 ≠ GUI 进程有权限**。

## 1. 测试目标

按 S1-01 判定的路线与 S1-02 定位的 JBROOT，解析 ElleKit 插件目录（TweakInject）与 `DynamicLibraries` 软链，记录目录存在性、可读性、可枚举性、realpath、结构旁证与软链状态，供 S1-04 插件枚举使用。

- 只做**目录级定位与状态记录**；不枚举 dylib/plist 条目（S1-04）、不解析 plist/Filter（S1-06）、不激活 Profile。
- 目录不可定位或受限时显式记录状态与原因，不臆造路径、不跨路线回退。

### 1.1 三条路线目录规则（源码确认口径）

| 路线 | TweakInject 目录 | DynamicLibraries 软链 | 源码依据 |
|---|---|---|---|
| RootHide | `<jbroot>/usr/lib/TweakInject/`（`jbroot("/usr/lib/TweakInject/")` 翻译） | `<jbroot>/Library/MobileSubstrate/DynamicLibraries` → TweakInject | `roothide-ellekit-src/injector/injector.c:43,499` |
| Rootless | `/var/jb/usr/lib/TweakInject/` | `/var/jb/Library/MobileSubstrate/DynamicLibraries` → TweakInject | `ellekit-src/injector/injector.c:32`；`ellekit-src/Makefile:89,94` |
| Rootful | `/usr/lib/TweakInject/` | `/Library/MobileSubstrate/DynamicLibraries`（传统 Substrate 布局） | `roothide-ellekit-src/injector/injector.c:42`；`ellekit-src/injector/injector.c:31` |

> RootHide 与 Rootless 的 `/usr/lib/TweakInject/` 相对段相同，但根前缀不同：RootHide 根来自 S1-02 的 JBROOT，Rootless 根固定 `/var/jb`。两者不得混用前缀。

## 2. 输入模型（只读）

| 输入 | 来源 | 说明 |
|---|---|---|
| S1-01 环境结果 | 上游产物 | `jailbreakType` / `ellekitImplementation`，作为路线参考 |
| S1-02 JBROOT 结果 | 上游产物 | `jbroot` / `jbrand` / `realpath`；RootHide 拼目录前缀的唯一依据 |
| 目录探测信号 | 只读 stat / lstat / realpath / 可列性探测 | 离线夹具以信号模拟，不访问真实文件系统 |
| 软链信号 | lstat 类型、链接目标、realpath、解析错误 | 区分普通软链 / 断链 / 循环 / 目标不可达 |

> 信号结构沿用 S1-01/S1-02 的 `{ value, present, readability, source, raw }` 口径；离线夹具 `source=fixture`。

## 3. 输出模型（Directory Report）

```json
{
  "route": "roothide",
  "tweakInject": {
    "value": "<jbroot>/usr/lib/TweakInject/",
    "exists": true,
    "readable": true,
    "enumerable": true,
    "realpath": "/private/var/.../usr/lib/TweakInject/",
    "structureMatch": true,
    "status": "confirmed",
    "evidence": { "value": "...", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-03/rh-valid" }
  },
  "dynamicLibraries": {
    "value": "<jbroot>/Library/MobileSubstrate/DynamicLibraries",
    "isSymlink": true,
    "symlinkTarget": "<jbroot>/usr/lib/TweakInject/",
    "realpath": "/private/var/.../usr/lib/TweakInject/",
    "symlinkState": "resolved",
    "status": "confirmed"
  },
  "warnings": []
}
```

字段口径：

| 字段 | 含义 / 未知口径 |
|---|---|
| `tweakInject.exists` | 目录是否真实存在（stat）；不存在 = `false` |
| `tweakInject.readable` | 是否可读（打开/读属性）；与存在性、可枚举性独立 |
| `tweakInject.enumerable` | 是否可列目录条目；不可列不阻断后续任务判定，单独记录 |
| `tweakInject.realpath` | 规范绝对路径；解析失败 = `null` |
| `tweakInject.structureMatch` | 结构旁证（含预期段/标记）；弱信号，不单独定案 |
| `dynamicLibraries.isSymlink` | lstat 是否为符号链接；非链接 = `false`（结构异常信号） |
| `dynamicLibraries.symlinkTarget` | 链接目标原始串；非链接 = `null` |
| `dynamicLibraries.symlinkState` | `resolved / broken / loop / denied / not_symlink` |
| `status` | `confirmed / partial / unverified / unknown / failed`；二手内省不得标 `confirmed` |

## 4. 目录定位规则

### 4.1 路线到目录的推导

1. 依据 S1-01 `jailbreakType` 确定路线；路线冲突沿用 S1-01 口径，不强行选边。
2. RootHide：以 S1-02 `jbroot` 为前缀拼接 `/usr/lib/TweakInject/`；`jbroot=null` 时目录不可定位，**不得**回退到 `/var/jb` 或 `/`。
3. Rootless：固定 `/var/jb/usr/lib/TweakInject/`。
4. Rootful：固定 `/usr/lib/TweakInject/`，归为不支持路线，目录记录仅作诊断，不产生 RootHide/Rootless Profile。
5. 推导结果先做词法规范化（沿用 S1-02 PATH-004 口径），再进入存在性/可读性探测。

### 4.2 目录状态分层

| 层级 | 探测 | 失败归类 |
|---|---|---|
| 存在 `exists` | stat 是否为目录 | 不存在 → `not_found` |
| 可读 `readable` | 读属性/打开权限 | 拒绝 → `access_limited` |
| 可枚举 `enumerable` | 列目录条目权限 | 拒绝 → `access_limited`，不代表目录不存在 |
| realpath | 符号链接解析规范路径 | 解析失败 → `resolve_failed` |
| 结构 `structureMatch` | 预期内部段/标记旁证 | 不符 → `structure_anomaly`（弱告警，不单独定案） |

> `readable`、`enumerable`、`realpath` 三者独立记录：realpath 成功不推出可读；可读不推出可枚举；存在不推出有权限。

### 4.3 DynamicLibraries 软链核对

- 源码要求该路径为符号链接（`injector.c:499`：`lstat` 非 `S_ISLNK` 即判损坏）。
- 记录链接目标与 realpath，并核对目标是否指向本路线 TweakInject；目标与 TweakInject 不一致 → `structure_conflict`。
- 软链状态分类见 §6。

## 5. 路线隔离红线

- RootHide 目录只由 S1-02 JBROOT 前缀推导；禁止因 `/var/jb` 存在而把 RootHide 回退到 Rootless 路径，禁止回退到根目录 `/`。
- Rootless 规则不套用于 RootHide 容器；Rootful 路径不被识别为任一越狱 Profile。
- S1-02 未定位到唯一 JBROOT（`ambiguous` / `no_candidate` / `resolve_failed`）时，S1-03 目录状态记 `unknown/failed`，保留上游原因，不自行猜测根前缀。

## 6. 异常分类

对齐计划 §2.3，目录定位异常独立归类，不直接算整轮硬失败：

| 情况 | 归类 | 记录口径 |
|---|---|---|
| 目录不存在（ENOENT / ENOTDIR） | 未发现 | `exists=false`，告警 `directory_not_found` |
| 存在但不可读/不可列（EACCES / EPERM） | 访问受限 | `readable/enumerable=false`，告警 `access_limited`，状态 `partial/unverified` |
| 软链断链（目标缺失） | 解析失败 | `symlinkState=broken`，`realpath=null`，告警 `symlink_broken` |
| 软链循环（ELOOP） | 解析失败 | `symlinkState=loop`，告警 `symlink_loop` |
| 软链目标不可达（EACCES/EPERM） | 访问受限 | `symlinkState=denied`，告警 `symlink_target_denied` |
| 路径应为软链但不是软链 | 结构异常 | `symlinkState=not_symlink`，告警 `not_a_symlink` |
| 软链目标与 TweakInject 不一致 | 结构冲突 | `structure_conflict`，两端路径均记录 |
| 无可用路线 / 上游 JBROOT 未定位 | 未定位 | 目录 `null`，告警 `directory_unresolved`，保留上游原因 |

## 7. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。

```
Tests/Fixtures/S1-03/
├── rh-valid/            # RootHide：目录存在/可读/可枚举，软链正常且目标匹配
├── rh-missing/         # TweakInject 不存在
├── rh-unreadable/      # 存在但不可读/不可列
├── rh-broken-link/     # DynamicLibraries 断链
├── rh-loop/            # 软链循环
├── rh-target-denied/   # 软链目标不可访问
├── rh-not-symlink/     # 应为软链但不是软链
├── rootless-valid/     # Rootless：/var/jb 路径有效（合成样本）
├── rootful-valid/      # Rootful：传统路径，诊断记录不产生 Profile
├── route-fallback-guard/ # RootHide 上游 jbroot 未定位 + /var/jb 存在，禁止回退
└── structure-conflict/ # 软链目标指向别处，与 TweakInject 不一致
```

每组分离 `environment.json`（定位器输入）与 `metadata.json`（测试预期）；定位器不得读取 metadata。

## 8. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| DIR-001 | 三路线各一有效样本 | 按路线推导正确目录前缀（RootHide=jbroot 前缀 / Rootless=/var/jb / Rootful=/） | 必须通过 |
| DIR-002 | 目录存在与不存在两组 | `exists` 正确区分 | 必须通过 |
| DIR-003 | 存在但不可读/不可列 | `readable`、`enumerable` 独立置否，不误标存在即有权限 | 必须通过 |
| DIR-004 | 含 `/var` 前缀路径 | realpath 输出规范路径（含 `/private/var` 映射）；失败归类解析失败 | 必须通过 |
| DIR-005 | 正常软链，目标匹配 TweakInject | `isSymlink=true`，`symlinkState=resolved`，目标一致 | 必须通过 |
| DIR-006 | 断链 | `symlinkState=broken`，`realpath=null`，告警 `symlink_broken` | 必须通过 |
| DIR-007 | 软链循环 | `symlinkState=loop`，告警 `symlink_loop` | 必须通过 |
| DIR-008 | 软链目标不可访问 | `symlinkState=denied`，告警 `symlink_target_denied` | 必须通过 |
| DIR-009 | 应为软链但非软链 | `symlinkState=not_symlink`，告警 `not_a_symlink` | 必须通过 |
| DIR-010 | RootHide jbroot 未定位 + `/var/jb` 存在 | 目录 `unresolved`，禁止回退 Rootless/Rootful 路径 | 必须通过 |
| DIR-011 | 软链目标与 TweakInject 不一致 | `structure_conflict`，两端路径均记录 | 必须通过 |
| DIR-012 | 相同目录信号重复解析 | 结果确定，路径/状态不产生随机变化（确定性） | 必须通过 |
| DIR-013 | metadata 与 environment 输入不一致 | 测试框架报错；定位器判断不受影响 | 必须通过 |

### 8.1 断言要点

- 目录路径必须由路线 + 上游 JBROOT 推导；不允许硬编码单一前缀覆盖三路线。
- `exists / readable / enumerable / realpath` 独立记录，禁止互相替代。
- 软链目标与 TweakInject 必须核对一致性；不一致进冲突，不静默接受。
- RootHide 不得跨路线回退；Rootful 记录仅诊断，不映射 Profile。

## 9. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 第三方 App 进程对 JBROOT 内 TweakInject 的可读/可列权限 | `readable/enumerable` 判定 | 待真机；离线不得标可枚举 |
| DynamicLibraries 软链真实 inode 与目标 | 软链核对 | 旧报告旁证目标指向 TweakInject，待新工程复核 |
| Rootless / Rootful 真机目录 | DIR-001 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| `pkgmirror` 路径性质（软链/镜像/是否在注入链路） | 旁路路径排除 | 待真机核实，暂列未知项 |
| 全量 TweakInject 目录列表 | 属 S1-04 范围 | 本项不枚举条目 |

## 10. 通过与失败标准

### 10.1 通过条件

- 三路线目录推导正确，前缀与路线一致；
- 存在/可读/可枚举/realpath/结构旁证分层记录，状态与告警归类准确；
- 软链五种状态（resolved / broken / loop / denied / not_symlink）可区分，目标一致性已核对；
- 上游 JBROOT 未定位时目录记未定位，不跨路线回退；
- 全程只读，不修改设备文件与软链；相同输入结果确定；报告结构稳定、证据可追溯。

### 10.2 失败情形（任一即不通过）

- RootHide 回退到 `/var/jb` 或 `/`；
- 由 realpath 成功或目录存在推出可读/可枚举；
- 软链损坏/循环/非链接被当作正常目录；
- 软链目标不一致被静默接受；
- 目录未定位仍输出猜测路径；
- 把 Rootful/Rootless 诊断结果映射为 RootHide Profile。

## 11. 设计边界

- S1-03 只定位目录与软链状态；**不做**插件条目枚举（S1-04）、配对（S1-05）、plist/Filter 解析（S1-06）、来源识别（S1-07）。
- 目录定位成功 ≠ 条目可枚举 ≠ 配对正确 ≠ Adapter 兼容；CLI 目录结果不作为 GUI 进程权限证据。
- 本项离线夹具为合成样本；Rootless/Rootful 无真机背书，不把 RootHide 结论推广到其他路线。
- S1-03 离线测试须单独授权后再创建夹具与代码；在此之前不扩展 S1-04，不创建正式工程。
