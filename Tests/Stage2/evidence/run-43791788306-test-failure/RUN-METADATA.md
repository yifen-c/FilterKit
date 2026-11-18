# RUN-METADATA.md — 第十轮（2.2-B1 环境识别 runner test 失败）

- Run ID：**43791788306**；仓库 `yi-fen/006` / `main`；job `test`（`swift test 2>&1 | tee .build/test-log.txt`）；artifact `filterkit-test-log`（ID 14192304037，1670 字节）。
- Runner SHA：`63d5474fa4b8ad13cde82387860a1b009981267e`（fetch-depth 1）。
- 时间：2026-11-16 02:23:39Z 起；`Build complete! (30.34s)`；测试 02:24:31，exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；westus / MacCloud；git 2.56.0。
- 测试平台：arm64e-apple-macos14.0；Testing Library 1902。本 job 未含 environment job，Swift/Xcode/SDK 版本未在日志出现。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core / Stage2Tests） | ✅ 编译通过 | `Build complete! (30.34s)`；Models/Adapters/Core/Stage2Tests 模块均 emit |
| test（Stage2Tests） | ❌ exit 1 | 28 例执行，**21 例 ModelsCodable 0 失败**；EnvironmentDetectionTests 7 例中 6 处断言失败 |
| isolation | ⏭ 未在本日志 | 待后续 job 结果 |

## 2. 2.2-A 既有回归：21 例全部通过

`Test Suite 'ModelsCodableTests' ... Executed 21 tests, with 0 failures (0 unexpected) in 0.005 (0.007) seconds`。本轮未改 Models 字段/枚举/原始值/解码行为，既有兼容保持。

## 3. B1 环境识别失败明细（6 处断言，2 个测试方法）

| 用例 | 位置 | 实测 | 期望 | 根因判定 |
|---|---|---|---|---|
| ENV-012 | `EnvironmentDetectionTests.swift:146` | 缺 `access_limited` 告警 | 含 `access_limited` | 版本就绪层告警未合并进结果告警表 |
| ENV-006 | 同文件:84（fixture 批次） | `[bootstrap_missing, implementation_missing]` | 另含 `version_unparsable` | 同上：unparsable 告警滞留 `readiness.warnings`，未合并 |
| ENV-010 | 同上 | 同上 | 同上 | 同上 |
| ENV-014 | 同上 | 同上 | 同上 | 同上 |
| ENV-008 | 同文件:75 | `jailbreakType = roothide` | `unknown` | 冲突分支只归零实现/版本，未归零越狱类型 |
| ENV-009 | 同文件:75 | `jailbreakType = roothide` | `unknown` | 同上 |

通过的 B1 用例：ENV-011（格式错误捕获）、ENV-013（确定性）、ENV-015（ID 不一致）、VersionReadiness 往返、旧 JSON 缺字段解码 nil。

## 4. 本地修复（提交待下一轮 runner 复验）

对齐 Stage 1 `detector.js`：

1. **告警合并**：结果返回前，将最终 `readiness.warnings` 按 code 去重合并进 `warnings`（`access_limited` / `version_unparsable` 进入顶层告警表）。
2. **冲突归零类型**：冲突分支增加 `jailbreakType = "unknown"`（基线 `jailbreakType = 'unknown'; ellekitImplementation = 'unknown'; ellekitVersion = null; status = conflicted`）；顾问匹配与 unknown 分支判断同步改用归零后的类型。

## 5. 边界核对（本轮未越界）

- 未改 `ElleKitAdapter` 七方法协议；未进入 B2~B5；未改 Stage 1 Fixtures/harness/报告；无真机写入、启停、扫描、探针。
- 改动仅集中在 `Core/Environment/EnvironmentDetector.swift`；Models、Adapters、测试断言口径、夹具均未改。

## 6. 待下一轮 runner 复验

1. `swift test`：21 例旧例 + B1 新增用例全部 0 失败；
2. isolation 三向通过；
3. environment job 工具链版本、test-log 归档。

> 下一轮结果未出前，B1 状态仍为「待复验」，不进入 B2。
