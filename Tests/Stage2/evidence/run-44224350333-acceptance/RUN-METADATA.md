# RUN-METADATA.md — 0.1-B Stage 2.2-D Reporting 第四轮统一 Runner 验收（全绿）

- Workflow run：`44224350333`；branch `2.2-D`；检出 SHA `9a3f087f6a699cf3390aad42668e5fed5be3d378`；工作流文件 `.github/workflows/filterkit-build.yml@refs/heads/2.2-D`。
- 本地基线：HEAD `94bd7f2`（第三轮断言修复）。本轮核对：`metadata/Package.swift`、`Makefile`、`control`、`project.yml`、`filterkit-build.yml` 与本地逐文件 diff 一致；`Models / Core / Tests / Adapters` 源码面与本地 `94bd7f2` 无差异；第三轮两处修复（`Plugin.encode(to:)` 显式落 `null`、Validator RV-003 样本直接构造 `Plugin`）在 Runner 检出树内确认存在。Runner 检出 SHA 与本地 HEAD 不同名（历史远程经网页上传），归档结论以 Runner 实际日志为准，不声称本地 HEAD 已被本轮 Runner 逐行重新编译验证。
- 时间：2026-11-18 02:35:14 ~ 02:42:02Z（UTC）。
- 环境：macOS 26.7.2（25G332）/ `macos-26-arm64` 20261102.0473.1 / runner 2.338.2 / westus MacCloud；Xcode 26.6（17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；swift-driver 1.148.6；iOS Simulator SDK 26.5；测试目标 `arm64e-apple-macos14.0`。

## 1. 门禁结论

| 验收门 | 结论 | 证据 |
|---|---|---|
| Core 三库 Build（Models / Adapters / Core，非 UI 目标） | ✅ `Build complete! (19.62s)`，0 error / 0 warning | `build/3_build.txt` |
| 全量 Swift 测试 | ✅ Executed **397 tests，0 failures（0 unexpected），0 skipped** | `test-log/test-log.txt`、`logs/test/3_Run full Swift test suite.txt` |
| **D2** Report Builder（`ReportBuilderTests` 6 例） | ✅ 套件 `passed`，0 failure；Builder-001～006 全部有实际执行记录 | `test-log/test-log.txt` |
| **D3** Report Validator（`ReportValidatorTests` 4 例） | ✅ 套件 `passed`，0 failure；第三轮失败的 `testValidator002InjectsInconsistenciesAndKeepsOriginal` 本轮 `passed (0.000s)` | `test-log/test-log.txt` |
| **D4** JSON Exporter（`ReportExporterTests` 5 例） | ✅ 套件 `passed`，0 failure；第三轮失败的 `testExporter002OptionalBoolThreeStatesSurvive` 本轮 `passed (0.001s)`，`installed=nil` 显式落 JSON `null` 三态断言通过 | `test-log/test-log.txt` |
| **D5** Report Service（`ReportServiceTests` 3 例） | ✅ 套件 `passed`，0 failure；Builder→Validator→Exporter 往返与接缝注入用例通过 | `test-log/test-log.txt` |
| 既有回归（379 例，0.1-A Engine C2 收口基线） | ✅ 0 failure / 0 skip；无损伤 | `test-log/test-log.txt` |
| S1-05 独立过滤（`PluginPairingS105FixtureTests` 15 例） | ✅ 15 tests，0 failures | `test-log/test-log-s105.txt`、`logs/test/4_Run S1-05 pairing mapping tests (independent filter).txt` |
| Adapter / 路线隔离静态检查（Runner 实际执行） | ✅ `bash scripts/check-adapter-isolation.sh` 四项输出 OK，结尾「隔离检查通过（静态文本层面）」；脚本由 CI `isolation` job 实际执行，非本机自检 | `isolation/3_isolation.txt`、`metadata/filterkit-build.yml` |
| App Build + 模拟器存活 | ✅ XcodeGen 生成工程后 `** BUILD SUCCEEDED **`；iPhone 17 Pro 模拟器 Booted，bundle `com.filterkit.manager`，PID 4096 alive check 通过；只读骨架截图归档 | `app-build/`、`logs/app-build/` |
| 全量日志错误扫描 | ✅ 无 `##[error]`、无 `exit code 1`、无 `FAILED`；非 UI Build 0 warning | `logs/` 全量 job 日志 |

## 2. 用例分列（397 = 379 既有回归 + 18 Reporting 新用例）

> 基线覆盖数（S1-05 15 项）为规格口径，不与 XCTest 执行总数相加。

