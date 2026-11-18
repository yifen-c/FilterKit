# RUN-METADATA.md — C3-B 首轮（Runner build 失败：classify 调用缺参数标签）

- Run 作业：`workflow-job-run-ad5c16ba-fca9-5ff8-afa9-435389bb1410`；仓库 `yi-fen/FilterKit` / 分支 `C3`；job 名 `build`。
- Runner SHA：`86f5269eede652a9cdede501eff261856ae37685`（fetch-depth 1；用户同步时变基/压缩属正常）。
- 时间：2026-11-16 12:42:41Z 起；`swift build` 12:43:09 开始，12:43:22 exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 工具链版本：本链接仅含 build job，未含 environment job，Swift/Xcode/SDK 版本未在本日志出现，待下一轮 environment job 补录。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core） | ❌ exit 1 | `Core/PlistParser/Reader/PlistDataReader.swift:43:35`、`:44:34` 编译错误；Models 13 文件、Adapters 3 文件模块已成功 emit |
| test（Stage2Tests） | ⏭ 未执行 | 依赖 build 通过，build 失败后未触发 |
| isolation / app-build / artifact | ⏭ 未执行 | 同上 |

编译进度：Models emit 成功 → Adapters emit 成功 → Core 并行编译，`PlistDataReader.swift` 重复报出同一对错误后中断；其余 Core 文件（含 PlistDecoder/PlistValueKind 等）编译诊断未完整展开。

## 2. 编译错误（runner 路径 `/Users/runner/work/FilterKit/FilterKit/Core/PlistParser/Reader/PlistDataReader.swift`）

| # | 位置 | 诊断 | 根因 |
|---:|---|---|---|
| 1 | `PlistDataReader.swift:43:35` | `error: missing argument label 'error:' in call` | 递归调用 `classify(underlying as Error)` 漏写外部参数标签；签名为 `static func classify(error: Error)`，须写 `Self.classify(error:)` |
| 2 | `PlistDataReader.swift:44:34` | `error: cannot infer contextual base in reference to member 'readFailed'` | 级联错误：上一行调用类型未推出，`mapped.status` 上下文缺失，`.readFailed` 无法推断基类型；调用修复后显式限定 `PlistReadStatus.readFailed` 消除歧义 |

## 3. 本地修复（待下一轮 Runner 出证）

- `Core/PlistParser/Reader/PlistDataReader.swift`
  - 第 43 行：`let mapped = classify(underlying as Error)` → `let mapped = Self.classify(error: underlying as Error)`。
  - 第 44 行：`mapped.status != .readFailed` → `mapped.status != PlistReadStatus.readFailed`。
- `Tests/Stage2/PlistReaderTests.swift`（build 未编译到测试目标，按静态自查一并加固）：
  - 不存在文件路径由 `String.appendingPathComponent` 改为 `URL(fileURLWithPath:).appendingPathComponent(...).path`，与既有测试路径范式一致。

## 4. 未改动边界

- 未改 Models、Adapters、七方法协议、C1/C2 冻结源码、Stage 1 fixtures/harness；未新增业务规则；未接服务层/真机扫描/写入。
- 本轮修复仅为编译期签名与类型推断问题，不改变 Reader/Decoder 既有口径与映射冻结结论。

## 5. 待下一轮 Runner 复核

1. `swift build` 三库 0 error / 0 warning。
2. `swift test` 全量：既有 210 例 + C3-B 新增 26 例，0 失败；三组可独立 `--filter` 执行。
3. App Simulator Build 不受影响；隔离三向复查。
