# RUN-METADATA.md — 第十七轮（Stage 2.2-C2-D2 验收轮：六 Job 全绿，C2 配对层 Runner 验收通过）

- Run ID：**118727393219**（Actions run `43857670397`）；仓库 `yi-fen/FilterKit` / 分支 `C2`；工作流 `filterkit-build.yml`。
- Runner SHA：`ce118319ec6940ac688d9fd08895474fe1e34c28`（fetch-depth 1；本地提交链锚点 `64420bb`，runner 侧 hash 由外部推送/变基产生）。
- 时间：2026-11-16 11:25:54Z ~ 11:35:25Z；全量 `swift test` 11:30:56 完成；S1-05 独立过滤 11:31:03 完成。
- Runner：macOS 26.7.2（Build 25G332），镜像 `macos-26-arm64` 20261112.0504.1；Provisioner 20261103.629；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 工具链：Xcode 26.6；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5 / Simulator iOS 26.5 / macOS 26.5；swift-driver 1.148.6；测试目标 `arm64e-apple-macos14.0`，Testing Library 1902。

## 1. Job 结果总览（全部 success）

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链/镜像版本落盘（见上） |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (17.41s)`；Core 63 源全部编译，0 error / 0 warning |
| isolation | ✅ success | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| test（Stage2Tests） | ✅ success | 全量 `swift test` **210 tests, 0 failures**；`--filter PluginPairingS105FixtureTests` 独立 **15 tests, 0 failures** |
| app-build | ✅ success | `** BUILD SUCCEEDED **`；模拟器安装启动，复查存活 `PID 3991`（`UIKitApplication:com.filterkit.manager`）；截图 `build/dashboard.png`（1206×2622，122,086 字节 PNG） |
| artifact | ✅ success | 三个产物上传成功（见 §4） |

> 观察项（不影响结论）：app-build 存活首次复查未在 launchctl 列表命中，脚本分支打印 `::error::` 提示后复查命中 PID 3991 并截图；Job 最终 evaluated success。存活仅证明 Simulator 进程启动，不证明越狱目录访问权限；SDK 26.5 不作为 Theos 16.5 兼容证据（沿用未决观察项）。

## 2. 全量测试分套件计数（Runner 实际发现，0 failure / 0 unexpected）

| 套件 | 分组 | 执行 | 失败 |
|---|---|---:|---:|
| ModelsCodableTests | B 阶段回归 | 21 | 0 |
| EnvironmentDetectionTests | B 阶段回归 | 7 | 0 |
| JBRootCandidateCollectionTests | B 阶段回归 | 10 | 0 |
| JBRootValidationTests | B 阶段回归 | 18 | 0 |
| ElleKitDirectoryTests | B 阶段回归 | 15 | 0 |
| B5IntegrationTests | B 阶段回归 | 10 | 0 |
| B5FixtureComparisonTests | B 阶段回归 | 4 | 0 |
| B5DeterminismTests | B 阶段回归 | 6 | 0 |
| **B 回归小计** | | **91** | **0** |
| PluginEnumerationTests | C1 Enumeration | 14 | 0 |
| PluginInventoryCodableTests | C1 Enumeration | 9 | 0 |
| **C1 小计** | | **23** | **0** |
| PluginPairingCodableTests | C2-A Models/Codable | 12 | 0 |
| PluginPairingKeyTests | C2-B Key/Engine | 11 | 0 |
| PluginPairingIndexTests | C2-B Key/Engine | 5 | 0 |
| PluginPairingEngineTests | C2-B Key/Engine | 21 | 0 |
| **C2-B 小计** | | **37** | **0** |
| PluginPairingIntegrationTests | C2-C Integration | 32 | 0 |
| **C2-C 小计** | | **32** | **0** |
| PluginPairingS105FixtureTests | S1-05 原始基线映射 | 15 | 0 |
| **合计** | | **210** | **0** |

## 3. 四类数字（按验收清单 §3 分列，不混算）

1. **XCTest 实际执行数量**：210（Runner `swift test` 发现并执行；0 failure、0 unexpected、未见跳过）。
2. **Stage 1 原始基线映射覆盖数量**：S1-04 枚举 23（PluginEnumeration 14 + PluginInventoryCodable 9）+ S1-05 配对映射 15 = **38**。
3. **新增专项测试数量**：C2-A 12 + C2-B 37 + C2-C 32 = **81**（合成专项，不计入原始基线映射）。
4. **架构静态检查**：双路线隔离三向 OK；公共 Models 契约未改（`Pairing` 四值封闭、`ReportEnvelope` 未改、集成结果留 Core）；Stage 1 fixtures/harness 自 C1 验收 `5b481e6` 起零改动（`git diff 5b481e6..HEAD -- Tests/Fixtures/` 为空）；确定性由 B5 确定性套件与 PAIR-013 合成用例覆盖；App Build iOS Simulator 成功。

## 4. 产物归档

| Artifact | ID | 字节 | SHA256 |
|---|---|---:|---|
| `filterkit-build-metadata.zip` | 14222656867 | 7,188 | `49af5e23da82a5061fde374bbaad0e262989a44177fbab695d9f8c157c8001d5` |
| `filterkit-app-build.zip` | 14222157455 | 1,210,287 | `c030e51f05b60838d2255320ddb7246a98925c972779554f79f483a687850790` |
| `filterkit-test-log.zip` | 14221662179 | 6,279 | `25768bfc631c7d5ba22a34efc33c5ecea1e96cbc8b51511d8327b7df0e079841` |

下载前缀：`https://github.com/yi-fen/FilterKit/actions/runs/43857670397/artifacts/<ID>`。
本地归档：`Tests/Stage2/evidence/run-43857670397/`（`logs/<job>/` 步骤日志、`test-log/` 双日志、`app-build/` 截图/启动日志/xcodebuild 日志、`metadata/` 工程清单快照、`acceptance-report.md`）。

## 5. 边界与未决项（沿用，不在本批评收口）

- 本结论仅限离线 Core 数据处理链路（枚举 + 配对）；不代表 GUI 已可扫描 RootHide 真机，不证明越狱目录访问权限。
- 2.2-A R6 未知枚举原始值默认解码行为仍未真机实测；Deployment Target / iOS 17 兼容、Rootless 无真机、Runner SDK 版本不作为 Theos 16.5 兼容证据。
- C3（Filter plist 解析）、归属识别、插件启停与真机操作须另行授权，本批未进入。
