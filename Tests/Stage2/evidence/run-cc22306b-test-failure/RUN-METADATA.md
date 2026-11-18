# RUN-METADATA.md — C3-B 第二轮（Runner test 编译失败：String 路径拼接不可用 + 级联类型推断）

- Run 作业：`workflow-job-run-cc22306b-850c-5e97-8fc2-3a94b426ce06`；仓库 `yi-fen/FilterKit` / 分支 `C3`；job 名 `test`。
- Runner SHA：`5b2c2bbb74acf8cebd50c9469ce9d9b3b3adbec1`（fetch-depth 1；用户同步时变基/压缩属正常）。
- 时间：2026-11-16 13:08:05Z 起；`swift test` 13:08:08 开始，13:08:46 exit 1。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 关联：Actions run `43871946738`；artifact `filterkit-test-log`（ID `14227884893`，1841 字节）。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core） | ✅ 本轮通过 | 日志内 `swift test` 前置编译：Models 13、Adapters 3、Core 全量 emit；8 个 Plist Core 文件（含 `PlistDataReader`）无编译诊断 |
| test（Stage2Tests） | ❌ exit 1 | 仅 `PlistReaderTests.swift` 报出一对错误；`PlistDecoderTests`、`PlistValueKindTests` 无诊断 |
| isolation / app-build / artifact | ⏭ 未执行 | test 编译失败后未触发 |

## 2. 编译错误（runner 路径 `/Users/runner/work/FilterKit/FilterKit/Tests/Stage2/PlistReaderTests.swift`）

| # | 位置 | 诊断 | 根因 |
|---:|---|---|---|
| 1 | `:61:87` | `missing argument for parameter 'conformingTo' in call`；附注 `UniformTypeIdentifiers.String.appendingPathComponent` 已 `@available(*, unavailable)`，提示改用 URL 上的方法 | `NSTemporaryDirectory()` 返回 `String`，在 String 上调 `appendingPathComponent(_:)`；该 String 重载在本 SDK 不可用，必须先包成 `URL(fileURLWithPath:)` 再拼接 |
| 2 | `:65:40` | `type 'Equatable' has no member 'notFound'` | 级联错误：上一行拼接返回类型退化为 `Never`，`XCTAssertEqual` 泛型 `T: Equatable` 未能从 `result.status` 推出 `PlistReadStatus`，成员 `.notFound` 失去上下文基类型 |

## 3. 本地修复（待下一轮 Runner 出证）

- `Tests/Stage2/PlistReaderTests.swift`
  - 不存在文件路径：`NSTemporaryDirectory()` → `URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(...).path`。
  - 状态断言：`.notFound` 显式限定为 `PlistReadStatus.notFound`，消除泛型推断歧义。
- 全仓复查：其余 `appendingPathComponent` 接收者均为 `URL`（夹具 URL 链、`S105FixtureLoader.directoryURL()`），无 String 残留。

## 4. 未改动边界

- Core 8 源本轮未改；未改 Models、Adapters、七方法协议、C1/C2 冻结源码、Stage 1 fixtures/harness；未新增业务规则；未接服务层/真机扫描/写入。
- 修复仅为测试目标编译期路径 API 与类型推断问题，不改变 Reader/Decoder 口径与 §4 映射冻结结论。

## 5. 待下一轮 Runner 复核

1. `swift build` 三库 0 error / 0 warning（本轮 Core 已过，回归确认）。
2. `swift test` 全量：既有 210 例 + C3-B 新增 26 例，0 失败；三组可独立 `--filter` 执行并归档日志。
3. App Simulator Build 不受影响；隔离三向复查。
