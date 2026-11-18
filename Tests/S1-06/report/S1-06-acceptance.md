# S1-06 正式验收记录 — Plist & Filter Parsing

- 验收结论：**Synthetic Fixture Validation Passed（离线验收通过）**
- 验收日期：2026-11-15
- 隶属：Stage 1 CLI 只读验证 · S1-06 Plist/Filter 解析
- 子规格：[Spec/Stage-1/S1-06-Plist-Filter-Parsing.md](../../Spec/Stage-1/S1-06-Plist-Filter-Parsing.md)
- 测试报告：[S1-06-report.json](./S1-06-report.json)

> **本结论仅代表离线合成 plist 信号上的解析与类型核对逻辑通过；不代表真机存在合法配置、插件已配置生效或已加载，也不代表 GUI 进程有权限。**

## 1. 执行环境与边界

- 执行主机：Linux 云主机（vm），Node v22.23.2；无 Swift / clang / Xcode / Theos，未连接真机。
- 产物性质：`Tests/S1-06/` 下 `parser.js`、`run.js` 为**离线测试 harness**，非 App 运行时；解析逻辑后续随工程落地迁移至 Core/Adapters。
- 解析输入为 S1-05 配对快照 + plist 内容信号（虚拟注入），harness 不访问真实文件系统；全程只读，未修改任何 plist、dylib、软链、dpkg 或规则。

## 2. 验收清单

| # | 验收项目 | 依据 | 结果 |
|---|---|---|---|
| 1 | plist 正常读取解析 | §4、PARSE-001 | 通过：XML 合法样本 `parseStatus=valid` |
| 2 | XML 格式识别 | §3、PARSE-002 | 通过：`plistFormat=xml`，按字典解析 |
| 3 | Binary 格式识别 | §3、PARSE-003 | 通过：`plistFormat=binary`，合法样本解析通过 |
| 4 | 根类型检查 | §4.2、PARSE-004 | 通过：根非字典 → `type_mismatch`（root_type） |
| 5 | Filter 类型检查 | §4.2、PARSE-005 | 通过：Filter 缺失/非字典 → `type_mismatch`（filter_missing / filter_type） |
| 6 | Bundles 类型核对 | §4.2、PARSE-006 | 通过：非字符串数组 → `type_mismatch`，记录期望/观测类型 |
| 7 | Classes 类型核对 | §4.2、PARSE-007 | 通过：元素非字符串 → `type_mismatch` |
| 8 | Executables 类型核对 | §4.2、PARSE-008 | 通过：非字符串数组 → `type_mismatch` |
| 9 | Versions 数字数组核对 | §4.2、PARSE-009 | 通过：数字数组合法；非数字数组 → `type_mismatch`（versions_type） |
| 10 | 混合类型异常保留证据 | §6、PARSE-010 | 通过：多字段不符记 `type_mismatch`，`skippedFields` 保留字段与类型 |
| 11 | 空配置区分 | §4.4、PARSE-011 | 通过：缺失字段、空数组、空字典分别标注，不混为一类 |
| 12 | 多规则条件保留 | §4、PARSE-012 | 通过：多 Bundles/Classes/Executables 全部保留，顺序确定 |
| 13 | 非法 plist 结构化记录 | §6、PARSE-013 | 通过：字节非法 → `parse_failed`（invalid_plist），条目不删除 |
| 14 | 单条失败不影响兄弟条目 | §5、PARSE-014 | 通过：损坏条目失败，良条目 `valid` |
| 15 | 双路线规则独立 | §4.1、PARSE-015 | 通过：Rootless 按 Codable 模型解析；未覆盖键入 `otherKeys`，不套 RootHide 严格规则判失败 |
| 16 | 解析确定性 | PARSE-016 | 通过：相同 plist 重复解析，归类/规则/计数深比较一致 |
| 17 | 前序回归保持通过 | PARSE-017 | 通过：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15 全部 passed |
| 18 | 五类归类互斥 | §3、§11.1 | 通过：`mutualLeakCount=0`，计数与清单条目一致 |
| 19 | 输入与预期严格分离 | §2 | 通过：解析器仅接收 `environment.json`，不读取 `metadata.json` |
| 20 | 证据标签全部为 fixture | §11 | 通过：22 例 `evidenceType=fixture`，无一条标真机 |
| 21 | 真机格式/字段分布背书 | §10 | **尚未进行**，待真机只读采样 |

## 3. 逐例结果

