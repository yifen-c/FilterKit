# RUN-METADATA.md — 第十四轮（Stage 2.2-C1 Plugin Enumeration Runner 验收通过）

- Run ID：**43825045361**；仓库 `yi-fen/FilterKit` / 分支 `C1`；工作流 `filterkit-build.yml`。
- Runner SHA：`cd13c99891d1c04862b2b12dd859ab2cb7285282`（fetch-depth 1）；对应本地提交链锚点 `b6b4cef`（2.2-C1 代码冻结）。runner 侧 `Package.swift` 接线与本地逐一 diff 一致（Core 8 个枚举器源 + 2 个 C1 测试源）。
- 时间：2026-11-16 07:36:40Z ~ 07:43:12Z。
- Runner：macOS 26.7.2（Build 25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；git 2.56.0。
- 工具链：Xcode 26.6（Build 17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5 / Simulator iOS 26.5；Testing Library 1902；测试平台 arm64e-apple-macos14.0。
- 归档产物（GitHub Actions Artifact，保留 14 天）：
  - `filterkit-build-metadata`（Artifact ID 14205873975，6947 字节；`Package.swift`/`control`/`Makefile`/`project.yml`/`filterkit-build.yml`）；
  - `filterkit-test-log`（Artifact ID 14205793915，压缩 3522 字节，内 `test-log.txt` 28125 字节）；
  - `filterkit-app-build`（Artifact ID 14206012635，1071424 字节；含 xcodebuild 日志、启动日志、截图与 `.app` 产物，本地归档按既有口径只留日志与截图，不含 DerivedData 二进制）。

## 1. Job 结果总览

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链/镜像版本落盘，无 error |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (18.08s)`；C1 新增 Core 8 源（`EnumerationStatus`/`PluginKindCounts`/`PluginInventoryFixtureSignal`/`PluginEntryClassifier`/`PluginFileEvidenceBuilder`/`PluginInventorySnapshot`/`PluginInventoryBuilder`/`PluginDirectoryEnumerator`）均编译通过 |
| test（Stage2Tests） | ✅ success | **Executed 114 tests, with 0 failures (0 unexpected)**；0 skipped、0 error、0 编译告警 |
| isolation | ✅ success（静态文本层面） | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| app-build | ✅ success | `** BUILD SUCCEEDED **`；模拟器 install/launch；存活复查 PID 3740；截图归档 |
| artifact | ✅ success | build-metadata、test-log、app-build 三个 artifact 上传成功 |

## 2. 测试明细（114 例，0 失败）

测试命令为整包 `swift test 2>&1 | tee .build/test-log.txt`（未分阶段 `--filter`；沿用既有口径）。

### 2.1 既有 91 例冻结/附加回归（零损伤，0 失败）

| 测试套件 | 方法数 | 批次 | 结果 |
|---|---:|---|---|
| `ModelsCodableTests` | 21 | 2.2-A Codable | ✅ 21/21 |
| `EnvironmentDetectionTests` | 7 | B1 环境识别 | ✅ 7/7 |
| `JBRootCandidateCollectionTests` | 10 | B2 候选收集 | ✅ 10/10 |
| `JBRootValidationTests` | 18 | B3 校验/裁决 | ✅ 18/18 |
| `ElleKitDirectoryTests` | 15 | B4 目录/软链 | ✅ 15/15 |
| `B5IntegrationTests` | 10 | B5 INT | ✅ 10/10 |
| `B5FixtureComparisonTests` | 4 | B5 深比较 | ✅ 4/4 |
| `B5DeterminismTests` | 6 | B5 确定性/映射 | ✅ 6/6 |
| **既有合计** | **91** | — | **91/91，0 failures** |

### 2.2 C1 新增 23 例（不计入既有 91，0 失败）

| 测试套件 | 方法数 | 覆盖 | 结果 |
|---|---:|---|---|
| `PluginEnumerationTests` | 14 | S1-04 13 组夹具深比较（20 例夹具用例）+ ENUM-011/013/014 合成用例 + 10 项专项口径（大小写敏感/非递归/软链不跟随/异常保留/隐藏保留/nil 三态/哈希透传/五类计数/空目录/排序） | ✅ 14/14 |
| `PluginInventoryCodableTests` | 9 | 三枚举原始值锁定、证据/快照往返、三态 nil 保留、缺失可选缺省、未知键忽略、计数累加 | ✅ 9/9 |
| **C1 合计** | **23** | — | **23/23，0 failures** |

### 2.3 S1-04 23 例映射核对

- 夹具用例 20 例：`testS104FixturesDeepComparison` 逐组解码 `environment.json` 与 `metadata.json`，深比较 route/sourceDirectory/status/counts/itemCount/unknownCount/names/warnings/expectedStatus，13 组全部通过。
- 合成用例 3 例：ENUM-011 路径身份（同名不按基名合并）、ENUM-014 重复枚举确定性、ENUM-013 路线隔离（无 `/var/jb` 回退）。
- Runner 日志中 C1 用例名与本地源码逐一比对一致（23/23）；无 skipped、pending 或 XCTFail。

## 3. 隔离与边界复核

- C1 Core 源码仅 `import Foundation` / `import Models`，无 `Adapters` 依赖，未引用 `RootHideAdapter`/`RootlessAdapter`；隔离脚本三向 OK。
- 未修改七方法 Adapter 协议、双路线 Adapter 冻结行为、`ReportEnvelope`、Stage 1 夹具/harness/报告与既有测试预期。
- App 截图沿用骨架页：环境「尚未检测」、权限「尚未验证（2.4 探针）」、脚注「本阶段为只读骨架；不含扫描、启停或写入功能」；中文渲染正常，无新增扫描/启停入口。App 存活仅证明工程构建与基础启动，不证明越狱目录访问权限。

## 4. 观察项与遗留

- 本机 Linux 无 Swift 工具链的限制已解除：本轮编译/测试均在 macOS Runner 完成；`swift build` 18.08s、`swift test` 0.048s。
- 2.2-A R6（未知枚举原始值默认解码行为）沿用观察项：本轮夹具全为已知封闭集取值，未触发未知原始值路径。
- B4 结果 → 枚举器的服务装配、`PluginScanService` 协议接入与 AdapterResolver 接线仍归后续装配授权；本轮枚举器消费离线信号快照。
- 哈希/元数据真机可取性留 2.5 只读验证；C2 配对、C3 解析、S1-07 归属、S1-08 导出未启动。
- Runner iOS 26.5 SDK 不能作为 Theos 16.5 SDK 对 iOS 17 兼容证据；Rootless 无真机。
