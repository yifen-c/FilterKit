# Stage 2.2-D（0.1-B）：统一报告与 JSON 导出实现记录

- 日期：2026-11-17
- 授权依据：用户指令「正式授权 0.1-B 开发」；冻结规格 `Stage-2.2-D-Reporting-Implementation-Spec.md`（D1～D5，提交 `1298edc`）。
- 状态标记：**Implementation Landed / Local L1 Static Review Passed / Runner Build & Test Pending**。本机 Linux 无 Swift/Xcode 工具链，本轮未编译、未执行 XCTest；编译与测试通过结论以阶段末统一 Runner 为准。

## 1. 本轮授权边界

### 允许
1. 按 D1～D5 批次新增 Core/Reporting、Core/ReportExporter 生产代码与对应 XCTest；
2. 新增三段可替换接缝协议（`ReportBuilding` / `ReportValidating` / `ReportExporting`）；
3. 必要时调整 `Package.swift` 显式 sources 接线；
4. 只读静态检查、接口核对与代码审查。

### 禁止（本轮均未触碰）
1. 未修改冻结公共 Models、七方法 `ElleKitAdapter` 协议、Parser 语义与 Stage1 fixtures；
2. 未实现 `OwnershipResolver`；归属输入为已解析快照注入；
3. 未重新扫描 / 重新解析 / 归属补判 / 运行时取证；
4. 未写 GUI 页面、entitlement、进程内 `jbroot()`；
5. 未做启停、装卸、注入、规则修改或任何文件写入；
6. 未调度阶段末统一 Runner，未声称本地编译通过。

## 2. 文件清单

| 类别 | 路径 | 说明 |
|---|---|---|
| Core D2 | `Core/Reporting/ReportBuilder.swift` | `ReportBuildInput`、归并键、状态映射、未知归集、告警合并与去重 |
| Core D3 | `Core/Reporting/ReportValidator.swift` | `ReportValidationResult`、RV-001～010 只读校验 |
| Core D5 | `Core/Reporting/ReportService.swift` | `ReportServiceProtocol`、三段接缝协议、默认装配 `ReportService` |
| Core D4 | `Core/ReportExporter/ReportExporter.swift` | 确定性 JSON 编码入口、`ReportExportError` |
| Core D4 | `Core/ReportExporter/ReportSerialization.swift` | plugins / unknownItems / warnings 显式排序策略 |
| 测试 D2 | `Tests/Stage2/ReportBuilderTests.swift` | Builder-001～006（6 例） |
| 测试 D3 | `Tests/Stage2/ReportValidatorTests.swift` | Validator-001～004（4 例） |
| 测试 D4 | `Tests/Stage2/ReportExporterTests.swift` | Exporter-001～005（5 例） |
| 测试 D5 | `Tests/Stage2/ReportServiceTests.swift` | Service-001～003（3 例） |
| 接线 | `Package.swift` | Core 登记 5 个源；Stage2Tests 登记 4 个测试源 |

未新增 Models 类型；既有 `CoreServices.swift` 冻结协议保持原样，未新建第二套上游服务抽象。

## 3. 实现口径要点

### 3.1 Builder（D2）
- 条目集合 = 枚举 `items` ∪ 配对 `records` ∪ 解析 `parsed`；归并键优先 `pairingKey`，回退文件名基名。
- `ambiguous / uncertain` 记录与 `not_parsed` / 未知路线解析结果留置 `unknownItems`，不并入 `Pairing` 枚举。
- 三层状态互不推导：`installed` 仅取 dylib `exists ?? readable`；`configured` 仅取解析 `valid`；`loaded` 恒 `.unknown`；`permission.decision` 恒 `undetermined`。
- 解析失败条目保留在 `plugins`，`filter=nil`，`validation.status / warnings / skippedFields` 保留证据。
- 归属未命中使用 `Ownership()` 未知默认，`ownershipDetails = nil`；`pluginID` 离线规则：优先 `<packageID>:<base>`，回退 `<base>`（0.2.0 定稿）。
- 上游阶段整体缺失为 `nil` 时对应证据留空，追加 `inventory_unresolved / pairing_unresolved / parsing_unresolved` 告警，不回退补齐。
- 配对侧与解析侧路径证据不一致时不强行合并，追加 `pairing_ambiguous` 告警。

