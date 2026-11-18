# RUN-METADATA.md — 第十三轮（Stage 2.2-B5 集成回归 Runner 验收通过）

- Run ID：**43817618222**；仓库 `yi-fen/FilterKit` / `main`；工作流 `filterkit-build.yml`。
- Runner SHA：`7fc5d530ed9650dea483204874f196fc468bea0e`（fetch-depth 1；对应本地提交链 `f8896dd → 0f35ea0 → bcdd5f0 → 12f16d1`，其中 `12f16d1` 为 4B 两处 B3 语法修复；runner 侧 `Package.swift`/`control`/`project.yml`/`Makefile`/`filterkit-build.yml` 快照与本地逐一 diff 一致）。
- 时间：2026-11-16 06:34:03Z ~ 06:40:29Z。
- Runner：macOS 26.7.2（Build 25G332），镜像 `macos-26-arm64` 20261112.0504；runner 2.338.2；git 2.56.1。
- 工具链：Xcode 26.6（Build 17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5 / Simulator iOS 26.5 / macOS 26.5；Testing Library 1902；测试平台 arm64e-apple-macos14.0。
- 归档产物（GitHub Actions Artifact，保留 14 天）：
  - `filterkit-build-metadata`（Artifact ID 14202614973，6851 字节）；
  - `filterkit-test-log`（Artifact ID 14202927858，压缩 2892 字节，内 `test-log.txt` 22286 字节）；
  - `filterkit-app-build`（Artifact ID 14202938735，916101 字节；含 xcodebuild 日志、启动日志、截图与 `.app` 产物，本地归档按既有口径只留日志与截图，不含 DerivedData 二进制）。

