# Stage 2.2-C2-D2：Runner 编译 / 测试 / 独立构建验收 — 前置冻结记录（Runner 未执行）

> 批次定位：C2-D2 是独立的 Runner 验证授权，**不是**进入 C3（Filter Parser）的授权。
> 本记录只冻结 Runner 前可在本地完成的静态/完整性/隔离检查；`swift build`、`swift test`、
> App Build 等 Runner 门槛须在 macOS GitHub Actions 上出证，本批不宣称已通过编译或回归。

## 1. 授权边界

### 已允许并执行（本地离线）

- Runner 前静态检查：`S105FixtureLoader.swift`、`PluginPairingS105FixtureTests.swift`、`Package.swift` 接线复核。
- Stage 1 夹具完整性检查：S1-04 13 组、S1-05 13 组在位，JSON 可解码，计数与列表一致。
- 三向隔离静态检查：RootHide/RootHide 互引、Core 实例化具体 Adapter。
- CI 工作流补充：全量 `swift test` 之外，独立 `--filter PluginPairingS105FixtureTests` 执行 15 例映射测试并归档日志。

### 禁止项（本轮均未触碰）

- 未修改 Stage 1 fixtures、metadata、harness、report；未改 Models 冻结字段、七方法协议、已验收 B1～B5 行为。
- 未修改 Core/Adapters 冻结源码与既有测试预期；未接入服务层；未扫描或修改真机插件文件。
- 未进入 C3；未开发插件启停或写入功能。

## 2. 本地前置检查结果（静态，非 Runner 证据）

| # | 检查项 | 口径 | 本地结论 |
|---:|---|---|---|
| 1 | Loader 可靠性 | 13 组夹具可解码；缺失/解码失败直接抛错，无 `try?` 掩盖；foreign 条目不进配对器 | ✅ 静态通过（编译/执行待 Runner） |
| 2 | 测试深比较 | 五桶逐桶比较；route/目录/状态/归类基名/文件名集合/告警码/软链标记逐项断言 | ✅ 静态通过 |
| 3 | 确定性用例 | PAIR-013 相同清单两轮快照 `XCTAssertEqual` 深比较 | ✅ 静态通过 |
| 4 | 路线隔离用例 | PAIR-006 `sourceDirectory=nil` 不补路径；无 `/var/jb` 前缀；无跨路线配对 | ✅ 静态通过 |
| 5 | Package 接线 | 两个新源登记进 `Stage2Tests`；Target 依赖未变（Models/Adapters/Core） | ✅ 静态通过 |
| 6 | 夹具完整性 | S1-04 13 组、S1-05 13 组在位；fixtureId 双端一致；计数与基名/文件名列表一致；封闭枚举值合法 | ✅ 通过 |
| 7 | 三向隔离 | RootHide 不引 Rootless；Rootless 不引 RootHide；Core 不实例化具体 Adapter | ✅ 脚本通过（静态文本层面） |
| 8 | 工作树冻结面 | 除 CI 工作流与本记录外，Models/Adapters/Core/既有测试/夹具/harness 无改动 | ✅ 通过 |

### 2.1 夹具一致性明细（S1-05 13 组）

| 夹具 | 状态 | 五桶计数 | 告警 |
|---|---|---|---|
| pair-valid | enumerated | paired 1 | — |
| pair-missing-plist | enumerated | missing_plist 1 | — |
| pair-orphan-plist | enumerated | orphan_plist 1 | — |
| pair-multi | enumerated | paired 3 | — |
| pair-case-mismatch | enumerated | missing_plist 1 / orphan_plist 1 | — |
| pair-cross-path | enumerated | paired 1；2 条 `foreign:true` `/var/jb` 条目排除 | — |
| pair-hidden | enumerated | paired 1 | — |
| pair-symlink | enumerated | paired 1；dylib 软链标记保留 | — |
| pair-other-ext | enumerated | 五桶全 0 | — |
| pair-duplicate | enumerated | ambiguous 1；全候选保留 | — |
| pair-access-denied | partial | uncertain 1 | partial_pairing |
| route-guard | unresolved | 五桶全 0 | inventory_unresolved |
| pair-determinism | enumerated | paired 1 / missing_plist 1 | — |

## 3. Runner 待出证门槛（本地不可执行，禁止提前判通过）

