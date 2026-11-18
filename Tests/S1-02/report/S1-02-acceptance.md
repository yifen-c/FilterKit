# S1-02 正式验收记录 — JBROOT Path Resolution

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-02 JBROOT 路径定位
- 子规格：[Spec/Stage-1/S1-02-JBROOT-Path-Resolution.md](../../Spec/Stage-1/S1-02-JBROOT-Path-Resolution.md)
- 测试报告：[S1-02-report.json](./S1-02-report.json)

> **本结论仅代表离线合成夹具上的路径定位逻辑通过；不代表 RootHide 真机 JBROOT 可定位、目录可读或 GUI 进程有权限。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-02/` 下 `resolver.js`、`run.js` 为**离线测试 harness**，非 App 运行时；解析逻辑后续随工程落地迁移至 Core/Adapters。
- 全程只读：harness 仅读取夹具 JSON、写出本目录报告；未访问真实文件系统，未修改任何设备文件、软链、dpkg 或规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | 五种候选来源均有覆盖 | §4 来源 A~E | 通过：`api / scan / bootstrap / rootless / rootful` 全覆盖，无缺失 |
| 2 | 非法容器名不被认定为 JBROOT | §5、PATH-003 | 通过：`rh-badname` 校验位非法，`jbroot=null`、`jbrand=null` |
| 3 | 不存在与不可访问明确区分 | §9、PATH-002/007 | 通过：`rh-name-only` 归 `candidate_missing`；`rh-unreadable` 归 `access_limited` |
| 4 | 不能仅凭目录名称判定 | §5 分层 | 通过：命名合法仍需存在性 + 结构旁证；`rh-name-only` 存在性失败被拒 |
| 5 | realpath 正确处理符号链接 | §7、PATH-005 | 通过：`realpath-privatevar` 输出 `/private/var/...`；`rh-broken-link` 断链归 `symlink_resolve_failed` |
| 6 | 可读性独立于 realpath | §7、§13.1 | 通过：`rh-unreadable` realpath 存在但 `readable=false`，状态 `partial`，未由 realpath 推出可读 |
| 7 | 多候选无法裁决返回 ambiguous | §8、PATH-006 | 通过：`rh-multiple` 两有效候选，`ambiguous=true`、`jbroot=null`，不盲目选边 |
| 8 | jbrand 不猜测、不补零 | §10、PATH-008 | 通过：合法输出 16 位大写 hex；非法/未定位输出 `null` |
| 9 | 路线隔离，不跨路线套用规则 | §13.1、PATH-010 | 通过：`/var/jb`、`/` 仅记为跨路线候选，`crossRouteLeakCount=0`，未写入 RootHide `jbroot` |
| 10 | 相同输入结果确定 | PATH-011 | 通过：重复解析结果深比较一致 |
| 11 | 格式/ID 异常由框架处理 | PATH-012 | 通过：fixtureId 不一致被框架识别，解析器判断不受影响 |
| 12 | 输入与预期严格分离 | §2.1 | 通过：解析器仅接收 `environment.json`，不读取 `metadata.json`，无文件系统读取 |
| 13 | 证据标签全部为 fixture | §11 | 通过：18 例 `evidenceType=fixture`，无一条标真机 |
| 14 | 真机进程内 `jbroot()` 等背书 | §14 | **尚未进行**，待真机只读复核 |

## 3. 逐例结果

| 用例 | 来源 | outcome | jbroot | jbrand | 选中来源 | 告警 |
|---|---|---|---|---|---|---|
| PATH-001 | fixture:rh-valid | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | — |
| PATH-002 | fixture:rh-valid | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | — |
| PATH-002 | fixture:rh-name-only | no_candidate | — | — | — | candidate_missing |
| PATH-003 | fixture:rh-valid | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | — |
| PATH-003 | fixture:rh-badname | no_candidate | — | — | — | invalid_container_name |
| PATH-004 | synthetic:lexical-normalize | — | 词法规范化结果正确 | — | — | — |
| PATH-005 | fixture:realpath-privatevar | resolved | 容器路径 | D87B48653D7178BA | bootstrap | — |
| PATH-005 | fixture:rh-broken-link | resolve_failed | — | — | — | symlink_resolve_failed |
| PATH-006 | fixture:rh-multiple | ambiguous | — | — | — | multiple_candidates |
| PATH-007 | fixture:rh-unreadable | partial | 容器路径 | 9C414BB7D5DCECC4 | scan | access_limited |
| PATH-007 | fixture:rh-broken-link | resolve_failed | — | — | — | symlink_resolve_failed |
| PATH-007 | fixture:no-candidate | no_candidate | — | — | — | no_jbroot_candidate |
| PATH-008 | fixture:rh-valid | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | — |
| PATH-009 | fixture:rh-valid | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | — |
| PATH-010 | fixture:rootless-varjb | cross_route_only | — | — | — | rootless_route_not_jbroot |
| PATH-010 | fixture:rootful-root | cross_route_only | — | — | — | rootful_route_not_jbroot |
| PATH-011 | synthetic:determinism | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | 重复结果一致 |
| PATH-012 | synthetic:id-mismatch | resolved | 容器路径 | 9C414BB7D5DCECC4 | scan | 框架识别 ID 不一致 |

## 4. 覆盖核对

- **候选来源**：A 进程内 API（`api`）、B 父目录扫描（`scan`）、C 引导库旁证（`bootstrap`）、D rootless（`rootless`）、E rootful（`rootful`）。
- **裁决分层**：发现候选 → 校验（命名/存在/结构/可读/realpath）→ 裁决选择；三层在 `resolver.js` 中分离。
- **异常分类**：未发现（`candidate_missing` / `no_jbroot_candidate`）、访问受限（`access_limited`）、解析失败（`symlink_resolve_failed`）、候选冲突（`ambiguous`）、跨路线（`cross_route_only`）。
- **路线隔离**：RootHide 容器规则不套用于 `/var/jb` 与 `/`；跨路线候选不产生 `jbroot`。

## 5. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 第三方 App 进程内 `jbroot()` / 全局 JBROOT 可取性 | 来源 A 可行性 | 旧报告有运行时旁证，新工程需只读复核 |
| 沙盒遍历 `/var/containers/Bundle/Application` 权限 | 来源 B 可行性 | 待真机只读探测 |
| JBROOT 目录可读/可列权限 | `readable` 判定 | 待真机；离线不得标可读 |
| 真机多容器并存 | 冲突裁决场景 | 待真机观察 |
| jbrand 跨重装/恢复/Bootstrap 切换稳定性与语义 | jbrand 解释 | 待源码 + 真机确认 |
| `/var` ↔ `/private/var` realpath 在目标 iOS 稳定性 | realpath 口径 | 旧报告旁证，待复核 |
| `pkgmirror` 路径性质 | 旁路路径排除 | 待真机，暂列未知项（跨 S1-03/S1-04） |

## 6. 归档与门禁

- 归档产物：十组夹具（`Tests/Fixtures/S1-02/`）、`Tests/S1-02/resolver.js`、`Tests/S1-02/run.js`、`S1-02-report.json`、本验收记录。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless/Rootful 合成通过 ≠ 真机兼容。
- 门禁：S1-02 离线验收归档完成；**S1-03（ElleKit 目录定位）尚未展开**，须经授权后再进入，不创建正式 App 工程。