### 3.2 Validator（D3）
- RV-001 信封必填；RV-002 身份非空且不重复；RV-003 配对状态与两侧路径证据一致；RV-004 解析状态封闭集；RV-005 仅 `valid` 携带 filter；RV-006 只读阶段 loaded 恒 unknown；RV-007 来源与归属一致；RV-008 告警去重；RV-009 未知条目身份保留；RV-010 Profile 路线一致、未知路线不携带路线专属 filter。
- 只发现不修复；校验器不修改原始报告。

### 3.3 Exporter（D4）
- 编码前按 `ReportSerialization` 显式排序；`JSONEncoder` 开启 `.sortedKeys` 仅保证对象键序。
- `Optional Bool` 三态保留，`nil` 序列化为 `null`；除 `generatedAt` 外相同输入确定性可复现。
- 编码失败抛 `ReportExportError.encodingFailed`，不吞错、不返回空数据；不修改原始报告。

### 3.4 Service（D5）
- 编排顺序：Builder → Validator → Exporter；校验不通过不抛异常阻断，是否导出由调用方决定。
- Builder / Validator / Exporter 经接缝协议注入，默认使用冻结实现；GUI 后续只消费 `ReportServiceProtocol`。

## 4. L1 静态自检记录

| 检查项 | 结论 |
|---|---|
| 新增 Core / 测试源文件与 `Package.swift` sources 一一对应 | 通过，无遗漏、无悬空登记 |
| 引用的 Models / Core 公共类型、字段、初始化器与真实源码核对 | 通过，未臆造类型 |
| 括号 / 花括号平衡 | 通过（10 个新文件均为 0 差值） |
| 越界 API 扫描（FileManager / jbroot() / 注入 / 写入 / GUI / entitlement） | 未发现生产调用 |
| 冻结 Models、Adapter 协议、Parser 语义、Stage1 fixtures 改动 | `git status` 仅 `Package.swift` 与里程碑计划文档改动 |
| 测试用例编号覆盖 | Builder 6 / Validator 4 / Exporter 5 / Service 3，共 18 例，对齐规格 §4.6/§5.3/§6.4/§7.3 |

## 5. 待验证与未决项

- 阶段末统一 Runner：编译、18 例新用例、既有回归无损伤、JSON 确定性深比较；本轮不单独启动 Runner。
- PARSE-009-B 继续独立挂起，不改 Parser 与基线期望。
- `OwnershipResolver` 迁移单列后续批次；`pluginID` 稳定标识规则 0.2.0 定稿；`loaded` 运行时取证待后续阶段。
- 本批次为 CI/Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据。

## 6. Runner 首轮编译错误与修复（2026-11-18）

### 6.1 现场口径

- Runner：仓库 `yi-fen/FilterKit`，分支 `2.2-D`，检出 SHA `117a5df5af96fec1234073e9a33d7c1d58c177f9`；macOS 26.7.2 / macos-26-arm64；步骤 `swift build`，`Process completed with exit code 1`；Core 编译中断，测试目标未进入编译，日志中无 `swift test` 段。
- Models、Adapters 模块编译通过；错误全部挂在 Core 目标 `Core/Reporting/ReportBuilder.swift`。

### 6.2 错误清单（日志原始坐标）

| 坐标 | 原始表达式 | 类型问题 |
|---|---|---|
| 154:70 | `result.plistPath?.lastPathComponent` | `plistPath` 为 `String?`，无 `lastPathComponent` 成员 |
| 161:67 | `result.dylibPath?.lastPathComponent` | 同上，`dylibPath` 为 `String?` |
| 161:106 | `result.plistPath?.lastPathComponent` | 同上 |
| 191:35 | `result?.plistPath?.lastPathComponent` | 同上 |

