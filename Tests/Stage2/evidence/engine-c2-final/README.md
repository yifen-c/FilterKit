# Engine-C2 最终 Runner 验收证据骨架（E4）

本目录是 Stage 2.2-C3-Engine-C2 最终验收的**归档结构与元数据模板**，在统一
Runner 验收授权前只落骨架，不产生任何已通过结论。

## 目录

| 路径 | 内容 | 填充时机 |
| --- | --- | --- |
| `source/HEAD.txt` / `source/git-status.txt` | 验收提交哈希与工作区状态 | Runner 执行时采集 |
| `core-build/core-build.log` | Core Build 0 error / 0 warning 日志 | Runner 执行时采集 |
| `app-build/app-xcodebuild.log` | App Build 与模拟器存活日志 | Runner 执行时采集 |
| `tests/stage1-baseline.log` | Stage1 夹具 / S1-05 / S1-06 基线回归 | Runner 执行时采集 |
| `tests/engine-b.log` | FilterParseEngineTests（C-G1） | Runner 执行时采集 |
| `tests/engine-c1.log` | Engine-C1 22 项基线 Parser / Engine 链路 | Runner 执行时采集 |
| `tests/engine-c2.log` | Engine-C2 A～D 套件 | Runner 执行时采集 |
| `tests/full-regression.log` | `swift test` 全量与独立过滤 | Runner 执行时采集 |
| `isolation/isolation-report.txt` | 三向隔离静态检查输出 | Runner 执行时采集 |
| `fixtures/integrity-report.txt` | 夹具/冻结件完整性核对 | Runner 执行时核对 |
| `acceptance/final-acceptance.md` | 门禁表与最终验收结论 | 仅在 C-G1～G7 全过后填写 |

## 计数纪律（禁止伪造通过）

- 未执行、跳过、待验收测试在 `RUN-METADATA.json` 中计数为 `null`，**不得填 0**；
  只有 Runner 实际执行后才能写 `passed / failed / skipped` 数值。
- `C2-D1～D4` 21 项在取得新 Runner 证据前保持待验收，不计入通过。
- `C-G1 / C-G2` 以有效归档 Runner 证据为准，历史汇报不解除门禁。
- 本骨架不实现报告生成器；统一报告 / JSON 导出属 Stage 2.2-D，未授权。
- 挂起项 `PARSE-009-B` 独立记录，独立授权前不改 Parser 与期望。
