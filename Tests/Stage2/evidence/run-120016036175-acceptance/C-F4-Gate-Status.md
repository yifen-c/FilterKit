# C-F4 门禁状态（interim，run `120016036175` / SHA `f50c284d`，2026-11-19 复核）

> 本记录是对第三轮 Runner 回传产物的逐项核对，**不是 0.1-C 最终签署**。最终门禁须以 HEAD `9e26a6e` 基线的一次新统一 Runner 为准（见 `Spec/Stage-2/Stage-2.3-CF4-Final-Acceptance-Gates.md`）。

## 0. 批次归属核对

- 本批附件工作流 yml 哈希 `68eab398…`，与本目录 `metadata/filterkit-build.yml` 一致，区别于本地 HEAD 工作流 `e7d2bc5…`；即 Runner 检出的是远端 `main` = `f50c284d` 旧树。
- 本地 HEAD `9e26a6e` 尚未推送远端；该提交仅改工作流、隔离脚本、规格与证据归档，**无 `.swift` 源码/测试改动**。
- 本批 app-build 日志、截图、PID 与既有第三轮归档哈希一致，确认为同一轮次回传，非新 Runner。

## 1. 十项门禁逐项判定

| 门禁 | 验收内容 | 本批证据 | 判定 |
|---|---|---|---|
| G1 | Models / Adapters / Core Build | 无独立 `swift build` 明细日志；test 日志内编译了 Models/Adapters/AppPresentation，不能替代 build job 取证 | ❌ 缺证 |
| G2 | 全量 XCTest | `test/test-log.txt`：**405 tests，0 failures（0 unexpected），0 skipped**，38 套件全 passed；归属 f50c284d 树 | 🟡 旧树通过，HEAD 待复核 |
| G3 | S1-05 独立 15 项 | `test/test-log-s105.txt`：15/15 passed，0 failure；含 PAIR-011、两个 PAIR-013 变体 | 🟡 旧树通过，HEAD 待复核 |
| G4 | GUI Presentation 测试 | `GUIPresentationTests` 8/8 passed（GUI-01～08） | 🟡 旧树通过，HEAD 待复核 |
| G5 | Isolation 原始日志 + JSON 摘要 | 旧工作流未配置 isolation 产物上传；无 Runner 原始输出与摘要；仅有本机复跑 7 项 passed 证据 | ❌ Runner 缺证 |
| G6 | App Build | `app-build/app-xcodebuild.log`：`** BUILD SUCCEEDED **`，0 `error:`，1 条 AppIntents 良性提示 | 🟡 旧树通过，HEAD 待复核 |
| G7 | Simulator 启动 | `app-build/sim-launch.log`：PID 13225 alive；iPhone 17 Pro `5AB3DACF…` | 🟡 旧树通过，HEAD 待复核 |
| G8 | 五页面导航及交互 | 仅 `dashboard.png` 首屏；Plugins / Detail / Diagnostics / Settings 未点击取证 | ❌ 缺证 |
| G9 | JSON 导出 | 无模拟器导出 JSON 样本；仅 GUI-08 单测接缝往返 | ❌ 缺证 |
| G10 | Share Sheet | 无 Share Sheet 截图与取证 | ❌ 缺证 |

## 2. 计数口径

- 405 = 既有基线 397 + GUI 8；S1-05 15 例已计入基线，不与总数相加。Reporting 18 例（Builder 6 / Validator 4 / Exporter 5 / Service 3）含在基线内。
- 本批 405 结论不可挪用为 HEAD 基线证据；HEAD 无 Swift 改动可降低回归风险，但不替代 Runner 复核。

## 3. 闭环前剩余动作

1. 推送 `9e26a6e` 到远端 `main`，确认 Runner 检出 SHA 一致。
2. 新统一 Runner 补齐：G1 build 明细、G5 isolation 原始日志 + JSON 摘要、G8 五页面交互截图、G9 导出 JSON 样本、G10 Share Sheet。
3. G2/G3/G4/G6/G7 在 HEAD 树复跑确认；全部门禁通过并归档后，按 C-F4 签署关闭 0.1-C。

## 4. 未纳入本轮判定

真机 JBROOT/TweakInject/dylib/plist/dpkg 读取、Entitlement/Sandbox、进程内 `jbroot()`、真实加载与 Rootless 真机兼容——属 0.1-D Permission Probe，待 0.1-C 关闭后另立规格授权；在此之前禁止插件启停与越狱文件写入。
