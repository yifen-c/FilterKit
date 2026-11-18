# S1-05 Plugin Pairing — 插件配对子规格

- 状态：**Stage 1 子规格，设计冻结，等待离线测试授权**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-05，不进入 S1-06（plist/Filter 解析）；**本轮仅规格设计与用例拆解，不写代码、不建实际夹具、不建正式工程、不编译**。
- 前置：S1-01~S1-04 均已离线验收归档；本项输入为 S1-04 Plugin Inventory。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.2。
- 运行上下文：Stage 1 CLI / 越狱 shell 只读探测；**配对成功 ≠ 插件有效 ≠ 已安装/已配置/已加载 ≠ Adapter 兼容 ≠ GUI 进程有权限**。

## 1. 测试目标

依据 S1-04 清单中的 dylib 与 plist 条目，按文件名建立候选配对关系，产出 Pairing Report，供 S1-06 解析、S1-07 来源识别使用。

- 只做**文件名级配对判断**；不读取 plist 内容、不校验 Filter 字典、不判断来源、不推断加载状态。
- 配对关系不确定时保留 `uncertain`，不强行选边；单条目异常不中断整轮配对。

### 1.1 源码配对语义（源码确认）

| 项 | 口径 | 源码依据 |
|---|---|---|
| 派生方式 | dylib 全路径剥离 6 字符（`.dylib`）得基名，再拼 `.plist` | `roothide-ellekit-src/injector/injector.c:389,90`；`ellekit-src/injector/injector.c:272,74` |
| 存在性判断 | `access(plist, F_OK)` 判文件存在；可解析性属后续环节 | `injector.c:101` |
| 大小写 | C 字符串 `strcmp` / 路径拼接，**大小写敏感**；`Example.dylib` 不匹配 `example.plist` | `injector.c:29-32,90` |
| 配对方向 | dylib 驱动：每个 dylib 查找其派生 plist；无 dylib 对应的 plist 为孤儿 | `injector.c:380-406` |
| 多候选 | 源码无“多个 plist 候选择优”逻辑；同目录基名唯一 | `injector.c:389` |

> 本规格的配对是**离线候选关系**，用于组织文件；与 injector 运行时是否实际注入无关。

## 2. 输入模型（只读）

| 输入 | 来源 | 说明 |
|---|---|---|
| S1-04 Plugin Inventory | 上游产物 | `route`、`sourceDirectory`、`items[]`（dylib/plist/目录/软链/其他）、`entryStatus` |
| 条目信号 | 路径、文件名、扩展名、`isSymlink`、`readable`、`entryStatus` | 离线夹具以信号模拟，不访问真实文件系统 |

> 只消费 S1-04 已枚举条目；本项不重新扫描目录、不补列缺失条目。

## 3. 输出模型（Pairing Report）

```json
{
  "route": "roothide",
  "sourceDirectory": "<jbroot>/usr/lib/TweakInject/",
  "pairs": [
    {
      "base": "Example",
      "dylibPath": "<dir>/Example.dylib",
      "plistPath": "<dir>/Example.plist",
      "pairing": "paired",
      "dylibIsSymlink": false,
      "plistIsSymlink": false,
      "status": "ok"
    }
  ],
  "missingPlist": [
    { "base": "Unmatched", "dylibPath": "<dir>/Unmatched.dylib", "pairing": "missing_plist", "dylibIsSymlink": false }
  ],
  "orphanPlist": [
    { "plistPath": "<dir>/Orphan.plist", "pairing": "orphan_plist", "reason": "missing_dylib" }
  ],
  "ambiguous": [
    { "base": "Case", "candidates": ["<dir>/Case.plist", "<dir>/case.plist"] }
  ],
  "uncertain": [
    { "path": "<dir>/Locked.dylib", "reason": "access_denied" }
  ],
  "counts": { "paired": 1, "missing_plist": 1, "orphan_plist": 1, "ambiguous": 0, "uncertain": 0 },
  "warnings": []
}
```

