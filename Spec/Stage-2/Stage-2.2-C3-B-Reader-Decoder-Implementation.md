# Stage 2.2-C3-B：Plist Reader / Decoder 实现记录（代码冻结，Runner 验收待授权）

> 批次定位：C3-B 只落地 `Core/PlistParser/Reader/` 与 `Core/PlistParser/Decoder/` 两层
> 底层能力（文件读取、Foundation plist 解码、内部类型识别）。RootHide / Rootless 业务
> Parser、Input 装配、结果五态模型与 Engine 编排属 C3-C / C3-D，本批不实现。
>
> 状态：**Implementation Complete / Local Static Review Passed**；**Runner Build /
> Test / App Build 未执行**（本机 Linux 无 Swift 工具链；编译、26 例新增专项与既有
> 210 例回归统一纳入后续独立 Runner 验收）。本记录不宣称已通过编译或回归。
>
> 依据：C3-A 契约冻结提交 `80f0471`，`Stage-2.2-C3-Parser-Data-Contract.md`
> PC3-1~14、§3.2 内容信号、§7 错误分类、§10 模块目录与批次门禁、§11 安全边界；
> S1-06 基线 `Tests/S1-06/parser.js`。

## 1. 本轮授权边界

### 已允许并执行（本地离线）

- **Reader 层**：`PlistReadStatus`（success / notFound / accessDenied / readFailed）、
  `PlistReadResult`（status / data / path / errorCode / errorDescription）、
  `PlistDataReader`（协议 `PlistDataReading` + 默认 `Data(contentsOf:)` 实现 + 纯函数
  错误分类接缝 `classify(error:)`）。
- **Decoder 层**：`PlistDecodeStatus`（success / parseFailed=`parse_failed`）、
  `PlistDecodedObject`（rootObject: Any + format）、`PlistDecodeResult`、
  `PlistDecoder`（协议 `PlistDecoding` + `PropertyListSerialization` 实现，空 Data 守卫）。
- **类型识别**：`PlistValueKind` 封闭集 + `PlistValueClassifier`，CFBoolean 优先判定，
  Bool / NSNumber 区分作为硬门禁。
- **独立 XCTest**：Reader 6 例、Decoder 9 例、类型识别 11 例，共 26 例；
  `Package.swift` Core 与 `Stage2Tests` 两处显式 sources 接线完成。

### 禁止项（本轮均未触碰）

- 未实现 RootHide 严格规则、Rootless Codable 模型、字段类型核对、CFV 长度校验；
  未建 `Input/`（C3-A 审计确认复用现有 C2 数据结构，不重复定义 `PluginParseInput`）。
- 未修改 Models、Adapters、七方法协议、C1/C2 冻结源码与既有测试、Stage 1 fixtures /
  harness / report；未新增公共 Codable 模型。
- 未接入服务层 / Adapter 实例化；未扫描真机目录；未修改任何 plist 或插件文件；
  未做启停、注入、dpkg、软链改动或配置写入。
- 未编译、未跑 Runner；无 `/var/jb` 路径猜测、无递归搜索、无文件名相同即替换 C2 路径。

## 2. 文件清单

