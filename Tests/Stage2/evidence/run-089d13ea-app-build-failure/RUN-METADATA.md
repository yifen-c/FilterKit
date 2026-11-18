# RUN-METADATA.md — 0.1-C app-build 首轮 XcodeGen/xcodebuild 失败（待下一轮复核）

- 分支：`main`；检出 SHA `386f18cbd528a9ad11f8e690e883a6d76c5f8409`（repo `yi-fen/FilterKit`）。
- Job：`app-build`；workflow job run `6069c747-f6ab-5151-8e4f-63a29b822c47`；日志时间 2026-11-18 15:15Z。
- 环境：macOS 26.7.2（25G332）/ image `macos-26-arm64` 20261102.0473.1 / runner 2.338.2 / Xcode 26.6 / iPhoneSimulator26.5.sdk / Swift 5 / XcodeGen 2.46.0；scheme `FilterKit`，destination `generic/platform=iOS Simulator`，Debug，target `arm64-apple-ios17.0-simulator`（x86_64 并行）。
- 结果：App target `EmitSwiftModule normal arm64` 失败，xcodebuild 退出码 65；未产出 `.app`，未进入模拟器启动与截图。本 job 日志不含 `swift build` / `swift test` 步骤，非 UI 库与单测结果以对应 job 日志为准。

## 1. 失败定位

| 阶段 | 结论 | 证据 |
|---|---|---|
| Models / Adapters / Core 包目标 | 随 xcodebuild 依赖图编译，日志未报该层错误 | 依赖图 `FilterKit ➜ Models / Adapters / Core` |
| App target 模块发射 | ❌ 4 处 `cannot find 'ReportExporter' in scope` | `build/job-logs.txt` 1949/1952/1955/1958 行 |

## 2. 根因

四个 SwiftUI 视图的 `#Preview` 闭包内以 `ReportExporter()` 装配 `AppDependencies`，但文件只 `import SwiftUI` + `import Models`，未 `import Core`；`ReportExporter` 定义在 Core 模块。SwiftPM `swift build` 不编译 App target，故首轮 `build` job 未暴露；XcodeGen app-build 将全部 App 源码编入单一 `FilterKit` 模块后，缺导入在模块发射阶段报错。

| # | 文件 | 行 | 报错 |
|---|---|---|---|
| 1 | `App/Features/Dashboard/DashboardView.swift` | 74:19 | `cannot find 'ReportExporter' in scope` |
| 2 | `App/Features/Diagnostics/DiagnosticsView.swift` | 50:19 | `cannot find 'ReportExporter' in scope` |
| 3 | `App/Features/Plugins/PluginListView.swift` | 91:19 | `cannot find 'ReportExporter' in scope` |
| 4 | `App/Features/Settings/SettingsView.swift` | 72:19 | `cannot find 'ReportExporter' in scope` |

## 3. 本地修复（仅补导入，未改装配逻辑 / 协议 / 模型）

- 上述四个文件各补一行 `import Core`，置于 `import Models` 之后；与既有 `App/AppEntry/FilterKitApp.swift`、`App/Features/Settings/SettingsViewModel.swift` 的 Core 导入范式一致。
- `ReportExporter` 不在隔离脚本 §4 禁止面（禁止的是扫描器/解析器/路径解析器/`ReportBuilder`/`ReportValidator`/`ReportService` 等具体实现）；§4b 仍禁止 `import Adapters`。隔离脚本复跑全项退出码 0。
- 全 App 复核：`ReportExporter` / `ReportExporting` 其余引用点（`AppDependencies.swift`、`FilterKitApp.swift`、`SettingsViewModel.swift`）导入面已完整；无其他缺导入符号。

## 4. 待下一轮 Runner 复核

- XcodeGen 生成 + `xcodebuild` `** BUILD SUCCEEDED **`，产出 `FilterKit.app`；模拟器启动存活、四页切换、合成信封渲染、导出落临时目录。
- 本机 Linux 无 Swift/Xcode 工具链，修复未经本地编译验证，结论以 Runner app-build 日志为准。

## 5. C-F1 补证：同轮 SwiftPM XCTest 日志（2026-11-19 归档）

- 本批 app-build job 日志本身不含 `swift build` / `swift test`；后补归档同轮 test job 产物：`test-log/filterkit-test-log.txt`、`test-log/test-log-s105.txt`，摘要 `test-log/test-summary.json`、`test-log/s1-05-summary.txt`。
- 日志时间 2026-11-18 15:12:02Z，目标 `arm64e-apple-macos14.0`，Testing Library 1902。
- 全量：**Executed 405 tests，0 failures（0 unexpected），0 skipped**；38 套件全 passed。分组：既有回归 397 + GUI-01～08 八例（`GUIPresentationTests` 8/8）；Reporting 18 例含在基线内；S1-05 独立过滤 15/15（`PluginPairingS105FixtureTests`，含 PAIR-011 AccessDenied 与两个 PAIR-013 变体）。
- 边界：SwiftPM test 目标不编译 App SwiftUI 视图；本日志不覆盖 App target 编译与模拟器交互。同轮 app-build 仍按 §1 判定失败；测试通过不推翻 app-build 失败结论。
- 未补证：本轮 build job 明细（`swift build` 0 error/0 warning 输出）与 isolation 脚本原始输出未随包留存；f50c284d 轮次（run `120016036175`）test-log 亦待后续补证。
