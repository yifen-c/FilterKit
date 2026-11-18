# RUN-METADATA.md — 第十一轮（Engine-C2 首轮 Runner build 失败：静态成员误用 / 可选 reason 未解包）

- Run 作业：`workflow-job-run-f5e97c82-674c-5d3e-bdde-11780eba3e20`；结果容器 `98afbe72-ea5c-4d7e-8e69-192e917b3054`；仓库 `yi-fen/FilterKit` / 分支 `C2-C3`；job 名 `build`。
- Runner SHA：`4b3e71c0e3a1e046d27a7d46a6cf3982fbfe0ded`（fetch-depth 1；本地链经变基/压缩后哈希不同属正常，修复按源码行对齐）。
- 时间：2026-11-17 03:20:23Z 起；`swift build` 03:21:16 报错中断，03:21:19 收尾，exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 工具链版本：本链接仅含 build job，未含 environment job；日志仅出现 `swift-version-7974D3F7F03D5E95.txt`，Swift/Xcode/SDK 版本待下一轮 environment job 补录。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core） | ❌ exit 1 | Models 13 文件、Adapters 3 文件模块已成功 emit；Core 编译至 `[18/66]` 后报错中断 |
| test（Stage2Tests） | ⏭ 未执行 | 依赖 build 通过，build 失败后未触发 |
| isolation / app-build / artifact | ⏭ 未执行 | 同上 |

编译进度：Models（PluginEntryStatus / PluginFileEvidence / PluginFileKind / EnvironmentAdvisor / EnvironmentModels / ModelEnums / PluginModels / ReportEnvelope）emit 成功 → Adapters（RootHideAdapter / ElleKitAdapter / RootlessAdapter）emit 成功 → Core `PlistValueKind.swift` 起编后报错。

## 2. 编译错误（runner 路径 `/Users/runner/work/FilterKit/FilterKit/Core/PlistParser/`）

| # | 位置 | 错误 | 判定 |
|---|---|---|---|
| 1 | `Engine/PluginFilterParseEngine.swift:72:44` | `static member 'snapshotRouteValue' cannot be used on instance of type 'PluginFilterParseEngine'` | 根因：`snapshotRouteValue` 是 `private static` 方法，实例上下文调用漏写 `Self.` 前缀 |
| 2 | `Rootless/RootlessFilterParser.swift:106:44` | `value of optional type 'String?' must be unwrapped to a value of type 'String'` | 根因：`topLevelReason(for:)` 返回 `String?`，而 `failed(...)` 形参 `reason: String` 为非可选；调用点未解包 |

告警（非阻断，一并清理）：

| # | 位置 | 告警 | 判定 |
|---|---|---|---|
| W1 | `Rootless/RootlessFilterParser.swift:85:14` | `result of call to 'checkStringArray(_:key:skipped:)' is unused [#no-usage]` | 返回的归一数组未被引用（字段级证据已写入 `skipped`），显式丢弃 |
| W2 | `Rootless/RootlessFilterParser.swift:86:14` | 同上（`Executables`） | 同上 |

两类错误被多个并行 Core 编译单元重复报出，实际位置各一处；日志无 Tests 目标错误、无其他错误类型。

## 3. 本地修复（提交待下一轮 runner 复验）

### `Core/PlistParser/Engine/PluginFilterParseEngine.swift`

- 72 行：
  - 改前：`extraDetail: ["route": snapshotRouteValue(snapshot.route)]`
  - 改后：`extraDetail: ["route": Self.snapshotRouteValue(snapshot.route)]`
- 行为不变：仍把快照路线原值（nil 归 `"nil"`）写入 unknown_route 条目 detail；仅补齐静态方法调用前缀。

### `Core/PlistParser/Rootless/RootlessFilterParser.swift`

- 85/86 行：两次 `Self.checkStringArray(...)` 前加 `_ =` 显式丢弃返回值；字段级类型证据仍通过 `inout skipped` 收集，行为不变。
- 106 行：
  - 改前：`route: route, reason: Self.topLevelReason(for: skipped.first),`
  - 改后：`route: route, reason: Self.topLevelReason(for: skipped.first) ?? "field_type",`
- 行为不变：`skipped` 非空时 `skipped.first.reason` 恒为非空封闭原因词，兜底 `"field_type"` 仅防御性使用，与 Rootless 字段级失败顶层归 `field_type` 的口径一致；未改失败状态归类、未改规则载体归属。

## 4. 边界核对（本轮未越界）

- 未改 Models 公共字段/枚举原始值、未改七方法协议、未改 Stage 1 fixtures/metadata/harness、未改既有测试预期与 C2-A~C 测试落点。
- 未接服务层、未碰真机；未调整 Reader/Decoder/双 Parser 的失败口径与告警 code 表。

## 5. 待下一轮 runner 复验

1. `swift build` Models/Adapters/Core 编译通过，无 error、无 `#no-usage` 告警；
2. `swift test` 全量执行（C2-A~C 新增 16 例静态落点 + 既有回归），实际通过数以 Runner 输出为准；
3. isolation 三向通过；app-build Simulator `BUILD SUCCEEDED`；
4. environment job 工具链版本、test-log 与必要 build 日志归档。

> 下一轮结果未出前，Engine-C2-A~C 状态仍为「待复验」；不宣布双路线集成完成，C2-D / C2-E 继续阻塞于 C-G1 / C-G2。
