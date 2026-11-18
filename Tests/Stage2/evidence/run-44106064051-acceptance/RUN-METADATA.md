# RUN-METADATA.md — Engine-C2 第五轮统一 Runner 验收（C-G1～G7 全过）

- Workflow run：`44106064051`；branch `D5`；检出 SHA `f4629f268e680bc0e25e911997d03959457263ec`。
- 本地基线：HEAD `1298edc`（2.2-D 规格冻结；代码面最近提交 `0d4315f`）。本地无远端，无法做逐行源码 diff；本轮核对：`metadata/Package.swift`、`Makefile`、`control`、`project.yml`、`filterkit-build.yml` 与本地逐文件 diff 一致；本地静态盘点 `func test` 共 **379**，与 Runner 实际执行 **379** 一一对应（套件类名与计数逐套件对齐）。Runner 检出 SHA 与本地 HEAD 不同名，归档结论以 Runner 实际日志为准，不声称本地 HEAD 已被本轮 Runner 逐行验证。
- 时间：2026-11-17 14:42:41 ~ 15:04:16Z（UTC）。
- 环境：macOS 26.7.2（25G332）/ `macos-26-arm64` 20261112.0504.1 / runner 2.338.2 / westus MacCloud；Xcode 26.6（17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；iOS Simulator SDK 26.5；目标 `arm64-apple-macosx26.0`。

## 1. 门禁结论

| 验收门 | 结论 | 证据 |
|---|---|---|
| Core 三库 Build（Models / Adapters / Core） | ✅ `Build complete! (8.44s)`，0 error / 0 warning | `build/3_build.txt` |
| 全量 Swift 测试 | ✅ Executed **379 tests，0 failures（0 unexpected），0 skipped** | `test-log/test-log.txt`、`logs/test/3_Run full Swift test suite.txt` |
| **C-G1** Engine-B（`FilterParseEngineTests` 19 例） | ✅ 套件 `passed`，0 failure / 0 skip；Core Build、既有回归、S1-05、App Build、隔离复查均满足出证口径 | `test-log/test-log.txt`、`build/`、`isolation/`、`app-build/` |
| **C-G2** C3-C2 Rootless Parser（`RootlessFilterParserTests` 22 例） | ✅ 套件 `passed`，0 failure / 0 skip；22 例全部有实际执行记录，无 `XCTSkipIf` 隐藏 | `test-log/test-log.txt` |
| **C-G3** S1-06 22 项基线映射对照 | ✅ 注册表自校验 `testRegistryHasTwentyTwoUniqueCases` 通过；Parser 8 例 + Engine 7 例 `passed`，0 failure / 0 skip | `test-log/test-log.txt` |
| **C-G4** 双路线隔离 | ✅ 路线选边 / 不跨路线回退 6 例、批次隔离 4 例、Engine-B 不回退用例通过；隔离脚本 1a/1b/2a/2b 四项 OK | `test-log/test-log.txt`、`isolation/3_isolation.txt` |
| **C-G5** 五态与 Counts 不变量 | ✅ Snapshot/Warnings 6 例、组合场景 5 例、集成校验器不变量断言通过 | `test-log/test-log.txt` |
| **C-G6** 既有回归全部通过 | ✅ 既有 275 例（见 §2 分组）0 failure / 0 skip | `test-log/test-log.txt` |
| **C-G7** App Build + 架构隔离 | ✅ `** BUILD SUCCEEDED **`；PID 3508 存活；只读骨架截图归档；隔离脚本第 4 项 App→Core OK；七方法协议签名未演进 | `app-build/`、`isolation/3_isolation.txt` |
| S1-05 独立过滤（`PluginPairingS105FixtureTests` 15 例） | ✅ 15 tests，0 failures | `test-log/test-log-s105.txt`、`logs/test/4_Run S1-05 pairing mapping tests (independent filter).txt` |
| Adapter / 路线隔离静态检查（Runner 实际执行） | ✅ `bash scripts/check-adapter-isolation.sh` 六项输出 OK，结尾「隔离检查通过（静态文本层面）」；脚本由 CI `isolation` job 实际执行，非本机自检 | `isolation/3_isolation.txt`、`metadata/filterkit-build.yml` |

## 2. 五类用例分列（379 = 275 既有 + 19 C-G1 + 22 C-G2 + 15 C1 + 16 C2-A~C + 21 C2-D + 11 E 组织自校验）

> 基线覆盖数（S1-06 22 项、S1-05 15 项）为规格口径，不与 XCTest 执行总数相加。