根因：`lastPathComponent` 是 `NSString` / `URL` 成员；纯 Swift `String` 不暴露该成员。既有可编译写法均为 `(x as NSString).lastPathComponent` 桥接或作用于 `URL` 数组。

### 6.3 修复口径（仅 `Core/Reporting/ReportBuilder.swift`）

- 新增私有辅助方法 `lastComponent(of path: String?) -> String?`：`nil` 透传，非空经 `(path as NSString).lastPathComponent` 取值。
- 三处调用点改为经辅助方法取末段：154 行 plist 回退；161 行 dylib → plist 回退链；191 行 `result.flatMap { lastComponent(of: $0.plistPath) }`。
- 未改归并键、状态映射、未知归集、排序与校验语义；未触碰冻结 Models、Adapter 协议、Parser 语义、Stage1 fixtures；`Package.swift` 登记与磁盘文件复核一致。

### 6.4 本轮静态复查（本机无 Swift 工具链，未本地编译）

- 四个新测试桩引用的 init 标签、枚举用例、接缝协议方法签名已与真实源码逐一核对：`FilterParseResult` / `PluginPairingRecord` / `PluginInventorySnapshot` / `FilterParseSnapshot` / `PluginPairingSnapshot` / `Ownership` / `OwnershipDetails` / `PluginFileEvidence` / `ReportBuildInput` / `ReportValidationResult` / `ReportExportError` / `ReportBuilding` / `ReportValidating` / `ReportExporting` 均匹配。
- 残留风险：Core 失败在前，测试目标编译错误本轮日志不可见；Stage2Tests 潜在签名 / 可选值 / Codable 往返问题需下一轮 Runner 暴露后再修。编译与通过结论以 Runner 日志为准，本轮不声称本地编译通过。

## 7. Runner 第二轮测试目标编译错误与修复（2026-11-18）

### 7.1 现场口径

- Runner：仓库 `yi-fen/FilterKit`，分支 `2.2-D`，检出 SHA `5fcb00e5124b661c492bbf3e0ad21cef2de258aa`；workflow run `44217387852`；job `test`；步骤 `swift test 2>&1 | tee .build/test-log.txt`；macOS 26.7.2 / macos-26-arm64；`Process completed with exit code 1`。
- Core 目标本轮编译通过：日志可见 `[93/99] ReportExporter`、`[94/99] ReportSerialization`、`[95/99] ReportBuilder`、`[96/99] ReportService`、`[97/99] ReportValidator`，Models/Adapters/Core 全部过编译，首轮 `b8ba3f3` Core 修复确认生效。
- 失败全部转入 Stage2Tests 测试目标（emit-module 中断）；日志在多个测试文件编译命令中重复打印同一错误集，属级联重复，非新增错误。测试目标未编译通过，18 例新用例与既有回归本轮尚未被 Runner 触达。

### 7.2 错误清单（日志原始坐标，去重后）

| 坐标 | 原始表达式 | 类型问题 |
|---|---|---|
| `Tests/Stage2/ReportBuilderTests.swift:66:59` | `dylibPath: String? = "/dir/\(key).dylib"` | 默认表达式引用兄弟形参 `key`，`cannot find 'key' in scope` |
| `Tests/Stage2/ReportBuilderTests.swift:67:59` | `plistPath: String? = "/dir/\(key).plist"` | 同上 |
| `Tests/Stage2/ReportBuilderTests.swift:98:54` | `dylibPath: String? = "/dir/\(key).dylib"` | 同上（`record` 桩） |
| `Tests/Stage2/ReportBuilderTests.swift:99:54` | `plistPath: String? = "/dir/\(key).plist"` | 同上（`record` 桩） |
| `Tests/Stage2/ReportExporterTests.swift:61:43` | `Set(object?.keys ?? [])` | `object?.keys` 为 `Dictionary<String, Any>.Keys?`，`?? []` 被推成 `[Any]`，与 `Keys` 不匹配 |
| `Tests/Stage2/ReportValidatorTests.swift:87:24` | 调用先传 `status:` 后传 `filter:` | helper 声明 `filter` 在 `status` 前，`argument 'filter' must precede argument 'status'` |
| `Tests/Stage2/ReportValidatorTests.swift:131:58` | `status: "type_mismatch", filter: nil` | 同上 |
| `Tests/Stage2/ReportBuilderTests.swift:38:13`（warning） | `` `extension`: `` | 保留词在实参标签位无需反引号转义 |

