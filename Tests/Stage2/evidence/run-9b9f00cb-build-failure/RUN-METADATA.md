# RUN-METADATA.md — 0.1-C Stage 2.3 GUI Foundation 首轮 Runner build 失败（待下一轮复核）

- 分支：`main`；检出 SHA `758855cd86c9aaa050d0a5a7fe2272a88cd05a5b`（repo `yi-fen/FilterKit`）。
- Job：`build`（`swift build`）；workflow job run `b0771806-ac40-53bf-92dc-f4a8127c41a5`；日志时间 2026-11-18 14:56Z。
- 环境：macOS 26.7.2（25G332）/ image `macos-26-arm64` 20261112.0504.1 / runner 2.338.2 / git 2.56.1 / westus MacCloud。
- 结果：AppPresentation 编译阶段退出码 1；`swift test`、隔离脚本、App XcodeGen 步骤均未进入；日志 0 warning。

## 1. 失败定位

| 阶段 | 结论 | 证据 |
|---|---|---|
| Models 编译 | 通过 | 日志 `[14/14] Compiling Models ReportEnvelope.swift` |
| Adapters 编译 | 通过 | 日志 `[18/24] Compiling Adapters RootlessAdapter.swift` |
| AppPresentation 编译 | ❌ 2 处错误（各在并行两次编译中重复出现一次） | `build/job-logs.txt` |
| Core 编译 | 刚开始即被中断，未暴露该层编译结果 | 日志 `[25/65] Compiling Core PlistValueKind.swift` 后退出 |

## 2. 根因与本地修复

### 错误 1：不可变 `let` 数组调用 `append`

- 位置：`App/Presentation/PluginDetailModel.swift:82:29`
- 原文：`error: cannot use mutating member on immutable value: 'filterRows' is a 'let' constant`；note 指向第 35 行 `public let filterRows: [DetailRow]`。
- 现场：init 内先 `self.filterRows = [Bundles / Executables / Classes / Other Keys]`，随后 `if let cf = filter?.coreFoundationVersion { self.filterRows.append(...) }`；`let` 数组不可 `append`。
- 修复：保持 struct 只读语义，init 内先建局部 `var filterRows = [...]`，append CoreFoundation 行后 `self.filterRows = filterRows`；与同文件既有 `ownershipRows` / `evidenceRows` 的「局部 var 再赋值」范式一致。属性仍为 `public let`，未改成 `var`。

### 错误 2：`FilterRule` 初始化实参顺序错误

- 位置：`App/Presentation/SyntheticReportFactory.swift:51:33`
- 原文：`error: argument 'classes' must precede argument 'executables'`。
- 冻结契约（`Models/PluginModels.swift` `FilterRule.init`）顺序：`bundles, classes, executables, coreFoundationVersion, otherKeys`。
- 修复：调用改为 `FilterRule(bundles: ["com.example.app"], classes: ["ExampleHook"], executables: ["ExampleApp"])`；未改 init 签名与默认参数。

## 3. 同类隐患排查（静态文本层面）

- 全 `App/` 无其他 `self.<row 数组>.append`；`ownershipRows`、`evidenceRows`、`DiagnosticsSections.jbrootRows/parsingRows` 本就是局部 `var` 再赋值范式。
- 其余 `FilterRule` 多参数调用站点顺序均正确：`Tests/Stage2/ModelsCodableTests.swift:116/162`、`ReportExporterTests.swift:136`、`FilterParseEngineTests.swift:373/457`；单参数 `bundles:` 站点不受影响。
- Presentation 导入面仍仅 Foundation + Models；隔离脚本 `check-adapter-isolation.sh` 全项退出码 0。

## 4. 待下一轮 Runner 复核

- AppPresentation / Models / Adapters / Core 库 `swift build` 0 error / 0 warning；`swift test` 既有回归 397 例 + GUI-01～08 共 8 例通过；隔离脚本通过。
- SwiftUI App 视图层（`App/Features/`、`App/Navigation/`、`App/AppEntry/`）不在 SwiftPM `swift build` 编译面内，其编译风险待 Runner app-build（XcodeGen）步骤暴露。
- 本机 Linux 无 Swift/Xcode 工具链，修复未经本地编译验证，结论以 Runner 日志为准。
