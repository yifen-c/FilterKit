# RUN-METADATA.md — C3-C1 首轮 Runner build 失败（待下一轮复核）

- 分支：`C3-C1`；检出 SHA `af7f163a18f2ced766a40c619c29a4fe13d48131`。
- Job：`build`（`swift build`）；workflow job run `0494e25c-b422-5b4c-9564-bc75ac92354c`；日志时间 2026-11-16 15:30Z。
- 环境：macOS 26.7.2 / macos-26-arm64 20261102.0473.1 / runner 2.338.2 / westus MacCloud（工具链版本记录在独立 environment job，本日志未含）。
- 结果：Core emit-module 阶段退出码 1；测试目标未进入编译；日志 0 warning。

## 1. 失败定位

| 阶段 | 结论 | 证据 |
|---|---|---|
| Models 编译 | 通过 | 日志 `[13/13] Compiling Models ReportEnvelope.swift` |
| Adapters 编译 | 通过 | 日志 `[17/17] Compiling Adapters RootlessAdapter.swift` |
| Core 编译 | ❌ emit-module failed exit 1 | `build/job-logs.txt`，错误集中在 3 个新文件 |

## 2. 根因

三个引用公共 Models 类型的 Core 文件只 `import Foundation`，未 `import Models`：

- `Core/PlistParser/Result/FilterParseResult.swift`：`FilterRule?`、`[ReportWarning]` 找不到。
- `Core/PlistParser/RootHide/RootHideFilterMapper.swift`：`FilterRule`、`CoreFoundationVersion`、`CoreFoundationMode`、`ReportWarning` 找不到。
- `Core/PlistParser/RootHide/RootHideFilterParser.swift`：`ReportWarning` 找不到。

级联错误：`Codable / Equatable` 无法自动合成、`.max / .range` 成员无法推断、`nil` 缺上下文类型；均为缺导入的派生现象，非规则或字段设计问题。

## 3. 本地修复（仅补导入，未改规则 / 字段 / 测试）

- 上述三个文件各补一行 `import Models`。
- `FilterParseStatus / SkippedField / RootHideFilterTypeChecker / RootHideFilterValidator` 不引用 Models 类型，无需导入；测试目标已 `@testable import Models`。

## 4. 待下一轮 Runner 复核

- Core 三库 Build 0 error / 0 warning；39 例新增专项（Result 7 + RootHide 32）通过；既有 236 例无回归；App Simulator Build 与隔离复查不受影响。
- 本机 Linux 无 Swift 工具链，修复未经本地编译验证。
