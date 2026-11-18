# RUN-METADATA.md — 第八轮（2.2-A Codable 测试 runner 复验）

- Run ID：**43741322151**；仓库 `yi-fen/005` / `master`；触发方式 `workflow_dispatch`（手动）。
- Runner SHA：`f28b67001f5201ffbf6d51e8715bdab5d1b6b3e4`（私有镜像提交；对应本地提交 `ddd042f`，2.2-A 仅测试补齐）。
- 时间：2026-11-15 17:28–17:35 UTC。
- 工具链：macOS 26 镜像 `macos-26-arm64`（image 20261102.0473）；Xcode 26.6；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5（iphoneos26.5 / iphonesimulator26.5）；XcodeGen 2.46.0。
- 测试平台：arm64e-apple-macos14.0；Testing Library 1902。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链版本落盘，无 error |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (4.47s)`；`Emitting module Models / Adapters / Core` |
| test（Stage2Tests） | ✅ success | `Executed 21 tests, with 0 failures (0 unexpected) in 0.011 (0.013) seconds` |
| isolation | ✅ success（静态文本层面） | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| app-build | ✅ success | `xcodegen generate` 成功；`** BUILD SUCCEEDED **`；模拟器 install/launch；存活复查；截图归档 |
| artifact | ✅ always（metadata 上传成功） | 三类 artifact 归档 |

## 2. 2.2-A Codable 测试明细（21 例，0 失败）

| 分组 | 用例 | 结果 |
|---|---|---|
| 骨架口径 | `testDefaultPluginStateIsUnknownAndUndetermined`、`testEnvelopeRoundTrip` | ✅ |
| 枚举原始值（R1，9 例） | `testJailbreakTypeRawValues`、`testOwnershipStatusRawValues`、`testLoadCategoryRawValues`、`testLoadedStateRawValues`、`testEvidenceLevelRawValues`、`testConfidenceRawValues`、`testPairingRawValues`、`testPermissionDecisionRawValue`、`testCoreFoundationModeRawValues`；既有 `testSourceTypeRawValues`、`testWritablePolicyRawValues` | ✅ |
| 全模型往返（R2） | `testFilterRuleRoundTrip`、`testOwnershipRoundTrip`、`testPluginRoundTrip`、`testEnvelopeRoundTripWithPlugin` | ✅ |
| nil / null / 缺失（R3、R4） | `testNilOptionalsSurviveRoundTrip`、`testMissingOptionalFieldsDecodeToNil` | ✅ |
| 空数组编码（R5） | `testEmptyArraysEncodeAsArrayNotNil`、`testEvidenceBlockEmptySourceStagesRoundTrip` | ✅ |

- R6（未知枚举原始值解码）：本批次未构造未知值输入，未锁定/未修改默认解码行为；结论留待后续批次按需观察，不在本批次修复。
- 本轮未改 Models 字段/枚举/原始值/解码行为，未改 Adapter 协议，未改 Stage 1 基线。

## 3. App Target 复验（沿用 2.1 闭环口径）

- 模拟器：`iPhone 17 Pro`，UDID `98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`；
- `launch com.filterkit.manager` PID **4693**；存活复查 `4693 0 UIKitApplication:com.filterkit.manager[648f][rb-legacy]`，存活 PID 4693 == 启动 PID 4693；
- 截图 `dashboard.png` 1206×2622：标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」、只读脚注，与 `DashboardView.swift` 逐字一致，中文渲染正常；
- 唯一无害告警：AppIntents 元数据提取跳过（骨架未用 AppIntents）。

## 4. Artifact

| Artifact | ID | 大小 | SHA256 |
|---|---|---|---|
| `filterkit-build-metadata` | 14172851309 | 6594 bytes | `d763df6aded2fe0f33eb5500e974b9937dc801a583b58b5592debba8b7cb0d2d` |
| `filterkit-test-log` | 14172795167 | 1184 bytes | `b835cc0f0fc11d03b8ab67de3705c6ad5eb975ee31a3370a97f73928f9f28b07` |
| `filterkit-app-build` | 14172880428 | 449101 bytes（9 文件） | `c7a7743e30b98b1ca5aa18b44e076a4a998710b35e0e55a12739ccaeb53dee99` |

- metadata 五文件（`Package.swift / Makefile / control / project.yml / .github/workflows/filterkit-build.yml`）与本地工作区逐字节一致；
- 全日志无 Node.js 20 deprecation、无 unhandled files 警告。

## 5. 边界与遗留

- 本轮仅验证 Codable 编译/往返/原始值/空数组与缺失解码的现有行为；未接入 Stage 1 fixture 行为深比较（属 2.2-E）；
- 包产品三元组 SPM 默认 iOS 12.0、App target 17.0 的观察项沿用 2.1 记录，打包阶段复核；
- 模拟器 3s 存活窗口不等于长期稳定性，不等于越狱权限通过（2.4）；Rootless 无真机；运行时隔离不在本轮；
- 2.2-A 验收通过后暂停，2.2-B（Environment / Path）须单独授权。
