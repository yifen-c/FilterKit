# RUN-METADATA.md — Engine-C2 第四轮 Runner 验收（通过，C-G1 / C-G2 关闭）

- Workflow run：`44021119037`；branch `C2-C3`；检出 SHA `ad443b151d9fddaa57dfac86ea58bbc33be8b8e1`。
- 本地基线：`767c3f5`（三轮对账回填；测试层修复 `d417965`）。远端检出因变基/压缩与本地链不一一同名，但第三轮两处失败对应套件本轮均 `passed`，可确认修复已包含在检出内容中。
- 时间：2026-11-17 05:01:15 ~ 05:07:12Z。
- 环境：macOS 26.7.2（25G332）/ `macos-26-arm64` 20261102.0473.1 / runner 2.338.2 / westus MacCloud；Xcode 26.6（17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；macOS SDK 26.5；测试平台 `arm64e-apple-macos14.0`。
- 基线文件一致性：`metadata/Package.swift`、`Makefile`、`control`、`project.yml`、`filterkit-build.yml` 与本地逐文件 diff 一致。

## 1. 门禁结论

| 验收门 | 结论 | 证据 |
|---|---|---|
| Core 三库 Build（Models / Adapters / Core） | ✅ `Build complete! (5.97s)`，0 error / 0 warning | `build/3_build.txt` |
| 全量 Swift 测试 | ✅ Executed **347 tests，3 skipped，0 failures（0 unexpected）** | `test/test-log.txt`、`test/3_Run full Swift test suite.txt` |
| **C-G1** Engine-B（`FilterParseEngineTests` 19 例） | ✅ 套件 `passed`，0 failure | `test/test-log.txt` |
| **C-G2** C3-C2 Rootless Parser（`RootlessFilterParserTests` 22 例） | ✅ 套件 `passed`，0 failure；Core Build / 既有回归 / S1-05 / App Build / 隔离复查均满足 §7 出证口径 | `test/test-log.txt`、`build/`、`isolation/`、`app-build/` |
| C2 新增 16 例（EndToEnd 6 / Batch 4 / Snapshot 6） | ✅ 0 failure；1 例 Rootless 对称挂起见 §3 | `test/test-log.txt` |
| C1 基线（Parser 8 / Engine 7） | ✅ 0 failure；2 例挂起见 §3 | `test/test-log.txt` |
| 既有回归 236 例 | ✅ 0 failure | 各既有套件 `passed` |
| S1-05 独立过滤（`PluginPairingS105FixtureTests` 15 例） | ✅ 15 tests，0 failures | `test/test-log-s105.txt`、`test/4_S1-05.txt` |
| Adapter / 路线隔离静态检查 | ✅ 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter | `isolation/3_isolation.txt` |
| App Simulator Build | ✅ `** BUILD SUCCEEDED **` | `app-build/app-xcodebuild.log` |
| App 存活与截图 | ✅ PID 10662 存活；iPhone 17 Pro（`5AB3DACF-C352-49D1-BF9A-3C0104FA4ED3`）；只读骨架首页截图归档 | `app-build/sim-launch.log`、`app-build/dashboard.png` |

## 2. 五类用例分列（347 = 236 既有 + 39 C3-C1 + 15 C1 基线 + 22 C-G2 + 19 C-G1 + 16 C2）

| 分组 | 套件 | 用例 | skip | fail |
|---|---|---:|---:|---:|
| C2 新增 | `EngineC2EndToEndTests` | 6 | 1 | 0 |
| C2 新增 | `EngineC2BatchIsolationTests` | 4 | 0 | 0 |
| C2 新增 | `EngineC2SnapshotWarningsTests` | 6 | 0 | 0 |
| C-G1 Engine-B | `FilterParseEngineTests` | 19 | 0 | 0 |
| C-G2 Rootless | `RootlessFilterParserTests` | 22 | 0 | 0 |
| C1 基线 | `EngineC1ParserBaselineTests` | 8 | 1 | 0 |
| C1 基线 | `EngineC1EngineBaselineTests` | 7 | 1 | 0 |
| C3-C1 | `FilterParseResultTests` | 7 | 0 | 0 |
| C3-C1 | `RootHideFilterParserTests` | 32 | 0 | 0 |
| 既有回归 | B5 三套件 6+4+10、ElleKit 15、Environment 7、JBRoot 10+18、Models 21、Plist 9+6+11、Enumeration 14、配对 Codable/Engine/Index/Integration/Key/Inventory 9+12+21+5+32+11、S1-05 15 | 236 | 0 | 0 |

> 基线覆盖数（S1-06 22 项）为规格口径，不与 XCTest 执行总数相加。

## 3. 挂起用例（XCTSkipIf，只记 skipped / pending，不计通过）

| 用例 | 文件 | 原因 |
|---|---|---|
| `EngineC1EngineBaselineTests.testFixtureEngineBaselines` | `EngineC1-EngineBaselineTests.swift:27` | PARSE-015-A 待 C3-C2 全链路出证（#151 / C-G2） |
| `EngineC1ParserBaselineTests.testRootlessBaselinePendingRunner` | `EngineC1-ParserBaselineTests.swift:163` | PARSE-015 待全链路出证 |
| `EngineC2EndToEndTests.testRootlessSymmetricPendingRunner` | `EngineC2-EndToEndTests.swift:135` | Rootless 完整链路待出证 |

C-G2 的 Parser 专项 22 例已由本轮关闭；上述 3 例为**完整 Engine 链路** Rootless 用例，归 C2-D2 双路线对称阶段解除挂起，本轮不计通过也不计失败。

## 4. 产物与归档

| Artifact | ID | 大小 | SHA256 | 下载 |
|---|---|---:|---|---|
| `filterkit-test-log.zip` | 14300912845 | 9419 B | `0d5263c37d875360b99914df77664fa5abf0d800367bb75e8060458479d75ed9` | https://github.com/yi-fen/FilterKit/actions/runs/44021119037/artifacts/14300912845 |
| `filterkit-app-build.zip` | 14300958224 | 1464973 B | `538cee97d06b85fe972d8e66ee62004c9083863c07f66845297f2de4c3548af3` | https://github.com/yi-fen/FilterKit/actions/runs/44021119037/artifacts/14300958224 |
| `filterkit-build-metadata.zip` | 14301467021 | 7513 B | `aae91e12d9bf282b48718345e7086038fd8051367d45e4e75342b9dc8c851ece` | https://github.com/yi-fen/FilterKit/actions/runs/44021119037/artifacts/14301467021 |

- 截图：`app-build/dashboard.png`；首页标题 FilterKit，环境「尚未检测」，权限「尚未验证（2.4 探针）」，副文案「本阶段为只读骨架；不含扫描、启停或写入功能」，与冻结骨架口径一致。
- 日志中 `::error::No available iPhone simulator found` / `App ... not found` / `PID is '-'` 为脚本兜底回显分支；最终 alive check `App alive: PID 10662`，非实际失败。

## 5. 边界与未决观察项

- PARSE-009-B 元素级下标 / 观测类型词与 Stage1 粗粒度报告差异仍挂起，待独立授权；本轮未改 Parser、未改基线期望。
- Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；未扫描真机目录，未修改 plist / 插件文件，未做启停 / 注入 / dpkg / 软链改动 / 配置写入；Parser 不推断 `loaded`。
- 本轮仅关闭 C-G1、C-G2 门禁；C2-D1~D4 为后续分批实现，每批单独提交、单独 Runner 验收；不改生产 Parser 迁就集成测试。