字段口径（对齐 [Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.2）：

| 字段 | 含义 / 未知口径 |
|---|---|
| `pairs[].pairing` | `paired`：同目录同名基名 dylib + plist 均在清单 |
| `missingPlist[].pairing` | `missing_plist`：dylib 在、派生 plist 不在 |
| `orphanPlist[].pairing` | `orphan_plist`：plist 在、无对应 dylib；`reason=missing_dylib` |
| `ambiguous[]` | 同一基名出现多个候选 plist（如大小写变体），不盲目选择 |
| `uncertain[]` | 条目访问/元数据受限，配对关系不能确定，保留原因 |
| `dylibIsSymlink / plistIsSymlink` | 记录条目软链身份；软链不改变配对方向 |
| `counts` | 各状态计数；`pairs` 与 `missingPlist`/`orphanPlist`/`ambiguous`/`uncertain` 互斥归类 |

## 4. 配对规则

### 4.1 基名派生与匹配

1. 仅取 S1-04 清单中 `kind=dylib` 与 `kind=plist` 的条目；目录、软链以外的其他类型不参与配对。
2. dylib 基名 = 文件名去掉末尾精确后缀 `.dylib`（6 字符，大小写敏感）；派生 plist 名 = 基名 + `.plist`。
3. 在**同一 `sourceDirectory`** 内按文件名精确匹配（大小写敏感）；跨目录同名不配对、不合并。
4. 匹配成功 → `paired`；dylib 无对应 plist → `missing_plist`；未被任何 dylib 匹配的 plist → `orphan_plist`。
5. 条目以完整路径为身份键；基名仅用于配对，不作为去重键。

### 4.2 软链、隐藏文件与扩展名

- **软链**：`isSymlink=true` 的 dylib/plist 仍按文件名参与配对，同时记录软链身份；软链目标不重复入清单（沿用 S1-04 口径）。断链/受限软链的配对结果进 `uncertain`，不判 `paired`。
- **隐藏文件**：点开头条目按同一基名规则参与配对（如 `.hidden.dylib` ↔ `.hidden.plist`），保留 `hidden` 标记，不静默排除。
- **非标准扩展名**：`other`/`directory` 条目不进入配对候选；`.DYLIB`/`.Dylib` 等大小写变体不归类为 dylib（沿用 S1-04 口径），不参与 dylib 配对。

### 4.3 重复候选与部分失败

- 同一基名匹配到多个 plist 候选（同一清单内同名 plist 出现多条记录，或跨路径重复条目）→ `ambiguous`，列出全部候选路径，不任选其一。大小写变体（`Case.plist` / `case.plist`）按大小写敏感规则互不为候选，分别归 `missing_plist` / `orphan_plist`。
- dylib/plist 条目 `entryStatus` 为 `access_denied / metadata_unavailable / read_failed` → 配对关系记 `uncertain`，不据此判 `missing_plist` 或 `orphan_plist`。
- 单个条目异常不中断整轮；其余条目正常归类。

### 4.4 状态边界（三层状态不越界）

- `installed`：本项**不产出**；配对成功不推出 dylib 在位可读已确认。
- `configured`：本项**不产出**；plist 在清单不等于 Filter 可解析。
- `loaded`：本项一律 `unknown`；禁止由配对成功推断已加载。
- 不判断插件来源（S1-07）、不解析 Filter（S1-06）。

## 5. 路线隔离红线

- 配对输入只能来自 S1-04 清单与 `sourceDirectory`；上游目录未定位/枚举失败时，本项产出空报告并保留上游原因，**禁止**自行扫描 `/var/jb`、`/` 或其他路线目录。
- Rootless/Rootful 样本结论不互相套用；跨目录同名条目不合并。
- S1-04 清单中受限/未知条目不被补全或猜测配对。

## 6. 异常分类

| 层级 | 情况 | 归类 | 记录口径 |
|---|---|---|---|
| 目录级 | 上游目录未定位/枚举失败 | 未定位 | 空报告，告警 `inventory_unresolved`，保留上游原因 |
| 配对级 | dylib 无 plist | 缺 plist | `missing_plist`，记录 dylib 路径 |
| 配对级 | plist 无 dylib | 孤儿 plist | `orphan_plist`，`reason=missing_dylib` |
| 配对级 | 多候选无法裁决 | 歧义 | `ambiguous`，列出候选，不选边 |
| 条目级 | 条目访问/元数据受限 | 不确定 | `uncertain`，保留 `entryStatus` 原因 |
| 条目级 | 软链断链/目标受限 | 不确定 | 进 `uncertain`，软链状态字段独立记录 |

> 文件访问失败 ≠ 文件不存在；`uncertain` 与 `missing_plist/orphan_plist` 必须区分。

## 7. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。

```
Tests/Fixtures/S1-05/
├── pair-valid/            # 同名 dylib+plist 正常配对
├── pair-multi/            # 多组配对混合
├── pair-missing-plist/    # dylib 无 plist
├── pair-orphan-plist/     # plist 无 dylib
├── pair-case-mismatch/    # 大小写差异，不配对
├── pair-cross-path/       # 跨目录同名，不合并（合成守卫）
├── pair-hidden/           # 隐藏文件配对
├── pair-symlink/          # 软链条目参与配对并记录身份
├── pair-other-ext/        # 非标准扩展名排除
├── pair-duplicate/        # 同基名多候选 → ambiguous
├── pair-access-denied/    # 条目受限 → uncertain
├── route-guard/           # 上游清单未定位，禁止回退扫描
└── determinism/           # 相同输入重复配对结果一致（合成）
```

每组分离 `environment.json`（配对器输入，含 S1-04 清单快照）与 `metadata.json`（测试预期）；配对器不得读取 metadata。

## 8. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| PAIR-001 | `pair-valid` | `Example.dylib` ↔ `Example.plist` 记 `paired` | 必须通过 |
| PAIR-002 | `pair-missing-plist` | dylib 单独记 `missing_plist`，不造 plist | 必须通过 |
| PAIR-003 | `pair-orphan-plist` | plist 单独记 `orphan_plist`，`reason=missing_dylib` | 必须通过 |
| PAIR-004 | `pair-multi` | 多组 dylib/plist 关系分别正确建立，计数一致 | 必须通过 |
| PAIR-005 | `pair-case-mismatch` | `Example.dylib` 与 `example.plist` 不配对，分记 `missing_plist`/`orphan_plist` | 必须通过 |
| PAIR-006 | `pair-cross-path` | 跨目录同名不配对、不合并，路径分别保留 | 必须通过 |
| PAIR-007 | `pair-hidden` | `.hidden.dylib` ↔ `.hidden.plist` 按规则配对，保留隐藏标记 | 必须通过 |
| PAIR-008 | `pair-symlink` | 软链条目按文件名参与配对，软链身份独立记录；断链进 `uncertain` | 必须通过 |
| PAIR-009 | `pair-other-ext` | `.deb/.txt` 等不进入配对候选 | 必须通过 |
| PAIR-010 | `pair-duplicate` | 同基名多候选记 `ambiguous`，不盲目选择 | 必须通过 |
| PAIR-011 | `pair-access-denied` | 受限条目进 `uncertain`，不判缺失/孤儿 | 必须通过 |
| PAIR-012 | `route-guard` | 只用 S1-04 清单；上游未定位时空报告，不回退扫描 | 必须通过 |
| PAIR-013 | 相同清单重复配对 | 配对关系、归类、计数确定一致（确定性） | 必须通过 |
| PAIR-014 | S1-01~S1-04 回归 | 前序产物保持通过，未被本项改动 | 必须通过 |

### 8.1 断言要点

- 配对键为“同目录 + 精确文件名（大小写敏感）”；禁止大小写不敏感匹配。
- 配对方向 dylib 驱动；孤儿 plist 与缺 plist 的 dylib 分别归类。
- 不读取 plist 内容，不产出 `installed/configured/loaded`、来源或 Filter 结论。

## 9. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 真机 dylib/plist 实际命名与派生一致性 | 配对命中率 | 待真机全量清单复核 |
| 软链 dylib/plist 在真机的配对表现 | 软链归类 | 待真机观察 |
| 大小写变体、多候选真实分布 | `ambiguous` 场景 | 待真机，离线为合成样本 |
| Rootless 真机配对 | 其余路线背书 | 当前仅合成样本，`[Rootless 真机待验证]` |
| 受限条目在真机的可访问性 | `uncertain` 归类 | 待真机只读探测 |

## 10. 通过与失败标准

### 10.1 通过条件

- 仅基于 S1-04 清单配对；同目录、精确文件名、大小写敏感；
- `paired / missing_plist / orphan_plist / ambiguous / uncertain` 归类准确，计数互斥一致；
- 跨目录同名不合并；多候选不选边；受限条目保留不确定；
- 未越界解析 plist、判断来源或推断加载状态；全程只读。

### 10.2 失败情形（任一即不通过）

- 大小写不敏感匹配，或跨目录合并同名条目；
- 访问受限被记为缺失 plist / 孤儿 plist；
- 多候选时任选其一；
- 读取 plist 内容或产出 Filter/来源/加载结论；
- 上游清单未定位仍回退扫描其他路线目录；
- 配对成功被表述为“已安装/已配置/已加载”。

## 11. 设计边界

- S1-05 只产出文件配对关系；**不做** plist/Filter 解析（S1-06）、来源识别（S1-07）、统一模型导出（S1-08）。
- 配对成功 ≠ 插件有效 ≠ 配对正确可注入；CLI 配对结果不作为 GUI 进程权限证据。
- 本项离线夹具为合成样本；Rootless/Rootful 无真机背书，不把 RootHide 结论推广到其他路线。
- S1-05 离线测试须单独授权后再创建夹具与代码；在此之前不扩展 S1-06，不创建正式工程。
