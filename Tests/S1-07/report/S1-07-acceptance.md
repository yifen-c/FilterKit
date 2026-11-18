# S1-07 正式验收记录 — Plugin Source Identification（插件来源识别）

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-07 插件来源识别
- 子规格：[Spec/Stage-1/S1-07-Plugin-Source-Identification.md](../../Spec/Stage-1/S1-07-Plugin-Source-Identification.md)
- 测试报告：[S1-07-report.json](./S1-07-report.json)

> **本结论仅代表离线合成 dpkg 清单/标记信号上的归属识别逻辑通过；不代表真机归属已核实，不代表 FilterKit 已获管理授权，也不代表插件已配置生效或已加载。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-07/` 下 `resolver.js`、`run.js` 为**离线测试 harness**，非 App 运行时；归属逻辑后续随工程落地迁移至 Core/Adapters。
- 输入为上游 Parsed Plugin Model 快照 + dpkg `status`/`.list` 信号 + 管理标记信号（虚拟注入）；harness 不访问真实文件系统，不读/写 dpkg 数据库，不修改任何插件文件、软链或规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | dpkg 清单精确路径命中 | §4.1、OWN-001 | 通过：单包 `.list` 精确命中 dylib+plist → `owned_package`，记录包名/版本/架构/清单路径 |
| 2 | 包状态计入归属 | §1.1、OWN-001 | 通过：仅 `install ok installed` 计入；`install ok unpacked` 包清单命中不计入归属 |
| 3 | 多包分别命中 | §4.2、OWN-002 | 通过：两个包各自命中自己的 dylib/plist，归属分别正确 |
| 4 | FilterKit 自管标记 | §4.1、OWN-003 | 通过：无 dpkg 归属 + 有效自管标记 → `filterkit_managed`，`writablePolicy=managed` |
| 5 | 用户导入标记 | §4.1、OWN-004 | 通过：无 dpkg 归属 + 有效导入标记 → `manual_import`，默认 `read_only`，不自动授权 |
| 6 | 未知来源安全降级 | §4.1、OWN-005 | 通过：无归属无标记 → `unknown`，**未**归类 `manual_import` |
| 7 | 多包冲突不选边 | §4.2、OWN-006 | 通过：同路径多包 → `conflict`，全部 owners 保留，`confidence=heuristic`，`read_only` |
| 8 | 混合来源分文件保留 | §4.2、OWN-007 | 通过：dylib/plist 分属不同包，分文件 owners 保留，标注 `mixed_package_ownership` |
| 9 | dpkg 库不可读 | §5、OWN-008 | 通过：数据库不可用 → `dpkg_unavailable`，条目 `unknown`，不回退、不猜归属 |
| 10 | 标记损坏降级 | §4.3、OWN-009 | 通过：标记 `corrupt` 不提升归属，降级 `unknown` |
| 11 | 标记缺失与损坏区分 | §4.3、OWN-010 | 通过：`absent` 与 `corrupt` 分别记录，缺失不反推导入 |
| 12 | 路线隔离 | §5、OWN-011 | 通过：上游未定位时空报告，不回退 `/var/jb` 或 `/` 清单路径 |
| 13 | 识别确定性 | OWN-012 | 通过：相同输入重复识别，归属/owners/策略/计数深比较一致 |
| 14 | 前序回归保持通过 | OWN-013 | 通过：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15、S1-06 22/22 全部 passed |
| 15 | 归属类别互斥 | §3、§10.1 | 通过：`mutualLeakCount=0`，六类计数与清单条目一致 |
| 16 | 输入与预期严格分离 | §2 | 通过：识别器仅接收 `environment.json`，不读取 `metadata.json` |
| 17 | 证据标签全部为 fixture | §11 | 通过：14 例 `evidenceType=fixture`，无一条标真机 |

## 3. 三条安全红线核对

| 红线 | 核对结果 |
|---|---|
| 位于 TweakInject ≠ 属于 FilterKit | 通过：归属只认 dpkg 清单命中与本地标记，目录位置不作为证据 |
| dpkg 未命中 ≠ 用户导入 | 通过：清单无记录且无有效标记 → `unknown`，不直接归类 `manual_import` |
| FilterKit 标记不忽略包归属冲突 | 通过：OWN-001 包归属条目同时带 FilterKit 标记，仍判 `owned_package` 并记 `marker_not_overridden`；冲突条目不被标记覆盖 |

## 4. 逐例结果

| 用例 | 来源 | 状态 | 计数（owned/filterkit/manual/unknown/conflict/dpkg_unavailable） | 告警 |
|---|---|---|---|---|
| OWN-001 | fixture:src-dpkg-owned | enumerated | 1/0/0/0/0/0 | 标记不覆盖包归属 |
| OWN-002 | fixture:src-dpkg-multi-file | enumerated | 2/0/0/0/0/0 | — |
| OWN-003 | fixture:src-filterkit-managed | enumerated | 0/1/0/0/0/0 | — |
| OWN-004 | fixture:src-manual-import | enumerated | 0/0/1/0/0/0 | 默认只读，待门禁确认 |
| OWN-005 | fixture:src-unknown | partial | 0/0/0/1/0/0 | — |
| OWN-006 | fixture:src-dpkg-conflict | partial | 0/0/0/0/1/0 | ownership_conflict |
| OWN-007 | fixture:src-mixed-ownership | enumerated | 1/0/0/0/0/0 | mixed_package_ownership |
| OWN-008 | fixture:src-dpkg-unavailable | partial | 0/0/0/0/0/1 | dpkg_unavailable |
| OWN-009 | fixture:src-marker-corrupt | partial | 0/0/0/1/0/0 | marker_corrupt |
| OWN-010 | fixture:src-marker-absent | partial | 0/0/0/1/0/0 | — |
| OWN-011 | fixture:src-route-guard | unresolved | 0/0/0/0/0/0 | inventory_unresolved |
| OWN-012 | fixture:determinism | enumerated | 1/0/0/0/0/0 | — |
| OWN-012 | synthetic:determinism | enumerated | 1/0/0/0/0/0 | 重复识别一致 |
| OWN-011 | synthetic:route-isolation | unresolved | 0/0/0/0/0/0 | 未回退其他路线 |
| OWN-013 | 前序回归 | — | S1-01~S1-06 全部 passed | — |

## 5. 状态边界核对

- **来源识别 ≠ 管理授权**：`filterkit_managed` / `manual_import` 仅为归属结论；是否允许启停、改写、删除由后续操作门禁独立决定，本项不产出操作放行结论。
- **loaded**：本项一律 `unknown`；归属明确不推断插件已配置生效或已加载。
- **完整性校验**：本项不做 md5/文件完整性核对；未判断 Filter 规则合法性（S1-06 已完成）；未做统一模型 JSON 导出（S1-08）。

## 6. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机 dpkg status/info 全量清单与路径规范化 | 归属命中率 | 待真机只读 `dpkg -S` / 清单复核 |
| FilterKit 自管/导入标记真实格式与存储位置 | 标记有效性判定 | 工程阶段定稿，离线为信号模拟 |
| 多包同路径、混合归属真机真实分布 | 冲突/混合场景 | 待真机采样 |
| 数据库不可读/受限条目真实表现 | `dpkg_unavailable` 归类 | 待真机只读探测 |
| Rootless/Rootful 路线归属口径 | 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| 前端（Sileo/Zebra）与 dpkg 归属对应关系 | 前端标签可信度 | 离线不臆测，待真机核对 |

## 7. 归档与门禁

- 归档产物：十二组夹具（`Tests/Fixtures/S1-07/`）、`Tests/S1-07/resolver.js`、`Tests/S1-07/run.js`、`S1-07-report.json`、本验收记录。
- 回归：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15、S1-06 22/22 保持通过。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless/Rootful 合成通过 ≠ 真机兼容。
- 门禁：S1-07 离线验收归档完成；**S1-08（统一模型 / JSON 导出）尚未展开**，须经授权后再进入，不创建正式 App 工程。
