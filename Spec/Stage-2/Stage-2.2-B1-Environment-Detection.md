# Stage-2.2-B1-Environment-Detection.md — B1 环境识别落地记录

> 状态：**runner 验收通过**（run-43793314782：build 通过、28 例测试 0 失败、隔离三向 OK、App 构建启动存活截图归档；见 §5）。过程性失败轮次（run-91c61814 build、run-43791788306 test）已修复并归档。
> 授权：用户授权执行 Stage 2.2-B1（Environment Detection）；严格依据 `Stage-2.2-B-Data-Contract-Freeze.md` 与 S1-01 基线实施。
> 边界：不改 `ElleKitAdapter` 七方法协议；不进入 B2~B5；不改 Stage 1 Fixtures；不做真机写入、插件启停或 GUI 文件扫描。

## 1. 授权范围

| 允许落地 | 落点 |
|---|---|
| `VersionReadiness` 模型与五态枚举 | `Models/EnvironmentModels.swift` |
| `JailbreakEnvironment.versionReadiness` 可选增补字段 | `Models/EnvironmentModels.swift` |
| `VersionParser`（版本五态解析） | `Core/Environment/VersionParser.swift` |
| `EnvironmentDetector`（环境识别编排） | `Core/Environment/EnvironmentDetector.swift`、`EnvironmentSnapshot.swift` |
| RootHide / Rootless 独立环境读取（Profile 匹配口径） | 两个 Adapter 扩展实现 `EnvironmentProfileAdvisor` |
| ENV-001~015 Swift 回归 | `Tests/Stage2/EnvironmentDetectionTests.swift` |

| 禁止项 | 执行情况 |
|---|---|
| 修改七方法协议 | ✅ 未改 `ElleKitAdapter` |
| 进入 B2/B3/B4/B5（候选收集校验、目录/软链定位、Pipeline 集成） | ✅ 未触碰 |
| 修改 Stage 1 Fixtures / harness / 报告 | ✅ 未改 |
| 真机写入、插件启停、GUI 文件扫描、权限探针 | ✅ 未接入 |
| 2.2-A 已通过的 21 例 Codable 测试被破坏 | 待 runner 回归确认；新增字段可选 + 默认 nil，旧 JSON 解码为 nil |

## 2. 落地清单与职责

### 2.1 Models（G-B1 增补，契约冻结 §3）

- `VersionReadinessStatus: String, Codable`：`parsed / notInstalled(not_installed) / unreadable / unparsable / conflicted`，原始值与 S1-01 实测五态逐字一致。
- `VersionReadiness`：`status: VersionReadinessStatus`、`rawVersion: String?`、`parsedVersion: String?`、`warnings: [ReportWarning]`；`sources` 按 D1 暂缓，不进结构。
- `JailbreakEnvironment` 增补 `versionReadiness: VersionReadiness?`，init 默认 `nil`；既有字段名称、类型、原始值、解码行为不变。
- `EnvironmentProfileAdvisor`（中性接口，`Models/EnvironmentAdvisor.swift`）：`route` + `proposedProfile(jailbreakType:implementation:versionStatus:)`；路线匹配条件由 Adapter 实现，Models/Core 不写路线规则。

### 2.2 Core（离线只读编排）

- `EnvironmentSnapshot` / `EnvironmentSignalValue`：夹具 `environment.json` signals 中性解码载体；信号缺失按未提供处理，不反推补齐；布尔信号经 `boolValue` 承载。
- `VersionParser.classify(_:)`：对齐 detector.js 版本规则——未提供 `not_installed`；`readability == "unreadable"` → `unreadable` + `access_limited`；格式不匹配 → `unparsable` + `version_unparsable`；格式匹配（`^\d+\.\d+(?:\.\d+)?(?:-\d+)?$`）→ `parsed`，`rawVersion`/`parsedVersion` 取同一原始串。
- `EnvironmentDetector.detect(_:)`：多信号组合判定；bootstrap/实现缺失告警仅在已识别越狱类型时上报；两类冲突（路线信号冲突、实现-版本冲突）不选边，置 `unknown`/`conflicted`，不出 Profile；Profile 候选由 Adapter 顾问提案；其余按 `profile_candidate / unsupported_profile / unknown / partial` 裁决。
- 结果 `EnvironmentDetectionResult` 字段对齐 S1-01 报告：类型、架构、iOS 版本、bootstrap 名/版本、实现、版本就绪、Profile、outcome、告警。

### 2.3 Adapters（双路线隔离）

- `RootHideAdapter`：顾问匹配 `roothide + roothide + parsed` → `RootHideProfile_1_2_3`；文件内不出现 Rootless 符号。
- `RootlessAdapter`：顾问匹配 `rootless + upstream + parsed` → `RootlessProfile_upstream`；文件内不出现 RootHide/roothide 符号。
- 七方法签名与返回类型不变；`getEnvironment()` 仍为保守骨架，真实文件环境接入属后续批次/2.4 探针。

### 2.4 测试接线

- `Package.swift`：Core 目标纳入三个 Environment 源文件；`Stage2Tests` 依赖补 `Adapters`、`Core`，测试源纳入 `EnvironmentDetectionTests.swift`。
- 测试只读引用 `Tests/Fixtures/S1-01/` 原始夹具（按 `#filePath` 定位），不复制基线；除 `generatedAt` 外逐字段比较；告警按 code 集合比较。

