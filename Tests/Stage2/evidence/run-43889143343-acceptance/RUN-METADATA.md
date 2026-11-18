# RUN-METADATA.md — C3-B 第五轮（macOS Runner 验收：build / test / app-build / 隔离 全绿）

- Actions run：`43889143343`；仓库 `yi-fen/FilterKit` / 分支 `C3`；Runner SHA `11f8b7f8e5cd7beeefac36d6501dcc3aba081422`。
- 时间：2026-11-16 14:45:48Z 起，14:56:31Z 归档完成。
- 环境：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；westus / MacCloud；Xcode 26.6（17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3，clang-2100.1.1.101）；swift-driver 1.148.6；iPhoneSimulator 26.5 SDK；deployment-target 17.0。
- 产物：test artifact `filterkit-test-log` ID `14236810658`；app-build artifact `filterkit-app-build` ID `14235214997`。

## 1. 验收门槛逐项核对

| 门槛 | 结论 | 证据 |
|---|---|---|
| 非 UI 三库 Build（Models / Adapters / Core） | ✅ 通过 | `build/3_build.txt`：Core 71 文件编译，`Build complete! (18.34s)`，无 error / warning |
| 全量 `swift test` | ✅ 236 例 0 失败 | `test/test-log.txt`：`Executed 236 tests, with 0 failures (0 unexpected)` |
| S1-05 配对映射独立 `--filter` | ✅ 15 例 0 失败 | `test/test-log-s105.txt`：`Executed 15 tests, with 0 failures (0 unexpected)` |
| Adapter 隔离复查 | ✅ 通过 | `isolation/3_isolation.txt`：`OK` ×3；Core 未直接实例化具体 Adapter |
| App Simulator Build | ✅ BUILD SUCCEEDED | `app-build/app-xcodebuild.log`：`** BUILD SUCCEEDED **`，0 error |
| App 存活与截图 | ✅ 存活 | `app-build/sim-launch.log`：PID 3928，`UIKitApplication:com.filterkit.manager` 在位；`app-build/dashboard.png` 1206×2622 只读骨架首页 |
| 构建元数据一致性 | ✅ 一致 | `metadata/Package.swift` 与本地逐字节相同；`Makefile / control / project.yml / filterkit-build.yml` 一并归档 |

## 2. 测试套件明细（全量 236 例，0 失败）

| 套件 | 例数 | 失败 |
|---|---:|---:|
| B5DeterminismTests | 6 | 0 |
| B5FixtureComparisonTests | 4 | 0 |
| B5IntegrationTests | 10 | 0 |
| ElleKitDirectoryTests | 15 | 0 |
| EnvironmentDetectionTests | 7 | 0 |
| JBRootCandidateCollectionTests | 10 | 0 |
| JBRootValidationTests | 18 | 0 |
| ModelsCodableTests | 21 | 0 |
| PlistDecoderTests（C3-B） | 9 | 0 |
| PlistReaderTests（C3-B） | 6 | 0 |
| PlistValueKindTests（C3-B） | 11 | 0 |
| PluginEnumerationTests | 14 | 0 |
| PluginInventoryCodableTests | 9 | 0 |
| PluginPairingCodableTests | 12 | 0 |
| PluginPairingEngineTests | 21 | 0 |
| PluginPairingIndexTests | 5 | 0 |
| PluginPairingIntegrationTests | 32 | 0 |
| PluginPairingKeyTests | 11 | 0 |
| PluginPairingS105FixtureTests | 15 | 0 |
| **合计** | **236** | **0** |

> 口径：既有基线 210 例 + C3-B 新增 26 例（Reader 6 / Decoder 9 / 类型识别 11）。第四轮 3 处失败（Decoder 夹具单 token、B5 键序）在本轮全部转绿。

## 3. 边界复核

- 本轮证据未改动 Models / Adapters / 七方法协议 / C1 / C2 冻结源码 / Stage 1 fixtures 与 harness；隔离脚本确认 Core 未装配具体 Adapter。
- App 首页仍为只读骨架：环境「尚未检测」、权限「尚未验证（2.4 探针）」；不含扫描、启停或写入功能。
- 未决观察项（不影响本轮验收）：R6 未知枚举默认解码未真机实测；iOS17 / Deployment Target 兼容以 Simulator 26.5 SDK 出证，不作 Theos 16.5 兼容证据；Rootless 无真机；Runner SDK 版本与真机 plist 格式/字段分布待只读取证。

## 4. 结论

C3-B（Plist Reader / Decoder）macOS Runner 验收通过：编译、236 例全量回归、S1-05 独立过滤、隔离复查、App Build 与存活截图均有归档证据。可按分阶段计划进入 C3-C1（统一 Result + RootHide Parser）；Rootless Parser、双路线 Engine、S1-06 22 项基线映射分别留待 C3-C2 / C3-C3 独立授权。
