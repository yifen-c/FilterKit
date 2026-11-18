# S1-04 正式验收记录 — Plugin Enumeration

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-04 插件文件枚举
- 子规格：[Spec/Stage-1/S1-04-Plugin-Enumeration.md](../../Spec/Stage-1/S1-04-Plugin-Enumeration.md)
- 测试报告：[S1-04-report.json](./S1-04-report.json)

> **本结论仅代表离线合成夹具上的文件发现与元数据记录逻辑通过；不代表真机目录可枚举、文件可读、存在有效插件，也不代表 GUI 进程有权限。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-04/` 下 `enumerator.js`、`run.js` 为**离线测试 harness**，非 App 运行时；枚举逻辑后续随工程落地迁移至 Core/Adapters。
- 虚拟 FS：目录条目与元数据以注入信号模拟，harness 不访问真实文件系统；全程只读，未修改任何设备文件、软链、plist、dpkg 或规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | `.dylib` 枚举为注入候选 | §4.1、ENUM-001 | 通过：`rh-mixed` 2 个 dylib、`rh-orphan-dylib` 1 个 dylib 列入 `items` |
| 2 | `.plist` 独立枚举 | §4.1、ENUM-002 | 通过：`rh-mixed` 1 个 plist、`rh-orphan-plist` 1 个 plist 独立列出，未与 dylib 合并 |
| 3 | 文件类型区分 | §4.1、ENUM-003 | 通过：目录/软链/dylib/plist/其他分类准确；`rh-other-extension` 3 个未知扩展名归 `other` |
| 4 | 文件名原样保留 | §3、ENUM-004 | 通过：未改写大小写、空格或扩展名；`Bad.DYLIB` 保留原始名 |
| 5 | 隐藏文件保留并标记 | §4.1、ENUM-005 | 通过：`.hidden.dylib`、`.plist` 列入清单且 `hidden=true`，未被排除 |
| 6 | 非递归扫描 | §4.1、ENUM-006 | 通过：`rh-dir-entry` 嵌套 `Plugins/Inside.dylib` 未进入清单，`recursive=false`，`nestedLeakCount=0` |
| 7 | 软链身份独立记录 | §4.2、ENUM-007 | 通过：`Link.dylib` 记 `symlink` 自身与目标；断链 `Broken.dylib` 记 `symlinkState=broken`，目标未重复入清单 |
| 8 | 访问受限与不存在区分 | §6、ENUM-008 | 通过：`rh-bad-permission` 条目 `access_denied`；`rh-enum-failed` 目录级 `enumeration_failed`；未混为 `not_found` |
| 9 | 大小等元数据记录 | §4.3、ENUM-009 | 通过：可获取条目记录 `size`；`rh-metadata-missing` `size/realpath=null` 记 `metadata_unavailable` |
| 10 | 哈希失败独立记录 | §4.3、ENUM-010 | 通过：成功条目带 `hash`；失败条目 `hash=null` 且不阻断枚举 |
| 11 | 同名条目按完整路径保留 | §4.1、ENUM-011 | 通过：合成两组同名 `Same.dylib`，路径不同分别保留，未按基名合并 |
| 12 | 单条目异常不中断整轮 | §6、ENUM-012 | 通过：`rh-bad-permission` 受限条目在列，其余条目正常入清单，状态 `partial` |
| 13 | 路线隔离，只用 S1-03 目录 | §5、ENUM-013 | 通过：`route-guard` 上游目录未定位 → `unresolved`、空清单，未回退 `/var/jb`；`rootless-mixed` 仅用于 Rootless 路线 |
| 14 | 相同输入结果确定 | ENUM-014 | 通过：重复枚举清单、顺序、计数深比较一致 |
| 15 | 前序回归保持通过 | ENUM-015 | 通过：`S1-01` 15/15、`S1-02` 18/18、`S1-03` 15/15 全部 passed |
| 16 | 输入与预期严格分离 | §2 | 通过：枚举器仅接收 `environment.json`，不读取 `metadata.json`，无文件系统读取 |
| 17 | 证据标签全部为 fixture | §10 | 通过：23 例 `evidenceType=fixture`，无一条标真机 |
| 18 | 真机目录可枚举/条目完整性背书 | §9 | **尚未进行**，待真机只读复核 |

## 3. 逐例结果

| 用例 | 来源 | 状态 | 计数（dylib/plist/dir/sym/other） | 条目数 | 告警 |
|---|---|---|---|---|---|
| ENUM-001 | fixture:rh-mixed | enumerated | 2/1/0/0/1 | 4 | — |
| ENUM-001 | fixture:rh-orphan-dylib | enumerated | 1/0/0/0/0 | 1 | — |
| ENUM-002 | fixture:rh-mixed | enumerated | 2/1/0/0/1 | 4 | — |
| ENUM-002 | fixture:rh-orphan-plist | enumerated | 0/1/0/0/0 | 1 | — |
| ENUM-003 | fixture:rh-dir-entry | enumerated | 0/0/1/0/0 | 1 | — |
| ENUM-003 | fixture:rh-other-extension | enumerated | 0/0/0/0/3 | 3 | — |
| ENUM-004 | fixture:rh-mixed | enumerated | 2/1/0/0/1 | 4 | — |
| ENUM-005 | fixture:rh-hidden-file | enumerated | 1/0/0/0/1 | 2 | — |
| ENUM-006 | fixture:rh-dir-entry | enumerated | 0/0/1/0/0 | 1 | 嵌套条目已排除 |
| ENUM-007 | fixture:rh-symlink-valid | enumerated | 1/0/0/1/0 | 2 | — |
| ENUM-007 | fixture:rh-symlink-broken | enumerated | 0/0/0/1/0 | 1 | 软链断链 |
| ENUM-008 | fixture:rh-bad-permission | partial | 2/0/0/0/0 | 2 | partial_enumeration |
| ENUM-008 | fixture:rh-enum-failed | enumeration_failed | 0/0/0/0/0 | 0 | enumeration_failed |
| ENUM-009 | fixture:rh-mixed | enumerated | 2/1/0/0/1 | 4 | — |
| ENUM-009 | fixture:rh-metadata-missing | partial | 1/0/0/0/0 | 1 | partial_enumeration |
| ENUM-010 | fixture:rh-mixed | enumerated | 2/1/0/0/1 | 4 | — |
| ENUM-010 | fixture:rh-metadata-missing | partial | 1/0/0/0/0 | 1 | partial_enumeration |
| ENUM-011 | synthetic:path-identity | — | 同名两条目路径不同，均保留 | 2 | — |
| ENUM-012 | fixture:rh-bad-permission | partial | 2/0/0/0/0 | 2 | partial_enumeration |
| ENUM-013 | fixture:rootless-mixed | enumerated | 1/1/0/0/0 | 2 | — |
| ENUM-013 | fixture:route-guard | unresolved | 0/0/0/0/0 | 0 | directory_unresolved |
| ENUM-013 | synthetic:route-isolation | unresolved | 未出现 /var/jb 回退路径 | 0 | — |
| ENUM-014 | synthetic:determinism | enumerated | 重复枚举一致 | 4 | — |
| ENUM-015 | 前序回归 | — | S1-01/S1-02/S1-03 全部 passed | — | — |

## 4. 覆盖核对

- **路线**：`roothide / rootless` 两组样本；Rootful 仅诊断口径，本项未建样本。
- **分类**：dylib（注入候选）与 plist（配对输入）独立计数；目录、软链、其他进入 `unknownItems`。
- **非递归**：只列 S1-03 目录单层；子目录与软链目标内文件不重复发现。
- **异常分层**：目录级 `enumeration_failed / unresolved / partial`；条目级 `access_denied / metadata_unavailable / read_failed / not_found`；访问失败不记为不存在。
- **状态边界**：本项未产出 `installed/configured`；`loaded` 一律 `unknown`，未由文件在位推断。

## 5. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 第三方 App 进程对 TweakInject 的列目录权限 | `enumeration.status` | 待真机；离线不得标可枚举 |
| 真机全量 dylib/plist 条目与命名 | 清单完整性 | 旧报告枚举不全，待真机全量采集 |
| 真机软链条目分布与目标 | 软链分类 | 待真机复核 |
| Rootless 真机目录条目 | ENUM 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| 条目真实大小/哈希可取性 | 元数据/哈希字段 | 待真机；离线样本为合成信号 |
| `pkgmirror` 路径性质与条目归属 | 旁路目录排除 | 待真机核实，暂列未知项 |

## 6. 归档与门禁

- 归档产物：十三组夹具（`Tests/Fixtures/S1-04/`）、`Tests/S1-04/enumerator.js`、`Tests/S1-04/run.js`、`S1-04-report.json`、本验收记录。
- 回归：S1-01 15/15、S1-02 18/18、S1-03 15/15 保持通过。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless 合成通过 ≠ 真机兼容。
- 门禁：S1-04 离线验收归档完成；**S1-05（插件配对）尚未展开**，须经授权后再进入，不创建正式 App 工程。