根因：Swift 默认参数表达式不能引用同函数的其他形参；`Dictionary.Keys` 不能与 `[Any]` 经 `??` 拼接；标签实参顺序须与 helper 声明一致。

### 7.3 修复口径（仅三个测试文件，`Core/` 未回改）

- `Tests/Stage2/ReportBuilderTests.swift`
  - `parseResult(...)`：`dylibPath` / `plistPath` 默认改 `nil`，函数体内 `?? "/dir/\(key).dylib"` / `?? "/dir/\(key).plist"` 拼默认路径，沿用 `EngineC2-TestSupport.swift` 既有桩范式。
  - `record(...)`：两路径默认 `nil`，函数体内按类别派生缺失侧——`orphanPlist` 不出 dylib 证据、`missingPlist` 不出 plist 证据，其余侧按 `key` 拼默认路径；证据仍经 `String?.map` 构造，`nil` 侧保持缺证据。
  - `evidence(...)` 标签 `` `extension`: `` 去掉反引号，改裸 `extension:`。
- `Tests/Stage2/ReportExporterTests.swift:61`：改为 `let topKeys: Set<String> = object.map { Set($0.keys) } ?? []`。
- `Tests/Stage2/ReportValidatorTests.swift`：两处调用点把 `filter:` 调到 `status:` 之前；helper `makePlugin(...)` 签名未改。
- 未改冻结公共 Models、七方法 Adapter 协议、Parser 语义、Stage1 fixtures；未实现 OwnershipResolver；未写 GUI/entitlement/进程内 `jbroot()`。

### 7.4 本轮静态复查（本机无 Swift 工具链，未本地编译）

- 三个桩构造器与 `FilterParseResult` / `PluginPairingRecord` / `PluginFileEvidence` / `Plugin` 字段可选性逐一核对：`dylibPath` / `plistPath` 为 `String?`，`dylib` / `plist` 为 `PluginFileEvidence?`，与改动后类型一致。
- `PairingCategory` 用例 `.paired / .missingPlist / .orphanPlist / .ambiguous` 与派生口径一致；`ReportServiceTests.swift` 直接构造模型、无默认参数引用兄弟形参，日志中无独立错误。
- 残留风险：测试目标编译是否通过、18 例新用例与既有回归是否绿，本轮日志不可见，需下一轮 Runner 证据；编译与通过结论以 Runner 日志为准，本轮不声称本地编译通过。本批次仍为 CI/Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据。

## 8. Runner 第三轮测试断言失败与修复（2026-11-18）

### 8.1 现场口径

- Runner：仓库 `yi-fen/FilterKit`，分支 `2.2-D`，检出 SHA `d08f04f69976c924d2298152be235063fe7428a7`；workflow run `44221150319`；artifact `filterkit-test-log`（ID `14390149054`）；job `test`；步骤 `swift test`；macOS 26.7.2 / macos-26-arm64；`Process completed with exit code 1`。
- 编译与链接本轮通过：日志可见 `[137/145] ReportBuilderTests`、`[138/145] ReportExporterTests`、`[139/145] ReportServiceTests`、`[140/145] ReportValidatorTests` 进入编译，`[146/147] Linking`、`Build complete! (30.05s)`，无编译错误；第二轮测试目标编译修复确认生效。
- 执行统计：`Executed 397 tests, with 2 failures (0 unexpected)`；除下两例外，既有回归与其余 Reporting 用例均 `0 failures`。

