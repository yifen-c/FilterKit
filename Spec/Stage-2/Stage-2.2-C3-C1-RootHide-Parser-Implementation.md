# Stage 2.2-C3-C1：统一 Result + RootHide Filter Parser 实现记录（代码冻结，Runner 验收待授权）

> 批次定位：C3-C1 落地 `Core/PlistParser/Result/` 统一解析结果模型与
> `Core/PlistParser/RootHide/` 严格类型 Parser。Rootless Codable Parser
> （C3-C2）、双路线 Engine / Snapshot / Counts / 22 项基线映射（C3-C3）
> 本批不实现。
>
> 状态：**Implementation Complete / Local Static Review Passed**；**Runner Build /
> Test / App Build 未执行**（本机 Linux 无 Swift 工具链；编译、39 例新增专项与既有
> 236 例回归统一纳入后续独立 Runner 验收）。本记录不宣称已通过编译或回归。
>
> 依据：C3-A 契约 `Stage-2.2-C3-Parser-Data-Contract.md` PC3-1~14、§4.1 RootHide
> 规则、§5.1/§5.2/§5.5 内部类型、§7 错误分类、§8 证据不可变、§10 模块目录；
> S1-06 基线 `Tests/S1-06/parser.js` `parseRootHide` / `checkStringArray` /
> `cfvToVersion`；C3-B 已冻结 Reader / Decoder / `PlistValueClassifier`。

## 1. 本轮授权边界

### 已允许并执行（本地离线）

- **统一 Result 层**：`FilterParseStatus` 五态封闭枚举（valid / parse_failed /
  type_mismatch / read_failed / not_parsed）；`SkippedField` 结构化证据
  （key / reason / expectedType / observedType / route / index）；
  `FilterParseResult`（配对键 / 路径透传、状态、原因、规则、IsTweakManager、
  跳过证据、otherKeys、告警、格式与读取状态透传）。
- **RootHide Parser**：类型谓词层（复用 C3-B `PlistValueClassifier`，Bool 先于
  NSNumber 判定）、严格校验器（根 / Filter / IsTweakManager / 三字符串数组 / CFV）、
  规则映射器（FilterRule 复用、版本约束映射、otherKeys 去重排序、空配置告警）、
  Parser 主入口。
- **独立 XCTest**：Result 模型 7 例 + RootHide 专项 32 例，共 39 例；
  `Package.swift` Core 与 `Stage2Tests` 两处显式 sources 接线完成。

### 禁止项（本轮均未触碰）

- 未实现 Rootless Codable 模型 / Parser；未建 `Engine/`、`FilterParseSnapshot`、
  `FilterParseCounts`、`PluginParseInput`；未做路线选边与 Reader/Decoder 编排。
- 未修改公共 Models、Adapters、七方法协议、C1/C2 冻结源码与既有测试、Stage 1
  fixtures / harness / report；未新增公共 Codable 模型。
- 未接入服务层 / Adapter 实例化；未扫描真机目录；未修改任何 plist 或插件文件；
  未做启停、注入、dpkg、软链改动或配置写入；未由 Parser 推断 `loaded`。
- 未编译、未跑 Runner；无文件系统访问，Parser 仅消费已解码的 Foundation 对象。

## 2. 文件清单

| 文件 | 模块 | 职责 |
|---|---|---|
| `Core/PlistParser/Result/FilterParseStatus.swift` | Core | 五态封闭枚举（String Codable / Equatable），原始值对齐 S1-06 |
| `Core/PlistParser/Result/SkippedField.swift` | Core | 字段 / 元素级错误证据；route 归属；index 可空 |
| `Core/PlistParser/Result/FilterParseResult.swift` | Core | 单条统一结果；`filter` 仅 valid 非空；透传 Reader 格式 / 读取状态 |
| `Core/PlistParser/RootHide/RootHideFilterTypeChecker.swift` | Core | 类型谓词与字典 / 数组桥接归一化；观测类型词对齐基线 `typeOf` |
| `Core/PlistParser/RootHide/RootHideFilterValidator.swift` | Core | 严格规则核对；硬失败证据 + 长度线索；归一化中间值 |
| `Core/PlistParser/RootHide/RootHideFilterMapper.swift` | Core | 合法 Filter → `FilterRule`；CFV 映射；otherKeys；空配置告警 |
| `Core/PlistParser/RootHide/RootHideFilterParser.swift` | Core | RootHide 主入口；校验失败整份 `type_mismatch`；不接 Engine |
| `Tests/Stage2/FilterParseResultTests.swift` | Test | Result 模型 7 例（五态原始值、互斥、证据口径、透传、Codable 往返） |
| `Tests/Stage2/RootHideFilterParserTests.swift` | Test | RootHide 专项 32 例（A 根/Filter 6、B 布尔 5、C 字符串数组 7、D 版本 8、F 证据 4、H 确定性 2） |

## 3. 契约落地对照（§4.1 RootHide 严格规则）

