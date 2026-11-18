# Stage 2.3（0.1-C）：GUI Foundation 实现记录

- 日期：2026-11-18
- 授权依据：用户上传 MD（0.1-B 第四轮 Runner `44224350333` 闭环后授权进入 0.1-C）；冻结规格 `Stage-2.3-GUI-Foundation-Spec.md`（C1～C6，GUI-01～08）。
- 状态标记：**Implementation Landed / Local L1 Static Review Passed / Runner Build & Test Pending**。本机 Linux 无 Swift/Xcode 工具链，本轮未编译、未执行 XCTest；编译、渲染与交互结论以阶段末统一 Runner 为准。

## 1. 本轮授权边界

### 允许
1. 按 C1～C6 批次新增 App Presentation 纯映射层、SwiftUI 视图与 ViewModel、共享组件、导航与组合根；
2. 新增 SwiftPM `AppPresentation` 目标（只依赖 Models）与对应 Presentation 单测；
3. 扩展隔离脚本 GUI 禁止面；
4. 只读静态检查、接口核对与代码审查。

### 禁止（本轮均未触碰）
1. 未修改冻结公共 Models 字段/init/解码契约、七方法 `ElleKitAdapter` 协议、Parser 语义、`ReportEnvelope` 契约与 Stage1 fixtures；
2. 未实现 `OwnershipResolver`；未迁移归属分类器；
3. 未在 App 内实现扫描、枚举、配对、解析、归属补判或运行时取证；
4. 未做启停、装卸、plist/规则/注入规则修改、entitlement 放行、进程内 `jbroot()`；
5. 未接入真机快照 → `ReportBuildInput` → 信封的在线链路（属 0.1-D）；
6. 未调度阶段末统一 Runner，未声称本地编译通过；PARSE-009-B 继续挂起。

## 2. 文件清单

### 2.1 Presentation 纯映射层（`App/Presentation/`，只 import Foundation + Models）

| 路径 | 说明 |
|---|---|
| `DisplayStatus.swift` | `DisplayStatusKind`（success/warning/failure/unknown）与 `DisplayStatus` 展示状态 |
| `ReportLabels.swift` | 冻结枚举 → 展示文案唯一落点；三层状态、配对/来源/归属/证据、解析状态映射 |
| `DashboardOverview.swift` | 环境行、插件统计（Total/Paired/Missing/Parse Failed）、系统状态行；空信封全 0 + Unknown |
| `PluginRowSummary.swift` | 列表行摘要、关键词搜索、ALL/PAIRED/ISSUES 分段筛选 |
| `PluginDetailModel.swift` | 详情六分区模型：状态/文件/配对/Filter/归属/证据 |
| `DiagnosticsSections.swift` | 诊断七分组：Environment/JBROOT/DynamicLibraries/Enumeration/Parsing/Warnings/UnknownItems |
| `SyntheticReportFactory.swift` | 0.1-C 预览用固定合成信封与空信封工厂（不冒充真机扫描） |

### 2.2 App 装配 / 导航 / 视图

| 路径 | 说明 |
|---|---|
| `App/AppEntry/AppDependencies.swift` | `ReportProviding` 接缝、`StaticReportProvider`、`AppDependencies`（报告来源 + `ReportExporting` 接缝） |
| `App/AppEntry/FilterKitApp.swift` | 唯一 `@main` 组合根；静态合成信封 + `ReportExporter()` 注入 |
| `App/Navigation/AppTab.swift` | 四 Tab 枚举（Dashboard/Plugins/Diagnostics/Settings） |
| `App/Navigation/RootTabView.swift` | `TabView` 四页容器 |
| `App/Features/Dashboard/` | `DashboardViewModel` + `DashboardView`（环境卡片、统计、系统状态行） |
| `App/Features/Plugins/PluginListViewModel.swift` | 列表搜索/筛选装配；按 pluginID 回查完整 `Plugin` |
| `App/Features/Plugins/PluginListView.swift` | 搜索框、分段筛选、列表行、详情导航 |
| `App/Features/Plugins/PluginDetailView.swift` | 详情六分区只读展示 |
| `App/Features/Diagnostics/` | `DiagnosticsViewModel` + `DiagnosticsView`（诊断分组） |
| `App/Features/Settings/SettingsViewModel.swift` | 版本信息；经 `ReportExporting.export(_:)` 导出到 App 临时目录；错误文案保留 |
| `App/Features/Settings/SettingsView.swift` | 版本行、导出按钮、Share Sheet、错误提示 |
| `App/Shared/Components/` | `StatusBadgeView` / `InfoRowView` / `SectionCardView` 只读通用组件 |