| 文件 | 模块 | 职责 |
|---|---|---|
| `Core/PlistParser/Reader/PlistReadStatus.swift` | Core | Reader 内部读取状态封闭集（String Codable / Equatable） |
| `Core/PlistParser/Reader/PlistReadResult.swift` | Core | 读取结果；失败 `data` 恒 `nil`，禁止空 Data 冒充成功 |
| `Core/PlistParser/Reader/PlistDataReader.swift` | Core | 协议 + 默认读取器；Cocoa/POSIX 错误分类；underlying error 追溯一次 |
| `Core/PlistParser/Decoder/PlistDecodeStatus.swift` | Core | 解码状态封闭集；`parseFailed` 原始值 `parse_failed` |
| `Core/PlistParser/Decoder/PlistDecodedObject.swift` | Core | 解码对象容器；`Any` 限制在 Core 内部，不进公共 Models |
| `Core/PlistParser/Decoder/PlistDecodeResult.swift` | Core | 解码结果；失败 `object` 恒 `nil`，不返回虚假空对象 |
| `Core/PlistParser/Decoder/PlistDecoder.swift` | Core | 协议 + 默认解码器；空 Data → `parse_failed/empty_data`；XML/Binary 识别 |
| `Core/PlistParser/Decoder/PlistValueKind.swift` | Core | 类型谓词：dictionary/array/string/boolean/number/data/date/null/unknown |
| `Tests/Stage2/PlistReaderTests.swift` | Test | Reader 专项 6 例（临时目录合成文件 + 分类接缝断言） |
| `Tests/Stage2/PlistDecoderTests.swift` | Test | Decoder 专项 9 例（XML/Binary/非法/空/根字典/根数组/嵌套/Data-Date） |
| `Tests/Stage2/PlistValueKindTests.swift` | Test | 类型识别 11 例（Bool/NSNumber 陷阱 + 全类型覆盖） |

## 3. 契约落地对照

| 契约项 | 落地情况 |
|---|---|
| PC3-2 解析候选 | 本批不做候选过滤；Reader 只接收上层给定路径，不主动发现文件 |
| PC3-4 五态枚举 | 五态 `FilterParseStatus` 属 C3-C Result 层，本批未创建；Reader/Decoder 状态为 Core 内部类型，不提升公共 Models（G-C3-1 部分收口：读取/解码层枚举内部化，五态枚举落位留 C3-C 评审） |
| §3.2 读取/解码信号 | Reader 交付字节与读取状态；Decoder 交付根对象与格式；`payloadInvalid` 由 decode 失败表达；本批不组装 `PluginParseInput` |
| §7 读取级/解析级分离 | Reader 不判内容合法性；Decoder 不判业务类型；读取失败与解析失败在两层结果模型上互不混入 |
| §10.1 目录 | 仅落地 `Reader/`、`Decoder/`；`Input/`、`RootHide/`、`Rootless/`、`Result/`、`Engine/` 留后续批次 |
| §11 安全边界 | 只读 `Data(contentsOf:)`；无写入、无扫描、无注入、无回退路径；未成功配对条目不进 Reader（候选过滤在 C3-C Engine） |

## 4. Reader / Decoder → Parser 五态映射（本轮冻结）

> 边界裁定（附件 §五要求实现前确认）：`notFound` 是否并入 `not_parsed`，以 C3-A 契约
> 原文为准。核对 PC3-9、§7 与 S1-06 `parser.js:291`（缺失 plist 信号默认
> `readStatus: 'read_failed', root: null`）后冻结如下口径：**已配对记录在读取时文件
> 缺失属读取级失败，映射 `read_failed`；`not_parsed` 仅用于根本不进入 Reader 的上游
> 非配对条目**。不把「文件不存在」与「未执行解析」合并。

| Reader 状态 | Decoder 状态 | Parser 最终五态 | 口径 |
|---|---|---|---|
| 未执行（非 `.paired` 记录） | 未执行 | `not_parsed` | PC3-2：未配对 / 缺失 plist / 孤立 plist / 歧义 / 不确定原样透传，保留上游 reason/basis/candidates，不调 Reader |
| `notFound`（`.paired` 记录路径文件缺失） | 未执行 | `read_failed` | PC3-9 / §7；`readStatus` 保留 `not_found` 原因；不判 `parse_failed`、不判不存在以外的业务结论；条目保留，`filter=null` |
| `accessDenied` | 未执行 | `read_failed` | PC3-9；`readStatus=access_denied`；不自动换路径、不猜 `/var/jb` |
| `readFailed` | 未执行 | `read_failed` | 其他 I/O 错误；保留 errorCode/errorDescription 作诊断证据 |
| `success` | `parseFailed` | `parse_failed` | §7；`reason=invalid_plist`；保留 plist 路径与读取状态 |
| `success` | `success` | 交路线 Parser 判断 | C3-C：RootHide 严格核对 / Rootless Codable 解码 |
| `success` | `success`，业务类型错误 | RootHide `type_mismatch`；Rootless `parse_failed` | C3-C 路线规则，本批不预置结论 |
| `success` | `success`，业务规则通过 | `valid` | C3-C 产出 `FilterRule`；本批不构造规则 |