| 字段 | 期望类型 | 缺失口径 | 类型不符处置 | 实现位置 |
|---|---|---|---|---|
| 根节点 | 字典 | — | `type_mismatch` / `root_type`，key `(root)` | Validator 第 1 步 |
| `Filter` | 字典 | 缺失 / 空指针 → `filter_missing` | 非字典 → `filter_type` | Validator 第 2 步 |
| `IsTweakManager` | 布尔 | 缺失 / 空指针 → `false` | 出现且非布尔 → `field_type` | Validator 第 3 步 |
| `Bundles` | 字符串数组 | 缺失 → `[]` | 非数组 `not_array`；元素非串 `element_type`；空指针元素容忍 | Validator `checkStringArray(allowNullElement: true)` |
| `Classes` | 字符串数组 | 缺失 → `[]` | 非数组 / 空指针元素 / 非串元素 → 失败 | `allowNullElement: false` |
| `Executables` | 字符串数组 | 缺失 → `[]` | 同 Classes | `allowNullElement: false` |
| `CoreFoundationVersion` | 数字数组（长度 1/2） | 缺失 → `nil` | 非数组 / 元素非数字 → `versions_type`；长度 0/3 → `unsupported_length` 线索 | `checkCoreFoundationVersion` |
| 其他键 | — | — | 记入 `otherKeys`，去重排序，不判失败 | Mapper `collectOtherKeys` |

- 版本映射：长度 1 → `{mode: max, max: v0}`；长度 2 → `{mode: range, min: v0,
  max: v1}`；长度 0/3 不构造版本约束，附 `unsupported_length` 线索与
  `versions_length_unhandled` 告警。
- Bool / NSNumber：CFV 布尔元素不计为数字；IsTweakManager 数字不计为布尔；
  判定统一走 `PlistValueClassifier`，本层不另写桥接判断。
- 空配置口径（§4.3）：字段缺失 `field_missing`；空数组 `empty_array`；空 Filter
  `empty_filter`；空串元素保留并告警 `empty_element`，不静默剔除。

## 4. 结果模型口径（§5.5）

- 五态互斥：`valid` 携带 `FilterRule`；`parse_failed / type_mismatch / read_failed /
  not_parsed` 的 `filter` 恒 `nil`。
- `isTweakManager`：RootHide 缺失归一 `false`；本批不产出 Rootless `nil` 口径。
- `otherKeys`：顶层识别键 `Filter / IsTweakManager`，Filter 内识别键
  `Bundles / Classes / Executables / CoreFoundationVersion`；两层未覆盖键合并、
  去重、字典序排序。
- 告警 `sourceStage = "stage2.2-c3"`；`plistFormat / readStatus` 由调用方透传，
  Parser 不读取文件系统。
- 字段命名以冻结契约为准：`expectedType / observedType`（建议 MD 示意的
  `expected / observed` 未采用）。

## 5. 测试清单（新增 39 例，待 Runner 执行）

### 5.1 Result 模型（7 例，`FilterParseResultTests.swift`）

- 五态原始值与 S1-06 逐字一致；valid 携带规则；四态规则恒 nil；
  SkippedField index 默认 nil / 元素级保留；透传字段保留；Codable 往返等值。

### 5.2 RootHide 专项（32 例，`RootHideFilterParserTests.swift`）

- **A 根 / Filter（6）**：空 Filter 合法；根数组 / 根字符串 `root_type`；
  Filter 缺失 / 空指针 `filter_missing`；Filter 非字典 `filter_type`。
- **B IsTweakManager（5）**：缺失默认 false；true / false 接受；数字 / 字符串
  `field_type`。
- **C 字符串数组（7）**：三数组合法；Bundles 非数组 `not_array`；Classes 空指针
  `null_element`；Executable 数字元素 `element_type`；Bundles 空指针容忍；
  Classes 非数组失败；空串保留 + `empty_element` 告警。
- **D CoreFoundationVersion（8）**：长度 1 → max；长度 2 → range；长度 3 / 0
  合法但附长度线索；字符串元素 / 布尔元素 / 非数组 `versions_type`；缺失为 nil。
- **F 证据归集（4）**：otherKeys 两层合并去重排序；失败结果 otherKeys 为空；
  证据 route 恒 `roothide`；三数组缺失 `field_missing` 告警。
- **H 确定性 / 不可变（2）**：重复解析结果等值；Parser 不修改输入字典。

## 6. 偏差与留痕

- `unsupported_length`（长度 0/3）按 S1-06 基线记为不阻断成功的线索，附在
  `skippedFields` 并补 `versions_length_unhandled` 告警；与硬失败证据同结构，
  但不改变 `valid` 状态。若 C3-D 评审要求 valid 证据数组严格为空，再调整归集位置。
- CFV 元素经 `NSNumber.intValue` 归一为 `Int`；浮点版本号的基线语义待真机 /
  夹具复核（沿用 Models `CoreFoundationVersion.min/max: Int?` 冻结口径）。
