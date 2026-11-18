# RUN-METADATA.md — 第十五轮（Stage 2.2-C2-D2 第二轮：build/isolation/app-build 通过，test target 编译失败）

- Run ID：**118709558501**（Actions run `43851060190`）；仓库 `yi-fen/FilterKit` / 分支 `C2`；工作流 `filterkit-build.yml`。
- Runner SHA：`7aaa511560e80a662686a0fbf7ae7fa5c8bd1625`（fetch-depth 1；本地提交链锚点 `2cc05a1`，runner 侧 hash 由外部推送/变基产生）。
- 时间：2026-11-16 10:41:18Z ~ 10:49:58Z；test Job `swift test` 10:44:26 exit 1。
- Runner：macOS 26.7.2（Build 25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 工具链：Xcode 26.6（Build 17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5 / Simulator iOS 26.5 / macOS 26.5；swift-driver 1.148.6。

## 1. Job 结果总览

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链/镜像版本落盘，无 error |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (18.14s)`；首轮 `contains(where:)` 修复生效，Core 63 源全部编译通过 |
| isolation | ✅ success（静态文本层面） | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| test（Stage2Tests） | ❌ exit 1 | test target 编译失败，3 个测试源；全量 `swift test` 未进入执行；S1-05 独立过滤步骤未触发 |
| app-build | ✅ success | `** BUILD SUCCEEDED **`；模拟器安装启动，`App alive: PID 4000`；截图 `build/dashboard.png` 写入 |
| artifact | ✅ success | `filterkit-build-metadata.zip` Artifact ID 14218077312，7188 字节；`filterkit-app-build.zip` ID 14218800482，1,211,802 字节；`filterkit-test-log.zip` ID 14218230384，5717 字节 |

> 说明：app-build 存活仅证明 Simulator 进程启动，不证明越狱目录访问权限；SDK 26.5 不作为 Theos 16.5 兼容证据（沿用未决观察项）。

## 2. 编译错误（runner 路径 `/Users/runner/work/FilterKit/FilterKit/Tests/Stage2/`）

根因两类，均在测试源，Core/Models 冻结契约未变：

### 2.1 调用缺 `inventory:` 参数标签（24 处）

Core 公共签名：`PluginPairingEngine.pair(inventory:)`、`PluginPairingPipeline.execute(inventory:)`，Swift 6.3.3 要求外部参数标签显式写出。测试源把 `engine.pair(inventory: ...)` 误写成 `engine.pair(inventory(...))`，标签缺失导致快照类型无法解析，下游级联出大量 `type 'Equatable' has no member 'paired'`、`type 'Any' cannot conform to 'Equatable'`、`unable to type-check in reasonable time` 报错。

| 文件 | 位置 | 处数 |
|---|---|---:|
| `PluginPairingEngineTests.swift` | 26, 41, 52, 68, 84, 98, 112, 122, 139, 163, 180, 181, 193, 195, 212, 229, 243, 252, 264, 298, 318 | 21 |
| `PluginPairingIntegrationTests.swift` | 260, 305, 306 | 3 |

### 2.2 S1-05 告警码引用了错误的结构体成员（1 处）

- `PluginPairingS105FixtureTests.swift:134:26`：`value of type 'S105FixtureLoader.S105Expected' has no member 'expectedWarnings'`。
- 判定：`expectedWarnings` 定义在 `S105Metadata` 上，不在 `S105Expected`；测试误从 `expected`（= `metadata.expected`）取值，应取 `fixture.metadata.expectedWarnings`。

## 3. 本地修复（提交待下一轮 Runner 复验）

1. `PluginPairingEngineTests.swift`：21 处 `engine.pair(inventory(...))` → `engine.pair(inventory: inventory(...))`；调用入参与判定预期均未改。
2. `PluginPairingIntegrationTests.swift`：3 处 `pipeline.execute(inventory(...))` → `pipeline.execute(inventory: inventory(...))`。
3. `PluginPairingS105FixtureTests.swift:134`：`Set(expected.expectedWarnings)` → `Set(fixture.metadata.expectedWarnings)`。

复核：全测试目录扫描确认无其他 `.pair(inventory(` / `.execute(inventory(` 裸标签调用；`UnknownItem`/`ReportWarning`/`PluginFileEvidence`/`PluginPairingInput`/`PluginPairingIntegrationValidator` 初始化标签与枚举值（`dylib/plist/directory/symlink/other`、`accessDenied/readFailed/notFound`、`paired/missingPlist/orphanPlist/missingDylib`、`exactFilenameMatch/ambiguousMultiCandidate/uncertainAccess`）逐一对照 Core/Models 签名一致。

## 4. 边界核对（本轮未越界）

- 仅改三个测试源；未改 Core/Models/Adapters 生产代码、七方法协议、Stage 1 fixtures/metadata/harness、夹具 JSON 与既有测试预期。
- 未接服务层、未碰真机；隔离三向结论沿用 Runner 本轮 OK。
- test target 尚未在 Runner 编译通过，210 例静态清点（冻结回归 114 + C2 专项 81 + S1-05 映射 15）未出执行数字；不宣称回归通过。

## 5. 待下一轮 Runner 复验

1. `swift build` Models/Adapters/Core 继续 0 error；
2. 全量 `swift test` 0 failure（含既有 114 例回归 + C2 专项 81 例）；
3. `swift test --filter PluginPairingS105FixtureTests` 独立 15 例 0 failure；
4. isolation 三向通过；app-build Simulator 存活与截图维持；
5. 回收 test-log / test-log-s105 日志归档，四类数字按 Runner 实际发现落档。

> 下一轮结果未出前，C2-D2 状态仍为「待复验」；不宣布 C2 完成，不进入 C3。