## 3. ENV-001~015 回归矩阵

| 用例 | 来源 | 类型 | 版本态 | Profile | outcome | 告警 |
|---|---|---|---|---|---|---|
| ENV-001 | fixture:roothide | roothide | parsed | RootHideProfile_1_2_3 | profile_candidate | — |
| ENV-002 | fixture:rootless | rootless | parsed | RootlessProfile_upstream | profile_candidate | — |
| ENV-003 | fixture:rootful | rootful | not_installed | — | unsupported_profile | unsupported_rootful |
| ENV-004 | fixture:unknown | unknown | not_installed | — | unknown | no_jailbreak_signals |
| ENV-005 | fixture:unknown | unknown | not_installed | — | unknown | no_jailbreak_signals |
| ENV-006 | fixture:incomplete | roothide | unparsable | — | partial | bootstrap_missing, implementation_missing, version_unparsable |
| ENV-007 | fixture:unknown | unknown | not_installed | — | unknown | no_jailbreak_signals |
| ENV-008 | fixture:conflicting | unknown | conflicted | — | conflict_no_profile | route_signal_conflict, impl_version_conflict |
| ENV-009 | fixture:conflicting | unknown | conflicted | — | conflict_no_profile | route_signal_conflict, impl_version_conflict |
| ENV-010 | fixture:incomplete | roothide | unparsable | — | partial | bootstrap_missing, implementation_missing, version_unparsable |
| ENV-011 | synthetic:malformed-input | unknown | not_installed | — | unknown | 解码错误结构化捕获，识别器不崩溃 |
| ENV-012 | synthetic:version-unreadable | roothide | unreadable | — | partial | access_limited |
| ENV-013 | synthetic:determinism | roothide | parsed | RootHideProfile_1_2_3 | profile_candidate | 重复输入结果一致 |
| ENV-014 | fixture:incomplete | roothide | unparsable | — | partial | bootstrap_missing, implementation_missing, version_unparsable |
| ENV-015 | synthetic:id-mismatch | roothide | parsed | RootHideProfile_1_2_3 | profile_candidate | 框架识别 ID 不一致，识别判断不受影响 |

五态覆盖：parsed（001/002/013/015）、not_installed（003/004/005/007/011）、unreadable（012）、unparsable（006/010/014）、conflicted（008/009）。

## 4. 静态自查（本地）

- 协议：`ElleKitAdapter` 七方法未增删改；未新增平行接口。
- 隔离：RootHide 文件无 Rootless 符号；Rootless 文件无 RootHide/roothide/`jbroot()`/RootHideProfile 符号；Core 未实例化具体 Adapter。
- 兼容：`versionReadiness` 可选 + 默认 nil；测试含旧 JSON 缺该字段解码为 nil 用例；既有 21 例 Codable 构造调用不受新默认参数影响。
- 只读：识别器消费快照，不触达文件系统/设备；无写入、启停、删除、装卸调用。

## 5. Runner 验收记录（已通过）

> **第九轮 build 失败（run-91c61814，SHA `3a6d26d0`）**：`swift build` exit 1，根因为 `classify` 调用漏参数标签 `signal:`，另两条枚举推断错误为级联。证据：`Tests/Stage2/evidence/run-91c61814-build-failure/`。
>
> **第十轮 test 失败（run-43791788306，SHA `63d5474f`）**：编译通过，21 例既有 Codable 0 失败；B1 新增用例 6 处断言失败——版本就绪告警未合并进顶层告警表（ENV-012/006/010/014），冲突分支未归零越狱类型（ENV-008/009）。证据：`Tests/Stage2/evidence/run-43791788306-test-failure/`。
>
> **第十一轮验收通过（run-43793314782，SHA `71e5d2fc`）**：build `Build complete! (9.81s)`；test **28 例 0 失败**（EnvironmentDetectionTests 7 方法/15 例 ENV + ModelsCodableTests 21 例）；隔离三向 OK；app-build `** BUILD SUCCEEDED **`，模拟器 launch PID 9148 存活一致，截图归档。证据：`Tests/Stage2/evidence/run-43793314782/`。

| 验收项 | 结论 |
|---|---|
| `swift build` Models / Adapters / Core 编译通过 | ✅ `Build complete! (9.81s)` |
| `swift test`：21 例既有 Codable + B1 15 例 ENV 回归 | ✅ 28 tests, 0 failures |
| Adapter 隔离脚本 | ✅ 三向 OK（静态文本层面） |
| 工具链 / 日志 / 产物归档 | ✅ environment、build、test-log、isolation、app-build、metadata 已归档 |

> B1 在 runner 编译、测试、隔离层面验收通过；App 仍为只读骨架，模拟器存活不代表真机越狱文件访问权限（归 2.4 探针）。B2~B5 未授权，待单独拍板。

## 6. 遗留与非目标

- `parsedVersion` 归一化算法当前与原始串一致；真实版本归一化归后续 Adapter/解析批次。
- Bootstrap 名/版本、架构、iOS 版本在检测结果中保留；装配进 `JailbreakEnvironment` 的完整映射留待 B5 / 2.2-D 编排。
- Rootless 结论仅离线夹具，不代表 Rootless 真机兼容；Rootful 仅诊断参照。
- G-B2/G-B3 候选与目录/软链证据模型属 B2~B4，本批次未落地。