| 门槛 | 通过要求 | 证据槽位 | 状态 |
|---|---|---|---|
| environment | macOS / Xcode / Swift / Simulator SDK 版本落盘 | `evidence/run-<id>/environment/` | ⏳ 待 Runner |
| build | Models/Adapters/Core/Stage2Tests `swift build` 0 error | `evidence/run-<id>/build/` | ⏳ 待 Runner |
| test（全量） | `swift test` 实际发现数、通过/失败/跳过/错误分列，0 failure | `evidence/run-<id>/test-log/` | ⏳ 待 Runner |
| test（C2 映射独立过滤） | `--filter PluginPairingS105FixtureTests` 15 例全部实际执行 | `evidence/run-<id>/test-log/test-log-s105.txt` | ⏳ 待 Runner |
| isolation | 三向隔离脚本通过 | `evidence/run-<id>/isolation/` | ⏳ 待 Runner |
| app-build | iOS Simulator `BUILD SUCCEEDED`；存活仅链路证据 | `evidence/run-<id>/app-build/` | ⏳ 待 Runner |
| artifact | 日志/测试结果/metadata 归档完整 | `evidence/run-<id>/metadata/` | ⏳ 待 Runner |

## 4. 四类数字（Runner 报告须分列，不混算通过率）

| 类别 | 静态清点（方法数，非执行数） | 说明 |
|---|---:|---|
| 冻结回归（B 91 + C1 23） | 114 | B 阶段 91；C1 枚举 23 |
| C2 新增专项（A 12 + B 37 + C 32） | 81 | C2-A 模型 12；C2-B 引擎 37；C2-C 集成 32；不计入原始基线映射 |
| Stage 1 原始基线映射（S1-05） | 15 | 13 组夹具 + 2 合成用例；S1-04 23 例已在 C1 回归内 |
| 架构静态检查 | 独立项 | 隔离三向、Models 契约、Fixture 完整性、确定性、App Build；不计入 XCTest 总数 |
| **XCTest 静态合计** | **210** | 最终以 Runner 实际发现为准，估算数不作为验收依据 |

## 5. CI 工作流调整（本批唯一代码侧改动）

- `test` Job 在全量 `swift test` 后新增独立过滤步骤 `swift test --filter PluginPairingS105FixtureTests`，日志 `test-log-s105.txt` 随 `filterkit-test-log` artifact 上传。
- 未改动六 Job 结构、触发方式（`workflow_dispatch` 手动）与 App Build 步骤；YAML 已静态解析合法。

## 6. 当前阻塞与交接条件

本执行环境为 Linux 云主机：无 `swift/swiftc/xcodebuild`；未配置 git remote；`gh` 未登录，环境 token 对 GitHub API 返回 401；浏览器当前处于未登录态。Runner 为 macOS GitHub Actions，本地无法替代执行。

恢复 Runner 验收需要：

1. 将本地 C2-D1 冻结提交链（锚点 `bd776aa`）与本批工作流调整推送到远端分支；
2. 在 GitHub 手动 `workflow_dispatch` 触发 `filterkit-build`；
3. 回收 environment/build/test/isolation/app-build/artifact 日志，按 §3 槽位归档；
4. 若出现编译错误或测试失败，保留失败证据（文件/位置/影响），不开修复批次、不改冻结基线，先回报。

## 7. 未决观察项（沿用，不在本批收口）

- 2.2-A R6 未知枚举原始值默认解码行为仍未实测，留 Runner 记录；本轮未修改公共 Models。
- 待 Runner 验证：C1 目录状态透传、不可读文件保留、unknownItems/warnings 完整传递、两侧目录作用域一致、C2 始终不读 plist 内容。
- Deployment Target/iOS 17 兼容、Rootless 无真机、App 存活不证明目录访问权限、Runner SDK 版本不作为 Theos 16.5 兼容证据。

## 8. 首轮 Runner 失败与最小编译修复（待下一轮复验）

Runner `build` job（作业 `8c01d4fc-82f6-55f6-beea-4c8298a4143d`，远端 `C2` @ `5fc804f6`）在 Core 阶段 exit 1：

- 错误：`PluginPairingSnapshotBuilder.swift:67:29: missing argument label 'where:' in call`；`Array.contains(where:)` 缺参数标签，被 15 个并行编译单元重复报出，实际仅一处。
- 修复：`records.contains({ ... })` → `records.contains(where: { ... })`，判定行为不变；全仓复核无其他同类缺标签调用。
- 证据归档：`Tests/Stage2/evidence/run-8c01d4fc-build-failure/`（`build/job-logs.txt` + `RUN-METADATA.md`）。
- 边界：仅改这一处调用标签；未改 Models/协议/夹具/harness/既有测试预期；test/isolation/app-build 本轮未执行，结论待下一轮 Runner 出证。

## 9. 第二轮 Runner：build/isolation/app-build 通过，test target 编译失败（待复验）

Run `43851060190`（本地归档目录 `run-118709558501`，远端 `C2` @ `7aaa5115`）：environment/build/isolation/app-build/artifact 均成功；首轮 `contains(where:)` 修复生效，Core 63 源编译通过，App Simulator `BUILD SUCCEEDED` 且存活 PID 4000。test Job 全量 `swift test` 编译阶段 exit 1，未进入用例执行，S1-05 独立过滤步骤未触发。

