# Stage 2.2-C2-D1：S1-05 原始配对基线映射测试实现记录（代码冻结，Runner 验收待授权）

> 批次定位：C2-D1 仅补齐 Stage 1 `S1-05` 15 项配对行为基线在 Swift 套件中的接入；
> 不重写配对算法，不执行 Runner，不编译。编译与全量回归归独立批次 C2-D2。

## 1. 本轮授权边界

### 已允许并执行

- 只读解码 `Tests/Fixtures/S1-05/<case>/{environment,metadata}.json`，按冻结映射构造 C1 形态 `PluginInventorySnapshot`，经当前 `PluginPairingPipeline` 执行配对。
- 在测试 target 内新增独立夹具加载器与参数化映射测试；13 组夹具逐例独立测试标识，2 项合成用例独立方法。
- 在 `Package.swift` testTarget `sources` 登记新增测试源。
- 冻结元数据预期原样保留；未为迁就 C2 行为修改任何 `metadata.json`。

### 禁止项（本轮均未触碰）

- 未修改 Stage 1 fixtures、metadata、harness（`Tests/S1-05/*`）。
- 未修改 `Models/`、`Adapters/`、Core 配对/枚举源码、七方法协议及既有测试。
- 未执行 GitHub Actions Runner、未本地编译、未接入服务层、未实例化 Adapter、未触碰真机。
- 未在 Core/Models 新增 `foreign` 字段；foreign 排除仅发生在测试加载层的 C1 边界复演。

## 2. 文件清单

| 文件 | 类型 | 职责 |
|---|---|---|
| `Tests/Stage2/S105FixtureLoader.swift` | 测试辅助（loader） | 中性解码 environment/metadata；构造清单快照；foreign 边界排除；夹具缺失直接抛错 |
| `Tests/Stage2/PluginPairingS105FixtureTests.swift` | 映射测试 | 13 组夹具深比较 + 2 合成用例；五桶计数/归类基名/告警/身份/软链标记逐例断言 |
| `Package.swift` | 接线 | testTarget `sources` 追加上述两源 |

加载器与测试均位于测试 target，不进入正式 App/Core；夹具读取使用 `try Data(contentsOf:)`，不使用 `try?` 掩盖缺失或解码失败。

## 3. 字段映射（environment → 清单快照）

| environment 字段 | 快照落点 | 口径 |
|---|---|---|
| `upstream.route` | `PluginInventorySnapshot.route` | 开放字符串原样保留 |
| `upstream.sourceDirectory` | `PluginInventorySnapshot.sourceDirectory` | 未定位 `nil` |
| `upstream.inventoryStatus` | `EnumerationBlock.status` | 枚举原始值映射 `enumerated/partial/enumeration_failed/unresolved`；缺失回退 `.enumerated` |
| `inventory.items[].name` | `PluginFileEvidence.name` | 原样保留大小写 |
| `inventory.items[].kind` | `PluginFileEvidence.kind` | `dylib/plist/directory/symlink/other`；不可识别不产生条目 |
| `inventory.items[].path` | `PluginFileEvidence.path` | 可选，缺失 `nil` |
| `inventory.items[].isSymlink` | `PluginFileEvidence.isSymlink` | 三态，缺失 `nil` |
| `inventory.items[].symlinkTarget` | `PluginFileEvidence.symlinkTarget` | 不跟随解析 |
| `inventory.items[].hidden` | `PluginFileEvidence.hidden` | 原样保留 |
| `inventory.items[].entryStatus` | `PluginFileEvidence.entryStatus` | 五态封闭集；不可识别回退 `.ok` |
| `inventory.items[].foreign == true` | 排除出配对输入 | C1 契约 PC5 边界复演，对齐 `Tests/S1-05/pairing.js` 第 48 行过滤 |

`inventory.enumerable` 与 `foreignRootless` 陷阱信号不进入模型；路由隔离由快照 `sourceDirectory=nil` + 引擎 `unresolved` 分支与合成断言覆盖。

## 4. 字段映射（metadata → 断言）

| metadata 字段 | 断言落点 |
|---|---|
| `expected.route` / `sourceDirectory` | 快照 route / sourceDirectory 相等 |
| `expected.status` / `expectedStatus` | `PairingStatus.rawValue` 相等 |
| `expected.counts.{paired,missing_plist,orphan_plist,ambiguous,uncertain}` | `PluginPairingCounts` 五桶逐桶比较；并核对 `total == records.count` |
| `expected.pairedBases` | `.paired` 记录 `pairingKey` 集合（排序后比较） |
| `expected.missingBases` | `.missingPlist` 记录 `pairingKey` 集合 |
| `expected.orphanNames` | `.orphanPlist` 记录 plist 文件名集合 |
| `expected.ambiguousBases` | `.ambiguous` 记录 `pairingKey` 集合（缺失按空集） |
| `expected.uncertainPaths` | `.uncertain` 记录中受限侧（`entryStatus != .ok`）条目文件名集合；被留置的 ok 对侧保留在记录证据中，不计入该集合（缺失按空集） |
| `expected.dylibSymlinkFlags` | 对应记录 dylib `isSymlink` 标记 |
| `expectedWarnings` | 快照告警码集合比较 |

五桶逐桶比较：即使总数相同，桶间错配（如 paired=3/missing=0 vs paired=2/missing=1）也判失败。

## 5. 15 例测试映射表

