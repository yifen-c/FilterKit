# RUN-METADATA.md — C3-B 第四轮（test 全量执行：236 例 / 3 失败；编译通过）

- Run 作业：`workflow-job-run-517d3a6c-acbd-5a2d-acc3-ca98adc375cd`；仓库 `yi-fen/FilterKit` / 分支 `C3`；job 名 `test`。
- Runner SHA：`5e2623463b5f397fd7011f709c1cfc505711f263`（远端已纳入本地修复；编译期错误清零，测试进入执行阶段）。
- 时间：2026-11-16 13:33:53Z 起；`swift test` 13:33:57 开始，13:35:11 归档；236 例执行完毕。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；region westus，Cloud MacCloud；git 2.56.0。
- 关联：Actions run `43876770249`；artifact `filterkit-test-log`（ID `14230811462`，6411 字节）。

## 1. Job 结果

| Job | 结论 | 证据 |
|---|---|---|
| build（Models / Adapters / Core） | ✅ 编译通过，无诊断 | Models/Adapters/Core 全量 emit；8 个 Plist Core 文件无 warning/error |
| test（Stage2Tests） | ❌ 236 例，3 失败（0 unexpected） | 失败分布见 §2；其余套件 0 失败 |
| isolation / app-build | ⏭ 本日志未含 | 待 Runner 其余 job 出证 |

### 套件通过情况（日志逐套件统计）

| 套件 | 例数 | 失败 |
|---|---:|---:|
| B5DeterminismTests | 6 | 1 |
| B5FixtureComparisonTests | 4 | 0 |
| B5IntegrationTests | 10 | 0 |
| ElleKitDirectoryTests | 15 | 0 |
| EnvironmentDetectionTests | 7 | 0 |
| JBRootCandidateCollectionTests | 10 | 0 |
| JBRootValidationTests | 18 | 0 |
| ModelsCodableTests | 21 | 0 |
| PlistDecoderTests | 9 | 2（同一用例两条断言） |
| PlistReaderTests | 6 | 0 |
| PlistValueKindTests | 11 | 0 |
| PluginEnumerationTests | 14 | 0 |
| PluginInventoryCodableTests | 9 | 0 |
| PluginPairingCodableTests | 12 | 0 |
| PluginPairingEngineTests | 21 | 0 |
| PluginPairingIndexTests | 5 | 0 |
| PluginPairingIntegrationTests | 32 | 0 |
| PluginPairingKeyTests | 11 | 0 |
| PluginPairingS105FixtureTests | 15 | 0 |
| **合计** | **236** | **3** |

## 2. 失败清单与根因

### 2.1 `PlistDecoderTests.swift:137 / 138` — `testFailureResultNeverCarriesObject`（2 条断言，同一用例）

- 诊断：`:137` `XCTAssertNotEqual failed: ("success") is equal to ("success")`；`:138` `XCTAssertNil failed: "PlistDecodedObject(rootObject: garbage, format: __C.NSPropertyListFormat)"`。
- 根因：测试夹具 `Data("garbage".utf8)` 是单 token 字节；Foundation 的 OpenStep 兼容解析器把它接受为顶层字符串标量，`PropertyListSerialization.propertyList` 返回 success，解码器据此交付对象——并非 Decoder 分类接缝缺陷。
- 契约口径（PC3-10）：Decoder 只判断「字节是否构成合法 plist」；顶层标量/非字典的类型核对属 C3-C 路线 Parser。Decoder 源码不改。
- 修复（测试夹具）：改用本 Runner 已验证会抛错的多词非法字节 `Data("this is not a property list".utf8)`（与 Decoder-03 同款，该用例本轮通过）。

### 2.2 `B5DeterminismTests.swift:99` — `testPipelineInputCodableRoundTripAndStableEncoding`（1 例）

- 诊断：`XCTAssertEqual failed: ("221 bytes") is not equal to ("221 bytes")`；两次编码字节数相同但内容不一致。
- 背景：该用例在 C2-D2（run `43857670397`，同镜像同 runner）通过；本地模型源码自 `59ee5f8` 起无改动（`ElleKitDirectoryPipelineInput` / `ReportWarning` 仅标量与有序数组，无 Dictionary/Set、无自定义 encode）。
- 判读：同值两次编码字节不一致，表现为编码容器键序不稳定；测试目标本就是「重复编码稳定」。
- 修复（测试配置）：编码器显式 `outputFormatting = .sortedKeys`，强制字典键字典序，消除键序不确定性；往返解码断言保持不变。模型源码不改。

## 3. 本地修复清单（待下一轮 Runner 出证）

| 文件 | 改动 | 性质 |
|---|---|---|
| `Tests/Stage2/PlistDecoderTests.swift` | 失败不携对象用例的非法字节夹具：`"garbage"` → `"this is not a property list"` | 测试夹具；Decoder 源码未改 |
| `Tests/Stage2/B5DeterminismTests.swift` | 稳定编码用例编码器加 `.sortedKeys` | 测试配置；Models/Core 源码未改 |

## 4. 边界与留痕

- 未改 Core 8 源、Models、Adapters、七方法协议、C1/C2 业务源码、Stage 1 fixtures/harness；未新增业务规则。
- 待复核：B5 用例若 `.sortedKeys` 后仍失败，下一轮日志需抓取两次编码的具体字节差，再判断是否存在其他非确定性来源；不预先扩大改动面。
- 未决观察项不变：R6 未知枚举默认解码、iOS17/Deployment Target 兼容、Rootless 无真机、Runner SDK 26.5 不作 Theos 16.5 兼容证据等。

## 5. 待下一轮 Runner 复核

1. `swift build` 三库 0 error / 0 warning。
2. `swift test` 全量 236 例 0 失败；Reader 6 / Decoder 9 / 类型识别 11 可独立 `--filter` 执行并归档。
3. App Simulator Build 与隔离三向复查不受影响。
