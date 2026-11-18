# RUN-METADATA.md — 第九轮（2.2-B1 环境识别 runner build 失败）

- Run 作业：`workflow-job-run-91c61814-52b2-5462-ac0d-5ffe61a01632`；仓库 `yi-fen/006` / `main`；job 名 `build`。
- Runner SHA：`3a6d26d0bd47c4fa0efb6b64d2b9c4363c4e22e0`（fetch-depth 1；用户同步时变基/压缩属正常）。
- 时间：2026-11-16 02:05:14Z 起；`swift build` 02:06:14 exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 工具链版本：本链接仅含 build job，未含 environment job，Swift/Xcode/SDK 版本未在本日志出现，待下一轮 environment job 补录。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core） | ❌ exit 1 | `Core/Environment/EnvironmentDetector.swift` 3 条编译错误；Models、Adapters 模块已成功 emit |
| test（Stage2Tests） | ⏭ 未执行 | 依赖 build 通过，build 失败后未触发 |
| isolation | ⏭ 未执行 | 同上 |
| app-build / artifact | ⏭ 未执行 | 同上 |

编译进度：`[5/9] ModelEnums → [6/9] PluginModels → [7/9] Emitting Models → [8/9] EnvironmentAdvisor → [9/9] EnvironmentModels → [10/10] ReportEnvelope → [11/13] RootHideAdapter → [12/14] Emitting Adapters → [13/14] ElleKitAdapter → [14/14] RootlessAdapter → [15/18] CoreServices.swift → 报错中断`。

## 2. 编译错误（runner 路径 `/Users/runner/work/006/006/Core/Environment/EnvironmentDetector.swift`）

| # | 位置 | 错误 | 判定 |
|---|---|---|---|
| 1 | 65:41 | `missing argument label 'signal:' in call` | 根因：`parser.classify(s.ellekitVersion)` 漏外部参数标签；签名为 `classify(signal:)` |
| 2 | 70:37 | `cannot infer contextual base in reference to member 'parsed'` | 级联：错误 1 导致 `classify` 返回类型无法解析，`readiness.status` 类型未知，`.parsed` 无法推断 |
| 3 | 93:95 | `cannot infer contextual base in reference to member 'notInstalled'` | 同上，级联 `.notInstalled` |

## 3. 本地修复（提交待下一轮 runner 复验）

1. `EnvironmentDetector.swift:65`：改为 `parser.classify(signal: s.ellekitVersion)`。
2. `EnvironmentSnapshot.swift`：`EnvironmentSignalValue` 改自定义 Codable；`value` 宽松解码——字符串入 `value`，布尔入 `boolValue`，其余类型忽略不抛错（夹具 `conflicting/rootlessPathPresent.value` 为布尔，合成解码会类型不匹配）。
3. `EnvironmentDetectionTests.swift`：版本比较字段由 `rawVersion` 改为 `parsedVersion`；基线报告 `ellekitVersion` 对应解析后版本，`rawVersion` 为诊断原始串（unparsable/unreadable/conflicted 基线报告版本为 null）。

## 4. 边界核对（本轮未越界）

- 未改 `ElleKitAdapter` 七方法协议；未进入 B2~B5；未改 Stage 1 Fixtures/harness/报告；无真机写入、启停、扫描、探针。
- 本地静态隔离脚本三向 OK；2.2-A 既有 21 例测试未改动。

## 5. 待下一轮 runner 复验

1. `swift build` Models/Adapters/Core 编译通过；
2. `swift test` 既有 21 例 + B1 新增环境识别用例 0 失败；
3. isolation 三向通过；
4. environment job 工具链版本、test-log、必要 build 日志归档。

> 下一轮结果未出前，B1 状态仍为「待复验」，不进入 B2。