- 根因一（24 处缺 `inventory:` 标签）：`PluginPairingEngine.pair(inventory:)` / `PluginPairingPipeline.execute(inventory:)` 被测试源写成裸闭包调用；级联产生 `Equatable 无成员`、`Any 不符合 Equatable`、类型检查超时等报错。`PluginPairingEngineTests.swift` 21 处、`PluginPairingIntegrationTests.swift` 3 处。
- 根因二（1 处成员引用错误）：`PluginPairingS105FixtureTests.swift:134` 把 `expectedWarnings` 从 `S105Expected` 取值，实际该字段在 `S105Metadata` 上；改为 `fixture.metadata.expectedWarnings`。
- 修复：仅改上述三个测试源，调用入参与判定预期不变；未改 Core/Models/Adapters/协议/夹具/harness。
- 证据归档：`Tests/Stage2/evidence/run-118709558501/`（六 Job 步骤日志 + `RUN-METADATA.md`）。
- 待下一轮：全量 `swift test` 0 failure、S1-05 独立 15 例 0 failure；210 例数字以 Runner 实际发现为准。

## 10. 第三轮 Runner：test 编译通过，210 例 1 失败（PAIR-011 uncertainPaths，待复验）

Run `43854232758`（本地归档目录 `run-43854232758`，远端 `C2` @ `2f2a930a`）：第二轮标签/成员修复生效，test target 86 单元编译通过，全量进入执行；仅回收 test Job 日志，environment/build/isolation/app-build 未随包提供，沿用各自既有结论不在本轮重判。

- 执行数字（Runner 实际）：**210 tests，1 failure（0 unexpected）**；16 个套件中 15 个全绿，唯一失败 `PluginPairingS105FixtureTests.testPAIR011AccessDenied`（PAIR-011 / `pair-access-denied`）。
- 失败：`uncertainPaths` 实际 `["Locked.dylib", "Locked.plist"]`，预期 `["Locked.dylib"]`。`Locked.dylib` 受限 `access_denied`，`Locked.plist` 为 `ok` 并被留置。
- 判定：Core uncertain 记录留置两侧候选是冻结设计（`testUncertainAccessDeniedHoldsBothSides` 显式断言两侧非空、候选 2 个；契约 PC8），生产代码不改；基线 `uncertain[].path` 只登记受限侧，问题在 S105 映射投影把 ok 对侧也平铺计入。
- 修复：`PluginPairingS105FixtureTests.swift` 的 `uncertainPaths(_:)` 收窄为仅取 `entryStatus != .ok` 条目；`Stage-2.2-C2-D1-S105-Fixture-Mapping-Implementation.md` §4 口径同步订正。夹具 JSON、metadata 预期、Core/Models/Adapters 与既有测试断言均未改。
- 证据归档：`Tests/Stage2/evidence/run-43854232758/`（test Job 日志 + `RUN-METADATA.md`，含分套件计数表）。
- 待下一轮：全量 210 例 0 failure；`--filter PluginPairingS105FixtureTests` 独立 15 例 0 failure 并回收 `test-log-s105.txt`；isolation / app-build / environment 复核出证；未全绿前不宣布 C2 完成，不进入 C3。

## 11. 第四轮 Runner：六 Job 全绿，C2-D2 验收通过（收口）

Run `43857670397`（Run ID `118727393219`，本地归档目录 `run-43857670397`，远端 `C2` @ `ce118319`）：第三轮投影修复生效，全部硬门槛出证通过。

- **编译**：build `Build complete! (17.41s)`，Core 63 源 + Stage2Tests 86 单元，0 error / 0 warning。
- **全量回归**：`swift test` **210 tests, 0 failures**（B 回归 91 + C1 23 + C2-A 12 + C2-B 37 + C2-C 32 + S1-05 映射 15）。
- **S1-05 独立过滤**：`--filter PluginPairingS105FixtureTests` **15 tests, 0 failures**（`test-log-s105.txt`）。
- **隔离**：三向 OK（RootHide↔Rootless 互不引用；Core 未实例化具体 Adapter）。
- **App Build**：`BUILD SUCCEEDED`；模拟器复查存活 PID 3991；截图 `dashboard.png`（1206×2622）归档。
- **Fixture 完整性**：自 C1 验收 `5b481e6` 起 `Tests/Fixtures/` 零改动。
- 产物：metadata ID 14222656867（7,188B）、app-build ID 14222157455（1,210,287B）、test-log ID 14221662179（6,279B），SHA256 见归档 `RUN-METADATA.md` §4。

**结论：Stage 2.2-C Enumeration & Pairing Core Migration Runner 验收通过，C2-D2 收口。** 结论仅限离线 Core 数据处理链路；真机扫描/GUI 权限/Rootless 兼容/插件启停不在本批。C3（Filter plist 解析）须另行授权。未决观察项（R6 默认解码、iOS 17 兼容、Rootless 真机、SDK 兼容口径）移交后续批次。
