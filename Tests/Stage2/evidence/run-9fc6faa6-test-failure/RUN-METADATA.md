# RUN-METADATA.md — C3-B 第三轮（stale-SHA 重跑：同一旧树，错误复现；无新增源码缺陷）

- Run 作业：`workflow-job-run-9fc6faa6-dc42-56ba-9e23-58fc5cafdbf9`；仓库 `yi-fen/FilterKit` / 分支 `C3`；job 名 `test`。
- Runner SHA：`5b2c2bbb74acf8cebd50c9469ce9d9b3b3adbec1`（与第二轮 `cc22306b` **同一提交**；fetch-depth 1）。
- 时间：2026-11-16 13:20:53Z 起；`swift test` 13:20:57 开始，13:21:55 exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 关联：Actions run `43874665766`；artifact `filterkit-test-log`（ID `14230345717`，1838 字节）。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core） | ✅ 本轮再次通过 | 日志内 Models/Adapters emit；Core 76 文件编译，8 个 Plist Core 文件（`PlistDecodeResult/Status/DecodedObject/Decoder/ValueKind/DataReader/ReadResult/ReadStatus`，行 165–172）无编译诊断 |
| test（Stage2Tests） | ❌ exit 1 | 与第二轮**逐条相同**：仅 `PlistReaderTests.swift` 一对错误；`PlistDecoderTests`、`PlistValueKindTests` 无诊断 |
| isolation / app-build / artifact | ⏭ 未执行 | test 编译失败后未触发 |

## 2. 编译错误（与第二轮同位置、同诊断）

| # | 位置 | 诊断 | 根因 |
|---:|---|---|---|
| 1 | `:61:87` | `missing argument for parameter 'conformingTo' in call`；附注 String 上 `appendingPathComponent` 已 `@available(*, unavailable)`，提示改用 URL | 检出旧树中 `NSTemporaryDirectory()`（String）直接链式拼接 |
| 2 | `:65:40` | `type 'Equatable' has no member 'notFound'` | 上一行类型退化为 `Never`，`XCTAssertEqual` 泛型基类型推断失败（级联） |

## 3. 关键判读：本轮无新增源码缺陷，属远端未同步

- 本地基线提交 `452d215` 已包含对应修复（见 `run-cc22306b-test-failure/` 与实现记录 §7.2）：
  - `Tests/Stage2/PlistReaderTests.swift` 路径改为 `URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(...).path`；
  - 断言显式限定 `PlistReadStatus.notFound`。
- 日志行 60–61 / 65 仍显示旧代码（`let missing = NSTemporaryDirectory()`、`.notFound`），且检出 SHA 与第二轮同为 `5b2c2bb…`，说明 **origin/C3 远端树尚未纳入本地 `f1cbd83` / `452d215` 两个修复提交**；Runner 在旧树上重跑，错误按原样复现。
- 本地无 remote 配置，推送 / workflow_dispatch 由外部完成；下一轮 Runner 必须在包含 `452d215` 的树（或等价内容）上调度，否则同一对错误会再次出现。

## 4. 本轮本地处置

- 未改任何源码（修复已在 `452d215` 在位）；仅归档本轮日志、回填实现记录 §7.3 与迁移表。
- 边界不变：未改 Models、Adapters、七方法协议、C1/C2 冻结源码、Stage 1 fixtures/harness；未新增业务规则。

## 5. 待下一轮 Runner 复核（前提：远端树已含本地修复）

1. `swift build` 三库 0 error / 0 warning。
2. `swift test` 全量：既有 210 例 + C3-B 新增 26 例，0 失败；三组可独立 `--filter` 执行并归档日志。
3. App Simulator Build 不受影响；隔离三向复查。