### 2.3 测试与接线

| 路径 | 说明 |
|---|---|
| `Tests/Stage2/GUIPresentationTests.swift` | GUI-01～08：空态、计数归类、搜索、筛选、三态标签、详情映射、诊断归集、导出接缝往返 |
| `Package.swift` | 新增 `AppPresentation` 库目标（依赖 Models）与产品；`Stage2Tests` 依赖增补 `AppPresentation` 与测试源 |
| `scripts/check-adapter-isolation.sh` | §4 增补 `PluginInventoryBuilder`/`PluginPairingPipeline`/`PluginPairingInputAdapter`/`PluginFilterParseEngine`/`ReportBuilder`/`ReportValidator`/`ReportService` 禁止面；§4b 检查 App 不得 `import Adapters` |

### 2.4 移除的旧骨架

- 删除 `App/FilterKitApp.swift` 旧占位入口（含 `AppAssembly`/`StubAdapterResolver`）与 `App/Views/DashboardView.swift` 骨架页；`App/Views/`、`App/ViewModels/` 目录由 `App/Features/`、`App/Navigation/`、`App/AppEntry/` 取代。`PermissionProbe/` 2.4 预留轮廓保留不动。

## 3. 实现口径要点

### 3.1 C1 架构
- 依赖方向：App Features → Presentation → Models；App 装配层持有 `ReportExporting` 协议接缝，不引用 Core 具体实现。
- `AppPresentation` 不 import SwiftUI/UIKit/Core，可被 SwiftPM 测试目标独立编译。
- 0.1-C 装配为静态信封提供者；无异步 `generateReport()`，`buildReport(input:)` 在线接入延后到 0.1-D。

### 3.2 C2 Dashboard
- 计数：Total=`plugins.count`；Paired=`pairing == .paired`；Missing=其余；Parse Failed=`validation.status ∈ {parse_failed, type_mismatch, read_failed}`，`not_parsed` 不计入。
- JBROOT 取 `environment.jbroot ?? pathEvidence.jbrootCandidates.first`；Permission 恒 undetermined 占位。

### 3.3 C3 列表
- 搜索命中 `name`/`pluginID` 大小写不敏感包含；空关键词全量。
- ISSUES = 配对未成功 或 未配置 或 `validation.status != valid`。
- 行内三层状态标签 + 配对标签；无启停/删除入口。

### 3.4 C4 详情
- 路径缺失展示 Unknown，不拼默认路径；空数组展示 `—`；归属冲突/备注/标记/包版本/架构原样追加。
- `loaded == .unknown` 文案 "Unknown · Runtime state not verified"，不渲染为 Not Loaded。

### 3.5 C5 诊断与导出
- 诊断七分组完整归集 Warnings / UnknownItems，不裁剪字段。
- 导出经 `ReportExporting.export(_:)` 产出 Data；UI 层不构造编码器、不重排键序；文件写 `FileManager.default.temporaryDirectory`，文件名 `FilterKit-Report-<generatorVersion>.json`；无信封时导出入口禁用。

### 3.6 C6 集成
- 空态：列表 `ContentUnavailableView`；诊断空分组 `—`；Dashboard 空信封计数全 0。
- 隔离脚本静态文本检查通过；GUI 禁止面见规格 §10。

