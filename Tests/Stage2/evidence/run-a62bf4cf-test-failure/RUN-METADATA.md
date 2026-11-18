# RUN-METADATA.md — 第十三轮（Engine-C2 第三轮：测试编译通过，3 处断言失败）

- Run 作业：`workflow-job-run-a62bf4cf-236f-5db3-a5a2-bd04049f167b`；结果容器 `4e0d041e-850b-453e-a1fb-af51154ef7df`；仓库 `yi-fen/FilterKit` / 分支 `C2-C3`；job 命令 `swift test 2>&1 | tee .build/test-log.txt`。
- Runner SHA：`7f91ed41a4b77b0b126976036c93e720e4c42890`（fetch-depth 1；本地链经变基/压缩后哈希不同属正常）。
- 时间：2026-11-17 04:05:32Z 起；04:06:58 测试结束，exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261112.0504.1；runner 2.338.2；region westus，Cloud MacCloud。
- 工具链版本：日志未直接列出 Swift/Xcode/SDK 版本，待 environment job 补录。

## 1. Job 结果

| 维度 | 结论 | 证据 |
|---|---|---|
| 编译 | ✅ Core 与 Stage2Tests 均编译通过，无 error、无 warning（`warning:` 计数 0） | 第二轮参数顺序 / 默认参数修复复验通过 |
| 测试执行 | ❌ 347 tests，3 skipped，3 failures（0 unexpected） | `FilterKitPackageTests.xctest` failed |
| 跳过 | 3 例 pendingRunner：PARSE-015-A、PARSE-015、Rootless 完整链路（#151 / C-G2） | 不记通过 |

### 各套件通过情况（Runner 日志）

- 全绿：B5 三套件、ElleKitDirectory、EngineC1EngineBaseline（1 skip）、EngineC2BatchIsolation 4/4、EngineC2EndToEnd 5 pass + 1 skip、EngineC2SnapshotWarnings 6/6、EnvironmentDetection、FilterParseResult、JBRoot*、ModelsCodable、PlistDecoder/Reader/ValueKind、PluginEnumeration/Inventory/Pairing 全套件、RootHideFilterParser 32/32、RootlessFilterParser 22/22。
- 失败套件：`EngineC1ParserBaselineTests`（1 failure）、`FilterParseEngineTests`（2 failures，同一用例两条路径断言）。

## 2. 失败定位与修复

### A. `EngineC1-ParserBaselineTests.swift:213` — BadVer 元素下标被比较器强制断言 nil

- 用例：`testRootHideFixtureBaselines`，基线 PARSE-009-B（夹具 `parse-versions-wrong`，`CoreFoundationVersion: ["1600"]`）。
- 现象：`XCTAssertNil failed: "0" - 条目 BadVer CoreFoundationVersion 不应有元素下标`。实际 Parser 走 CFV 元素分支，产出 `index = 0`；基线条目未冻结 `index`，比较器却在 `wanted.index == nil` 时强制 `XCTAssertNil(match.index, …)`。
- 口径核对：C1 实现规格 §63 明确「PARSE-009-B 只冻结 key / reason / expectedType，观测类型/下标留待 Runner 对照」；`observedType` 在比较器中本就是可选断言（`if let`），`index` 的强制 nil 分支与该冻结范围不一致。
- 修复（测试比较器，不改 Parser、不改基线期望）：`Tests/Stage2/EngineC1-ResultComparator.swift` `assertSkippedFields` 的 index 断言改为与 observedType 同构——仅当 `wanted.index` 显式给出时才比对相等；未冻结时不强制 nil。
- **保留待复核差异（本轮未改 Parser、未改 Stage1 基线报告）**：Stage1 报告例 13 记录 `observedType: "array"`、无 `index`；当前 Swift 元素分支产出元素级证据（下标 0，观测类型词按元素取 `"string"`）。两者口径差异待独立授权后复核：是 Parser 应回退到字段级粗粒度记录，还是基线报告需补登元素级下标/类型词。

### B/C. `FilterParseEngineTests.swift:356-357` — 桩 Parser 未回显上游路径

- 用例：`testResultPreservesRecordEvidence`；记录显式传入 `/lib/Example.dylib`、`/lib/Example.plist`，结果却为 `/dir/Example.dylib`、`/dir/Example.plist`。
- 根因：私有 `StubParser.parse(...)` 原样返回 canned 结果，未把入参 `pairingKey / dylibPath / plistPath / route` 回显；canned 内硬编码 `/dir/...`，掩盖了 Engine→Parser 的证据透传。真实 `RootHideFilterParser` / `RootlessFilterParser` 均按契约把这四个上游信号透传进结果。
- 修复（测试桩，不改生产代码）：`Tests/Stage2/FilterParseEngineTests.swift` `StubParser.parse` 在保留 canned 状态/规则/原因/告警/格式/读取状态的前提下，用入参回显 `pairingKey / dylibPath / plistPath / route`；`pairingKey` 入参为 nil 时回退 canned 值。
- 连带排查：本文件其余结果断言只核对 status/reason/route/readStatus，不核对键与路径；C2 套件使用 `EngineC2-TestSupport.swift` 自有桩，本轮未改动且已全绿。

## 3. 边界核对（本轮未越界）

- 改动仅 2 个 `Tests/Stage2/` 文件：`EngineC1-ResultComparator.swift`、`FilterParseEngineTests.swift`。
- 未改 Core 生产逻辑、Models、Adapters、七方法协议、冻结 Parser、Stage1 fixtures/metadata/harness 与既有夹具期望；未接服务层、未碰真机。
- 未调整任何已冻结的 reason / expectedType / 状态映射；PARSE-009-B 的观测类型词与下标差异按待复核项保留。

## 4. 待下一轮 Runner 复验

1. 编译无 error / warning；347 例中 3 例 pendingRunner 跳过，其余 0 failure。
2. `testResultPreservesRecordEvidence` 回显 `/lib/...` 路径通过；`testRootHideFixtureBaselines` 不再因未冻结下标报错。
3. PARSE-009-B 元素级 vs 字段级口径差异另出独立缺陷报告，独立授权后再决定改 Parser 还是补登基线。
4. environment job 补录 Swift/Xcode/SDK 版本；test-log 归档。

> 下一轮结果未出前，Engine-C2-A~C 状态仍为「待复验」；C2-D / C2-E 继续阻塞于 C-G1 / C-G2，不宣布双路线完整集成验收通过。
