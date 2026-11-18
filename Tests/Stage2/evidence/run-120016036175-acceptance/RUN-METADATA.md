# RUN-METADATA.md — 0.1-C Stage 2.3 GUI Foundation 第三轮 Runner 验收（app-build 全绿；test-log 已补归档；交互/导出待取证）

- Workflow run：`120016036175`；branch `main`；检出 SHA `f50c284dfe9b6b40a0b877eeb5d6588dbb9f78a4`；工作流文件 `.github/workflows/filterkit-build.yml@refs/heads/main`；repo `yi-fen/FilterKit`。
- 本地基线：HEAD `0a341f8`（第二轮四视图补 `import Core`）。本轮核对：`metadata/Package.swift`、`project.yml`、`Makefile`、`control` 与本地逐文件 diff 一致；Runner 检出 SHA 与本地 HEAD 不同名（历史远程经网页上传），归档结论以 Runner 实际日志为准，不声称本地 HEAD 已被本轮 Runner 逐行重新编译验证。app-build 日志显示 `DashboardView`/`DiagnosticsView`/`PluginListView`/`SettingsView` 及 `PluginDetailView`、`FilterKitApp` 等全部 App 源码在 `FilterKit` 目标内双架构（arm64/x86_64）编译通过，佐证两轮修复（`549d7ae` AppPresentation 两处、`0a341f8` 四视图导入）已进入 Runner 检出树。
- 时间：2026-11-18 16:01:41 ~ 16:14:32Z（UTC）。
- 环境：macOS 26.7.2（25G332）/ `macos-26-arm64` 20261112.0504.1 / runner 2.338.2 / westus MacCloud；Xcode 26.6（`/Applications/Xcode_26.6.app`）；iPhoneSimulator26.5.sdk；Swift 5；XcodeGen 2.46.0；模拟器 iPhone 17 Pro（`5AB3DACF-C352-49D1-BF9A-3C0104FA4ED3`）。

## 1. 门禁结论

| 验收门 | 结论 | 证据口径 |
|---|---|---|
| environment（工具链版本记录） | ⚪ 未随本批附件提供步骤日志；任务序列在跑 | 无本轮步骤取证 |
| build（Models / Adapters / Core 非 UI 目标） | 🟡 job 退出 0（success，artifact `needs` 映射）；`Build complete` 与 0 error / 0 warning 明细未取证 | `logs/artifact/` Worker 日志 `needs.build.result=success` |
| test（全量 Swift 测试 + S1-05 独立过滤） | ✅ 已取证（f50c284d 远程树）：`test/test-log.txt` **Executed 405 tests，0 failures（0 unexpected），0 skipped**，38 套件全 passed；`GUIPresentationTests` 8/8；`PluginPairingS105FixtureTests` 15/15；Reporting 18 例。归属 f50c284d 树，本地 HEAD `9e26a6e` 尚未推送，待 HEAD 基线 Runner 复核 | `test/test-log.txt`、`test/test-log-s105.txt`、`test/test-summary.json`、`test/s1-05-summary.txt` |
| isolation（适配器 / 路线三向静态检查） | 🟡 job 退出 0（success，`needs.isolation.result=success`）；脚本逐项 OK 输出未取证 | `logs/artifact/` Worker 日志 `needs.isolation.result=success` |
| app-build（XcodeGen + xcodebuild + 模拟器存活 + 截图） | ✅ **全量取证通过**：XcodeGen 生成工程；`** BUILD SUCCEEDED **`；0 条 `error:`；`FilterKit.app` 定位、安装、启动；alive check 通过；截图归档 | `app-build/app-xcodebuild.log`、`app-build/sim-launch.log`、`app-build/dashboard.png`、`logs/app-build/` |

> 口径说明：`needs` 映射的 `result: success` 仅证明对应 job 退出码为 0；在缺少 build/test/isolation 步骤日志与 test-log 产物时，不能据此复述具体编译耗时、warning 条数、测试用例数或断言明细。待 `filterkit-test-log` artifact 补齐后再登记用例分列。

## 2. app-build 取证明细

