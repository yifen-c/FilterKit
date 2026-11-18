# S1-01 正式验收记录 — Environment Detection

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-01 环境识别
- 子规格：[Spec/Stage-1/S1-01-Environment-Detection.md](../../Spec/Stage-1/S1-01-Environment-Detection.md)
- 测试报告：[S1-01-report.json](./S1-01-report.json)

> **本结论仅代表离线合成夹具上的识别逻辑通过；不代表 RootHide 真机环境识别已通过，不代表 Rootless 真机兼容。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-01/` 下 `detector.js`、`run.js` 为**离线测试 harness**，非 App 运行时；识别逻辑后续随工程落地迁移至 Core/Adapters。
- 全程只读：harness 仅读取夹具 JSON、写出本目录报告；未修改任何 plist/Bundles、未增删移设备文件、未碰 dpkg、未改软链、未注入、无常驻 Daemon。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | ENV-001 ~ 015 全部通过 | 报告 `summary.passed/total` | **15/15 通过** |
| 2 | 六组环境样本齐备 | §6.2 / 夹具目录 | 通过（roothide / rootless / rootful / unknown / incomplete / conflicting） |
| 3 | 输入与预期严格隔离 | §2.1 | 通过：识别器仅接收 `environment.json`，不读取 `metadata.json`；harness 源码无 metadata / 文件系统读取 |
| 4 | 版本五态全覆盖 | §3.1 矩阵 | 通过：`parsed / not_installed / unreadable / unparsable / conflicted` |
| 5 | 两类冲突正确识别 | §2.4.6 | 通过：`route_signal_conflict`、`impl_version_conflict`，未强行选边、未出 Profile |
| 6 | 确定性（重复输入结果一致） | ENV-013 | 通过 |
| 7 | 只读约束 | 计划 §2.1 | 通过：离线运行，无设备写入 |
| 8 | 证据标签全部为 fixture | §4.3 | 通过：15 例 `evidenceType=fixture`，无一条标真机 |
| 9 | 缺失信息独立降级，不拖垮整轮 | ENV-006 / 010 / 014 | 通过：已确认字段保留，缺失/不可解析字段显式 null/unknown |
| 10 | 格式错误结构化捕获，不崩溃 | ENV-011 | 通过 |
| 11 | metadata/environment ID 不一致由框架报错，不影响识别器 | ENV-015 | 通过 |
| 12 | RootHide 真机验证 | §8 待真机缺口 | **尚未进行**（待真机只读复核） |

## 3. 逐例结果

| 用例 | 来源 | jailbreakType | 版本态 | Adapter Profile | outcome | 告警 |
|---|---|---|---|---|---|---|
| ENV-001 | fixture:roothide | roothide | parsed | RootHideProfile_1_2_3 | profile_candidate | — |
| ENV-002 | fixture:rootless | rootless | parsed | RootlessProfile_upstream | profile_candidate | — |
| ENV-003 | fixture:rootful | rootful | not_installed | — | unsupported_profile | unsupported_rootful |
| ENV-004 | fixture:unknown | unknown | not_installed | — | unknown | no_jailbreak_signals |
| ENV-005 | fixture:unknown | unknown | not_installed | — | unknown | no_jailbreak_signals |
| ENV-006 | fixture:incomplete | roothide | unparsable | — | partial | bootstrap_missing, implementation_missing, version_unparsable |
| ENV-007 | fixture:unknown | unknown | not_installed | — | unknown | no_jailbreak_signals |
| ENV-008 | fixture:conflicting | unknown | conflicted | — | conflict_no_profile | route_signal_conflict, impl_version_conflict |
| ENV-009 | fixture:conflicting | unknown | conflicted | — | conflict_no_profile | route_signal_conflict, impl_version_conflict |
| ENV-010 | fixture:incomplete | roothide | unparsable | — | partial | bootstrap_missing, implementation_missing, version_unparsable |
| ENV-011 | synthetic:malformed-input | unknown | not_installed | — | unknown | 结构化捕获格式错误，识别器未崩溃 |
| ENV-012 | synthetic:version-unreadable | roothide | unreadable | — | partial | access_limited |
| ENV-013 | synthetic:determinism | roothide | parsed | RootHideProfile_1_2_3 | profile_candidate | 重复输入结果一致 |
| ENV-014 | fixture:incomplete | roothide | unparsable | — | partial | bootstrap_missing, implementation_missing, version_unparsable |
| ENV-015 | synthetic:id-mismatch | roothide | parsed | RootHideProfile_1_2_3 | profile_candidate | 框架识别 fixtureId 不一致，识别判断不受影响 |

## 4. 覆盖核对

- **版本五态**：`parsed`（ENV-001/002/013/015）、`not_installed`（ENV-003/004/005/007/011）、`unreadable`（ENV-012）、`unparsable`（ENV-006/010/014）、`conflicted`（ENV-008/009）。
- **Profile 候选**：RootHide 候选（ENV-001）、Rootless 候选（ENV-002，合成样本）；**Unknown / 不支持 / 冲突 / 部分**四类无 Profile 情形均覆盖。
- **冲突**：路线信号冲突 + 实现-版本冲突各至少一例；冲突态不自动降级到 RootHide/Rootless Profile。

## 5. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| `.version-roothide` 文件原文 | Bootstrap / 版本精确判定 | 未读取，离线以夹具信号旁证 |
| ElleKit 实现标识真机取法 | `ellekitImplementation` 判定 | 离线先定口径，真机复核 |
| Bootstrap 类型/版本来源 | `bootstrap` 字段 | 真机只读探测确认 |
| RootHide 真机环境识别背书 | S1-01 真机结论 | 待真机 shell 只读复核 |
| Rootless / Rootful 真机 | ENV-002 / ENV-003 真机背书 | 当前仅夹具，`[Rootless 真机待验证]` |

## 6. 归档与门禁

- 归档产物：六组夹具（`Tests/Fixtures/S1-01/`）、`Tests/S1-01/detector.js`、`Tests/S1-01/run.js`、`S1-01-report.json`、本验收记录。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless 合成通过 ≠ Rootless 真机兼容。
- 门禁：S1-01 离线验收归档完成；**S1-02（JBROOT 路径定位）尚未展开**，须经授权后再进入，不提前创建正式 App 工程。
