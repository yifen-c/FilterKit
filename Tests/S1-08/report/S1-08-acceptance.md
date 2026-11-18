# S1-08 正式验收记录 — Unified Model & JSON Export（统一模型 / JSON 导出）

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-08 统一模型 / JSON 导出（Stage 1 闭环阶段）
- 子规格：[Spec/Stage-1/S1-08-Unified-Model-JSON-Export.md](../../Spec/Stage-1/S1-08-Unified-Model-JSON-Export.md)
- 测试报告：[S1-08-report.json](./S1-08-report.json)

> **本结论仅代表离线合成快照上的模型整合与序列化逻辑通过；不代表真机模型完整、不代表插件已配置生效或已加载，也不代表 FilterKit 已获管理授权。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-08/` 下 `exporter.js`、`run.js` 为**离线测试 harness**，非 App 运行时；模型与导出逻辑后续随工程迁移至 Core/Models。
- 输入为 S1-01~S1-07 产物快照（虚拟注入）；harness 不访问真实文件系统，不回写设备，不读写 dpkg / plist / dylib / 软链 / 规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | 信封结构符合模型 | §3、EXPORT-001 | 通过：`schemaVersion` / `generatorVersion` / `profile` / `generatedAt` / `environment` / `plugins` / `unknownItems` / `warnings` 齐全 |
| 2 | Rootless 独立 Profile | §5、EXPORT-002 | 通过：Rootless Profile 与 `/var/jb` 路径口径独立，未套 RootHide 字段 |
| 3 | 失败/孤儿/歧义条目保留 | §4.1、EXPORT-003 | 通过：解析失败留在 `plugins`（`configured=false`）；孤儿 plist、歧义配对入 `unknownItems`，未被裁剪 |
| 4 | 冲突与混合归属细节保留 | §3.2、EXPORT-004 | 通过：`ownershipDetails.conflicts` 保留多包 owners；混合来源分文件归属与备注完整，不选边 |
| 5 | dpkg 不可用降级 | §6、EXPORT-005 | 通过：归属 `unknown`，`dpkg_unavailable` 告警保留，不猜包名 |
| 6 | 未知 Profile 不套规则 | §6、EXPORT-006 | 通过：`profileId=unknown-profile`，`profile_unknown` 告警；未强行映射路线规则 |
| 7 | 上游未定位空模型 | §6、EXPORT-007 | 通过：`plugins=[]`，`inventory_unresolved` 告警，不回退扫描 |
| 8 | 扩展证据不丢失 | §4.3、EXPORT-008 | 通过：`otherKeys`、`skippedFields`、`markers`、`notes` 全部序列化可比对 |
| 9 | 导出确定性 | §5.2、EXPORT-009 | 通过：相同快照两次导出，除 `generatedAt` 外深比较一致；排序与键序固定 |
| 10 | 三层状态分离 | §4.2、EXPORT-010 | 通过：`installed` 仅来自库存证据；`configured` 仅来自解析 valid；`loaded=unknown`；缺库存证据 `installed=null` |
| 11 | 来源/权限互斥 | §4.2、EXPORT-011 | 通过：全部插件 `loaded=unknown`、`permission.decision=undetermined`；`source` 与 `ownership.sourceType` 一致 |
| 12 | 未取到项显式 null/unknown | §4.3、EXPORT-012 | 通过：缺失环境置 `unknown`；证据标签全部 `fixture`，无空串冒充已知 |
| 13 | 前序回归保持通过 | EXPORT-013 | 通过：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15、S1-06 22/22、S1-07 14/14 全部 passed |

## 3. 五项原则核对

| 原则 | 核对结果 |
|---|---|
| 不丢失原始证据 | 通过：告警、冲突、跳过字段、扩展键、未配对/失败条目均有模型落点 |
| 三层状态严格分离 | 通过：`installed` / `configured` / `loaded` 互不推导；`loaded` 恒 `unknown` |
| 来源与权限严格分离 | 通过：`ownership.writablePolicy` 不决定 `permission.decision`；后者恒 `undetermined` |
| 不确定状态保留 | 通过：`unknown` / `partial` / `ambiguous` / `conflict` / `heuristic` 显式表达，未强行归类 |
| JSON 版本化 | 通过：信封版本字段齐全；`generatedAt` 排除在确定性比较之外 |

## 4. 逐例结果

| 用例 | 来源 | 状态 | 插件数 | 告警/未知项 |
|---|---|---|---|---|
| EXPORT-001 | fixture:export-full-roothide | enumerated | 4 | 包管/自管/导入/未知混合 |
| EXPORT-002 | fixture:export-rootless | enumerated | 1 | Rootless Profile |
| EXPORT-003 | fixture:export-partial-failures | partial | 1 | missing_dylib、ambiguous |
| EXPORT-004 | fixture:export-conflict-mixed | enumerated | 2 | 冲突/混合归属细节保留 |
| EXPORT-005 | fixture:export-dpkg-unavailable | partial | 1 | dpkg_unavailable |
| EXPORT-006 | fixture:export-unknown-profile | partial | 1 | profile_unknown |
| EXPORT-007 | fixture:export-missing-upstream | unresolved | 0 | inventory_unresolved |
| EXPORT-008 | fixture:export-evidence-preservation | enumerated | 1 | 证据字段完整保留 |
| EXPORT-009 | fixture:export-determinism | enumerated | 1 | — |
| EXPORT-010 | fixture:export-state-separation | partial | 3 | 失败/自管/缺库存条目状态分离 |
| EXPORT-009 | synthetic:determinism | enumerated | 1 | 重复导出一致 |
| EXPORT-011 | synthetic:state-mutex | enumerated | 4 | 状态/权限互斥复核 |
| EXPORT-012 | synthetic:evidence-null | — | 1 + 0 | 未取到项 null/unknown |
| EXPORT-013 | 前序回归 | — | — | S1-01~S1-07 全部 passed |

## 5. 状态边界核对

- **installed**：仅来自 S1-04 库存在位/可读证据；库存缺失或条目未列入 → `null`，不由 plist/归属推导。
- **configured**：仅当 S1-06 `parseStatus=valid`；不由 `installed` 或来源推导。
- **loaded**：本阶段无独立运行时取证，恒 `unknown`。
- **permission**：`decision=undetermined`、`reason=authorization_gate_not_evaluated`；管理授权门禁属后续阶段，本项不评估、不放行。
- 导出为只读快照；未重新扫描、重新解析、补判归属、校验完整性或执行启停/注入。

## 6. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机一轮完整导出的模型完整性 | 端到端字段覆盖 | 待真机只读采样，离线为合成快照 |
| 真机 Profile 识别与版本映射 | `profileId` 准确性 | 待真机核对 ElleKit 版本 |
| 运行时加载取证接口 | `loaded` 脱离 `unknown` | 后续阶段，本阶段不取证 |
| 管理授权门禁口径 | `permission.decision` 取值 | 后续阶段定义，本项恒 `undetermined` |
| Rootless/Rootful 真机模型适配 | 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| `pluginID` 定稿规则 | 稳定标识 | 0.2.0 定稿，离线按优先级规则生成 |

## 7. 归档与门禁

- 归档产物：十组夹具（`Tests/Fixtures/S1-08/`）、`Tests/S1-08/exporter.js`、`Tests/S1-08/run.js`、`S1-08-report.json`、本验收记录。
- 回归：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15、S1-06 22/22、S1-07 14/14 保持通过。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless/Rootful 合成通过 ≠ 真机兼容；来源识别 ≠ 管理授权。
- **Stage 1 只读 CLI 验证链离线闭环完成**；正式 App 工程创建、Core/Models/Adapters 迁移、GUI、权限探针、管理授权与插件操作设计均属后续独立授权阶段，本阶段通过不自动获得上述授权。