## 4. L1 静态自检记录（本机无 Swift 工具链，未本地编译）

| 检查项 | 结果 |
|---|---|
| 隔离脚本 `check-adapter-isolation.sh` 全项 | OK（1a/1b/2a/2b/3/4/4b 均通过，退出码 0） |
| Presentation 导入面 | 仅 Foundation + Models，无 SwiftUI/UIKit/Core |
| `@main` 唯一性 | App 内仅 `AppEntry/FilterKitApp.swift` 一处 |
| App 对 Adapters 的直接依赖 | 无 `import Adapters` |
| App 文件系统/解析 API | 仅 `SettingsViewModel` 读取 `temporaryDirectory`；无目录枚举、plist 解码、解析器调用 |
| 括号配平 | 新增 App 与测试 Swift 文件 `{}`/`()` 配平一致 |
| 旧骨架符号残留 | 无 `AppAssembly`/`StubAdapterResolver`/旧 `DashboardView` 外部引用 |
| 冻结契约 | 未改 Models 字段/init/解码、Adapter 协议、Parser 语义、Stage1 fixtures |

## 5. 待验证与未决项（本阶段不闭合）

1. 阶段末统一 Runner：非 UI `swift build`、`swift test`（既有回归 397 + GUI 新增 8 例）、隔离脚本、App XcodeGen 生成与模拟器构建/启动/四页切换/合成信封渲染/导出落临时目录。
2. 真机快照在线接入（`ReportBuildInput` 组装与注入）属 0.1-D 探针阶段；合成信封通过只证明 UI 映射正确。
3. Deployment Target（草案 iOS 17.0）、Bundle ID（占位 `com.filterkit.manager`）待链接 + 真机证据冻结。
4. `OwnershipResolver` 未迁移；`loaded` 恒 `.unknown`；`pluginID` 稳定标识规则 0.2.0 定稿；PARSE-009-B 挂起。
5. 本阶段产物不构成真机权限、真实加载、Rootless 真机兼容或可写入管理证据。

## 6. 首轮 Runner `swift build` 失败修复（2026-11-18，待下一轮复核）

- Runner：`build` job，检出 SHA `758855cd86c9aaa050d0a5a7fe2272a88cd05a5b`；证据归档 `Tests/Stage2/evidence/run-9b9f00cb-build-failure/`（含完整 job 日志与 `RUN-METADATA.md`）。
- Models / Adapters 编译通过；AppPresentation 两处错误后 Core 刚开始编译即退出，未进入 `swift test` 与 app-build。

| # | 位置 | 错误 | 修复 |
|---|---|---|---|
| 1 | `App/Presentation/PluginDetailModel.swift:82` | `self.filterRows.append` 作用于 `public let` 常量数组，`cannot use mutating member on immutable value` | init 内改为局部 `var filterRows = [...]`，append CoreFoundation 行后 `self.filterRows = filterRows`；属性仍 `let`，沿用 `ownershipRows`/`evidenceRows` 局部 var 范式 |
| 2 | `App/Presentation/SyntheticReportFactory.swift:51` | `FilterRule` 实参 `executables` 先于 `classes`，`argument 'classes' must precede argument 'executables'` | 按冻结 init 顺序改为 `bundles:, classes:, executables:`；未改 init 签名与默认参数 |

- 同类隐患静态排查：全 `App/` 无其他 `self.<row>.append`；其余 `FilterRule` 多参数站点（ModelsCodableTests / ReportExporterTests / FilterParseEngineTests）顺序正确；隔离脚本复跑全项退出码 0；Presentation 导入面仍仅 Foundation + Models。
- 本机 Linux 无 Swift/Xcode 工具链，修复未本地编译；通过与否以下一轮 Runner `swift build` / `swift test` 日志为准。SwiftUI App 视图层不在 SwiftPM 编译面，其风险待 app-build（XcodeGen）步骤暴露。

## 7. 首轮 app-build（XcodeGen/xcodebuild）失败修复（2026-11-18，待下一轮复核）