- G-C3-1（五态枚举落 Models 还是 Core 内部）、G-C3-2（结构化 skippedFields 是否
  提升公共 `ValidationReport`）维持待评审；本批类型保持 Core 中间层。
- 路线选边（`roothide / rootless / unknown`）、未配对条目 `not_parsed`、读取级
  `read_failed` 与解码级 `parse_failed` 的结果构造属 C3-C3 Engine 职责；本批
  Result 模型已预留五态字段，Parser 主入口仅产出 `valid / type_mismatch`。

## 7. Runner 失败与本地修复（待下一轮出证）

### 7.1 首轮：Core emit-module 编译失败（已本地修复）

- Runner：branch `C3-C1`，检出 SHA `af7f163a18f2ced766a40c619c29a4fe13d48131`，
  `swift build` 在 Core emit-module 阶段退出码 1；测试目标未进入编译。
- 根因：三个引用公共 Models 类型的 Core 文件只 `import Foundation`，未 `import Models`，
  导致 `FilterRule / ReportWarning / CoreFoundationVersion` 在作用域内找不到；
  级联触发 `Codable / Equatable` 合成失败、`.max / .range` 成员无法推断、
  `nil` 缺上下文类型等错误。日志 0 warning。
- 本地修复（仅补导入，未改规则 / 字段 / 测试）：
  - `Core/PlistParser/Result/FilterParseResult.swift`：补 `import Models`（`FilterRule`、
    `ReportWarning`）。
  - `Core/PlistParser/RootHide/RootHideFilterMapper.swift`：补 `import Models`
    （`FilterRule`、`CoreFoundationVersion`、`CoreFoundationMode`、`ReportWarning`）。
  - `Core/PlistParser/RootHide/RootHideFilterParser.swift`：补 `import Models`
    （`ReportWarning`）。
- 其余新文件（`FilterParseStatus / SkippedField / RootHideFilterTypeChecker /
  RootHideFilterValidator`）不引用 Models 类型，无需导入；测试目标已 `@testable import Models`。

### 7.2 第二轮：数组 mismatch 顶层 reason 口径错误（已本地修复）

- Runner：branch `C3-C1`，检出 SHA `44376c621c68fef4777b674020c5f32b4f290b23`；
  Core Build `Build complete! (40.43s)`，首轮导入问题消除。全量 275 例 1 failure：
  `RootHideFilterParserTests.testBundlesNotArrayIsTypeMismatch` 顶层 `reason` 实际
  `not_array`，期望 `field_type`；S1-05 独立过滤 15 例 0 失败，Result 模型 7 例全过。
- 根因：契约 §7 与基线 `parser.js` 规定数组非数组 / 元素不符属字段级失败，顶层 reason
  统一 `field_type`，细粒度 `not_array / null_element / element_type` 仅入
  `SkippedField`；Parser 原先直接取 `errors.first?.reason`，把细粒度原因透传到了顶层。
- 本地修复（未改规则 / 字段 / 夹具 / 测试断言）：`RootHideFilterParser.swift` 新增
  `topLevelReason(for:)` 映射：`not_array / null_element / element_type` → 顶层
  `field_type`；`root_type / filter_missing / filter_type / field_type /
  versions_type` 原样透传。校验器产出的细粒度证据不变。
- 待下一轮 Runner 复核：Core 三库 Build 0 error/0 warning；39 例专项通过；既有 236 例
  无回归；S1-05 15 例保持 0 失败；App Build 不受影响。

### 7.3 第三轮：Runner 验收通过（已归档）

- Runner：Actions run `43993649974`，branch `C3-C1`，检出 SHA `919185b10df94f057d31c6cf36a9b237d1973218`
  （本地 HEAD `245ea12`，Package.swift / Makefile / control / project.yml / workflow 逐文件一致）。
- 结果：Core Build `Build complete! (29.74s)`；全量 275 例 0 失败（既有 236 + 新增 39：
  Result 7 + RootHide 32）；S1-05 独立过滤 15 例 0 失败；隔离三项 OK；App `BUILD SUCCEEDED`，
  PID 3786 存活，只读骨架截图归档。
- 证据目录：`Tests/Stage2/evidence/run-43993649974-acceptance/`（日志、元数据、截图、产物
  artifact ID/SHA256 见 `RUN-METADATA.md`）。
- 前两轮失败修复（§7.1 补导入、§7.2 顶层 reason 映射）在本轮实测中均通过复核。

## 8. 出证状态与剩余观察项

- ✅ 已由 Runner 出证：Core 三库 Build 0 error；39 例新增专项通过；既有 236 例无回归；
  S1-05 15 例 0 失败；App Simulator Build 与存活复查不受影响。
- 本机 Linux 无 Swift / Xcode 工具链；类型桥接（Swift Int ↔ NSNumber、NSDictionary /
  NSArray 归一化）以 Runner 实测为准。
- 真机 plist 格式分布、非常规键、RootHide 严格规则兼容性待只读取证；离线合成样本
  不作真机背书。Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；CFV 浮点版本号语义、
  未知枚举默认解码、Rootless 真机行为仍为观察项。
