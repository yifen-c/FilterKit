# Stage 2.2-C3-C2：Rootless Codable Filter Parser 实现记录（代码冻结，Runner 验收待授权）

> 批次定位：C3-C2 落地 `Core/PlistParser/Rootless/` 独立 Codable Parser，与
> C3-C1 RootHide 严格 Parser 语义隔离。双路线 Engine / Snapshot / Counts /
> Input、S1-06 22 项基线映射（C3-C3）本批不实现。
>
> 状态：**Runner 已出证**；第四轮 `44021119037` 首次关闭 C-G2，第五轮 `44106064051` 复验
> 22 例 0 fail / 0 skip、全量 379 例 0 fail / 0 skip。本机 Linux 无 Swift 工具链；编译与回归结论以 Runner 日志为准。
>
> 依据：C3-A 契约 `Stage-2.2-C3-Parser-Data-Contract.md` §4.2 Rootless 规则、
> §4.3 空配置口径、§5.1/§5.2/§5.5 内部类型、§7 错误分类、§8 证据不可变；
> S1-06 基线 `Tests/S1-06/parser.js` `parseRootless` /
> `checkCodableStringArray` / `collectOtherKeys`；夹具
> `Tests/Fixtures/S1-06/parse-rootless-model/`（PARSE-015）；C3-B 已冻结
> Reader / Decoder / `PlistValueClassifier`；C3-C1 已冻结 Result 模型
> （`FilterParseStatus / SkippedField / FilterParseResult`）。

## 1. 本轮授权边界

### 已允许并执行（本地离线）

- **Rootless Codable 模型**：Core 内部 Decodable `RootlessPlistCodable`（顶层
  `UnloadAfter: Bool?`，嵌套 `FilterPayload{bundles, executables}`），仅三个叶子
  字段；`Classes / IsTweakManager / CoreFoundationVersion` 不纳入模型。
- **Rootless Parser**：根节点 / Filter 结构核对；字段级类型预核对（字符串数组、
  布尔）产出结构化 `SkippedField`；整份根字典重新序列化为 XML plist Data，交
  `PropertyListDecoder` 解码；失败一律 `parse_failed`；成功交 Mapper。
- **Rootless Mapper**：解码模型 → 公共 `FilterRule`；`Bundles / Executables`
  统一 `lowercased()`；`classes` 恒空、`coreFoundationVersion` 恒 `nil`；
  `otherKeys` 两层合并去重排序；空配置告警。
- **独立 XCTest**：Rootless 专项 22 例；`Package.swift` Core 与 `Stage2Tests`
  两处显式 sources 接线完成。

### 禁止项（本轮均未触碰）

- 未实现 RootHide 规则复用；未建 `Engine/`、`FilterParseSnapshot`、
  `FilterParseCounts`、`PluginParseInput`；未做路线选边与 Reader/Decoder 编排。
- 未修改公共 Models、Adapters、七方法协议、C1/C2 冻结源码与既有测试、Stage 1
  fixtures / harness / report；未新增公共 Codable 模型。
- `UnloadAfter` 按 G-C3-5 仅解码保留在内部模型内，未写入 `FilterRule`，未新增
  公共 Models 字段；其导出层归属继续等待独立评审。
- 未接入服务层 / Adapter 实例化；未扫描真机目录；未修改任何 plist 或插件文件；
  未做启停、注入、dpkg、软链改动或配置写入；未由 Parser 推断 `loaded`。
- 未编译、未跑 Runner；无文件系统访问，Parser 仅消费已解码的 Foundation 对象。

## 2. 文件清单

| 文件 | 模块 | 职责 |
|---|---|---|
| `Core/PlistParser/Rootless/RootlessFilterCodable.swift` | Core | 上游 Codable 输入模型（内部类型，不进公共 Models）；嵌套 `FilterPayload`；Decodable / Equatable |
| `Core/PlistParser/Rootless/RootlessFilterMapper.swift` | Core | Codable 模型 → `FilterRule`；小写规范化；otherKeys 两层合并去重排序；空配置告警 |
| `Core/PlistParser/Rootless/RootlessFilterParser.swift` | Core | Rootless 主入口；结构 / 类型预核对；序列化 + Codable 解码边界；失败 `parse_failed`；不接 Engine |
| `Tests/Stage2/RootlessFilterParserTests.swift` | Test | Rootless 专项 22 例（A 正常解码 9、B 结构错误 5、C 类型错误 5、D 确定性 / 不可变 / 隔离 3） |

