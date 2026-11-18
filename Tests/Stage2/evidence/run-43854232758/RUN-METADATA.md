# RUN-METADATA.md — 第十六轮（Stage 2.2-C2-D2 第三轮：test 编译通过，210 例 1 失败，PAIR-011 uncertainPaths 投影口径）

- Actions run：**43854232758**（workflow-job-run guid `9a32cda6-3dc5-5f33-9315-4255b63c04c0`；results blob `57b44dc3-1187-4f36-ab3d-dfc357b9aa30`）；仓库 `yi-fen/FilterKit` / 分支 `C2`；工作流 `filterkit-build.yml`。
- Runner SHA：`2f2a930a901d7dbef315972358f1a1ed3406c621`（fetch-depth 1；本地提交链锚点 `e6d30b3`，runner 侧 hash 由外部推送/变基产生）。
- 时间：2026-11-16 11:04:05Z ~ 11:05:11Z；test Job `swift test` 11:05:09 exit 1。
- Runner：macOS 26.7.2（Build 25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 工具链：本 job 日志未落 environment 版本；沿用上一轮记录 Xcode 26.6 / Swift 6.3.3，**未经本轮 environment Job 复核**。测试目标平台 `arm64e-apple-macos14.0`，Testing Library 1902。

## 1. Job 结果总览

本轮仅回收 test Job 单份 `job-logs.txt`；environment / build / isolation / app-build / artifact 步骤日志未随包提供，结论沿用各自上一轮出证状态，不在本轮重新判定。

| Job | 本轮证据 | 结论 |
|---|---|---|
| environment | 未回收 | 待下一轮复核工具链版本 |
| build | 未回收（本日志内 `swift test` 顺带完成 Models/Adapters/Core/Tests 共 86 单元编译，无 error） | 编译面未报错 |
| isolation | 未回收 | 待下一轮复核三向 |
| test（Stage2Tests） | 编译通过；`Executed 210 tests, with 1 failure` | ❌ exit 1 |
| app-build | 未回收 | 待下一轮复核存活与截图 |
| artifact | `filterkit-test-log.zip` Artifact ID **14219337745**，5596 字节，SHA256 `315f6c251207317d14e61541297dce3bf4f17feffca827502100132f1ace816b` | ✅ 上传成功 |

> 说明：尾部 `Test run with 0 tests in 0 suites passed` 为 Swift Testing 框架侧空跑（本工程测试均为 XCTest），不是 S1-05 独立过滤步骤结果；`swift test --filter PluginPairingS105FixtureTests` 独立 15 例的日志本轮未回收。

## 2. 执行结果（Runner 实际发现）

全量 `swift test`：**210 tests，1 failure（0 unexpected）**，0.310s。分套件：

| 测试套件 | 执行 | 失败 |
|---|---:|---:|
| B5DeterminismTests | 6 | 0 |
| B5FixtureComparisonTests | 4 | 0 |
| B5IntegrationTests | 10 | 0 |
| ElleKitDirectoryTests | 15 | 0 |
| EnvironmentDetectionTests | 7 | 0 |
| JBRootCandidateCollectionTests | 10 | 0 |
| JBRootValidationTests | 18 | 0 |
| ModelsCodableTests | 21 | 0 |
| PluginEnumerationTests | 14 | 0 |
| PluginInventoryCodableTests | 9 | 0 |
| PluginPairingCodableTests | 12 | 0 |
| PluginPairingEngineTests | 21 | 0 |
| PluginPairingIndexTests | 5 | 0 |
| PluginPairingIntegrationTests | 32 | 0 |
| PluginPairingKeyTests | 11 | 0 |
| PluginPairingS105FixtureTests | 15 | 1 |
| **合计** | **210** | **1** |

与静态清点一致：冻结回归 114 + C2 专项 81 + S1-05 映射 15。

## 3. 唯一失败（runner 路径 `/Users/runner/work/FilterKit/FilterKit/Tests/Stage2/`）

- 位置：`PluginPairingS105FixtureTests.swift:129`，`testPAIR011AccessDenied`（PAIR-011，夹具 `pair-access-denied`）。
- 断言：`uncertainPaths` 集合比较。
- 实际：`["Locked.dylib", "Locked.plist"]`；预期：`["Locked.dylib"]`。
- 夹具事实：`Locked.dylib` `entryStatus=access_denied`；`Locked.plist` `entryStatus=ok`。预期 uncertain 计数 1、状态 `partial`、告警 `partial_pairing`，`Locked.plist` 留置。

### 3.1 根因判定（Core 行为 vs 测试投影）

1. Core 侧 uncertain 记录**留置两侧候选**是冻结设计：`PluginPairingEngineTests.testUncertainAccessDeniedHoldsBothSides` 显式断言 uncertain 记录 `dylib`/`plist` 均非空、`candidates.count == 2`；契约 PC8「留置对应候选不消费」。本轮 Core/Models 归类与记录形状不构成错误，不改生产代码。
2. S1-05 基线 `uncertain[].path` 只登记**受限侧**条目（`S1-05-Plugin-Pairing.md` §3 示例：`{ "path": "<dir>/Locked.dylib", "reason": "access_denied" }`）；被留置的 ok 对侧保留在记录证据中，不作为 uncertain 路径上报。
3. 失败出在 S105 映射测试的投影辅助 `uncertainPaths(_:)`：原实现把 uncertain 记录两侧文件名全部平铺，未按 `entryStatus != .ok` 过滤，把 ok 的 `Locked.plist` 多计入集合。D1 映射规格 §4 原表「两侧条目文件名集合」与基线口径及 PAIR-011 用例行自相矛盾，一并订正。

## 4. 本地修复（提交待下一轮 Runner 复验）

1. `Tests/Stage2/PluginPairingS105FixtureTests.swift` `uncertainPaths(_:)`：改为仅收集 uncertain 记录中 `entryStatus != .ok` 的 dylib/plist 文件名；ok 对侧仍保留在记录证据，不进集合。
2. `Spec/Stage-2/Stage-2.2-C2-D1-S105-Fixture-Mapping-Implementation.md` §4：`expected.uncertainPaths` 口径订正为「受限侧（`entryStatus != .ok`）条目文件名集合；被留置的 ok 对侧不计入」。

复核：13 组夹具中仅 `pair-access-denied` 含 uncertain=1 记录；其余夹具 uncertain 计数均为 0，投影收窄不影响其他用例；EngineTests / IntegrationTests 对 uncertain 记录两侧证据与候选的既有断言未改动。

## 5. 边界核对（本轮未越界）

- 未改 Core / Models / Adapters 生产代码、七方法协议、夹具 JSON 与 metadata 预期；未改 EngineTests / IntegrationTests 既有断言。
- 未接服务层、未碰真机；本轮无 isolation / app-build 新证据，不宣称隔离或 App 存活维持。
- 本机 Linux 无 Swift 工具链，修复仅做静态签名/口径对照，未本地编译或跑测试。

## 6. 待下一轮 Runner 复验

1. `swift build` / `swift test` 编译 0 error；
2. 全量 `swift test` 0 failure（114 回归 + 81 C2 专项 + 15 S1-05 映射，210 例）；
3. `swift test --filter PluginPairingS105FixtureTests` 独立 15 例 0 failure，回收 `test-log-s105.txt`；
4. isolation 三向通过；app-build Simulator 存活与截图维持；environment 工具链版本落盘复核；
5. 四类数字按 Runner 实际发现落档；未全绿前 C2-D2 仍为「待复验」，不宣布 C2 完成，不进入 C3。
