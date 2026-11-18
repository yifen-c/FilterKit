# RUN-METADATA.md — C3-C1 第二轮 Runner test 失败（待下一轮复核）

- 分支：`C3-C1`；检出 SHA `44376c621c68fef4777b674020c5f32b4f290b23`（含首轮 `import Models` 修复）。
- Job：`test`（`swift test 2>&1 | tee .build/test-log.txt`）；workflow job run `db66abf4-b1c1-55ee-88c7-8345a17e91d2`；日志时间 2026-11-16 15:55~15:57Z。
- 环境：macOS 26.7.2（25G332）/ macos-26-arm64 20261102.0473.1 / runner 2.338.2 / westus MacCloud；Testing Library 1902；Target Platform `arm64e-apple-macos14.0`。工具链版本记录在独立 environment job，本日志未含。
- 测试日志 artifact：`filterkit-test-log`，ID `14241029043`，上传 7109 bytes，SHA256 `7378d758ec0f810ab20a7256911fdc9350fd59e3f2879aa546f32c3dcd7a6091`。

## 1. 编译与执行结果

| 阶段 | 结论 | 证据 |
|---|---|---|
| Core 三库 Build | ✅ `Build complete! (40.43s)`，0 error（首轮缺导入问题已消除） | `test/job-logs.txt` L250 |
| 全量测试 | ❌ Executed 275 tests，1 failure（0 unexpected），274 passed | L867~870 |
| S1-05 独立过滤 | ✅ `PluginPairingS105FixtureTests` 15 tests，0 failures | L797~798 |
| 新增 Result 模型 | ✅ `FilterParseResultTests` 7 例全过 | L367 |
| 新增 RootHide 专项 | ❌ `RootHideFilterParserTests` 32 例，1 failure（31 passed） | L865~866 |

## 2. 唯一失败用例

`RootHideFilterParserTests.testBundlesNotArrayIsTypeMismatch`（`Tests/Stage2/RootHideFilterParserTests.swift:133`）：

- 夹具：`["Filter": ["Bundles": "com.example.app"]]`（Bundles 为字符串，非数组）。
- 断言：顶层 `result.reason` 期望 `"field_type"`，实际 `"not_array"`。
- `skippedFields.first.reason` 断言 `"not_array"` 通过，细粒度证据本身正确。

## 3. 根因与口径

- 契约 §7 与基线 `Tests/S1-06/parser.js`（`checkStringArray` + `mismatch('field_type', …)`）：数组非数组 / 元素类型不符属字段级失败，**顶层 reason 统一归 `field_type`**；细粒度 `not_array / null_element / element_type` 仅保留在 `SkippedField`。
- 本地 Parser 原先直接取 `errors.first?.reason` 作为顶层 reason，把细粒度 `not_array` 透传到了结果顶层。

## 4. 本地修复（未改规则 / 字段 / 夹具 / 测试断言）

- `Core/PlistParser/RootHide/RootHideFilterParser.swift`：新增 `topLevelReason(for:)` 映射——`not_array / null_element / element_type` 归顶层 `field_type`；`root_type / filter_missing / filter_type / field_type / versions_type` 原样透传。
- 校验器产出的 `SkippedField` 细粒度原因不变；测试断言无需改动。

## 5. 待下一轮 Runner 复核

- Core 三库 Build 0 error/0 warning；39 例新增专项全过；既有 236 例无回归；S1-05 15 例保持 0 失败；App Simulator Build 与隔离复查不受影响。
- 本机 Linux 无 Swift 工具链，修复未经本地编译验证。