## 3. 契约落地对照（§4.2 Rootless Codable 规则）

| 字段 | 位置 | 期望类型 | 缺失口径 | 类型不符处置 | 实现位置 |
|---|---|---|---|---|---|
| 根节点 | 顶层 | 字典 | — | `parse_failed` / `root_type`，key `(root)` | Parser 第 1 步 |
| `Filter` | 顶层 | 字典 | 缺失 / 空指针 → `filter_missing` | 非字典 → `filter_type` | Parser 第 2 步 |
| `Bundles` | Filter | `[String]?` | 缺失 / 空指针 → `[]` | 非数组 / 元素非串 → `parse_failed`，细粒度 `codable_type` 证据 | Parser `checkStringArray` |
| `Executables` | Filter | `[String]?` | 缺失 / 空指针 → `[]` | 同 Bundles | Parser `checkStringArray` |
| `UnloadAfter` | 顶层 | `Bool?` | 缺失 / 空指针 → 容忍 | 出现且非布尔 → `parse_failed` / `field_type`，记录类型证据 | Parser 第 3 步 |
| `Classes / CoreFoundationVersion / IsTweakManager` | — | 模型未覆盖 | 出现即记入 `otherKeys` | 不判失败；不写入模型字段 | Mapper `collectOtherKeys` |

- 取值规范化：`Bundles / Executables` 输出 `lowercased()`；原始值由内容信号保留。
- 失败口径：Rootless 结构不符 / 字段类型不符 / Codable 解码失败一律
  `parse_failed`，不转换为 RootHide 的 `type_mismatch`；重新序列化失败属解析链路，
  不记 `read_failed`（文件已成功读取）。
- 顶层 reason 映射：结构词 `root_type / filter_missing / filter_type` 原样透传；
  数组级 `codable_type` 顶层归 `field_type`（细粒度原因仅入 `SkippedField`）；
  序列化 / 解码兜底为 `codable_type`。
- 识别键：顶层 `Filter / UnloadAfter`；Filter 内 `Bundles / Executables`。
- 空配置口径（§4.3）：字段缺失 `field_missing`；空数组 `empty_array`；空 Filter
  `empty_filter`；空串元素保留并告警 `empty_element`，不静默剔除。

## 4. 结果模型口径（复用 C3-C1，不另造第二套 Result）

- 五态互斥：`valid` 携带 `FilterRule`；`parse_failed` 的 `filter` 恒 `nil`。
- `isTweakManager`：Rootless 恒 `nil`（模型无此键；`IsTweakManager` 入 otherKeys）。
- `otherKeys`：顶层与 Filter 内未覆盖键合并、去重、字典序排序；失败结果 `otherKeys`
  恒空。
- 告警 `sourceStage = "stage2.2-c3"`；`plistFormat / readStatus` 由调用方透传，
  Parser 不读取文件系统。
- Codable 中间模型 `RootlessPlistCodable` 仅在 Parser / Mapper 内部使用，不进入公共
  Models；业务规则载体仍是现有 `FilterRule`。

## 5. 测试清单（新增 22 例；run `44106064051` 复验通过）

### 5.1 A 正常解码与规范化（9 例）

- Bundles / Executables 小写化（对齐 PARSE-015：`Com.Example.App` →
  `com.example.app`、`RLApp` → `rlapp`）；`classes=[]`、`coreFoundationVersion=nil`、
  `isTweakManager=nil`。
- `UnloadAfter = true / false` 接受；三字段全缺失 → 合法空规则；空数组接受。
- `Classes / CoreFoundationVersion / IsTweakManager` 入 otherKeys 不判失败；
  otherKeys 排序与大小写敏感；跨层同键去重；两数组缺失 `field_missing` + `empty_filter`
  告警。

