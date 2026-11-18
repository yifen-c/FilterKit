# Stage 2.2-C3-Engine-C1：S1-06 基线映射测试实施规格（设计冻结，实现待授权）

- 上游依据：`Stage-2.2-C3-Engine-C-Audit.md` 22 项覆盖矩阵；Engine-B 冻结实现（`6bb34f8`）；Stage 1 `Tests/S1-06/` harness 与 `Tests/Fixtures/S1-06/` 夹具。
- 本轮状态：**规格冻结**。本文不落地测试代码、不改生产源码；C1 编码须在独立授权后按本规格执行。
- 计数纪律：22 是 S1-06 行为覆盖数，不与 XCTest 用例数简单相加；同一基线可由多个断言组成，一个测试也可覆盖多个相关断言。报告须分列：XCTest 实际执行数、基线覆盖数、各模块专项数、既有回归数、静态检查数。

## 1. 目标与边界

### 1.1 目标

1. 将 22 项 PARSE 基线逐条映射到 Swift XCTest，经 `PluginFilterParseEngine` 管线（或对应路线 Parser 层）对照 `metadata.json` 期望全维度断言。
2. 验证 RootHide 严格类型、Rootless Codable、Engine 双路线调用与状态传递、五态计数、告警与证据保留。
3. 确保既有 C1/C2/C3-B/C3-C1/C3-C2 行为无回归（回归执行归 Engine-C2，C1 不破坏既有断言）。

### 1.2 禁止项（C1 实现时同样遵守）

- 不为通过测试另造与基线相似的夹具；输入与期望以 `Tests/Fixtures/S1-06/` 原始文件为准。
- 不修改生产 Models / Adapters / 七方法协议 / C1/C2/C3-B/C3-C1/C3-C2 冻结源码；测试层描述类型只存在于测试 target。
- 不把 C1 测试通过记为 C3-C2 Runner 验收；不实现 Engine-C2 完整集成回归。
- 不新增 S1-06 基线条目：22 项不增不减；`read_failed / not_parsed` 在 22 例中无直接样本，沿用 Engine-B 专项覆盖，不在 C1 伪造基线失败用例。
- 不接服务层装配、不实例化 Adapter、不扫真机、不做任何写操作。

## 2. 文件组织（授权后落地）

| 测试源（`Tests/Stage2/`） | 职责 |
|---|---|
| `S106FixtureLoader.swift` | 只读解码 `environment.json / metadata.json`；构造 `PluginPairingSnapshot`、配对记录与 Decoder 桩输入；测试 target 内部，不进 App/Core |
| `FilterParseBaselineCases.swift` | 测试层基线描述模型（见 §3）；22 例描述与夹具/合成来源绑定 |
| `FilterParseBaselineTests.swift` | XCTest 分组 C1-01 ~ C1-09；夹具驱动与合成样本驱动断言 |

- `Package.swift` Stage2Tests sources 追加上述文件；Core  sources 不变。
- 加载范式参照既有 `S105FixtureLoader.swift`：中性 Codable 形态解码、不重扫目录、不改夹具文件。

## 3. 基线描述模型（测试层，不进生产 Models）

```text
ParseBaselineCase
  baselineID: String            // PARSE-001 ~ PARSE-017 展开编号，原样保留
  source: String                // fixture:<kind> 或 synthetic:<name>
  route: String?                // roothide / rootless / nil(unknown)
  base: String?                 // pairingKey 基名；unresolved/isolation 为 nil
  expectedStatus: FilterParseStatus?   // 条目五态；快照级状态另列
  expectedSnapshotStatus: String       // enumerated / partial / unresolved
  expectedFilter: ExpectedRule?        // bundles/classes/executables/CFV；失败态为 nil
  expectedOtherKeys: [String]
  expectedSkippedKeys: [String]       // skippedFields 键名归集（对齐 run.js）
  expectedWarnings: [String]           // 条目级 + 快照级告警 code
  expectedCounts: FilterParseCounts
  syntheticRoot: [String: Any]?        // 合成样本根对象；夹具样本为 nil
```

- 期望规则字段对齐 `filterByBase`：`bundles / classes / executables`；CFV 单独断言 `mode/min/max`。
- `otherKeysByBase / skippedFieldsByBase` 以 base 归集，键名集合比较（对齐 `run.js` 第 60~71 行）。

## 4. 输入构造与管线接入

### 4.1 夹具驱动

1. Loader 读 `environment.json`：`upstream`（route/sourceDirectory/inventoryStatus）、`pairing.pairs`（base/dylibPath/plistPath/pairing）、`plists`（plistPath/format/readStatus/payloadInvalid/root）。
2. 构造 `PluginPairingSnapshot`：records 由 pairs 映射（paired 记录带 dylib/plist 证据），unknownItems 为空，counts/warnings 按上游透传。
3. 管线注入复用 Engine-B 桩范式：
   - `StubReader`：`readStatus=ok` 返回合成 Data；`payloadInvalid=true` 或 readStatus 非 ok 时按基线返回失败态。
   - `StubDecoder`：`payloadInvalid=false` 返回 `PlistDecodedObject(rootObject: root, format: env.format)`；`payloadInvalid=true` 返回 `parseFailed`。
   - 路线 Parser 用真实 `RootHideFilterParser / RootlessFilterParser`；隔离/计数断言可用 `FilterParsing` 桩（与 Engine-B 一致）。
4. 不读真实文件系统；env 中的路径仅作证据透传断言，不参与读取。

### 4.2 合成样本驱动

五组合成样本在测试内按 `run.js buildSyntheticCases` 同口径构造：

