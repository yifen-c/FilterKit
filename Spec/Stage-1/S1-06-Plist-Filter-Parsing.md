# S1-06 Plist & Filter Parsing — Plist / Filter 解析子规格

- 状态：**Stage 1 子规格，设计冻结，等待离线测试授权**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-06，不进入 S1-07（来源识别）；**本轮仅规格设计与用例拆解，不写代码、不建实际夹具、不建正式工程、不编译**。
- 前置：S1-01~S1-05 均已离线验收归档；本项输入为 S1-05 Pairing Report。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.2（Plugin / FilterRule / ValidationReport）、§2.3（FilterRule 字段）。
- 职责边界：**S1-05 判断文件是否配对；S1-06 判断 plist 内容是否合法、Filter 规则表达了什么；S1-07 判断插件来自哪里。** S1-06 只解析，不修改任何 plist 或插件文件。

## 1. 测试目标

依据 S1-05 建立的配对关系，只读读取配对 plist，按路线对应的 Parser Adapter 解析 ElleKit Filter 配置，产出 Parsed Plugin Model，供 S1-07 来源识别与 S1-08 统一模型导出使用。

- 只做**只读解析与类型核对**；不修改 plist、不安装/卸载/启用/禁用、不注入、不判断来源、不推断加载状态。
- 解析失败只说明配置解析失败，**不把插件从发现结果中删除**；单插件解析失败不中断其他插件。
- 两条路线使用**独立 Adapter 规则**，不得把 Rootless 上游行为套用到 RootHide，反之亦然。

### 1.1 源码解析语义（源码确认）

#### 1.1.1 RootHide 1.2-3（`roothide-ellekit-src/injector/injector.c:83-358`，严格规则）

| 项 | 源码口径 | 依据 |
|---|---|---|
| 读取 | `CFURLCreateDataAndPropertiesFromResource` 读数据，`CFPropertyListCreateWithData` 建属性列表；读不出/建不成都判无效 | `injector.c:109-130` |
| 根类型 | 根节点必须是 `CFDictionary`；否则无效 | `injector.c:132-135` |
| Filter 类型 | `Filter` 必须存在且为 `CFDictionary`；缺失或非字典无效 | `injector.c:137-142` |
| IsTweakManager | 顶层 `IsTweakManager` 可选；出现时必须是 `CFBoolean`，否则无效 | `injector.c:144-149` |
| CoreFoundationVersion | Filter 内可选 `CFArray`；非数组无效；元素必须是 `CFNumber`；长度 1：单值 > 当前 CFV 则跳过；长度 2：双值区间判断；非数值元素无效 | `injector.c:155-191` |
| Bundles | 可选 `CFArray`；非数组无效；元素必须是 `CFString`；空指针元素容忍，非字符串无效 | `injector.c:194-207` |
| Classes | 可选 `CFArray`；非数组无效；元素必须是 `CFString`，空指针/非字符串无效 | `injector.c:242-255` |
| Executables | 可选 `CFArray`；非数组无效；元素必须是 `CFString`，空指针/非字符串无效 | `injector.c:280-302,331-338` |
| 类型违规处置 | 任一类型不符，整份 plist 判无效（`return false`）；**不是按字段静默跳过** | `injector.c:157-158,197-198,205-206,245-246,253-254,282-283,300-301` |

> 注：RootHide C 解析器在运行时还做“是否命中当前进程”的注入判断（Bundle/Class/Executable 实际匹配）；S1-06 只做离线规则解析，**不做进程命中判断**，命中结论留待运行时证据。

#### 1.1.2 Rootless 上游（双实现，分别记录）

| 实现 | 位置 | 解析口径 |
|---|---|---|
| Swift launchd | `ellekit-src/launchd/Tweak.swift:7-37` | `PropertyListDecoder` 解码 Codable：根需含 `Filter` 字典；`Filter.Bundles`、`Filter.Executables` 为 `[String]?`；顶层 `UnloadAfter: Bool?`；解码抛错 → 该 tweak 被 `compactMap` 丢弃；Bundle/Executable 值统一 `lowercased()`；**模型无 Classes、无 CoreFoundationVersion、无 IsTweakManager 字段** |
| C injector | `ellekit-src/injector/injector.c:67-224` | 较宽松：未做根类型/Filter 类型/数组类型/元素类型核对；直接遍历数组取值；Bundles 含大小写不敏感查找；Executables 末尾组件大小写不敏感比较 |

