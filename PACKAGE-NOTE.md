# FilterKit DevDocs 0.1

## 基线

- 本地提交：`e6845aa`（0.1-C interim 复核：补归档 f50c284d 轮 test-log 405/0/0；C-F4 门禁状态落档，G2/G3/G4/G6/G7 旧树通过待 HEAD 复核，G1/G5/G8/G9/G10 缺证；0.1-C 不予闭环）。
- 上游链：`9e26a6e`（C-F1～F4 落地：386f18c 轮 test-log 归档、隔离脚本 JSON 摘要 + CI 接线、C-F3/C-F4 规格冻结）；`c741856`（第三轮 Runner 验收归档）；`0a341f8`（四视图补 `import Core`）；`549d7ae`（首轮 AppPresentation 两处修复）；`8b3b057`（Stage 2.3 / 0.1-C GUI Foundation 落盘）；`1dff38a`（0.1-B 闭环）。
- 打包时间：2026-11-19（UTC+8）。
- 本机 Linux 无 Swift/Xcode 工具链；本包仅含规格、源码快照、测试与历史 Runner 证据，编译、渲染与测试结论以 Runner 日志为准。

## 当前状态：0.1-A 已闭环；0.1-B 已闭环（CI/Simulator 口径）；0.1-C interim 复核完成、未闭环，待 HEAD 基线新统一 Runner；0.1-D 未授权

### 0.1-A Engine C2 收口（已闭环，CI/Simulator 口径）

第五轮统一验收 Runner `44106064051`：379 例 0 fail / 0 skip，Core 0 error / 0 warning，App BUILD SUCCEEDED、PID 3508 存活，隔离六项 OK；C-G1～G7 passed。证据 `Tests/Stage2/evidence/run-44106064051-acceptance/`。

### 0.1-B 统一报告与 JSON 导出（已闭环，CI/Simulator 口径）

第四轮 Runner `44224350333`（检出 SHA `9a3f087f6a699cf3390aad42668e5fed5be3d378`）：397 例 0 failures / 0 skipped（既有回归 379 + Reporting 18）；S1-05 15/15；隔离 OK；App BUILD SUCCEEDED、PID 4096 alive。证据 `Tests/Stage2/evidence/run-44224350333-acceptance/`。

### 0.1-C GUI Foundation（interim：旧树部分取证，HEAD 基线待统一 Runner）

冻结规格 `Spec/Stage-2/Stage-2.3-GUI-Foundation-Spec.md`；实现记录 `Spec/Stage-2/Stage-2.3-GUI-Foundation-Implementation-Record.md`；门禁规格 `Stage-2.3-CF4-Final-Acceptance-Gates.md`；交互规格 `Stage-2.3-CF3-Simulator-Interaction-Acceptance.md`。

- 分层：`App/Presentation/` 纯 Foundation 映射层；`App/Features/` SwiftUI 视图 + ViewModel；四页只读 + Settings 经 `ReportExporting` 接缝导出（写 App 临时目录 + Share Sheet）。
- 单测 `GUIPresentationTests`：GUI-01～08。

**第三轮 run `120016036175`（SHA `f50c284d`，旧远程树）回传复核**：

| 门禁 | 结论 | 证据 |
|---|---|---|
| G1 非 UI Build | ❌ 缺独立 build 明细 | 无 build job 日志 |
| G2 全量 XCTest | 🟡 405 tests，0 failures（0 unexpected），0 skipped，38 套件；旧树通过，HEAD 待复核 | `run-120016036175-acceptance/test/test-log.txt` |
| G3 S1-05 | 🟡 15/15 passed；HEAD 待复核 | `test/test-log-s105.txt` |
| G4 GUI Presentation | 🟡 8/8 passed；HEAD 待复核 | 同上 |
| G5 Isolation | ❌ 旧工作流未上传隔离产物；仅本机复跑证据 | 待 Runner |
| G6 App Build | 🟡 `** BUILD SUCCEEDED **`，0 error；旧树通过 | `app-build/app-xcodebuild.log` |
| G7 Simulator 启动 | 🟡 PID 13225 alive；旧树通过 | `app-build/sim-launch.log` |
| G8 五页面导航交互 | ❌ 仅 Dashboard 首屏截图 | 待 Runner |
| G9 JSON 导出 | ❌ 无模拟器导出样本 | 待 Runner |
| G10 Share Sheet | ❌ 无取证 | 待 Runner |

- 门禁逐项判定见 `Tests/Stage2/evidence/run-120016036175-acceptance/C-F4-Gate-Status.md`；缺口清单 `C-F1-GAPS.md`（F1-1 build 明细、F1-4 isolation 输出仍缺）。
- 闭环前置：推送本地 HEAD 到 `main` → HEAD 基线新统一 Runner 补齐 G1/G5/G8/G9/G10 并复跑 🟡 项 → 全部门禁归档后签署。本地 HEAD 提交无 `.swift` 改动，可降低回归风险，但不替代 Runner 复核。

### C-Final 补证批次（C-F1～F4 实施完成，Runner 待调度）

- **C-F1**：386f18cb 轮 test-log 归档于 `run-089d13ea-app-build-failure/test-log/`（405/0/0，GUI 8/8，S1-05 15/15）；f50c284d 轮 test-log 本轮补归档于 `run-120016036175-acceptance/test/`。
- **C-F2**：隔离脚本追加 JSON 摘要（`checks[].id/name/status` + `failed`），CI isolation job 归档 `isolation-output.log` / `isolation-summary.json`；本机复跑 7 项 passed、`failed=0`。Runner 复核待新轮次。
- **C-F3 / C-F4**：五页面交互清单与十项门禁规格已冻结。

## 边界与未决项

- 0.1-C 合成信封仅用于界面预览，不代表真实 RootHide 文件权限、真实加载或扫描结果；真机探针属 0.1-D。
- `Core/OwnershipResolver/` 仍占位未迁移；`loaded` 恒 `.unknown`；`permission.decision` 恒 `undetermined`；`pluginID` 稳定标识规则 0.2.0 定稿；PARSE-009-B 继续挂起。
- Deployment Target（草案 iOS 17.0）、Bundle ID（占位 `com.filterkit.manager`）待链接 + 真机证据冻结。
- 本包所有 CI/Simulator 口径结论均不构成真机权限、真实加载、Rootless 真机兼容或可写入管理证据。

## 打包排除项

`.git/`、小写 `research/`（第三方上游克隆）、`node_modules/`、编译产物（`build/`、`.theos/`、`DerivedData/`、`.build/`、`.swiftpm/`、`*.xcodeproj/`、`*.xcworkspace/`）、`.tmp/`、`.DS_Store`、`*.zip`、`App/Info.plist`；`Research/` 仅排除 `Research/Validation/evidence/0.1.18-device-report.json` 设备私有数据。
