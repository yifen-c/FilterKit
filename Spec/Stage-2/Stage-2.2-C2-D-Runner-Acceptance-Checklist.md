# Stage 2.2-C2-D：Runner 验收清单（冻结）与 C2 只读审计记录

- 状态：**Runner 验收通过**（run `43857670397` / Run ID `118727393219`，2026-11-16）；全量 210 例 0 失败、S1-05 独立 15 例 0 失败、隔离三向 OK、App Simulator 构建存活。证据归档 `Tests/Stage2/evidence/run-43857670397/`（`acceptance-report.md`）。
- 审计依据：C1 验收 `5b481e6`、G-C3 契约 `7dbac87`、C2-A 冻结 `cc5c98e`、C2-B 冻结 `35d8d76`、C2-C 冻结 `9e98744`。
- 本批不新增配对功能、不改冻结代码/Stage 1 fixtures/Models 公共契约/七方法协议/Adapter；不接服务层；不扫描或修改真机插件文件。

## 1. 审计结论摘要

| 审计项 | 结论 |
|---|---|
| C2-A 模型 / Codable | 6 源 + 12 例测试已接线；模型字段、五桶分类、四值兼容与 C1 范式一致（待 Runner 编译出证） |
| C2-B Key / Index / Engine | 6 源 + 37 例测试已接线；五态归类、作用域、大小写敏感、候选保留、确定性排序落地（待 Runner 出证） |
| C2-C 集成桥接 | 5 源 + 32 例测试已接线；状态矩阵与 INT-C2-001~014 校验落地（待 Runner 出证） |
| 冻结面改动 | 自 C1 验收 `5b481e6` 以来：`Models/`、`Adapters/`、七方法协议、Stage 1 fixtures/harness、既有 Stage2 测试**零改动** |
| 双路线隔离 | 隔离脚本三向通过；Core 未直接实例化 Adapter；配对层无 `/var/jb` 硬编码回退 |
| 集成结果模型 | `PluginPairingInput/IntegrationResult` 位于 Core，未混入公共 Models，未进 `ReportEnvelope` |

## 2. Runner 测试分组与实际映射

### 2.1 已有 XCTest 方法盘点（静态清点，未执行）

| 组 | 测试源 | 方法数 |
|---|---|---:|
| A B 阶段回归 | `ModelsCodableTests` | 21 |
| A B 阶段回归 | `EnvironmentDetectionTests` | 7 |
| A B 阶段回归 | `JBRootCandidateCollectionTests` | 10 |
| A B 阶段回归 | `JBRootValidationTests` | 18 |
| A B 阶段回归 | `ElleKitDirectoryTests` | 15 |
| A B 阶段回归 | `B5IntegrationTests` | 10 |
| A B 阶段回归 | `B5FixtureComparisonTests` | 4 |
| A B 阶段回归 | `B5DeterminismTests` | 6 |
| **A 小计** | | **91** |
| B C1 Enumeration | `PluginEnumerationTests` | 14 |
| B C1 Enumeration | `PluginInventoryCodableTests` | 9 |
| **B 小计** | | **23** |
| C C2-A Models/Codable | `PluginPairingCodableTests` | 12 |
| D C2-B Key/Index/Engine | `PluginPairingKeyTests` | 11 |
| D C2-B Key/Index/Engine | `PluginPairingIndexTests` | 5 |
| D C2-B Key/Index/Engine | `PluginPairingEngineTests` | 21 |
| **D 小计** | | **37** |
| E C2-C Integration | `PluginPairingIntegrationTests` | 32 |
| **已有 XCTest 合计** | | **195** |

### 2.2 F 组：S1-05 原始配对行为映射（15 例，当前接入状态：0）

> 审计发现：现有 Swift 套件**尚无**加载 `Tests/Fixtures/S1-05/*/environment.json` 并与 `metadata.json` 深比较的配对夹具测试（C1 的 S1-04 深比较范式可复用）。F 组 15 例在 Runner 前须以独立批次补齐夹具映射测试；不得用 C2-B/C2-C 合成专项测试顶替原始行为映射，也不重复计数。

| # | 编号 | 夹具/来源 | 归类断言 | 预期计数 / 告警 |
|---:|---|---|---|---|
| 1 | PAIR-001 | `pair-valid` | dylib ↔ plist → paired | paired 1 |
| 2 | PAIR-002 | `pair-missing-plist` | dylib → missing_plist | missing_plist 1 |
| 3 | PAIR-003 | `pair-orphan-plist` | plist → orphan_plist，reason=missing_dylib | orphan_plist 1 |
| 4 | PAIR-004 | `pair-multi` | 多组分别配对 | paired 3（Alpha/Beta/Gamma） |
| 5 | PAIR-005 | `pair-case-mismatch` | 大小写不同不配对 | missing_plist 1 / orphan_plist 1 |
| 6 | PAIR-006 | `pair-cross-path` | 跨目录同名不配对不合并 | 同目录 paired 1；foreign 排除 |
| 7 | PAIR-007 | `pair-hidden` | 隐藏前缀保留 | paired 1，键 `.hidden` |
| 8 | PAIR-008 | `pair-symlink` | ok 软链身份保留并参与配对 | paired 1 |
| 9 | PAIR-009 | `pair-other-ext` | .txt/.deb/.DYLIB 不入候选 | 五桶全 0，入 unknownItems |
| 10 | PAIR-010 | `pair-duplicate` | 同基名多候选 → ambiguous，全候选 | ambiguous 1（Case） |
| 11 | PAIR-011 | `pair-access-denied` | 受限 → uncertain，留置 plist | uncertain 1，partial，`partial_pairing` |
| 12 | PAIR-012 | `route-guard` | 未定位 → unresolved 空报告 | 全 0，`inventory_unresolved` |
| 13 | PAIR-013 | `pair-determinism` | 重复配对结果确定 | paired 1 / missing_plist 1 |
| 14 | PAIR-013 | `synthetic:determinism` | 两轮快照深比较全等 | 记录/归类/计数一致 |
| 15 | PAIR-006 | `synthetic:route-isolation` | 无 /var/jb 回退；无跨路线配对 | sourceDirectory=nil 不泄漏路径 |