### 8.2 失败清单（日志原始坐标）

| 坐标 | 用例 | 断言 | 根因 |
|---|---|---|---|
| `Tests/Stage2/ReportExporterTests.swift:91` | `testExporter002OptionalBoolThreeStatesSurvive` | `XCTAssertTrue(unknownEntry?["installed"] is NSNull)` 失败 | `Plugin` 为合成 Codable，可选属性经 `encodeIfPresent` 输出，`installed=nil` 时键被省略；JSON 中无 `null`，与冻结规格 §6.2.2「Optional Bool 的 `nil` 序列化为 `null`」不符。解码往返不受影响，故 84～86 行三态往返断言通过，仅原始 JSON 空值表示失败。 |
| `Tests/Stage2/ReportValidatorTests.swift:114` | `testValidator002InjectsInconsistenciesAndKeepsOriginal` | `XCTAssertTrue(codes.contains("RV-003"))` 失败 | 桩 `makePlugin(...)` 用 `dylibPath ?? "/dir/…dylib"`、`plistPath ?? "/dir/…plist"` 回填默认路径；显式传入的 `nil` 被 `??` 当作缺省值覆盖，`paired` 样本两侧路径都被补上证据，RV-003「配对状态与路径证据矛盾」未被触发。生产校验器判定口径与规格 §5.2 RV-003 一致，未回改。 |

### 8.3 修复口径

- `Models/PluginModels.swift`（编码层，字段 / init / 解码 / 契约未改）
  - 新增显式 `CodingKeys`（19 键，键名与既有合成键名一致）与 `public func encode(to:)`。
  - `installed: Bool?` 改经 `encode(_:forKey:)` 输出：`nil` 显式落 JSON `null`，三态 `true / false / nil` 可辨。
  - 其余可选字段（`version / dylibPath / plistPath / ownershipDetails / filter`）维持 `encodeIfPresent` 既有语义；非可选字段按原口径直写。
  - 解码仍由编译器合成（未实现 `init(from:)`），缺键解码为 `nil` 的既有兼容策略不变。
- `Tests/Stage2/ReportValidatorTests.swift`
  - RV-003 的 `nopair` 样本改为直接构造 `Plugin(...)`，显式保留 `dylibPath=nil / plistPath=nil`，不再经桩默认回填；`makePlugin(...)` 桩签名与其余样本未改。
- 未改冻结 Adapter 协议、Parser 语义与 Stage1 fixtures；未实现 `OwnershipResolver`；未写 GUI / entitlement / 进程内 `jbroot()`；未做启停、装卸、注入或文件写入。

### 8.4 本轮静态复查（本机无 Swift 工具链，未本地编译）

- `Plugin` init 标签、枚举用例（`.paired / .dpkgSileo / .unknown`）、`Ownership(sourceType:packageID:)`、`FilterRule(bundles:)`、`ValidationReport(status:)` 与真实源码逐一核对；两处改动括号 / 花括号差值为 0。
- 基线扫描：`ModelsCodableTests` 的空值断言均为解码侧或往返等价比较，`testEmptyArraysEncodeAsArrayNotNil` 的非 null 负向检查仅覆盖 `FilterRule` 数组，不涉及 `Plugin.installed`；`installed` 显式落 `null` 不破坏既有往返与缺失键解码。
- 残留风险：本轮两处修复未经本地编译；18 例新用例与既有回归是否全绿，以第四轮 Runner 日志为准，本轮不声称本地编译通过。本批次仍为 CI/Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据。

## 9. Runner 第四轮复验与 0.1-B 验收闭环（2026-11-18）

### 9.1 现场口径

