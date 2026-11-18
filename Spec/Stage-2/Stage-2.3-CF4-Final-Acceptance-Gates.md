# Stage 2.3 C-F4：0.1-C 最终统一 Runner 验收门禁（冻结，待调度）

- 定位：C-F1（CI 日志补齐）、C-F2（隔离机器可读摘要）、C-F3（五页面交互取证）完成后，执行一次完整 Runner 作为 0.1-C / Stage 2.3 GUI Foundation 的闭环门禁。本规格冻结门禁与取证口径，不在本机执行编译/测试/模拟器。
- 前置：C-F1 缺口清单 `Tests/Stage2/evidence/run-120016036175-acceptance/C-F1-GAPS.md` 各项有真实日志；C-F3 截图与导出样本归档齐备；隔离脚本机器可读摘要可被 CI 比较。
- 计数口径：基线为 0.1-B 闭环的 397 例既有回归，加 GUI-01～08 共 8 例；S1-05 15 例为独立过滤口径，不与 XCTest 总数相加。**最终通过数量以真实日志 `Executed N tests` 为准，不预先写死为 405。**

## 1. 门禁表

| 门禁 | 通过条件 | 证据来源 | 不得仅凭 |
|---|---|---|---|
| Build（非 UI 目标） | Models / Adapters / Core `swift build` 0 error / 0 warning | build job 日志 `Build complete` 行 | CI 绿色勾选 |
| Test（全量 XCTest） | 既有回归 + GUI-01～08 实际执行；Failure = 0；Unexpected Skip = 0；套件明细可追溯 | `filterkit-test-log.txt` + 测试摘要 | 进程退出码 0 |
| S1-05 独立过滤 | `PluginPairingS105FixtureTests` 15/15 passed，0 failure | `test-log-s105.txt` / S1-05 摘要 | 全量测试顺带通过 |
| GUI Tests | `GUIPresentationTests` 8/8 passed（GUI-01～08 逐一有执行记录） | test-log 内套件段 | 列表源码存在 |
| Isolation | 1a/1b/2a/2b/3/4/4b 全部 `passed`，机器可读摘要 `failed = 0`；原始脚本输出留存 | `isolation-output.log` + `isolation-summary.json` | 脚本退出码 0 |
| App Build | XcodeGen 生成后 `** BUILD SUCCEEDED **`，0 `error:` | `app-xcodebuild.log` | 产物目录存在 |
| Simulator 启动 | 模拟器 Booted，`com.filterkit.manager` 安装、启动、alive check PID 存活 | `sim-launch.log` | 安装成功 |
| Navigation | Dashboard / Plugins / Detail / Diagnostics / Settings 五面可达，导航无崩溃卡死；C-F3 §2～§4 观察项逐项通过 | `simulator/*.png` 与交互日志 | 首屏截图 |
| Export | 经 `ReportExporting` 接缝生成合法 JSON；样本可重新解析回等义信封；仅写 App 临时目录 | `export/` JSON 样本 + Settings 截图 | 按钮可点 |
| Share | 系统 Share Sheet 正常调起并归档 `share-sheet.png` | 截图 | 导出成功 |

## 2. 必须显式复核的口径

- `loaded = .unknown` 全程显示为未确认态，不得渲染为 Not Loaded / 已加载；`configured` 不推导 `loaded`。
- 未知项、warnings、skippedFields、otherKeys 不被 UI 裁剪；空组展示空态而非省略。
- 导出只写 `FileManager.default.temporaryDirectory`；不得写 JBROOT / TweakInject / 越狱目录，不改原始信封。
- 隔离摘要与文本输出一致；机器可读 `failed` 计数与脚本文本 OK/FAIL 项一一对应。
- 无信封样本：导出入口禁用并说明空态文案。

## 3. 不纳入 0.1-C 闭环判定的事项

- 真机目录扫描、真实插件加载、entitlement 放行、GUI 进程内 `jbroot()` 调用、sandbox 放行、Rootless 真机兼容——属 0.1-D Permission Probe 及后续批次。
- 归属识别 `OwnershipResolver` 未迁移；`loaded` 恒 `.unknown`；`permission.decision` 恒 `undetermined`；`pluginID` 稳定标识规则 0.2.0 定稿；PARSE-009-B 继续独立挂起。
- 模拟器合成信封通过不构成真机权限或可写入管理证据。

## 4. 闭环动作（门禁全绿后）

1. 归集 build / test / S1-05 / isolation / app-build / simulator / export / Share 证据到最终验收目录，生成统一 `ACCEPTANCE.md`。
2. 回填 `Stage-2.3-GUI-Foundation-Implementation-Record.md`：各门禁实际计数、套件明细、截图清单与未决项。
3. 更新 DevDocs 资料包与进度记录；随后才进入 0.1-D 批次规划（D1 PermissionProbe Models → D2 JBROOT Probe → D3 ElleKit Directory Probe → D4 Plugin File Probe → D5 Entitlement & jbroot Probe → D6 GUI Integration），0.1-D 设计另立规格，不混入本门禁。

## 5. 未闭环判定

任一门禁不通过、证据缺失无法复核、或观察项与 C-F3 清单冲突：0.1-C 不予关闭，按失败项回到对应批次修复后重跑完整 Runner；不得用后续批次结论回填本阶段门禁。