### 5.2 B 根节点 / Filter 结构错误（5 例）

- 根数组 / 根字符串 → `root_type`；Filter 缺失 / 空指针 → `filter_missing`；
  Filter 非字典 → `filter_type`；失败结果规则恒 nil。

### 5.3 C 字段类型错误（5 例）

- Bundles 非数组 / Executables 非数组 → 顶层 `field_type`，`codable_type` 证据；
  Bundles 元素非串 → `codable_type` + 元素 index；UnloadAfter 非布尔 →
  `field_type`（expected `boolean`）；三类失败均不携 `FilterRule`、otherKeys 为空。

### 5.4 D 确定性 / 不可变 / 隔离（3 例）

- 重复解析结果等值；Parser 不修改输入根字典；证据 `route` 恒 `rootless`。

## 6. 偏差与留痕

- 类型预核对先于 Codable 解码：`checkStringArray` / 布尔判断先行产出结构化证据
  （含元素 index、观测类型词），再以整份根字典序列化后交 `PropertyListDecoder`
  做解码边界确认；Mapper 取值以解码模型为准。预核对返回的数组仅作证据归集，
  不直接进入规则。
- 观测类型词私有映射 `PlistValueKind`：`.dictionary → object`，其余取 kind rawValue
  （array / string / boolean / number / data / date / null / unknown），对齐基线
  `typeOf` 口径。
- 序列化边界的已知风险：若未知键携带 `NSNull` 或其他 plist 不支持的 Foundation
  对象，`PropertyListSerialization` 可能抛错，Parser 按 `parse_failed` /
  `codable_type` 兜底；离线合成样本未覆盖该情形，待 Runner / 真机取证复核。
- G-C3-1（五态枚举落 Models 还是 Core 内部）、G-C3-2（结构化 skippedFields 是否
  提升公共 `ValidationReport`）维持待评审；本批类型保持 Core 中间层。
- 路线选边、未配对条目 `not_parsed`、读取级 `read_failed` 与编排属 C3-C3 Engine
  职责；本批 Parser 主入口仅产出 `valid / parse_failed`。

## 7. Runner 出证记录（第四轮，2026-11-17）

外部 Runner workflow run `44021119037`（branch `C2-C3`，SHA `ad443b151d9fddaa57dfac86ea58bbc33be8b8e1`）已出证，证据归档
`Tests/Stage2/evidence/run-44021119037-acceptance/`：Core 三库 Build 0 error / 0 warning（`Build complete! (5.97s)`）；
Rootless 专项 22 例通过；全量 347 例、3 skipped、0 failures；S1-05 独立过滤 15 例 0 失败；App Simulator `BUILD SUCCEEDED`
并存活；隔离三向 OK。本地未编译，Swift 语法、`PropertyListDecoder` 对 `[String]?` / `Bool?` 的解码行为与类型桥接以 Runner 实测为准。

**第五轮复验（run `44106064051`，检出 SHA `f4629f268e680bc0e25e911997d03959457263ec`）**：Rootless 专项 22 例 0 fail / 0 skip，
全量 379 例 0 fail / 0 skip；第四轮 3 例 `XCTSkipIf` 对应用例本轮实际执行通过。证据归档
`Tests/Stage2/evidence/run-44106064051-acceptance/`。

## 8. 出证状态与剩余观察项

- ✅ Runner 已出证：Core 三库 Build；22 例新增专项；既有回归无损伤；S1-05 15 例；App Simulator Build 与存活复查。
- 完整 Engine 链路 Rootless 用例（PARSE-015、PARSE-015-A、Rootless 对称）`XCTSkipIf` 挂起已在第五轮解除，run `44106064051` 实际执行通过。
- 本机 Linux 无 Swift / Xcode 工具链；类型桥接（Swift Bool ↔ CFBoolean、
  NSDictionary / NSArray 归一化、`lowercased()` 本地化口径）以 Runner 实测为准。
- 真机 plist 格式分布、Rootless 非常规键 / 字段分布待只读取证；离线合成样本不作
  真机背书。Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；R6 未知枚举默认解码、
  iOS 17 / Rootless 真机兼容仍为观察项。