| 分组 | 套件 | 用例 | skip | fail |
|---|---|---:|---:|---:|
| D2 Reporting | `ReportBuilderTests` | 6 | 0 | 0 |
| D3 Reporting | `ReportValidatorTests` | 4 | 0 | 0 |
| D4 Reporting | `ReportExporterTests` | 5 | 0 | 0 |
| D5 Reporting | `ReportServiceTests` | 3 | 0 | 0 |
| 既有回归 Engine-B | `FilterParseEngineTests` | 19 | 0 | 0 |
| 既有回归 Rootless | `RootlessFilterParserTests` | 22 | 0 | 0 |
| 既有回归 RootHide | `RootHideFilterParserTests` | 32 | 0 | 0 |
| 既有回归 C1 | `EngineC1ParserBaselineTests` | 8 | 0 | 0 |
| 既有回归 C1 | `EngineC1EngineBaselineTests` | 7 | 0 | 0 |
| 既有回归 C2-A~C | `EngineC2EndToEndTests` | 6 | 0 | 0 |
| 既有回归 C2-A~C | `EngineC2BatchIsolationTests` | 4 | 0 | 0 |
| 既有回归 C2-A~C | `EngineC2SnapshotWarningsTests` | 6 | 0 | 0 |
| 既有回归 C2-D | `EngineC2BaselineIntegrationTests` | 2 | 0 | 0 |
| 既有回归 C2-D | `EngineC2RouteSymmetryTests` | 6 | 0 | 0 |
| 既有回归 C2-D | `EngineC2EvidenceTraceTests` | 8 | 0 | 0 |
| 既有回归 C2-D | `EngineC2CombinedScenarioTests` | 5 | 0 | 0 |
| 既有回归 E 自校验 | `EngineC2ERegressionPlanTests` | 11 | 0 | 0 |
| 既有回归 | `EnvironmentDetectionTests` | 7 | 0 | 0 |
| 既有回归 | `JBRootCandidateCollectionTests` | 10 | 0 | 0 |
| 既有回归 | `JBRootValidationTests` | 18 | 0 | 0 |
| 既有回归 | `ElleKitDirectoryTests` | 15 | 0 | 0 |
| 既有回归 | `PluginEnumerationTests` | 14 | 0 | 0 |
| 既有回归 | `PluginPairingKeyTests` | 11 | 0 | 0 |
| 既有回归 | `PluginPairingIndexTests` | 5 | 0 | 0 |
| 既有回归 | `PluginPairingEngineTests` | 21 | 0 | 0 |
| 既有回归 | `PluginPairingIntegrationTests` | 32 | 0 | 0 |
| 既有回归 | `PluginPairingCodableTests` | 12 | 0 | 0 |
| 既有回归 | `PluginPairingS105FixtureTests` | 15 | 0 | 0 |
| 既有回归 | `PlistReaderTests` | 6 | 0 | 0 |
| 既有回归 | `PlistDecoderTests` | 9 | 0 | 0 |
| 既有回归 | `PlistValueKindTests` | 11 | 0 | 0 |
| 既有回归 | `B5IntegrationTests` | 10 | 0 | 0 |
| 既有回归 | `B5FixtureComparisonTests` | 4 | 0 | 0 |
| 既有回归 | `B5DeterminismTests` | 6 | 0 | 0 |
| 既有回归 | `ModelsCodableTests` | 21 | 0 | 0 |
| 既有回归 | `PluginInventoryCodableTests` | 9 | 0 | 0 |
| 既有回归 | `FilterParseResultTests` | 7 | 0 | 0 |

## 3. 挂起与解除挂起核对

- 本轮全量 **0 skipped**；测试日志无 `XCTSkip` / `pendingRunner` 记录。
- **PARSE-009-B** 继续独立挂起：元素级下标 / 观测类型词与 Stage1 粗粒度报告口径差异，待独立授权复核；本轮未改 Parser、未改基线期望。
- 第三轮两处断言失败本轮复验通过：`ReportExporterTests.testExporter002OptionalBoolThreeStatesSurvive`（三态 `Bool?` nil 显式 `null`）、`ReportValidatorTests.testValidator002InjectsInconsistenciesAndKeepsOriginal`（RV-003 矛盾路径证据注入）。

## 4. 产物与归档

| Artifact | Artifact ID | 大小 | SHA256 |
|---|---:|---:|---|
| `filterkit-test-log.zip` | 14392112483 | 10851 B | `bde79cf4135386fda5087fddc9d9808a46a894ad20fd1294f2b356a698ec3e77` |
| `filterkit-app-build.zip` | 14391852889 | 1596264 B | `f24038cb2d112462d592068427b1fffe3b3ae8c9175e43427f8dca1bc87db063` |
| `filterkit-build-metadata.zip` | 14392960956 | 7622 B | `afbfb2206f5172fd8e77aafeccd6476e0341498c9ba4132c004a05c9f54b0fcf` |

- 下载页：`https://github.com/yi-fen/FilterKit/actions/runs/44224350333/artifacts/14392112483`（test-log）；`…/artifacts/14391852889`（app-build）；`…/artifacts/14392960956`（metadata）。
- 截图：`app-build/dashboard.png`（MD5 `9e2d2db7c427e7a364073db2b60a4da9`，1206×2622）；首页标题 FilterKit，环境「尚未检测」，权限「尚未验证（2.4 探针）」，副文案「本阶段为只读骨架；不含扫描、启停或写入功能」，与冻结骨架口径一致。
- 模拟器：iPhone 17 Pro（`98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`）；bundle `com.filterkit.manager`；launch PID 4096，alive check `App alive: PID 4096`。
- App 构建仅 1 条 `appintentsmetadataprocessor` 提示：未链接 AppIntents.framework，元数据提取跳过；非代码告警，不计入 warning 计数。

## 5. 边界与未决观察项

- Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；未扫描真机目录，未修改 plist / 插件文件，未做启停 / 注入 / dpkg / 软链改动 / 配置写入；Parser 不推断 `loaded`。
- 归属识别（`Core/OwnershipResolver/`）仍未迁移，单列后续批次；0.1-B 的 D2/D5 归属由已解析快照注入，`loaded` 恒 `.unknown`，`pluginID` 稳定标识规则 0.2.0 定稿。
- 本轮未改冻结公共 Models 字段 / init / 解码契约、七方法 `ElleKitAdapter` 协议、Parser 语义与 Stage1 fixtures；未实现 GUI / entitlement / 进程内 `jbroot()`。
- 本批次为 CI/Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据；0.1-C GUI、0.1-D 探针真机仍需单独授权。