### 2.3 G 组：额外集成与架构检查（静态/独立 Job）

| 检查 | 口径 |
|---|---|
| 双路线隔离 | RootHide 不引用 Rootless，反之亦然；Core 不实例化具体 Adapter；配对层不依赖具体越狱实现；无 `/var/jb` 回退；无路线污染 |
| 公共 Models 契约 | `Pairing` 不新增取值；既有枚举 rawValue 不变；`ReportEnvelope` 未改；内部集成结果未入公共 Models；七方法协议未改 |
| Fixture 完整性 | Stage 1 fixtures/harness 未修改；原始 JSON 输出无意外变化；S1-04 13 组、S1-05 13 组夹具完整在位 |
| 确定性 | 相同输入重复 100 次：records/candidates/warnings 顺序、counts、JSON 一致；无时间字段参与比较 |
| App Build | iOS Simulator 构建成功；存活仅作链路证据，不证明真机目录访问权限 |

## 3. 四类数字统计口径（Runner 报告必须分开列示）

1. **XCTest 实际执行数量**：Runner `swift test` 发现并执行的测试用例数。
2. **Stage 1 原始基线映射覆盖数量**：S1-04 23 + S1-05 15 例中通过夹具/合成映射断言的数量。
3. **新增专项测试数量**：C2-A 12 + C2-B 37 + C2-C 32 合成专项，不计入原始基线映射。
4. **架构静态检查数量**：隔离三向、Models 契约、Fixture 完整性、确定性、App Build 等独立检查项数。

> 禁止把同一断言同时计入"原始基线映射"与"新增专项"；总数以 Runner 实际发现为准，估算值（约 210 项）不作为验收依据。

## 4. 硬门槛（任一不满足即不宣布 C2-D 通过）

| 验收项目 | 通过要求 |
|---|---|
| Swift 编译 | 0 error |
| XCTest | 0 failure；跳过测试为 0 或逐项说明合理原因 |
| Stage 1 回归 | S1-04 / S1-05 原始基线全部覆盖且通过 |
| C1 回归 | 23 项全部通过 |
| C2-A | 模型/Codable 测试全部通过 |
| C2-B | 配对行为测试全部通过 |
| C2-C | 集成桥接测试全部通过 |
| 路线隔离 | 双路线隔离检查全部通过 |
| Fixture 完整性 | 无意外修改 |
| App Build | iOS Simulator 构建成功 |

出现代码问题须单独开修复批次，不在 Runner 验收过程中偷改冻结基线。

## 5. Runner 证据归档结构（对齐 C1 先例 + 本批建议）

```
Tests/Stage2/evidence/run-<runner-id>/
├── RUN-METADATA.md            # 运行编号、环境、工具链、时间、结论
├── environment/               # macOS / Xcode / Swift / Simulator SDK 版本
├── build/                     # swift build 日志
├── test-log/                  # swift test 用例结果与计数
├── isolation/                 # 三向隔离报告
├── app-build/                 # App 构建日志与存活截图
└── acceptance-report.md        # 四类数字、逐项门槛结论、未决项
```

## 6. 未决项与边界

- ~~本机未编译/未跑测试；C2-A/B/C 代码行为结论以 C2-D Runner 出证为准~~ 已由 run `43857670397` 出证：编译 0 error、210 例 0 失败（见 `acceptance-report.md`）。
- 2.2-A R6（未知枚举原始值默认解码行为）仍未实测，留 Runner 记录。
- 待 Runner 验证：C1 目录状态透传、不可读文件保留、unknownItems/warnings 完整传递、两侧目录作用域一致、C2 始终不读 plist 内容。
- 部署目标/iOS 17 兼容、Rootless 无真机、App 存活不证明目录访问权限、Runner SDK 版本不作为 Theos 16.5 兼容证据——沿用既有观察项，不在本批收口。

## 7. C2-D 通过后的状态

C2-D 全部通过方可宣布 **Stage 2.2-C：Enumeration & Pairing Core Migration 完成**；该结论仅限离线 Core 数据处理链路，不代表 GUI 已可扫描 RootHide 真机。后续 Stage 2.2-D（Filter Parser，原计划 C3）须另行授权。

> 2026-11-16 收口：run `43857670397` 十项硬门槛全部通过（见 `Tests/Stage2/evidence/run-43857670397/acceptance-report.md`），**Stage 2.2-C 宣布完成**；C3 未授权、未启动。
