# S1-03 正式验收记录 — ElleKit Directory Resolution

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-03 ElleKit 目录定位
- 子规格：[Spec/Stage-1/S1-03-ElleKit-Directory-Resolution.md](../../Spec/Stage-1/S1-03-ElleKit-Directory-Resolution.md)
- 测试报告：[S1-03-report.json](./S1-03-report.json)

> **本结论仅代表离线合成夹具上的目录定位与软链核对逻辑通过；不代表 RootHide 真机目录可读/可枚举、软链真实完好，也不代表 GUI 进程有权限。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-03/` 下 `resolver.js`、`run.js` 为**离线测试 harness**，非 App 运行时；目录定位逻辑后续随工程落地迁移至 Core/Adapters。
- 虚拟 FS：目录与软链以注入信号模拟，harness 不访问真实文件系统；全程只读，未修改任何设备文件、软链、plist、dpkg 或规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | 三路线目录前缀推导正确 | §4.1、DIR-001 | 通过：RootHide=`<jbroot>/usr/lib/TweakInject/`，Rootless=`/var/jb/usr/lib/TweakInject/`，Rootful=`/usr/lib/TweakInject/` |
| 2 | 存在性正确区分 | §4.2、DIR-002 | 通过：`rh-missing` `exists=false`，状态 `not_found`；`rh-valid` `exists=true` |
| 3 | 可读/可枚举独立记录 | §4.2、DIR-003 | 通过：`rh-unreadable` `readable=false`、`enumerable=false`，未由存在或 realpath 推出可枚举 |
| 4 | realpath 规范路径 | §4.2、DIR-004 | 通过：`rh-valid` realpath 输出 `/private/var/...` 规范路径 |
| 5 | 正常软链目标匹配 | §4.3、DIR-005 | 通过：`rh-valid` `resolved`，目标与本路线 TweakInject 一致，`targetMatch=true` |
| 6 | 断链归类 | §6、DIR-006 | 通过：`rh-broken-link` `symlinkState=broken`，`realpath=null`，告警 `symlink_broken` |
| 7 | 循环链接归类 | §6、DIR-007 | 通过：`rh-loop` `symlinkState=loop`，告警 `symlink_loop` |
| 8 | 目标受限不误判断链 | §6、DIR-008 | 通过：`rh-target-denied` `symlinkState=denied`，告警 `symlink_target_denied`，未归 `broken` |
| 9 | 非软链结构异常 | §6、DIR-009 | 通过：`rh-not-symlink` `symlinkState=not_symlink`，告警 `not_a_symlink` |
| 10 | RootHide 禁止回退 | §5、DIR-010 | 通过：`route-fallback-guard` 上游 `jbroot=null`，目录 `unresolved`、`tiPath=null`，未选 `/var/jb` 或 `/`，`fallbackLeakCount=0` |
| 11 | 软链目标不一致记冲突 | §4.3/§6、DIR-011 | 通过：`structure-conflict` `resolved` 但 `targetMatch=false`，`outcome=structure_conflict`，两端路径记录 |
| 12 | 相同输入结果确定 | DIR-012 | 通过：重复解析结果深比较一致 |
| 13 | 格式/ID 异常由框架处理 | DIR-013 | 通过：fixtureId 不一致被框架识别，解析器判断不受影响 |
| 14 | 输入与预期严格分离 | §2 | 通过：解析器仅接收 `environment.json`，不读取 `metadata.json`，无文件系统读取 |
| 15 | 证据标签全部为 fixture | §10 | 通过：15 例 `evidenceType=fixture`，无一条标真机 |
| 16 | 真机目录可读/可列、软链 inode 等背书 | §9 | **尚未进行**，待真机只读复核 |

## 3. 逐例结果

| 用例 | 来源 | outcome | TI 状态 | 软链状态 | 目标匹配 | 告警 |
|---|---|---|---|---|---|---|
| DIR-001 | fixture:rh-valid | resolved | confirmed | resolved | true | — |
| DIR-001 | fixture:rootless-valid | resolved | confirmed | resolved | true | — |
| DIR-001 | fixture:rootful-valid | rootful_diagnostic | confirmed | resolved | true | rootful_route_not_profile |
| DIR-002 | fixture:rh-missing | not_found | not_found | not_symlink | false | directory_not_found |
| DIR-003 | fixture:rh-unreadable | partial | partial | resolved | true | access_limited |
| DIR-004 | fixture:rh-valid | resolved | confirmed | resolved | true | — |
| DIR-005 | fixture:rh-valid | resolved | confirmed | resolved | true | — |
| DIR-006 | fixture:rh-broken-link | partial | confirmed | broken | false | symlink_broken |
| DIR-007 | fixture:rh-loop | partial | confirmed | loop | false | symlink_loop |
| DIR-008 | fixture:rh-target-denied | partial | confirmed | denied | false | symlink_target_denied |
| DIR-009 | fixture:rh-not-symlink | partial | confirmed | not_symlink | false | not_a_symlink |
| DIR-010 | fixture:route-fallback-guard | unresolved | unresolved | not_symlink | false | directory_unresolved |
| DIR-011 | fixture:structure-conflict | structure_conflict | confirmed | resolved | false | structure_conflict |
| DIR-012 | synthetic:determinism | resolved | confirmed | resolved | true | 重复结果一致 |
| DIR-013 | synthetic:id-mismatch | resolved | confirmed | resolved | true | 框架识别 ID 不一致 |

## 4. 覆盖核对

- **路线**：`roothide / rootless / rootful` 三路线均有样本，`missingRoutes=[]`。
- **状态分层**：`exists / readable / enumerable / realpath / structureMatch` 独立记录；realpath 成功不推出可读，存在不推出可枚举。
- **软链五态**：`resolved / broken / loop / denied / not_symlink` 全部可区分；目标一致性已与本路线 TweakInject 核对。
- **异常分类**：未发现、访问受限、解析失败（断链/循环）、结构异常（非软链）、结构冲突（目标不一致）、未定位、Rootful 诊断。
- **路线隔离**：RootHide 目录只由上游 JBROOT 前缀推导；`/var/jb` 陷阱信号未被选中；Rootful 仅诊断，不映射 Profile。

## 5. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 第三方 App 进程对 JBROOT 内 TweakInject 的可读/可列权限 | `readable/enumerable` 判定 | 待真机；离线不得标可枚举 |
| DynamicLibraries 软链真实 inode 与目标 | 软链核对 | 旧报告旁证目标指向 TweakInject，待新工程复核 |
| Rootless / Rootful 真机目录 | DIR-001 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| `pkgmirror` 路径性质（软链/镜像/是否在注入链路） | 旁路路径排除 | 待真机核实，暂列未知项 |
| 全量 TweakInject 目录列表 | 属 S1-04 范围 | 本项不枚举条目 |

## 6. 归档与门禁

- 归档产物：十一组夹具（`Tests/Fixtures/S1-03/`）、`Tests/S1-03/resolver.js`、`Tests/S1-03/run.js`、`S1-03-report.json`、本验收记录。
- 回归：S1-01 保持 15/15 通过，S1-02 保持 18/18 通过。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless/Rootful 合成通过 ≠ 真机兼容。
- 门禁：S1-03 离线验收归档完成；**S1-04（插件枚举）尚未展开**，须经授权后再进入，不创建正式 App 工程。