| 用例 | 来源 | 状态 | 计数（valid/parse_failed/type_mismatch/read_failed/not_parsed） | 告警 |
|---|---|---|---|---|
| PARSE-001 | fixture:parse-xml-valid | enumerated | 1/0/0/0/0 | — |
| PARSE-002 | fixture:parse-xml-valid | enumerated | 1/0/0/0/0 | XML 格式识别 |
| PARSE-003 | fixture:parse-binary | enumerated | 1/0/0/0/0 | Binary 格式识别 |
| PARSE-004 | synthetic:root-type | partial | 0/0/1/0/0 | root_type |
| PARSE-005 | fixture:parse-missing-filter | partial | 0/0/1/0/0 | filter_missing |
| PARSE-005 | synthetic:filter-type | partial | 0/0/1/0/0 | filter_type |
| PARSE-006 | fixture:parse-bundles-wrong | partial | 0/0/1/0/0 | field_type |
| PARSE-007 | fixture:parse-classes-wrong | partial | 0/0/1/0/0 | field_type |
| PARSE-008 | fixture:parse-executables-wrong | partial | 0/0/1/0/0 | field_type |
| PARSE-009 | fixture:parse-versions | enumerated | 1/0/0/0/0 | — |
| PARSE-009 | fixture:parse-versions-wrong | partial | 0/0/1/0/0 | versions_type |
| PARSE-010 | synthetic:mixed-type | partial | 0/0/1/0/0 | 多字段证据保留 |
| PARSE-011 | fixture:parse-empty-filter | enumerated | 1/0/0/0/0 | 空字典 |
| PARSE-011 | fixture:parse-missing-fields | enumerated | 1/0/0/0/0 | 可选字段缺失 |
| PARSE-012 | fixture:parse-multi-rule | enumerated | 1/0/0/0/0 | 多规则保留 |
| PARSE-012 | synthetic:route-isolation | unresolved | 0/0/0/0/0 | inventory_unresolved，未回退 /var/jb |
| PARSE-013 | fixture:parse-invalid-plist | partial | 0/1/0/0/0 | invalid_plist |
| PARSE-014 | fixture:parse-partial-corrupt | partial | 1/1/0/0/0 | 兄弟条目隔离 |
| PARSE-015 | fixture:parse-rootless-model | enumerated | 1/0/0/0/0 | 未覆盖键入 otherKeys |
| PARSE-016 | fixture:synthetic:determinism | enumerated | 1/0/0/0/0 | 重复解析一致 |
| PARSE-017 | 前序回归 | — | S1-01~S1-05 全部 passed | — |

## 4. 双路线 Adapter 核对

### 4.1 RootHide（严格规则）

- 根节点、`Filter` 必须为字典；`IsTweakManager` 出现时必须布尔。
- `Bundles / Classes / Executables` 必须字符串数组；`CoreFoundationVersion` 必须数字数组（长度 1 或 2）。
- 任一类型不符 → 整份 `type_mismatch`，不按字段静默跳过；跳过字段保留期望/观测类型。

### 4.2 Rootless（Swift Codable 模型为准）

- 模型字段：`Filter.Bundles`、`Filter.Executables`（`[String]?`）、`UnloadAfter`（`Bool?`）。
- Bundles/Executables 取值规范化为小写；`Classes / CoreFoundationVersion / IsTweakManager` 未覆盖，记入 `otherKeys`，不判解码失败。
- C injector 的宽松行为仅作兼容性风险记录，未套用到本 Adapter；实际运行时调用路径待真机取证。

## 5. 状态边界核对

- `configured`：仅 `parseStatus=valid` 可在 S1-08 映射为已配置；`parse_failed / type_mismatch / read_failed` 不视为已配置。
- `loaded`：本项一律 `unknown`；Filter 合法不推断已注入/已生效。
- 未判断来源与归属（S1-07）、未做统一模型 JSON 导出（S1-08）；未回写任何设备文件。

## 6. 限制与待真机缺口（不改本项范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机 plist 格式（XML/Binary 混合占比） | 格式识别口径 | 待真机全量 plist 采样 |
| 真机 Filter 字段真实分布与非常规键 | `otherKeys` 覆盖 | 待真机只读采样 |
| RootHide 严格规则与既有插件兼容性 | 误判无效风险 | 待真机对照，离线为合成样本 |
| Rootless 真机 Codable 解码失败分布 | 上游兼容口径 | `[Rootless 真机待验证]` |
| 受限 plist 读取失败表现 | `read_failed` 归类 | 待真机只读探测 |
| 进程内 Filter 命中行为 | 运行层结论 | 本阶段不取证，`loaded=unknown` |

## 7. 归档与门禁

- 归档产物：十六组夹具（`Tests/Fixtures/S1-06/`）、`Tests/S1-06/parser.js`、`Tests/S1-06/run.js`、`S1-06-report.json`、本验收记录。
- 回归：S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15 保持通过。
- 状态口径：规格冻结 ≠ 测试已执行；离线通过 ≠ 真机验证通过；Rootless 合成通过 ≠ 真机兼容。
- 门禁：S1-06 离线验收归档完成；**S1-07（来源识别）尚未展开**，须经授权后再进入，不创建正式 App 工程。