- 编译：Models / Adapters / Core / FilterKit 四目标；`app-xcodebuild.log` 全文 0 条 `error:`；1 条 `warning:` 为 `appintentsmetadataprocessor` 元数据提取跳过（未链接 AppIntents.framework，非代码告警，不计入源码 warning）。
- 产物：`build/DerivedData/Build/Products/Debug-iphonesimulator/FilterKit.app`（`FilterKit` 可执行 + `FilterKit.debug.dylib` + `__preview.dylib` + `Info.plist` + `PkgInfo` + 签名）。
- 启动：bundle `com.filterkit.manager`，launch PID `13225`；冷启动 3 秒后 alive check：`13225 0 UIKitApplication:com.filterkit.manager[134d][rb-legacy]`，`App alive: PID 13225 (launch PID 13225)`。
- 截图：`app-build/dashboard.png`（MD5 `3d258d430e3ee7b9887a8cd64b6e478a`，1206×2622）。

### 截图内容（Dashboard 合成信封渲染）

- 标题 `FilterKit`；Environment 卡片：Jailbreak `RootHide`（绿标 RootHide）、ElleKit `ellekit 1.0.0`、Profile `roothide-preview`。
- Plugins 统计：Total 3 / Paired 2 / Missing 1 / Parse Failed 1。
- System 卡片：JBROOT `/private/var/jb`（绿标 Confirmed）；TweakInject `/private/var/jb/Library/TweakInject`（绿标 Accessible）；Permission `Undetermined`（灰标 2.4 probe）。
- 底部 Tab：Dashboard（选中）/ Plugins / Diagnostics / Settings；脚注「只读界面：展示信封由 Core/Models 生成；本阶段不含扫描、启停或写入功能」。
- 与 0.1-B 骨架截图（环境「尚未检测」）对比：本轮 Dashboard 已接入 `SyntheticReportFactory` 合成信封并完成映射渲染。

## 3. 本轮取证缺口（下一批次补齐）

1. ~~`filterkit-test-log`（`test-log.txt` / `test-log-s105.txt`）未随包上传~~ **已补归档**（2026-11-19）：405 例 0 failure / 0 unexpected / 0 skip，GUI 8/8，S1-05 15/15；该结论归属 f50c284d 远程树，HEAD `9e26a6e` 基线仍需新 Runner 复核。
2. build / isolation / environment 步骤日志未随包上传：0 error/0 warning、隔离脚本逐项 OK、工具链版本输出待对应日志复核。
3. 模拟器内仅取证 Dashboard 首屏；Plugins 列表、Plugin Detail、Diagnostics、Settings 四页切换与交互、Settings 导出落临时目录未在本轮点击取证；其余页面正确性以 GUI-01～08 单测（待 test-log 复核）为准。
4. 本轮未扫描真机目录；合成信封不代表真实 RootHide 文件权限、真实加载或扫描结果。

## 4. 产物与归档

| 附件 | 大小 | SHA256 |
|---|---:|---|
| `filterkit-build-metadata.zip` | 7778 B | `0205b72e2f0ba0bd9d072703d50b7201ca9887a50bab98c9507c553da8345c23` |
| `logs_120016036175.zip` | 163756 B | `964e069d4f8492a09e65b164e9745fda8bdc0e0c9852bc5caded4b7cdf43fc35` |
| `filterkit-app-build 2.zip` | 2738899 B | `599b55c100d3160d7f7087fef30e9484b1a009877912a583d80a45e129ba71e9` |
| `filterkit-test-log.zip` | 11123 B | `aaef54c016cab3206c8927252dcc44362a25a50aa10f529063e935354d697dff` |

- check_run：app-build `134932122496`；artifact `134940908003`。
- 归档目录：`Tests/Stage2/evidence/run-120016036175-acceptance/`（`app-build/`、`logs/`、`metadata/`）。

## 5. 边界与未决观察项

- Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；未修改 plist / 插件文件，未做启停 / 注入 / dpkg / 软链改动 / 配置写入；Parser 不推断 `loaded`。
- 归属识别（`Core/OwnershipResolver/`）仍未迁移；`loaded` 恒 `.unknown`；`permission.decision` 恒 `undetermined`；`pluginID` 稳定标识规则 0.2.0 定稿；PARSE-009-B 继续挂起。
- 本轮未改冻结公共 Models 字段 / init / 解码契约、七方法 `ElleKitAdapter` 协议、Parser 语义与 Stage1 fixtures。
- 本批次为 CI/Simulator 口径；app-build 存活与 Dashboard 渲染已取证，真机权限、真实加载、Rootless 真机兼容、四页交互与导出落盘仍需后续批次单独取证。