- Runner：仓库 `yi-fen/FilterKit`，分支 `2.2-D`，检出 SHA `9a3f087f6a699cf3390aad42668e5fed5be3d378`；workflow run `44224350333`；artifacts：`filterkit-test-log` ID `14392112483`、`filterkit-app-build` ID `14391852889`、`filterkit-build-metadata` ID `14392960956`；macOS 26.7.2 / `macos-26-arm64` 20261102.0473.1；Xcode 26.6（17F113）；Swift 6.3.3；iOS Simulator SDK 26.5。
- 代码面核对：`Models / Core / Tests / Adapters` 与本地 `94bd7f2` 无 diff；五个 metadata 文件（`Package.swift` / `Makefile` / `control` / `project.yml` / `filterkit-build.yml`）逐文件 diff 一致；第三轮两处修复在检出树内确认存在。Runner 检出 SHA 与本地 HEAD 不同名（历史远程网页上传惯例），结论以 Runner 实际日志为准。
- 本机 Linux 无 Swift/Xcode 工具链，本轮未本地编译；编译与测试通过结论均以 Runner 日志为准。

### 9.2 门禁结果

| 验收门 | 结论 | 证据坐标 |
|---|---|---|
| 非 UI 目标 Build（Models / Adapters / Core） | ✅ `Build complete! (19.62s)`，0 error / 0 warning | `logs/build/3_Build non-UI targets (Models _ Adapters _ Core).txt` |
| 全量 Swift 测试 | ✅ `Executed 397 tests, with 0 failures (0 unexpected)`，0 skipped | `test-log/test-log.txt` |
| Reporting 18 例 | ✅ Builder 6 / Validator 4 / Exporter 5 / Service 3，套件全部 `passed` | `test-log/test-log.txt` |
| 既有回归 379 例 | ✅ 0 failure / 0 skip，无损伤 | `test-log/test-log.txt` |
| S1-05 独立过滤 | ✅ 15 tests，0 failures | `test-log/test-log-s105.txt` |
| 架构隔离静态检查 | ✅ 四项 OK，「隔离检查通过（静态文本层面）」 | `logs/isolation/3_Adapter isolation check.txt` |
| App Build + 模拟器存活 | ✅ `** BUILD SUCCEEDED **`；iPhone 17 Pro Booted；bundle `com.filterkit.manager`；PID 4096 alive；截图 `dashboard.png` | `logs/app-build/`、`app-build/` |
| 全量日志错误扫描 | ✅ 无 `##[error]` / `exit code 1` / `FAILED` | `logs/` 全量 job 日志 |

### 9.3 第三轮失败复验

- `ReportExporterTests.testExporter002OptionalBoolThreeStatesSurvive`：`passed (0.001s)`；`installed: Bool?` 的 `nil` 显式落 JSON `null`，三态 `true / false / nil` 断言通过。
- `ReportValidatorTests.testValidator002InjectsInconsistenciesAndKeepsOriginal`：`passed (0.000s)`；RV-003 样本保留显式 nil 路径证据，矛盾注入与原始报告不变断言通过。
- 生产 Builder / Validator / Exporter / Service 语义本轮未回改；除第三轮两处既有修复外无新增代码改动。

### 9.4 口径与残留项

- 0.1-B（Stage 2.2-D Reporting）在 CI/Simulator 口径下闭环：D1～D5 用例、既有回归、确定性编码与三态保留、接缝注入均经 Runner 验证。
- App 构建仅 1 条 `appintentsmetadataprocessor` 工具链噪声（无 AppIntents.framework 依赖，元数据提取跳过），非 Swift/Clang 代码告警。
- 未决项维持：`OwnershipResolver` 未迁移；`loaded` 恒 `.unknown`；`pluginID` 稳定标识规则 0.2.0 定稿；PARSE-009-B 独立挂起未改 Parser 与基线期望。
- 本轮为 CI/Simulator 口径，不构成真机权限、真实加载或 Rootless 真机兼容证据；0.1-C GUI、0.1-D 探针真机未授权。
- 证据归档：`Tests/Stage2/evidence/run-44224350333-acceptance/`（`RUN-METADATA.md`、test-log、全量 job 日志、app-build 产物、metadata 快照）。
