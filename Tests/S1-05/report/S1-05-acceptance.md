# S1-05 正式验收记录 — Plugin Pairing

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-05 插件配对
- 子规格：[Spec/Stage-1/S1-05-Plugin-Pairing.md](../../Spec/Stage-1/S1-05-Plugin-Pairing.md)
- 测试报告：[S1-05-report.json](./S1-05-report.json)

> **本结论仅代表离线合成清单上的文件名配对逻辑通过；不代表真机存在有效插件、插件已安装/已配置/已加载，也不代表 GUI 进程有权限。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-05/` 下 `pairing.js`、`run.js` 为**离线测试 harness**，非 App 运行时；配对逻辑后续随工程落地迁移至 Core/Adapters。
- 配对输入为 S1-04 清单快照（信号注入），harness 不访问真实文件系统；全程只读，未修改任何设备文件、软链、plist、dpkg 或规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | 同名配对建立 | §4.1、PAIR-001 | 通过：`Example.dylib` ↔ `Example.plist` 记 `paired` |
| 2 | dylib 缺 plist 单独记录 | §4.1、PAIR-002 | 通过：`Unmatched.dylib` 记 `missing_plist`，未造 plist |
| 3 | plist 缺 dylib 单独记录 | §4.1、PAIR-003 | 通过：`Orphan.plist` 记 `orphan_plist`，`reason=missing_dylib` |
| 4 | 多组配对正确建立 | §4.1、PAIR-004 | 通过：`pair-multi` 三对分别配对，计数 3 |
| 5 | 大小写敏感 | §4.1、PAIR-005 | 通过：`Example.dylib` 与 `example.plist` 不配对，分记 `missing_plist`/`orphan_plist` |
| 6 | 跨目录同名不合并 | §4.1、PAIR-006 | 通过：外目录 `Shared.*` 陷阱条目被排除，仅本目录一对配对 |
| 7 | 隐藏文件按规则配对 | §4.2、PAIR-007 | 通过：`.hidden.dylib` ↔ `.hidden.plist` 配对，保留隐藏标记 |
| 8 | 软链参与配对并记录身份 | §4.2、PAIR-008 | 通过：`Link.dylib` 软链身份保留，配对成功 |
| 9 | 非标准扩展名排除 | §4.2、PAIR-009 | 通过：`.txt/.deb/.DYLIB` 不进入配对候选 |
| 10 | 多候选记歧义不选边 | §4.3、PAIR-010 | 通过：同名重复 plist 候选记 `ambiguous`，列出路径，未任选 |
| 11 | 受限条目进 uncertain | §4.3、PAIR-011 | 通过：`Locked.dylib` 访问受限记 `uncertain`，对应 plist 留置未判孤儿 |
| 12 | 只用 S1-04 清单，路线隔离 | §5、PAIR-012 | 通过：上游清单未定位 → `unresolved`、空报告，未回退 `/var/jb` |
| 13 | 相同清单结果确定 | PAIR-013 | 通过：重复配对关系、归类、计数深比较一致 |
| 14 | 前序回归保持通过 | PAIR-014 | 通过：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23 全部 passed |
| 15 | 五类归类互斥 | §3、§10.1 | 通过：`mutualLeakCount=0`，每条目仅归一类 |
| 16 | 输入与预期严格分离 | §2 | 通过：配对器仅接收 `environment.json`，不读取 `metadata.json` |
| 17 | 证据标签全部为 fixture | §10 | 通过：15 例 `evidenceType=fixture`，无一条标真机 |
| 18 | 真机命名/软链/受限场景背书 | §9 | **尚未进行**，待真机只读复核 |

## 3. 逐例结果

| 用例 | 来源 | 状态 | 计数（paired/missing/orphan/ambiguous/uncertain） | 告警 |
|---|---|---|---|---|
| PAIR-001 | fixture:pair-valid | enumerated | 1/0/0/0/0 | — |
| PAIR-002 | fixture:pair-missing-plist | enumerated | 0/1/0/0/0 | — |
| PAIR-003 | fixture:pair-orphan-plist | enumerated | 0/0/1/0/0 | — |
| PAIR-004 | fixture:pair-multi | enumerated | 3/0/0/0/0 | — |
| PAIR-005 | fixture:pair-case-mismatch | enumerated | 0/1/1/0/0 | — |
| PAIR-006 | fixture:pair-cross-path | enumerated | 1/0/0/0/0 | 外目录条目已排除 |
| PAIR-007 | fixture:pair-hidden | enumerated | 1/0/0/0/0 | — |
| PAIR-008 | fixture:pair-symlink | enumerated | 1/0/0/0/0 | 软链身份保留 |
| PAIR-009 | fixture:pair-other-ext | enumerated | 0/0/0/0/0 | 其他扩展名排除 |
| PAIR-010 | fixture:pair-duplicate | enumerated | 0/0/0/1/0 | 多候选歧义 |
| PAIR-011 | fixture:pair-access-denied | partial | 0/0/0/0/1 | partial_pairing |
| PAIR-012 | fixture:route-guard | unresolved | 0/0/0/0/0 | inventory_unresolved |
| PAIR-013 | fixture:pair-determinism | enumerated | 1/1/0/0/0 | — |
| PAIR-013 | synthetic:determinism | enumerated | 重复配对一致 | — |
| PAIR-006 | synthetic:route-isolation | unresolved | 未出现 /var/jb 回退路径 | — |
| PAIR-014 | 前序回归 | — | S1-01/S1-02/S1-03/S1-04 全部 passed | — |

## 4. 覆盖核对

- **配对方向**：dylib 驱动；有 plist → `paired`，无 plist → `missing_plist`；无 dylib 的 plist → `orphan_plist`。
- **匹配规则**：同目录、精确文件名、大小写敏感；基名仅用于配对，完整路径为身份键。
- **互斥归类**：`paired / missing_plist / orphan_plist / ambiguous / uncertain` 计数与条目清单一致，无重复归属。
- **不确定保留**：访问/元数据受限条目进 `uncertain`，留置对应 plist，不判缺失或孤儿。
- **状态边界**：未读取 plist 内容，未产出 Filter/来源结论；`loaded` 一律 `unknown`。

## 5. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机 dylib/plist 实际命名与派生一致性 | 配对命中率 | 待真机全量清单复核 |
| 软链 dylib/plist 在真机的配对表现 | 软链归类 | 待真机观察 |
| 同名重复/跨路径重复候选真实分布 | `ambiguous` 场景 | 待真机，离线为合成样本 |
| 受限条目在真机的可访问性 | `uncertain` 归类 | 待真机只读探测 |
| Rootless 真机配对 | 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |

## 6. 归档与门禁

- 归档产物：十三组夹具（`Tests/Fixtures/S1-05/`）、`Tests/S1-05/pairing.js`、`Tests/S1-05/run.js`、`S1-05-report.json`、本验收记录。
- 回归：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23 保持通过。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless 合成通过 ≠ 真机兼容。
- 门禁：S1-05 离线验收归档完成；**S1-06（plist/Filter 解析）尚未展开**，须经授权后再进入，不创建正式 App 工程。