## 5. Bool / NSNumber 类型识别硬门禁

- Foundation 桥接陷阱：`NSNumber(value: true)` 在 `is NSNumber` 判断下同样命中，
  不能仅凭 `is NSNumber` 认定为数字。
- 实现顺序：先 `CFBooleanGetTypeID() == CFGetTypeID(_:)` 判布尔；其余再按
  NSDictionary / NSArray / String / Data / Date / NSNull / NSNumber 归类；
  未覆盖对象 → `unknown`。
- 整数与浮点 NSNumber 在 C3-B 同归 `.number`；整数 / 浮点细化、CFV 数字数组长度核对
  属 C3-C RootHide 规则职责，本批不拆分。
- 测试锁定：Swift Bool、`NSNumber(value: true/false)` 必须为 `.boolean`；
  整型 / 浮点 NSNumber 必须为 `.number` 且 `isNumber` 为真、`isBoolean` 为假。

## 6. 错误分类口径（Reader 接缝）

| 域 | 码值 | 分类 |
|---|---|---|
| NSCocoaErrorDomain | `fileNoSuchFile`(4) / `fileReadNoSuchFile`(260) | `notFound` |
| NSCocoaErrorDomain | `fileReadNoPermission`(259) | `accessDenied` |
| NSCocoaErrorDomain | 其余 | `readFailed` |
| NSPOSIXErrorDomain | `ENOENT` | `notFound` |
| NSPOSIXErrorDomain | `EACCES` / `EPERM` | `accessDenied` |
| NSPOSIXErrorDomain | 其余（含 `EIO`） | `readFailed` |
| 其他域 | — | `readFailed` |

`NSUnderlyingErrorKey` 追溯一次；底层非 `readFailed` 时采用底层分类。真实 chmod 000
场景在 CI 以 root 运行时可能被绕过，故权限拒绝用分类接缝合成错误断言，不依赖真实权限位。

## 7. 测试清单（新增 26 例，待 Runner 执行）

| 测试组 | 例数 | 覆盖场景 |
|---|---:|---|
| `PlistReaderTests` | 6 | Reader-01 正常读取；Reader-02 不存在；Reader-03 权限拒绝（接缝）；Reader-04 其他 I/O；Reader-05 空文件成功读空 Data；失败结果不携带数据 |
| `PlistDecoderTests` | 9 | Decoder-01 XML；Decoder-02 Binary；Decoder-03 非法字节；Decoder-04 空 Data；Decoder-05 根字典；Decoder-06 根数组；Decoder-08 嵌套字典/数组；Decoder-09 Data/Date；失败结果不携带对象 |
| `PlistValueKindTests` | 11 | Swift Bool；布尔桥接 NSNumber 陷阱；整型 NSNumber；浮点 NSNumber；String；Array；Dictionary；Data；Date；nil/NSNull；未知对象（UUID） |

既有基线：C2-D2 Runner 全量 210 例 0 失败（run `43857670397`）。本批新增 26 例
未执行；Runner 验收时预期全量 236 例，以 Runner 日志为准，本地不作通过结论。

### 7.1 首轮 Runner build 失败与本地修复（待下一轮出证）

首轮 build job（`workflow-job-run-ad5c16ba-fca9-5ff8-afa9-435389bb1410`，Runner SHA
`86f5269`，证据归档 `Tests/Stage2/evidence/run-ad5c16ba-build-failure/`）在 Core 编译
阶段 exit 1；Models / Adapters 模块已 emit 成功，test target 未触发。

