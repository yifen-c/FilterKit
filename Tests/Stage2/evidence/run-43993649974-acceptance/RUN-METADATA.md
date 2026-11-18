# RUN-METADATA.md — C3-C1 第三轮 Runner 验收（通过）

- Workflow run：`43993649974`；branch `C3-C1`；检出 SHA `919185b10df94f057d31c6cf36a9b237d1973218`。
- 本地对应提交：`245ea12`（第二轮 test 失败修复后 HEAD）；`metadata/Package.swift`、`Makefile`、`control`、`project.yml`、`filterkit-build.yml` 与本地逐文件 diff 一致。
- 时间：2026-11-17 01:11~01:17Z。
- 环境：macOS 26.7.2（25G332）/ macos-26-arm64 20261102.0473.1 / runner 2.338.2 / westus MacCloud；Xcode 26.6 (17F113)，iPhoneSimulator26.5 SDK；Testing Library 1902；测试 Target Platform `arm64e-apple-macos14.0`；App deployment-target 17.0，Models/Adapters/Core 12.0。

## 1. 验收结果总览

| 验收门 | 结论 | 证据 |
|---|---|---|
| Core 三库 Build | ✅ `Build complete! (29.74s)`，0 error | `build/3_build.txt` L112 |
| 全量 Swift 测试 | ✅ Executed 275 tests，0 failures（0 unexpected） | `test/test-log.txt` |
| 既有回归（236 例） | ✅ 0 失败 | `test/test-log.txt` 各既有套件 |
| C3-C1 新增专项（39 例） | ✅ Result 7 + RootHide 32，全过 | `FilterParseResultTests` 7；`RootHideFilterParserTests` 32 |
| S1-05 独立过滤 | ✅ 15 tests，0 failures | `test/test-log-s105.txt` |
| Adapter/路线隔离静态检查 | ✅ 三项 OK | `isolation/3_isolation.txt` |
| App Simulator Build | ✅ `** BUILD SUCCEEDED **` | `app-build/app-xcodebuild.log` |
| App 存活与截图 | ✅ PID 3786 存活；骨架首页截图归档 | `app-build/sim-launch.log`、`app-build/dashboard.png` |

## 2. 套件用例分布（275 = 236 既有 + 39 新增）

| 套件 | 用例数 | 归属 |
|---|---:|---|
| B5DeterminismTests | 6 | 既有 |
| B5FixtureComparisonTests | 4 | 既有 |
| B5IntegrationTests | 10 | 既有 |
| ElleKitDirectoryTests | 15 | 既有 |
| EnvironmentDetectionTests | 7 | 既有 |
| FilterParseResultTests | 7 | **C3-C1 新增** |
| JBRootCandidateCollectionTests | 10 | 既有 |
| JBRootValidationTests | 18 | 既有 |
| ModelsCodableTests | 21 | 既有 |
| PlistDecoderTests | 9 | 既有 |
| PlistReaderTests | 6 | 既有 |
| PlistValueKindTests | 11 | 既有 |
| PluginEnumerationTests | 14 | 既有 |
| PluginInventoryCodableTests | 9 | 既有 |
| PluginPairingCodableTests | 12 | 既有 |
| PluginPairingEngineTests | 21 | 既有 |
| PluginPairingIndexTests | 5 | 既有 |
| PluginPairingIntegrationTests | 32 | 既有 |
| PluginPairingKeyTests | 11 | 既有 |
| PluginPairingS105FixtureTests | 15 | 既有（S1-05 独立过滤另跑 15 例 0 失败） |
| RootHideFilterParserTests | 32 | **C3-C1 新增** |

## 3. 产物与归档

- 测试日志 artifact：`filterkit-test-log`，ID `14287879523`，7590 bytes，SHA256 `251fb79f31ddc6648c5cef2385c158bf1fc194625f37aca2bd50c38c22b32291`；下载 `https://github.com/yi-fen/FilterKit/actions/runs/43993649974/artifacts/14287879523`。
- App 构建 artifact：`filterkit-app-build`，ID `14289655313`，1338290 bytes，SHA256 `d1fe2ec52b7874e1ef697212a8adc5920517bd32c1da0c27b543b196d92271c8`；下载 `https://github.com/yi-fen/FilterKit/actions/runs/43993649974/artifacts/14289655313`。
- 隔离检查：RootHide 未引用 Rootless OK；Rootless 未引用 RootHide OK；Core 未直接实例化具体 Adapter OK（静态文本层面）。
- 截图：`app-build/dashboard.png`，iPhone 17 Pro（`98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`）；首页只读骨架，无扫描/启停/写入入口。

## 4. 边界与未决观察项

- 本批仅 RootHide 严格解析 + 统一 Result 模型；Rootless Parser、双路线 Engine、Snapshot/Counts/Input、路线选边均未实现（C3-C2 / C3-C3 待独立授权）。
- Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；iOS 17.0.2 真机 plist 格式与字段分布待只读取证；CFV 浮点版本号语义、未知枚举默认解码、Rootless 真机行为仍为观察项。
- 全程未扫描真机目录、未修改 plist/插件文件、未做启停/注入/dpkg/软链改动/配置写入；Parser 不推断 `loaded`。