> 口径说明：S1-06 的 Rootless Adapter 以 **Swift Codable 模型**为准做结构化解析；C injector 的宽松行为作为兼容性风险记录。Swift 模型未覆盖的键（Classes / CoreFoundationVersion / IsTweakManager 等）若出现，记入 `otherKeys` 只读保留，**不判为解码失败**，也不臆测语义。
>
> 调用路径归属：两套源码分属不同侧（Swift 为 launchd 加载侧，C injector 为进程内注入侧）；离线不判定二者在同一次插件加载中同时生效，也不合并成一条宽松规则。Rootless 真机实际走哪套实现、是否两条路径并存，属运行时取证事项，本阶段记 `[Rootless 真机待验证]`，不下兼容结论。

## 2. 输入模型（只读）

| 输入 | 来源 | 说明 |
|---|---|---|
| S1-05 Pairing Report | 上游产物 | `route`、`sourceDirectory`、`pairs[]`、`missingPlist[]`、`orphanPlist[]`、`ambiguous[]`、`uncertain[]`、`counts`、`status` |
| plist 字节/内容信号 | 离线夹具注入 | 文件名、`plistFormat`（xml/binary/unknown）、`readStatus`、原始字段与类型；离线不访问真实文件系统 |

> 只消费 S1-05 已建立的配对关系：仅 `pairing=paired` 的条目进入解析；其余条目原样携带为 `notParsed`，保留上游配对原因，不重新配对、不补列。

## 3. 输出模型（Parsed Plugin Model，S1-06 中间产物）

```json
{
  "route": "roothide",
  "sourceDirectory": "<jbroot>/usr/lib/TweakInject/",
  "status": "enumerated",
  "parsed": [
    {
      "base": "Example",
      "dylibPath": "<dir>/Example.dylib",
      "plistPath": "<dir>/Example.plist",
      "plistFormat": "xml",
      "readStatus": "ok",
      "parseStatus": "valid",
      "isTweakManager": false,
      "filter": {
        "bundles": ["com.apple.example"],
        "classes": ["ExampleClass"],
        "executables": ["ExampleApp"],
        "coreFoundationVersion": null,
        "otherKeys": []
      },
      "skippedFields": [],
      "validation": { "status": "valid", "warnings": [] }
    }
  ],
  "notParsed": [
    { "base": "Unmatched", "dylibPath": "<dir>/Unmatched.dylib", "plistPath": null, "pairing": "missing_plist", "reason": "missing_plist" },
    { "base": "Locked", "dylibPath": "<dir>/Locked.dylib", "plistPath": "<dir>/Locked.plist", "pairing": "uncertain", "reason": "access_denied" }
  ],
  "counts": { "valid": 1, "parse_failed": 0, "type_mismatch": 0, "read_failed": 0, "not_parsed": 2 },
  "warnings": []
}
```