| 位置 | 诊断 | 修复 |
|---|---|---|
| `PlistDataReader.swift:43` | `missing argument label 'error:' in call` | 递归调用改为 `Self.classify(error: underlying as Error)` |
| `PlistDataReader.swift:44` | `cannot infer contextual base in reference to member 'readFailed'`（上一行级联） | 显式限定 `PlistReadStatus.readFailed` |

另按静态自查加固测试目标（build 未编译到 Stage2Tests）：`PlistReaderTests` 不存在文件
路径改为 `URL(fileURLWithPath:).appendingPathComponent(...).path`，与既有测试路径范式一致。
修复不改变 Reader/Decoder 口径与 §4 映射冻结结论；下一轮 Runner 复核 build / test /
app-build 三项门槛。

### 7.2 第二轮 Runner test 编译失败与本地修复（待下一轮出证）

第二轮 test job（`workflow-job-run-cc22306b-850c-5e97-8fc2-3a94b426ce06`，Runner SHA
`5b2c2bbb74acf8cebd50c9469ce9d9b3b3adbec1`，Actions run `43871946738`，证据归档
`Tests/Stage2/evidence/run-cc22306b-test-failure/`）：Models / Adapters / Core 三库编译
emit 成功，8 个 Plist Core 文件无诊断；失败转入 Stage2Tests 编译，仅 `PlistReaderTests.swift`
一对错误，`PlistDecoderTests`、`PlistValueKindTests` 无诊断。

| 位置 | 诊断 | 根因 / 修复 |
|---|---|---|
| `PlistReaderTests.swift:61:87` | `missing argument for parameter 'conformingTo' in call`；附注 String 上的 `appendingPathComponent` 已 `@available(*, unavailable)`，提示改用 URL | `NSTemporaryDirectory()`（String）直接链式拼接；改为 `URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(...).path` |
| `PlistReaderTests.swift:65:40` | `type 'Equatable' has no member 'notFound'` | 上一行类型退化为 `Never` 导致 `XCTAssertEqual` 泛型基类型推断失败（级联）；状态断言显式限定 `PlistReadStatus.notFound` |

全仓复查其余 `appendingPathComponent` 接收者均为 `URL`（夹具 URL 链、
`S105FixtureLoader.directoryURL()`），无 String 残留。本轮未改 Core 源码；修复仅为测试
目标编译期路径 API 与类型推断问题，不改变 Reader/Decoder 口径与 §4 映射冻结结论。

### 7.3 第三轮 Runner 重跑：stale-SHA 复现，无新增源码缺陷（待远端同步后复核）

第三轮 test job（`workflow-job-run-9fc6faa6-dc42-56ba-9e23-58fc5cafdbf9`，Actions run
`43874665766`，artifact `14230345717`，证据归档 `Tests/Stage2/evidence/run-9fc6faa6-test-failure/`）
检出 SHA 仍为 `5b2c2bbb74acf8cebd50c9469ce9d9b3b3adbec1`（与第二轮同一提交）。Models /
Adapters / Core 再次编译通过，8 个 Plist Core 文件无诊断；Stage2Tests 报出与第二轮**逐条
相同**的一对错误（`PlistReaderTests.swift:61:87` String `appendingPathComponent` unavailable；
`:65:40` 级联 `Equatable` 无 `notFound`）。

判读：本地基线 `452d215` 已含 §7.2 修复，但 origin/C3 远端树尚未纳入本地 `f1cbd83` /
`452d215` 两个修复提交，Runner 在旧树上重跑导致错误原样复现。本轮未改源码；下一轮须在
包含本地修复的树（或等价内容）上调度，再复核 build / test / app-build 三项门槛。

### 7.4 第四轮 Runner 全量执行：236 例 / 3 失败，测试夹具与编码配置修复（待下一轮出证）

