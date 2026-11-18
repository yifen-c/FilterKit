# RUN-METADATA.md — 第十一轮（2.2-B1 Environment Detection runner 验收通过）

- Run ID：**43793314782**；仓库 `yi-fen/006` / `main`；artifact `filterkit-build-metadata`（ID 14193164937）、`filterkit-test-log`。
- Runner SHA：`71e5d2fc347654dae72038c939ad954b01abd2f7`（fetch-depth 1；与本地 `175e27f` 的差异为用户同步时变基/压缩，内容对应 B1 修复后状态）。
- 时间：2026-11-16 02:37:42Z ~ 02:44:05Z。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；westus / MacCloud；git 2.56.0。
- 工具链：Xcode 26.6（Build 17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5 / Simulator iOS 26.5 / macOS 26.5；Testing Library 1902；测试平台 arm64e-apple-macos14.0；XcodeGen 2.46.0。

## 1. Job 结果总览

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链版本落盘，无 error |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (9.81s)`；Models / Adapters / Core 模块均 emit |
| test（Stage2Tests） | ✅ success | **Executed 28 tests, with 0 failures (0 unexpected)** |
| isolation | ✅ success（静态文本层面） | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| app-build | ✅ success | `xcodegen generate`；`** BUILD SUCCEEDED **`；模拟器 install/launch；存活复查；截图归档 |
| artifact | ✅ success | build-metadata、test-log 上传成功 |

## 2. 测试明细（28 例，0 失败）

### 2.1 B1 环境识别：EnvironmentDetectionTests 7 方法 / 15 例 ENV，0 失败

`Test Suite 'EnvironmentDetectionTests' ... Executed 7 tests, with 0 failures (0 unexpected) in 0.013 (0.014) seconds`

| 测试方法 | 覆盖 ENV | 结果 |
|---|---|---|
| `testFixtureCasesENV001To010And014` | ENV-001/002/003/004/005/006/007/008/009/010/014（夹具表驱动） | ✅ |
| `testENV011MalformedInputCapturedWithoutCrash` | ENV-011 格式错误结构化捕获 | ✅ |
| `testENV012UnreadableVersion` | ENV-012 不可读 + access_limited | ✅ |
| `testENV013Determinism` | ENV-013 重复执行确定性 | ✅ |
| `testENV015IdMismatchDoesNotAffectDetection` | ENV-015 框架 ID 不一致不影响识别 | ✅ |
| `testVersionReadinessRoundTrip` | VersionReadiness Codable 往返 | ✅ |
| `testEnvironmentWithoutReadinessDecodesLegacyJSON` | 旧 JSON 缺字段解码为 nil | ✅ |

五态覆盖：parsed（001/002/013/015）、not_installed（003/004/005/007/011）、unreadable（012）、unparsable（006/010/014）、conflicted（008/009）。

### 2.2 2.2-A 既有回归：ModelsCodableTests 21 例，0 失败

`Test Suite 'ModelsCodableTests' ... Executed 21 tests, with 0 failures (0 unexpected) in 0.005 (0.008) seconds`。本轮未改 Models 字段/枚举/原始值/解码行为，既有兼容保持。

## 3. App Target 复验（沿用 2.1 闭环口径）

- 模拟器：`iPhone 17 Pro`，UDID `98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`，Booted；
- 安装 `FilterKit.app`（Debug-iphonesimulator）；`xcrun simctl launch com.filterkit.manager` → PID **9148**；
- 存活复查：`9148 0 UIKitApplication:com.filterkit.manager[4c6e][rb-legacy]`，存活 PID 9148 == 启动 PID 9148；
- 截图 `dashboard.png` 1206×2622 RGBA：标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」、脚注「本阶段为只读骨架；不含扫描、启停或写入功能。」，中文渲染正常。

## 4. 边界核对（B1 授权范围内）

- `ElleKitAdapter` 七方法协议未改；G-B4 无参 `resolvePaths()` 保留；
- 未进入 B2~B5（候选收集校验、目录/软链定位、Pipeline 集成）；
- Stage 1 Fixtures / harness / 报告未改；
- 无真机写入、插件启停、GUI 文件扫描、权限探针；
- 隔离脚本三向通过；双路线 Adapter 互不引用，Core 不实例化具体 Adapter。

## 5. 遗留与非目标（不构成本轮失败项）

- App 仍为只读骨架：模拟器存活只证明未立即退出，不代表越狱文件访问权限；GUI 真实权限 / entitlement / `jbroot()` 进程内调用归 2.4 探针。
- Rootless 结论仅离线夹具，不代表 Rootless 真机兼容；Rootful 仅诊断参照。
- `parsedVersion` 归一化算法当前与原始串一致；真实归一化归后续 Adapter/解析批次。
- B2~B5、2.2-C、进入 2.3 均未授权，待单独拍板。

## 6. 归档清单

- `logs/`：environment / build / test / isolation / app-build 各 job 分步日志与 system 日志；
- `test-log/test-log.txt`：`swift test` 完整输出；
- `app-build/`：`app-xcodebuild.log`、`sim-launch.log`、`dashboard.png`；
- `metadata/`：runner 侧 `control`、`Package.swift` 快照。