字段口径（对齐 [Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.2/§2.3）：

| 字段 | 含义 / 未知口径 |
|---|---|
| `parsed[].plistFormat` | `xml` / `binary` / `unknown`；仅记录格式，不据此判断内容合法性 |
| `parsed[].readStatus` | `ok` / `access_denied` / `read_failed`；读不出内容时与解析失败区分 |
| `parsed[].parseStatus` | `valid`：结构与类型通过本路线规则；`parse_failed`：字节不是合法属性列表；`type_mismatch`：结构在但类型/字段不符本路线规则 |
| `isTweakManager` | 顶层 `IsTweakManager`；缺失 = `false`；类型不符按 §6 归类；Rootless 模型无此键时记 `null` 并入 `otherKeys` 线索 |
| `filter.bundles / classes / executables` | 字符串数组；缺失字段为空数组 `[]`，与空数组在 `validation` 中分别标注 |
| `filter.coreFoundationVersion` | `{ mode: "max"|"range", min?: number, max?: number }`；缺失/非本路线支持 = `null` |
| `filter.otherKeys` | 本路线 Adapter 未覆盖的扩展字段名（只读记录，不臆测语义） |
| `skippedFields[]` | 被排除/降级的字段：`{ key, reason, expectedType, observedType }`；保留原始字段类型证据 |
| `notParsed[]` | 上游未配对/不确定/本次未解析条目；保留 `pairing` 与原因，不删除 |
| `counts` | `valid / parse_failed / type_mismatch / read_failed / not_parsed` 互斥计数 |

## 4. Parser Adapter 规则（路线隔离）

### 4.1 Adapter 选择

- `route=roothide` → `RootHideProfile_1_2_3`，采用 §1.1.1 严格规则。
- `route=rootless` → `RootlessProfile`，采用 §1.1.2 Swift Codable 规则。
- `route=rootful` / `unknown` → 不自动套用任一规则；规则语义记 `unknown`，解析结果进 `uncertain` 线索，不强行选边。
- Adapter 规则与路线 Profile 绑定；禁止跨路线复用类型核对口径。

### 4.2 RootHide 字段核对规则

| 字段 | 位置 | 期望类型 | 缺失 | 类型不符处置 |
|---|---|---|---|---|
| 根节点 | 顶层 | 字典 | — | 根非字典 → `type_mismatch`（root_type） |
| `Filter` | 顶层 | 字典 | 缺失 → `type_mismatch`（filter_missing） | 非字典 → `type_mismatch`（filter_type） |
| `IsTweakManager` | 顶层 | 布尔 | 缺失 = `false`，可容忍 | 出现且非布尔 → `type_mismatch` |
| `Bundles` | Filter | 字符串数组 | 缺失 = `[]`，可容忍 | 非数组 → `type_mismatch`；元素非字符串 → `type_mismatch`（element 级记录到 `skippedFields`） |
| `Classes` | Filter | 字符串数组 | 缺失 = `[]`，可容忍 | 非数组 / 元素非字符串 → `type_mismatch` |
| `Executables` | Filter | 字符串数组 | 缺失 = `[]`，可容忍 | 非数组 / 元素非字符串 → `type_mismatch` |
| `CoreFoundationVersion` | Filter | 数字数组（长度 1 或 2） | 缺失 = `null`，可容忍 | 非数组 / 元素非数字 → `type_mismatch`；长度非 1/2 记 `skippedFields` 线索 |
| 其他键 | Filter/顶层 | — | — | 记入 `otherKeys`，不判失败 |

### 4.3 Rootless 字段核对规则

| 字段 | 位置 | 期望类型 | 缺失 | 类型不符处置 |
|---|---|---|---|---|
| 根节点 | 顶层 | 字典（Codable 解码前提） | — | 解码失败 → `parse_failed` |
| `Filter` | 顶层 | 字典 | 缺失 → 解码失败（`parse_failed`，filter_missing） | 非字典 → 解码失败 |
| `Bundles` | Filter | `[String]?` | 缺失 = `[]` | 元素非字符串 → 解码失败 |
| `Executables` | Filter | `[String]?` | 缺失 = `[]` | 元素非字符串 → 解码失败 |
| `UnloadAfter` | 顶层 | `Bool?` | 缺失 = `null` | 非布尔 → 解码失败（记录类型证据） |
| `Classes` / `CoreFoundationVersion` / `IsTweakManager` | — | 上游模型未覆盖 | 出现即记入 `otherKeys`，不判失败 | — |
| 取值规范化 | Bundles/Executables | 字符串 | — | 离线解析记录原始值与规范化（lowercased）双份证据；不做运行时命中判断 |

### 4.4 空配置区分

| 情形 | 记录口径 |
|---|---|
| 字段缺失 | `filter.<field>` = `[]`（数组类）/ `null`（版本类），`validation.warnings` 标注 `field_missing` |
| 空数组 | `[]`，标注 `empty_array` |
| 空字典 | `Filter={}`，各规则为空，标注 `empty_filter` |
| 空值元素 | 字符串数组中的空串保留并标注 `empty_element`，不静默剔除 |

## 5. 解析流程

1. 取 S1-05 `pairs[]`；逐条读取对应 plist 的内容信号。
2. 读不到（`access_denied / read_failed`）→ `read_failed`，条目进 `parsed` 但 `filter=null`，同时在 `notParsed` 线索中保留配对身份；不判 `parse_failed`。
3. 读取成功 → 按路线 Adapter 做属性列表解析：非法字节 → `parse_failed`。
4. 结构解析成功 → 按 §4 核对根/Filter/字段类型；全部通过 → `valid`；任一不符 → `type_mismatch`，保留 `skippedFields` 与原始类型证据。
5. 规范化规则数组；记录 `otherKeys`；不做进程命中、不判来源、不判加载。
6. 汇总 `counts`、`warnings`；上游 `missingPlist / orphanPlist / ambiguous / uncertain` 原样进 `notParsed`。

## 6. 异常分类

| 层级 | 情况 | 归类 | 记录口径 |
|---|---|---|---|
| 读取级 | 条目访问受限 / 读取失败 | `read_failed` | `readStatus` 保留原因；不判不存在、不判解析失败 |
| 解析级 | 字节不是合法属性列表（XML 破损 / Binary 损坏 / 空文件） | `parse_failed`，`reason=invalid_plist` | 保留 plist 路径与读取状态 |
| 结构级 | 根节点非字典 | `type_mismatch`，`reason=root_type` | 记录观测类型 |
| 结构级 | `Filter` 缺失 | `type_mismatch`，`reason=filter_missing` | 与字段缺失区分 |
| 结构级 | `Filter` 非字典 | `type_mismatch`，`reason=filter_type` | 记录观测类型 |
| 字段级 | 数组字段非数组 / 元素类型不符 | `type_mismatch`，`reason=field_type` | `skippedFields` 记录键、期望/观测类型 |
| 字段级 | 版本字段非数字数组 | `type_mismatch`，`reason=versions_type` | 记录长度与元素类型 |
| 条目级 | 上游未配对 / 不确定 / 歧义 | `not_parsed` | 保留 S1-05 `pairing` 与原因，不删除 |
| 路线级 | 上游目录未定位 / 清单未枚举 | 未定位 | 空模型，告警 `inventory_unresolved`，禁止回退扫描 |

> 读取失败 ≠ 解析失败 ≠ 插件不存在；`read_failed / parse_failed / type_mismatch / not_parsed` 必须互相区分。

## 7. 状态边界（三层状态不越界）

- `installed`：本项**不产出新结论**；dylib 在位状态沿用 S1-04/S1-05 证据。
- `configured`：仅当 `parseStatus=valid` 才可在 S1-08 映射为 `configured=true`；`parse_failed / type_mismatch / read_failed` 一律不视为已配置。
- `loaded`：本项一律 `unknown`；即使 Filter 合法且规则解析成功，也**禁止**推断已注入/已生效。
- 不判断来源与归属（S1-07）、不做统一模型 JSON 导出（S1-08）、不改写 plist。

## 8. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。

```
Tests/Fixtures/S1-06/
├── parse-xml-valid/        # XML plist，Filter 字典，四类字符串/数字字段合法
├── parse-binary/           # Binary plist 合法样本（合成格式标记）
├── parse-empty-filter/      # Filter 空字典，空配置可容忍
├── parse-missing-filter/    # 无 Filter 键 → type_mismatch (filter_missing)
├── parse-bundles-wrong/     # Bundles 为字符串而非数组 → type_mismatch
├── parse-classes-wrong/     # Classes 元素非字符串 → type_mismatch
├── parse-executables-wrong/ # Executables 非数组 → type_mismatch
├── parse-versions/         # CoreFoundationVersion 数字数组（max / range）合法
├── parse-versions-wrong/    # 版本元素非数字 → type_mismatch
├── parse-multi-rule/        # 多 Bundles/Classes/Executables 全部保留
├── parse-invalid-plist/     # 破损字节 → parse_failed，条目保留
├── parse-partial-corrupt/    # 一损一良：损坏条目失败，兄弟条目正常解析
├── parse-rootless-model/    # Rootless Codable 样本；Classes/CFV 入 otherKeys 不判失败
├── parse-missing-fields/    # 可选字段缺失，合法且与空数组区分
├── route-guard/             # 上游清单未定位，空模型不回退扫描
└── determinism/             # 相同 plist 重复解析，结果一致（合成）
```

每组分离 `environment.json`（解析器输入，含 S1-05 配对快照与 plist 内容信号）与 `metadata.json`（测试预期）；解析器不得读取 metadata。

## 9. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| PARSE-001 | `parse-xml-valid` | XML plist 正常解析，`parseStatus=valid` | 必须通过 |
| PARSE-002 | XML 格式样本 | XML 格式识别为 `xml`，内容按字典解析 | 必须通过 |
| PARSE-003 | `parse-binary` | Binary 格式识别为 `binary`，合法样本解析通过 | 必须通过 |
| PARSE-004 | 根类型异常样本 | 根非字典 → `type_mismatch`（root_type），不崩溃 | 必须通过 |
| PARSE-005 | Filter 类型异常样本 | Filter 非字典 → `type_mismatch`（filter_type） | 必须通过 |
| PARSE-006 | Bundles 异常样本 | Bundles 非字符串数组 → `type_mismatch`，记录期望/观测类型 | 必须通过 |
| PARSE-007 | Classes 异常样本 | Classes 非字符串数组 → `type_mismatch` | 必须通过 |
| PARSE-008 | Executables 异常样本 | Executables 非字符串数组 → `type_mismatch` | 必须通过 |
| PARSE-009 | `parse-versions` / `parse-versions-wrong` | 数字数组合法；非数字数组 → `type_mismatch`（versions_type） | 必须通过 |
| PARSE-010 | 字段类型异常混合样本 | 不符类型按本路线规则归类，`skippedFields` 保留证据 | 必须通过 |
| PARSE-011 | `parse-empty-filter` / `parse-missing-fields` | 缺失字段、空数组、空字典分别标注，不混为一类 | 必须通过 |
| PARSE-012 | `parse-multi-rule` | 多个 Bundles/Classes/Executables 条件全部保留，顺序确定 | 必须通过 |
| PARSE-013 | `parse-invalid-plist` | 非法 plist → `parse_failed`（invalid_plist），条目不删除 | 必须通过 |
| PARSE-014 | `parse-partial-corrupt` | 单条失败不影响兄弟条目；损坏条目进失败归类，良条目 `valid` | 必须通过 |
| PARSE-015 | `parse-rootless-model` | RootHide/Rootless 规则独立；Rootless 未覆盖键入 `otherKeys`，不套严格规则判失败 | 必须通过 |
| PARSE-016 | 相同 plist 重复解析 | 规则数组、归类、计数、`otherKeys` 一致（确定性） | 必须通过 |
| PARSE-017 | S1-01~S1-05 回归 | 前序产物保持通过，未被本项改动 | 必须通过 |

### 9.1 断言要点

- 解析只消费 S1-05 `pairs[]`；未配对条目原样进 `notParsed`，不重新配对。
- 读取失败、解析失败、类型不符、未配对四类原因互斥，计数与清单一致。
- 路线规则不交叉：Rootless 样本不按 RootHide 严格规则判失败，反之亦然。
- 不产出来源/归属结论；`loaded` 一律 `unknown`；不修改 plist 字节。

## 10. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机 plist 实际格式（XML/Binary 混合占比） | 格式识别口径 | 待真机全量 plist 采样 |
| 真机 Filter 字段真实分布与非常规键 | `otherKeys` 覆盖 | 待真机只读采样 |
| RootHide 严格规则与真机既有插件的兼容性 | 误判为无效的风险 | 待真机对照，离线为合成样本 |
| Rootless 真机 Codable 解码失败分布 | 上游兼容口径 | `[Rootless 真机待验证]` |
| 受限 plist 的读取失败表现 | `read_failed` 归类 | 待真机只读探测 |
| 进程内 Filter 命中行为 | 运行层结论 | 本阶段不取证，`loaded=unknown` |

## 11. 通过与失败标准

### 11.1 通过条件

- 仅基于 S1-05 配对关系只读解析；路线 Adapter 规则独立、不交叉；
- `valid / parse_failed / type_mismatch / read_failed / not_parsed` 归类准确，计数互斥一致；
- 缺失字段、空数组、空字典、类型异常分别标注；异常字段保留原始类型与跳过原因；
- 单插件失败不中断整轮；未配对条目保留；未越界判断来源、推断加载或改写设备文件。

### 11.2 失败情形（任一即不通过）

- 把解析失败的插件从发现结果中删除；
- 读取失败被记为解析失败或插件不存在；
- RootHide / Rootless 规则互相套用；
- 类型异常被静默跳过且不留证据，或空配置与缺失字段混为一类；
- 由合法 Filter 推断“已加载/已生效”，或在本项判断来源归属；
- 上游清单未定位仍回退扫描其他路线目录；
- 解析过程回写/修改 plist 或插件文件。

## 12. 设计边界

- S1-06 只产出 Plist/Filter 解析结果；**不做**来源与所有权识别（S1-07）、统一模型 JSON 导出（S1-08）。
- 解析合法 ≠ 插件已配置生效 ≠ 已加载；解析结果不作为 GUI 进程权限证据。
- 本项离线夹具为合成样本；Rootless/Rootful 无真机背书，不把 RootHide 结论推广到其他路线。
- S1-06 离线测试须单独授权后再创建夹具与代码；在此之前不扩展 S1-07，不创建正式工程。