- Runner：`app-build` job，检出 SHA `386f18cbd528a9ad11f8e690e883a6d76c5f8409`；Xcode 26.6 / Swift 5 / XcodeGen 2.46.0 / iOS Simulator Debug，退出码 65；证据归档 `Tests/Stage2/evidence/run-089d13ea-app-build-failure/`（`RUN-METADATA.md` + `build/job-logs.txt`）。
- 非 UI 包目标（Models/Adapters/Core）随 xcodebuild 依赖图编译未报该层错误；失败集中在 App target 模块发射（`EmitSwiftModule normal arm64`），未产出 `.app`、未进入模拟器启动。

| # | 位置 | 错误 | 修复 |
|---|---|---|---|
| 1 | `App/Features/Dashboard/DashboardView.swift:74` | `#Preview` 内 `ReportExporter()` 报 `cannot find 'ReportExporter' in scope`；文件仅 import SwiftUI/Models | 补 `import Core`（置于 `import Models` 后） |
| 2 | `App/Features/Diagnostics/DiagnosticsView.swift:50` | 同上 | 补 `import Core` |
| 3 | `App/Features/Plugins/PluginListView.swift:91` | 同上 | 补 `import Core` |
| 4 | `App/Features/Settings/SettingsView.swift:72` | 同上 | 补 `import Core` |

- 根因：`ReportExporter` 定义在 Core 模块；SwiftPM `swift build` 不编译 App target，首轮 `build` job 未暴露，XcodeGen 单模块编译后缺导入才在模块发射阶段报错。
- 复核：其余 `ReportExporter`/`ReportExporting` 引用点（`AppDependencies.swift`、`FilterKitApp.swift`、`SettingsViewModel.swift`）导入面完整；`ReportExporter` 不在隔离脚本 §4 禁止面；隔离脚本复跑全项退出码 0；未改装配逻辑、协议、Models 冻结契约。
- 本机 Linux 无 Swift/Xcode 工具链，修复未本地编译；待下一轮 Runner 复核 `** BUILD SUCCEEDED **`、模拟器存活、四页渲染与导出落临时目录。

## 8. 第三轮 Runner 验收（2026-11-18，app-build 全绿；test 明细待补证）

- Runner：workflow run `120016036175`，检出 SHA `f50c284dfe9b6b40a0b877eeb5d6588dbb9f78a4`；Xcode 26.6 / iPhoneSimulator26.5.sdk / Swift 5 / XcodeGen 2.46.0；证据归档 `Tests/Stage2/evidence/run-120016036175-acceptance/`。
- 门禁：artifact job `needs` 映射 `build / test / isolation / app-build` 四 job 均 `result: success`；本批附件仅含 app-build 产物日志与 metadata，build/test/isolation 步骤日志与 test-log 未随包上传，用例计数与隔离输出待补证（见证据归档 `RUN-METADATA.md` §1/§3）。
- app-build 全量取证通过：`** BUILD SUCCEEDED **`，0 条 `error:`（仅 1 条 AppIntents 元数据提取跳过的良性提示）；`FilterKit.app` 定位、安装、启动 PID 13225，3 秒后 alive check 通过；`dashboard.png` 1206×2622，Dashboard 合成信封渲染正确（RootHide / ellekit 1.0.0 / roothide-preview；3 插件 2 配对 1 Missing 1 Parse Failed；JBROOT Confirmed、TweakInject Accessible、Permission Undetermined 2.4 probe；四 Tab，Dashboard 选中）。
- 两轮修复（§6 `549d7ae`、§7 `0a341f8`）在 Runner 检出树编译通过：四视图与 Detail/Entry/Components 全部 App 源码双架构（arm64/x86_64）编入 `FilterKit` 目标，无作用域缺失或实参顺序错误。
- 未闭合取证项：GUI-01～08 八例与既有 397 例的实际执行计数待 `filterkit-test-log` 复核；Plugins/Detail/Diagnostics/Settings 页内交互与 Settings 导出落临时目录未在模拟器内点击取证；真机权限、真实加载、Rootless 真机兼容仍属后续批次。