| 测试方法 | PAIR | 夹具 / 来源 | 状态 | 五桶预期 | 列表 / 附加断言 |
|---|---|---|---|---|---|
| `testPAIR001PairValid` | PAIR-001 | `pair-valid` | enumerated | paired 1 | pairedBases `[Example]` |
| `testPAIR002MissingPlist` | PAIR-002 | `pair-missing-plist` | enumerated | missing_plist 1 | missingBases `[Unmatched]` |
| `testPAIR003OrphanPlist` | PAIR-003 | `pair-orphan-plist` | enumerated | orphan_plist 1 | orphanNames `[Orphan.plist]`；reason `missing_dylib` |
| `testPAIR004Multi` | PAIR-004 | `pair-multi` | enumerated | paired 3 | pairedBases `[Alpha, Beta, Gamma]` |
| `testPAIR005CaseMismatch` | PAIR-005 | `pair-case-mismatch` | enumerated | missing_plist 1 / orphan_plist 1 | missingBases `[Example]`，orphanNames `[example.plist]`；大小写不配对 |
| `testPAIR006CrossPath` | PAIR-006 | `pair-cross-path` | enumerated | paired 1 | pairedBases `[Shared]`；两条 `foreign:true` `/var/jb` 条目排除 |
| `testPAIR007Hidden` | PAIR-007 | `pair-hidden` | enumerated | paired 1 | pairedBases `[.hidden]`；hidden 标记保留 |
| `testPAIR008Symlink` | PAIR-008 | `pair-symlink` | enumerated | paired 1 | pairedBases `[Link]`；`dylibSymlinkFlags {Link: true}`；软链身份不跟随 |
| `testPAIR009OtherExt` | PAIR-009 | `pair-other-ext` | enumerated | 五桶全 0 | Notes.txt / Tweak.deb / Bad.DYLIB 不入配对记录 |
| `testPAIR010Duplicate` | PAIR-010 | `pair-duplicate` | enumerated | ambiguous 1 | ambiguousBases `[Case]`；全量候选保留不取 first |
| `testPAIR011AccessDenied` | PAIR-011 | `pair-access-denied` | partial | uncertain 1 | uncertainPaths `[Locked.dylib]`；告警 `partial_pairing`；Locked.plist 留置 |
| `testPAIR012RouteGuard` | PAIR-012 | `route-guard` | unresolved | 五桶全 0 | sourceDirectory `nil`；告警 `inventory_unresolved`；items 空 |
| `testPAIR013DeterminismFixture` | PAIR-013 | `pair-determinism` | enumerated | paired 1 / missing_plist 1 | pairedBases `[Delta]`，missingBases `[Echo]` |
| `testPAIR013SyntheticDeterminism` | PAIR-013 | 合成：determinism | enumerated | — | 相同清单两轮配对快照深比较全等（归类/计数/记录一致） |
| `testPAIR006SyntheticRouteIsolation` | PAIR-006 | 合成：route-isolation | unresolved | 五桶全 0 | sourceDirectory `nil`；无任何记录路径前缀 `/var/jb`；无跨路线回退 |

合成用例不虚构夹具文件；确定性复用 `pair-determinism` 清单，路线隔离复用 `route-guard` 清单，与 Stage 1 `run.js` `buildSyntheticCases` 口径一致。

## 6. 静态审查记录

- **冻结面零改动**：本轮 `git status` 仅含新增两测试源 + `Package.swift` 接线；`Models/`、`Adapters/`、Core 源码、`Tests/Stage2` 既有测试、`Tests/Fixtures/S1-05`、`Tests/S1-05` 均无改动。
- **加载层隔离**：loader 仅 `import Foundation/Models` + `@testable import Core`；不实例化 Adapter，不读 plist 内容，不访问真实文件系统（仅读离线 JSON）。
- **夹具缺失不掩盖**：environment/metadata 读取与解码失败直接抛出，无 `try? Data(contentsOf:)`。
- **参数化标识**：13 组夹具各为独立 XCTest 方法，非单一大方法内部循环计数；2 合成用例独立方法；合计 15 例，与 Stage 1 基线一一对应。
- **字段口径复核**：`PairingCategory` 五值原始值、`PairingStatus` 四态、`PluginPairingCounts` 键名（`missing_plist/orphan_plist`）、`PluginFileEvidence` init 标签均对照冻结源码核对。
- **计数一致性**：测试内核对 `counts.total == records.count`，覆盖五桶互斥不重不漏。
- **未执行项**：本机 Linux 无 Swift 工具链，未 `swift build` / `swift test`；本轮结论为静态接入完成，测试是否通过须由 C2-D2 Runner 出证，记录中不描述为已通过编译或已通过回归。

## 7. 已知观察项（不在 C2-D1 关闭）

- 若 Runner 阶段发现某 metadata 预期与 C2 行为差异，按授权纪律先判定：C2 算法回归 / 新旧模型字段映射问题 / 基线语义差异；保留原始预期，不回改 metadata 迁就 C2。
- R6 未知枚举解码行为仍未实测，留 C2-D2 单独 Codable 兼容评审，本轮未修改公共 Models。
- `pair-other-ext` 的 other 条目归集到 `unknownItems` 的明细断言以 C2-D2 Runner 实际归集口径为准；本轮只断言五桶与配对记录不漏不重。

## 8. 下一阶段门槛（C2-D2，待独立授权）

1. Runner `swift build` 0 error；
2. `swift test` 全量执行，既有 195 + 本轮 15 例（规划合计约 210，以 Runner 实际发现为准）0 failure；
3. 双路线隔离、Fixture 完整性、App Build 按验收清单 G 组出证；
4. 四类数字分列统计（XCTest 执行 / 基线映射覆盖 / 新增专项 / 架构静态检查），架构脚本检查不计入 XCTest 总数；
5. 证据归档 `Tests/Stage2/evidence/run-<runner-id>/`，回填本记录 §6 静态审查为 Runner 实测结论。
