# C-F1 CI 日志 Artifact 缺口清单（run `120016036175`，SHA `f50c284d`）

> 口径：Job 退出码 success 只证明进程退出 0，不能替代用例计数、断言明细与脚本原始输出。本清单登记尚缺的 Runner 产物，补齐后逐项回填结论，不预先写死通过数量。

## 已取证（同归档目录）

| 门 | 证据 | 结论 |
|---|---|---|
| app-build | `app-build/app-xcodebuild.log`、`app-build/sim-launch.log`、`app-build/dashboard.png` | ✅ `** BUILD SUCCEEDED **`，0 error；PID 13225 存活；Dashboard 截图归档 |
| 全量 XCTest（F1-2） | `test/test-log.txt`、`test/test-summary.json` | ✅ f50c284d 轮 **Executed 405 tests，0 failures（0 unexpected），0 skipped**；38 套件全 passed；GUI 8/8；报告 18 例；归属 f50c284d 远程树，HEAD 9e26a6e 待复核 |
| S1-05 独立过滤（F1-3） | `test/test-log-s105.txt`、`test/s1-05-summary.txt` | ✅ 15/15 passed，0 failure；含 PAIR-011 AccessDenied 与两个 PAIR-013 变体 |

## 待补证

| # | 缺项 | 期望产物 | 验收条件（以真实日志为准） | 当前口径 |
|---|---|---|---|---|
| F1-1 | build job 明细 | `build/swift-build.log`、`build/build-summary.txt` | Models/Adapters/Core `Build complete`；0 error / 0 warning | 🟡 仅 `needs.build.result=success`，无明细 |
| F1-4 | isolation 原始输出 | `isolation/isolation-output.log`、`isolation/isolation-summary.json` | 1a/1b/2a/2b/3/4/4b 逐项 passed；机器可读摘要 `failed=0` | 🟡 仅 `needs.isolation.result=success`；旧工作流未配置 isolation 产物上传，Runner 原始输出未归档 |

## 旁证（非本轮次，不可挪用）

- 386f18cb 轮次（第二轮 app-build 失败轮）test-log 归档于 `../run-089d13ea-app-build-failure/test-log/`：405 例 0 failure / 0 unexpected / 0 skip，GUI 8/8，S1-05 15/15。该日志来自 SwiftPM test 目标，不编译 App SwiftUI 视图，**不能**作为 App target 或模拟器交互证据。
- 本轮 `test/` 日志归属 f50c284d 远程树；本地 HEAD `9e26a6e`（含 C-F2 脚本/CI 改动与 C-F3/F4 规格）尚未推送远端，本批 405 结论不能替代 HEAD 基线的 Runner 复核。

## 补齐后动作

1. 把对应日志落入上表目录，按 C-F2 口径生成机器可读摘要。
2. 更新 `RUN-METADATA.md` §1 门禁表与 `Spec/Stage-2/Stage-2.3-GUI-Foundation-Implementation-Record.md` §8。
3. 不得仅凭 CI 绿色勾选回填「全量通过」。