## 9. 0.1-C-Final 补证批次 C-F1～F4（2026-11-19 授权，规格/归档落地，Runner 执行待调度）

> 路线调整：不提前进入 0.1-D 或插件启停开发；先完成 0.1-C 验收补证与交互验收，闭环后再规划 Permission Probe。

- **C-F1 CI 日志补证**：后补归档 386f18cb 轮次（第二轮 app-build 失败轮）SwiftPM XCTest 日志至 `Tests/Stage2/evidence/run-089d13ea-app-build-failure/test-log/`：全量 **405 tests，0 failures（0 unexpected），0 skipped**，38 套件全 passed；`GUIPresentationTests` 8/8；`PluginPairingS105FixtureTests` 15/15；摘要 `test-summary.json`、`s1-05-summary.txt`。f50c284d 轮次（run `120016036175`）缺项登记于同轮证据目录 `C-F1-GAPS.md`（build 明细 / 全量 test-log / S1-05 结果 / isolation 原始输出），不得以 Job 绿色勾选替代用例计数。
- **C-F2 隔离机器可读摘要**：`scripts/check-adapter-isolation.sh` 保留原文本输出与退出码，结尾追加 JSON 摘要（`checks[].id/name/status` + `failed` 计数），支持 `ISOLATION_SUMMARY_PATH` 落盘；CI `isolation` job 增补 `isolation-output.log` / `isolation-summary.json` 归档。本机复跑 7 项全 passed、`failed=0`，JSON 校验通过。
- **C-F3 五页面交互验收规格**：`Spec/Stage-2/Stage-2.3-CF3-Simulator-Interaction-Acceptance.md` 冻结 Plugins / Detail / Diagnostics / Settings / Share Sheet 观察清单、证据截图清单与导出边界；本机无模拟器，执行待 Runner。
- **C-F4 最终统一验收门禁**：`Spec/Stage-2/Stage-2.3-CF4-Final-Acceptance-Gates.md` 冻结 Build / Test / S1-05 / GUI / Isolation / App Build / Simulator / Navigation / Export / Share 十项门禁与取证口径；计数以真实日志为准，不预写死总数。
- 本批未新增 Swift 业务代码；未改冻结 Models 契约、Adapter 协议、Parser 语义与 Stage1 fixtures；本机 Linux 无 Swift/Xcode，脚本与 YAML 仅做语法/静态复跑，结论待 Runner 日志复核。

## 10. 第三轮回传产物复核（2026-11-19，interim，未签署 0.1-C）

- 用户回传 run `120016036175`（SHA `f50c284d`）四件产物；工作流 yml 哈希与本目录 `metadata/` 旧版一致，确认是远端旧树回传，非 HEAD `9e26a6e` 新 Runner。
- 补归档该轮 SwiftPM 日志至 `run-120016036175-acceptance/test/`：**405 tests，0 failures（0 unexpected），0 skipped**，38 套件；GUI 8/8、S1-05 15/15、Reporting 18 例；摘要 `test-summary.json`、`s1-05-summary.txt`。F1-2 / F1-3 关闭；F1-1 build 明细、F1-4 isolation 原始输出仍缺。
- 门禁逐项核对见 `run-120016036175-acceptance/C-F4-Gate-Status.md`：G2/G3/G4/G6/G7 为旧树通过（🟡 HEAD 待复核）；G1/G5/G8/G9/G10 缺证（❌）。
- 判定：**0.1-C 不予正式验收关闭**。前置：推送 `9e26a6e` 到 `main` → HEAD 基线新统一 Runner 补齐 G1/G5/G8/G9/G10 并复跑 🟡 项 → 全部门禁归档后签署。HEAD 提交无 `.swift` 改动，可降低回归风险，但不替代 Runner 复核。