| 基线 | 合成根 / 输入 | 断言 |
|---|---|---|
| PARSE-004 root-type | 根 `"not-a-dict"`（非字典） | `type_mismatch` / `root_type`；skipped `(root)` |
| PARSE-005 filter-type | `{Filter: [1,2]}` | `type_mismatch` / `filter_type`；skipped `Filter` |
| PARSE-010 mixed-type | `{Filter: {Bundles: "not-array", Classes: [123]}}` | `type_mismatch` / `field_type`；skipped 同时含 `Bundles` 与 `Classes` |
| PARSE-016 determinism | 同 `parse-determinism` 根重复解析两次 | 快照深比较一致（规则/归类/计数/otherKeys/skippedFields） |
| PARSE-012 route-isolation | `sourceDirectory=null`、unresolved 上游 | 空结果；`/var/jb` 路径零泄漏；下游调用全 0 |

## 5. 断言维度（对齐 `run.js compareResult`）

每个夹具用例逐项核对，不只断言状态：

1. **快照级**：`route`、`sourceDirectory`、`status`（enumerated/partial/unresolved）、`counts` 五桶、快照 `warnings` 去重集合。
2. **条目级（statusByBase）**：按 base 取结果，断言五态与顶层 `reason`。
3. **规则级（filterByBase）**：`bundles / classes / executables` 逐数组相等；CFV `mode/min/max`；失败态 `filter == nil`。
4. **otherKeys（otherKeysByBase）**：去重排序后集合相等；Rootless 三项 `Classes / CoreFoundationVersion / IsTweakManager`；`UnloadAfter` 不入 otherKeys。
5. **错误证据（skippedFieldsByBase）**：键名归集相等；元素级证据保留 `index / expectedType / observedType`；RootHide 与 Rootless 失败语义不互套。
6. **不可变**：上游快照执行前后深比较相等；Parser 不改写输入根；上游 unknownItems 原样保留。
7. **路线隔离**：RootHide 输入不调 Rootless Parser，反之亦然；未知路线两 Parser 调用均 0；失败不跨路线重试。

### 5.1 五态语义红线（断言时强制）

- RootHide 类型不匹配 → `type_mismatch`，不得记 `parse_failed`。
- Rootless Codable 解码失败 → `parse_failed`，不得擅自改 `type_mismatch`。
- Reader 失败 → `read_failed`，不得误报 `parse_failed`。
- 非 paired / 未知路线 → `not_parsed` 归集，不得误报 `read_failed`。
- `valid` 不推断 `loaded`；`not_parsed` 不计入失败桶。

## 6. 测试分组与基线映射

| 组 | 内容 | 覆盖基线（矩阵 #） |
|---|---|---|
| C1-01 | RootHide 正常 plist 解析 | #15 PARSE-001、#16 PARSE-002、#1 PARSE-003、#4 PARSE-016、#10 PARSE-012、#13 PARSE-009(range) |
| C1-02 | RootHide 根字典 / Filter 结构 | #18 PARSE-004 root-type、#19 PARSE-005 filter-type、#9 PARSE-005 missing-filter |
| C1-03 | RootHide 严格类型检查 | #2 PARSE-006、#3 PARSE-007、#6 PARSE-008、#20 PARSE-010 mixed、#14 PARSE-009 versions-wrong |
| C1-04 | RootHide CoreFoundationVersion | #13 range 1500-1700、#14 versions_type（与 C1-03 交叉断言 CFV 证据） |
| C1-05 | RootHide 空配置与异常字段 | #5 PARSE-011 empty、#8 PARSE-011 sparse、#7 PARSE-013 invalid_plist、#11 PARSE-014 partial-corrupt |
| C1-06 | Rootless Codable 正常解析 | #12 PARSE-015（依赖 C-G2 出证，见 §7） |
| C1-07 | Rootless 类型与解码失败 | 22 例无 Rootless 失败样本；复用 C3-C2 既有 22 例专项，C1 不新造基线 |
| C1-08 | 双路线 otherKeys 与字段映射 | #12 Rootless otherKeys 三项；#4/#10/#15 otherKeys 空集合 |
| C1-09 | 五态结果与错误证据 | 全五态口径核对；`read_failed / not_parsed` 样本由 Engine-B 专项覆盖，C1 不补基线条目 |

## 7. 依赖挂起与验收衔接

- **PARSE-015（#12）**：测试可随 C1 落地，但验收结论挂起，直到 C3-C2 Runner（#151 / C-G2）通过；C1 通过不替代该门禁。
- **Engine-B 行为**：C1 快照级状态/计数/隔离断言依赖 Engine-B 实现；Engine-B Runner（C-G1）未出证前，C1 结果仅作本地静态与离线桩核对，不记集成通过。
- **Engine-C2**：22 项映射完成后，进入完整集成回归（既有全量回归 + App Build + 隔离检查），按 `Stage-2.2-C3-Engine-C2-Regression-Plan.md` 执行。

## 8. 待 C1 实现时复核的细节

- 夹具 `metadata.json` 缺省字段（`otherKeysByBase / skippedFieldsByBase` 为空对象）按空集合断言，不得省略为不检查。
- `parse-partial-corrupt` 双记录：Good/Bad 分别归集到 `parsed`，counts valid=1、parse_failed=1，快照 `partial`，告警含 `invalid_plist` 与 `partial_parsing`。
- 重复样本 PARSE-001/002 与 PARSE-016 两次解析：计数不重复累加，深比较一致。
- 合成 route-isolation 只断言空结果、零泄漏、零调用；不构造未知路线 paired 条目归集样本（归 Engine-B 专项）。