## 1. Job 结果总览

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链/镜像版本落盘，无 error |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (7.78s)`；Models / Adapters / Core 模块均 emit；4B 修复的 `JBRootDecisionResolver.swift`、`JBRootNameValidator.swift` 均编译通过 |
| test（Stage2Tests） | ✅ success | **Executed 91 tests, with 0 failures (0 unexpected)**；0 skipped、0 error |
| isolation | ✅ success（静态文本层面） | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| app-build | ✅ success | `xcodegen generate`；`** BUILD SUCCEEDED **`；模拟器 install/launch；存活复查；截图归档 |
| artifact | ✅ success | build-metadata、test-log、app-build 三个 artifact 上传成功 |

## 2. 测试明细（91 例，0 失败）

测试命令为整包 `swift test 2>&1 | tee .build/test-log.txt`（未分阶段 `--filter`；日志按 Test Suite 分别给出计数与结果，符合规格 §7「测试命令以 `Package.swift` 实际 testTarget 为准」）。

### 2.1 验证线 A：71 项冻结回归（分套件出证，0 失败）

| 测试套件 | 方法数 | 批次 | 结果 |
|---|---:|---|---|
| `ModelsCodableTests` | 21 | 2.2-A Codable | ✅ 21/21，0 failures |
| `EnvironmentDetectionTests` | 7 | B1 环境识别 | ✅ 7/7，0 failures |
| `JBRootCandidateCollectionTests` | 10 | B2 候选收集 | ✅ 10/10，0 failures |
| `JBRootValidationTests` | 18 | B3 校验/裁决 | ✅ 18/18，0 failures |
| `ElleKitDirectoryTests` | 15 | B4 目录/软链 | ✅ 15/15，0 failures |
| **冻结合计** | **71** | — | **71/71，0 failures** |

### 2.2 验证线 B：B5 附加 20 例（不计入 71，0 失败）

| 测试套件 | 方法数 | 覆盖口径 | 结果 |
|---|---:|---|---|
| `B5IntegrationTests` | 10 | INT-001~010 跨批次集成（确认 jbroot 转发/歧义不选边/无回退/双路线隔离/未确认状态保留/告警保留/三态 nil） | ✅ 10/10，0 failures |
| `B5FixtureComparisonTests` | 4 | S1-01 环境、S1-02 收集+裁决、S1-03 目录/软链 Stage 1 夹具深比较 | ✅ 4/4，0 failures |
| `B5DeterminismTests` | 6 | B3/B4/Pipeline/Bridge 重复执行确定；衔接输入 Codable 往返与编码稳定；路线映射五组口径+告警保留+重复确定 | ✅ 6/6，0 failures |
| **附加合计** | **20** | — | **20/20，0 failures** |

总套件：`Executed 91 tests, with 0 failures (0 unexpected) in 0.047 (0.060) seconds`。

## 3. 规格 §8 最终验收门槛核对

| 验收项 | 通过条件 | 本轮证据 | 结论 |
|---|---|---|---|
| 71 项冻结回归 | 71/71，分阶段出证 | §2.1 五套件计数 21/7/10/18/15，各套件 0 failures | ✅ |
| Stage 1 原始行为 | 无未解释差异 | 深比较 4 例对 S1-01/02/03 夹具 `environment.json` + `metadata.json` 基线全过；夹具/harness/报告零改动 | ✅ |
| Codable 兼容 | 规格 §5 八项全过 | 旧 JSON 缺可选字段解码、nil 不补空串/默认、nil 与 false 区分、证据结构往返、targetMatch 独立保留、五态原始值、D9 status 与 EvidenceLevel 独立，由 Models/B3/B4 Codable 与三态用例覆盖，全过 | ✅ |
| 三态语义 | 无 `nil → false` | `testThreeStateBitsNotCoerced`、`testThreeStatePreservedAndRouteCoverage`、INT-010 未验证字段保持 nil，全过 | ✅ |
| B2 → B3 → B4 集成 | INT-001~010 全过 | §2.2 `B5IntegrationTests` 10/10 | ✅ |
| RootHide / Rootless 隔离 | 三向通过 | 隔离脚本三项 OK（§1 isolation） | ✅ |
| Core 抽象依赖 | 不实例化具体 Adapter | 隔离脚本第三向 OK；本地复核 `Core/` 无 `RootHideAdapter()/RootlessAdapter()` 实例化 | ✅ |
| Core Build | 成功 | `swift build` `Build complete! (7.78s)`，0 error | ✅ |
| App Build | 成功（仅证明工程构建与基础启动） | `** BUILD SUCCEEDED **`；模拟器安装启动并存活复查通过 | ✅ |
| Runner 证据 | 完整归档 | `logs/`（六 Job 分步+system）、`test-log/`、`app-build/`（日志+截图）、`metadata/` 本轮目录归档 | ✅ |
| Git 追溯 | 提交链完整，B3 锚点入链，冻结代码未被悄悄修改 | runner SHA `7fc5d53`；metadata 快照与本地一致；本地链含 B3 冻结点 `3e878cb`、B4 `6bbd64f`、B5 `f8896dd/0f35ea0/bcdd5f0/12f16d1`；71 冻结测试方法数未增删改 | ✅ |

## 4. App Target 复验（沿用 2.1/B1/B2 闭环口径）

- 模拟器：`iPhone 17 Pro`，UDID `98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`，Booted；
- 安装 `FilterKit.app`（Debug-iphonesimulator，bundle `com.filterkit.manager`）；`xcrun simctl launch` → PID **3571**；
- 存活复查（冷启动后 sleep 3）：`3571 0 UIKitApplication:com.filterkit.manager[dae1][rb-legacy]`，存活 PID 3571 == 启动 PID 3571；
- 截图 `dashboard.png` 1206×2622 RGBA：标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」、脚注「本阶段为只读骨架；不含扫描、启停或写入功能。」，中文渲染正常；界面无扫描/启停/写入入口；
- xcodebuild 仅 1 条良性告警：`appintentsmetadataprocessor: Metadata extraction skipped. No AppIntents.framework dependency found`（无 AppIntents 依赖，非代码告警）；0 error。

## 5. 边界与不得宣布的结论（沿用规格 §9）

- App Build 成功只证明工程构建与基础启动，**不证明** RootHide GUI 具备越狱目录访问权限；离线/模拟器通过不代表真机兼容。
- 隔离为静态文本 + 编译层核对；运行时隔离属后续阶段。
- `AdapterResolver` 具体实现与两服务装配、B1 完整字段（架构/版本/Profile）向服务装配的传递，不在 B5 范围，留后续集成授权批次。
- 本轮未进入 2.2-C（插件枚举/配对/解析），未做真机写入、软链增删、注入配置修改、插件启停、dpkg 改动、GUI 私有扫描器/权限探针。
- 仍**不得**宣布：RootHide GUI 权限已验证、Rootless 真机兼容、插件已成功注入、插件启停功能可用（属后续阶段）。

## 6. 归档清单

- `logs/`：environment / build / test / isolation / app-build / artifact 各 Job 分步日志与 system 日志；
- `test-log/test-log.txt`：`swift test` 完整输出（91 例 0 失败）；
- `app-build/`：`app-xcodebuild.log`、`sim-launch.log`、`dashboard.png`（不含 DerivedData `.app` 二进制）；
- `metadata/`：runner 侧 `Package.swift`、`control`、`project.yml`、`Makefile`、`filterkit-build.yml` 快照。
