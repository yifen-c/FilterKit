# RUN-METADATA.md — 第十二轮（Engine-C2 第二轮：Stage2Tests 编译失败，参数顺序 / 默认参数引用 key）

- Run 作业：`workflow-job-run-9270f2b6-d1af-5e3e-ab76-75ffd5462e67`；结果容器 `64410c3e-807b-439f-b29f-5f549ab4a3f5`；仓库 `yi-fen/FilterKit` / 分支 `C2-C3`；job 命令 `swift test 2>&1 | tee .build/test-log.txt`。
- Runner SHA：`672b8562c9fdf077ad374a136789e7fe5c883cf8`（fetch-depth 1；本地链经变基/压缩后哈希不同属正常）。
- 时间：2026-11-17 03:46:10Z 起；03:47:07 Stage2Tests emit-module 失败，03:47:10 exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud。
- 工具链版本：日志仅出现 `swift-version-7974D3F7F03D5E95.txt`，Swift/Xcode/SDK 版本待 environment job 补录。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| Core 模块 | ✅ emit 成功 | `[45/94] Emitting module Core`；上一轮 Engine / Rootless 两处 Core 修复在本轮编译通过，无 Core 错误、无告警 |
| Stage2Tests（测试目标） | ❌ emit-module exit 1 | 注册表参数顺序 8 处 + 默认参数引用 `key` 4 处；测试用例未执行 |
| test 执行 / isolation / app-build | ⏭ 未执行 | 测试目标编译失败后未触发 |

日志无 `warning:`；尾部 `error: fatalError` 为 SwiftPM 在 emit-module 失败后的包装退出，非源码 `fatalError`。

## 2. 编译错误（runner 路径 `/Users/runner/work/FilterKit/FilterKit/Tests/Stage2/`）

### A. 参数顺序：`expectedSkippedByBase` 必须先于 `expectedReasonByBase`

`EngineC1BaselineModels.swift` 的 `EngineC1BaselineCase.init` 声明顺序为 `expectedRulesByBase → expectedOtherKeysByBase → expectedSkippedByBase → expectedWarnings → expectedReasonByBase`；注册表 8 处调用把 `expectedReasonByBase` 写在 `expectedSkippedByBase` 之前，Swift 要求实参顺序匹配形参声明顺序。

| # | 位置 | 基线样本 |
|---|---|---|
| A1 | `EngineC1-BaselineRegistry.swift:34` | PARSE-006-A `BadBundles` |
| A2 | `:45` | PARSE-007-A `BadClasses` |
| A3 | `:72` | PARSE-008-A `BadExec` |
| A4 | `:98` | PARSE-005-A `NoFilter` |
| A5 | `:149` | PARSE-009-B `BadVer` |
| A6 | `:186` | PARSE-004-A `RootType` |
| A7 | `:198` | PARSE-005-B `FilterType` |
| A8 | `:212` | PARSE-010-A `Mixed` |

仅 `expectedReasonByBase`、无 skipped 的两处（PARSE-013 `Broken`、PARSE-014 `Bad`）顺序合法，未改动。

### B. 默认参数引用同签名其他参数：`cannot find 'key' in scope`

Swift 默认实参表达式在独立作用域求值，不能引用同一签名的其他参数。

| # | 位置 | 问题 |
|---|---|---|
| B1 | `EngineC2-TestSupport.swift:168` | `plistPath: String? = "/dir/\(key).plist"` 默认值引用 `key` |
| B2 | `EngineC2-TestSupport.swift:169` | `dylibPath: String? = "/dir/\(key).dylib"` 默认值引用 `key` |
| B3 | `FilterParseEngineTests.swift:419` | `dylibPath: String? = "/dir/\(key).dylib"` 默认值引用 `key` |
| B4 | `FilterParseEngineTests.swift:420` | `plistPath: String? = "/dir/\(key).plist"` 默认值引用 `key` |

## 3. 本地修复（提交待下一轮 runner 复验）

### `Tests/Stage2/EngineC1-BaselineRegistry.swift`

- 8 处成对站点交换实参顺序：`expectedSkippedByBase` 块在前，`expectedReasonByBase` 在后；字典键、原因词、跳过证据内容与 index 全部保持原值，未改任何期望口径。
- PARSE-009-B 复核注释保留在 skipped 块上方。

### `Tests/Stage2/EngineC2-TestSupport.swift`（`engineC2Record`）

- 改前：`plistPath` / `dylibPath` 默认值为 `"/dir/\(key).plist"`、`"/dir/\(key).dylib"`。
- 改后：两形参默认 `nil`；函数体内 `let plistPath = plistPath ?? "/dir/\(key).plist"`、`let dylibPath = dylibPath ?? "/dir/\(key).dylib"`，再构造记录。
- 行为不变：调用方不传路径时仍按 `key` 推导同名 plist/dylib 路径；显式传路径时优先用传入值。

### `Tests/Stage2/FilterParseEngineTests.swift`（`pairedRecord`）

- 同上模式：两形参默认 `nil`，函数体内按 `key` 兜底推导；证据名兜底与路径取值不变。

## 4. 边界核对（本轮未越界）

- 改动仅限 3 个 `Tests/Stage2/` 测试目标文件；未改 Core、Models、Adapters、七方法协议、冻结 Parser、Stage1 fixtures/metadata/harness 与既有夹具期望。
- 未调整任何基线期望（reason / expectedType / observedType / index / bundles/classes/executables）；PARSE-009-B 观测类型词与下标口径仍待 Runner 对照复核。

## 5. 待下一轮 runner 复验

1. `swift test` 测试目标编译通过，无 error、无 `#no-usage` 告警；
2. 全量测试执行：C1 22 项基线 + Engine-B/C1/C2 专项 + 既有回归，实际通过数以 Runner 输出为准；
3. isolation 三向通过；app-build Simulator `BUILD SUCCEEDED`；
4. environment job 工具链版本、test-log 归档。

> 下一轮结果未出前，Engine-C2-A~C 状态仍为「待复验」；不宣布双路线集成完成，C2-D / C2-E 继续阻塞于 C-G1 / C-G2。