第四轮 test job（`workflow-job-run-517d3a6c-acbd-5a2d-acc3-ca98adc375cd`，Runner SHA
`5e262346…`，Actions run `43876770249`，artifact `14230811462`，证据归档
`Tests/Stage2/evidence/run-517d3a6c-test-failure/`）：远端已纳入本地修复，编译期错误清零，
三库编译通过无诊断；`swift test` 全量执行 236 例（既有 210 + C3-B 新增 26），3 失败。

| 位置 | 诊断 | 根因 / 修复 |
|---|---|---|
| `PlistDecoderTests.swift:137/138`（`testFailureResultNeverCarriesObject`） | 失败结果却为 `success` 并携带 `rootObject: garbage` | 夹具 `"garbage"` 单 token 被 OpenStep 兼容解析器接受为顶层字符串标量；Decoder 接缝无缺陷（PC3-10：顶层类型核对属 C3-C）。夹具改为本 Runner 已验证抛错的多词非法字节 `"this is not a property list"`；Decoder 源码未改 |
| `B5DeterminismTests.swift:99`（`testPipelineInputCodableRoundTripAndStableEncoding`） | 两次编码同为 221 字节但 `Data` 不相等 | 编码容器键序不稳定表现；模型自 C2-D2 起无改动（仅标量与有序数组）。测试编码器显式 `outputFormatting = .sortedKeys` 强制字典序；Models/Core 源码未改 |

PlistReaderTests 6 例、PlistValueKindTests 11 例本轮 0 失败；PlistDecoderTests 9 例中除上述
同一用例两条断言外其余通过。若 `.sortedKeys` 后 B5 用例仍失败，下一轮日志须抓取两次编码
的具体字节差，再判断其他非确定性来源，不预先扩大改动面。

### 7.5 第五轮 Runner 验收通过（run `43889143343`，SHA `11f8b7f8…`）

第五轮 macOS Runner（Xcode 26.6 / Swift 6.3.3 / Simulator 26.5 SDK / deployment-target 17.0）
全部门槛转绿，证据归档 `Tests/Stage2/evidence/run-43889143343-acceptance/`：

- 非 UI 三库 Build：Core 71 文件，`Build complete! (18.34s)`，无 error / warning。
- 全量 `swift test`：**236 例 0 失败**（既有 210 + C3-B 新增 26：Reader 6 / Decoder 9 / 类型识别 11）；S1-05 独立 `--filter` 15 例 0 失败。
- Adapter 隔离复查 OK：Core 未直接实例化具体 Adapter。
- App Simulator Build：`** BUILD SUCCEEDED **`，PID 3928 存活，只读骨架首页截图归档。
- 第四轮 3 处失败（Decoder 单 token 夹具、B5 键序 `.sortedKeys`）本轮全部转绿。

C3-B 验收闭环；Rootless Parser、双路线 Engine、S1-06 22 项基线映射留待 C3-C2 / C3-C3 独立授权。

## 8. 待 Runner 出证项（本地静态无法替代）

1. `swift build`（Models / Adapters / Core 三库）0 error / 0 warning。
2. `swift test` 全量回归：既有 210 例 + 新增 26 例，0 失败；Reader/Decoder/类型识别
   三组可独立 `--filter` 执行并归档日志。
3. App Simulator Build 不受影响（沿用 C2-D2 存活构建口径）。
4. 隔离静态复查：Core 未实例化具体 Adapter；无 RootHide/Rootless 路线分支泄漏进 Reader/Decoder。

## 9. 偏差与留痕

- 附件目录示意的 `Reader/PlistReadError.swift` 未单建文件；错误码与描述并入
  `PlistReadResult.errorCode/errorDescription`，分类纯函数接缝置于 `PlistDataReader`。
- `Input/PluginParseInput.swift`、`PluginParseInputBuilder.swift` 本批不建，
  待 C3-C 按 C3-A 审计结论复用 C2 结构后再定。
- G-C3-2（skippedFields 结构化）、G-C3-4（Adapter 签名证据载体）、G-C3-5
  （UnloadAfter 归属）维持未决，不在本批评审改动。