| 分组 | 套件 | 用例 | skip | fail |
|---|---|---:|---:|---:|
| C-G1 Engine-B | `FilterParseEngineTests` | 19 | 0 | 0 |
| C-G2 Rootless | `RootlessFilterParserTests` | 22 | 0 | 0 |
| C1 基线 | `EngineC1ParserBaselineTests` | 8 | 0 | 0 |
| C1 基线 | `EngineC1EngineBaselineTests` | 7 | 0 | 0 |
| C2-A~C | `EngineC2EndToEndTests` | 6 | 0 | 0 |
| C2-A~C | `EngineC2BatchIsolationTests` | 4 | 0 | 0 |
| C2-A~C | `EngineC2SnapshotWarningsTests` | 6 | 0 | 0 |
| C2-D | `EngineC2BaselineIntegrationTests` | 2 | 0 | 0 |
| C2-D | `EngineC2RouteSymmetryTests` | 6 | 0 | 0 |
| C2-D | `EngineC2EvidenceTraceTests` | 8 | 0 | 0 |
| C2-D | `EngineC2CombinedScenarioTests` | 5 | 0 | 0 |
| E 组织自校验 | `EngineC2ERegressionPlanTests` | 11 | 0 | 0 |
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
| 既有回归 | `RootHideFilterParserTests` | 32 | 0 | 0 |

## 3. 挂起与解除挂起核对

- 本轮全量 **0 skipped**；第四轮 3 例 `XCTSkipIf`（PARSE-015-A Parser 层、PARSE-015-A Engine 层、Rootless 对称端到端）对应用例本轮均实际执行并 `passed`，注册表 `pendingRunner` 标记已解除。
- 代码中保留的 `XCTSkipIf(baseline.pendingRunner, ...)` 为条件守卫：本轮注册表无 `pendingRunner == true` 条目，守卫未触发；不构成 Skip 记录。
- **PARSE-009-B** 继续独立挂起：元素级下标 / 观测类型词与 Stage1 粗粒度报告口径差异，待独立授权复核；本轮未改 Parser、未改基线期望。

## 4. 产物与归档

| Artifact | Artifact ID | 大小 | SHA256 |
|---|---:|---:|---|
| `filterkit-test-log.zip` | 14338367472 | 10194 B | `6d1458e6a6064be36144af5faf94b5c6fe11f9686c5688d5b1ef3799eaaf8487` |
| `filterkit-app-build.zip` | 14339497228 | 1466021 B | `0b59f0fd4b6aeb65fadb085b947d74c7dddd830448efd138d6a574c0c4207d8f` |
| `filterkit-build-metadata.zip` | 14339957319 | 7569 B | `bee890ac88abfefd34515d069964e5e92767ced99bbf0e0c0e0b0c423002351e` |

- 截图：`app-build/dashboard.png`（MD5 `e9e1f79c334c912e0989baa42ba2a83f`，1206×2622）；首页标题 FilterKit，环境「尚未检测」，权限「尚未验证（2.4 探针）」，副文案「本阶段为只读骨架；不含扫描、启停或写入功能」，与冻结骨架口径一致。
- 模拟器：iPhone 17 Pro（`98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`）；bundle `com.filterkit.manager`；launch PID 3508，alive check `App alive: PID 3508`。
- 日志中 `::error::No available iPhone simulator found` / `App ... not found` / `PID is '-'` 为脚本兜底回显分支；最终 alive check 通过，非实际失败。
- App 构建仅 1 条 `appintentsmetadataprocessor` 提示：未链接 AppIntents.framework，元数据提取跳过；非代码告警，不计入 warning 计数。

## 5. 边界与未决观察项

- 工作流无独立的「夹具完整性」job；夹具完整性由内嵌回归覆盖：S1-05 15 例独立过滤、B5 夹具深比较 4 例、C1 基线夹具加载用例本轮全部通过。未另设独立夹具校验脚本。
- Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；未扫描真机目录，未修改 plist / 插件文件，未做启停 / 注入 / dpkg / 软链改动 / 配置写入；Parser 不推断 `loaded`。
- 归属识别（`Core/OwnershipResolver/`）与统一报告 / JSON 导出属 Stage 2.2-D，本阶段未实现；本轮未改 Core 生产逻辑、Models、Adapters、七方法协议、冻结 Parser 与 Stage1 fixtures。
- 观察项（不阻塞本轮门禁）：JSONSerialization 还原 NSNumber/NSNull 与 TypeChecker 桥接；Rootless Codable 桩输入行为；`Dictionary(uniqueKeysWithValues:)` 键唯一性；合法根三数组齐备时 mapper 是否零条目告警。
