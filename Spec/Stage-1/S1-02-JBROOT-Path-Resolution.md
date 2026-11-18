# S1-02 JBROOT Path Resolution — JBROOT 路径定位子规格

- 状态：**Stage 1 子规格已冻结；离线夹具验证已执行并通过（18/18）**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-02，不进入 S1-03（ElleKit 目录定位）；离线 harness 位于 `Tests/S1-02/`，属测试工具链，非 App 运行时，解析逻辑后续迁移 Core/Adapters；不创建正式工程，不编译。
- 前置：S1-01 环境识别已离线验收归档（15/15，`Tests/S1-01/`）；本项输入以上游环境识别结果为参考，但路径定位不反向替代环境识别。
- 关联：[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.1 `jbroot/jbrand`、[Research/R&D 0.2/Path-Resolution.md](../../Research/R&D%200.2/Path-Resolution.md)、[Dev-Preparation-0.1.md](../Dev-Preparation-0.1.md)。
- 运行上下文：Stage 1 CLI / 越狱 shell 只读探测；**路径定位成功 ≠ 目录可读 ≠ Adapter 兼容 ≠ GUI 进程有权限**。

## 1. 测试目标

在 S1-01 识别出的环境基础上，定位唯一有效的 JBROOT 根目录，输出规范绝对路径、jbrand 标识、候选来源与校验记录，供 S1-03 定位 TweakInject 目录使用。

- 只做**发现、校验、规范化、解析、记录**；不读取插件内容、不枚举插件目录（S1-03/S1-04）、不激活 Profile。
- 定位失败时显式 `jbroot=null` 并给出失败原因，不臆造路径、不并列两套根。

### 1.1 三个不可混淆的技术判断

1. **`.jbroot-*` 不等于已确认 JBROOT。** 目录名前缀只命中候选；必须叠加命名校验、目录真实存在、内部结构旁证与可读信号共同确认。
2. **realpath 不等于路径权限验证。** 符号链接解析到规范路径成功，只说明路径可被解析，不代表后续目录一定可读/可枚举；可读性须单独探测并单独记录。
3. **jbrand 不提前假设语义。** jbrand 取自容器名后缀，其编码规则可由源码确认；其是否等同设备标识、是否跨重装保持等语义，须以源码与真机证据为准，不凭名称推断。

## 2. 输入模型（只读）

| 输入 | 来源 | 说明 |
|---|---|---|
| S1-01 环境结果 | 上游产物 | `jailbreakType` / `ellekitImplementation` 等，作为路线参考；不作为路径本身的证据 |
| 进程内路径 API | libroothide `jbroot("/")` / `__roothideinit_JBROOT` | 候选来源 A；第三方 App 进程内可用性待真机验证 |
| 父目录扫描 | `/var/containers/Bundle/Application` 下的 `.jbroot-*` 条目 | 候选来源 B；复刻 `is_jbroot_name` 校验 |
| 旁路根候选 | `/var/jb`（rootless）、`/`（rootful） | 路线区分用，**不得**当作 RootHide JBROOT |
| 引导库旁证 | `<root>/usr/lib/roothideinit.dylib` 在位 | 结构旁证信号之一 |
| 文件系统探测 | stat / realpath / 目录可列性（只读） | 校验阶段使用，不修改任何文件 |

> 输入信号结构沿用 S1-01 的 `{ value, present, readability, source, raw }` 口径；离线夹具中所有信号 `source=fixture`。

## 3. 输出模型（PathResolver 报告）

对齐数据模型 §2.1 `jbroot` / `jbrand`，并附候选与校验记录：

```json
{
  "jbroot": { "value": "/var/containers/Bundle/Application/.jbroot-<JBRAND>", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "candidate:scan" },
  "jbrand": { "value": "9C414BB7D5DCECC4", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "candidate:scan" },
  "realpath": "/private/var/containers/Bundle/Application/.jbroot-<JBRAND>",
  "resolution": { "strategy": "single_valid", "ambiguous": false, "tieBreak": null },
  "candidates": [
    {
      "root": "/var/containers/Bundle/Application/.jbroot-<JBRAND>",
      "source": "scan",
      "nameValid": true,
      "exists": true,
      "structureMatch": true,
      "readable": true,
      "realpath": "/private/var/...",
      "status": "confirmed",
      "warnings": []
    }
  ],
  "warnings": []
}
```

字段口径：

| 字段 | 取值 / 未知口径 |
|---|---|
| `jbroot.value` | 规范绝对路径；未定位 = `null` |
| `jbrand.value` | 16 位大写 hex；非 RootHide / 校验失败 = `null` |
| `realpath` | 符号链接解析后的规范绝对路径；解析失败 = `null` |
| `candidates[].nameValid` | 容器名是否通过命名校验（§5） |
| `candidates[].exists` | stat 是否为真实目录；不存在 = `false` |
| `candidates[].structureMatch` | 是否含预期内部标记（弱旁证，不单独定案） |
| `candidates[].readable` | 是否可列/可读；与 `exists`、`realpath` 独立记录 |
| `resolution.ambiguous` | 多有效候选无法裁决 = `true`，此时 `jbroot=null` |
| `status` | `confirmed / partial / unverified / unknown`；二手内省不得标 `confirmed` |

## 4. 候选路径发现规则（PATH-001）

按来源依次收集候选，**只收集不选定**：

| 优先级 | 来源 | 候选形态 | 路线归属 |
|---|---|---|---|
| A | 进程内 libroothide `jbroot("/")` / 全局 `__roothideinit_JBROOT` | 进程内已解析根 | RootHide（可用性待真机） |
| B | 扫描 `JB_ROOT_PARENT = /var/containers/Bundle/Application`，匹配 `.jbroot-` 前缀条目 | 隐藏容器目录 | RootHide |
| C | 引导库旁证：由 `usr/lib/roothideinit.dylib` 所在目录回推根 | 容器目录 | RootHide |
| D | `/var/jb` | rootless 根 | Rootless，非 RootHide |
| E | `/` | rootful 根 | Rootful，非 RootHide |

规则：

- 候选记录其 `source` 与原始形态；发现阶段不做符号链接解析。
- 来源 A 仅在符号存在且调用未返回空时纳入；缺失时降级到 B/C，不假设进程内构造器已运行。
- `/var/jb` 与 `/` 只用于路线对照，禁止填入 RootHide `jbroot`。

## 5. RootHide 容器名识别（PATH-003）

源码确认口径（`libroothide-src/common.h`、`common.c:17-34`、`init.c:34-49`）：

- 前缀 `JB_ROOT_PREFIX = ".jbroot-"`；父目录 `JB_ROOT_PARENT = /var/containers/Bundle/Application`。
- 容器名 = 前缀 + `JB_RAND_LENGTH`（uint64 的 16 位 hex）字符。
- `is_jbroot_name()` 校验：长度匹配 → 前缀匹配 → 后缀可解析为 16 位 hex → 校验位通过（`is_jbrand_value`：高位各字节异或等于最低字节）。
- jbrand 由后缀解析为 uint64，格式化为 `%016llX` 大写 16 位 hex。

识别分层：

| 层级 | 含义 | 是否足以定案 |
|---|---|---|
| 前缀命中 | 名字以 `.jbroot-` 开头 | 否，仅候选 |
| 命名合法 `nameValid` | 长度/hex/校验位通过 | 否，仍需存在与结构旁证 |
| 目录存在 `exists` | stat 为真实目录 | 否，需结构/可读信号 |
| 结构旁证 `structureMatch` | 含 `usr/lib/`、`basebin/` 或引导库 | 弱旁证 |
| 可读 `readable` | 目录可列/可读 | 确认信号之一，不等于兼容 |

> 仅前缀或仅命名合法不得输出为确认 JBROOT。

## 6. 路径规范化（PATH-004，词法层，不访问文件系统）

在不触发 FS 调用的前提下做词法规范化：

- 折叠重复分隔符 `/`；
- 解析词法 `.` 与 `..`（超出根目录时停在根，不越界）；
- 去除结尾斜杠（根目录除外）；
- 相对路径基于基准目录拼接后再规范化；
- 规范化结果仍是词法路径，**不代表已存在或可解析**。

词法规范化与 realpath 分离：前者纯字符串处理，后者需要 FS 访问与符号链接解析。

## 7. realpath 处理（PATH-005）

- 对候选根做规范路径解析，解析符号链接（含 iOS 上 `/var` → `/private/var` 的映射；真机旁证：旧报告中 JBROOT realpath 为 `/private/var/containers/Bundle/Application/.jbroot-...`）。
- 解析结果写入 `realpath`；解析错误按 §9 分类记录。
- **realpath 成功只表示路径可解析**：不写入 `readable=true`，不推断目录内容可读。
- 不通过 realpath 结果反推候选路线归属。

## 8. 候选冲突裁决（PATH-006）

- 收集到多个 `nameValid && exists` 候选时，不盲目取第一个或取字典序最小者。
- 裁决信号优先级：进程内 API 来源 A > 结构旁证完整 > 可读可列；仍无法唯一裁决时，`resolution.ambiguous=true`，`jbroot=null`，输出全部候选与分歧原因。
- 跨路线候选（RootHide 容器与 `/var/jb` 并存）按 S1-01 路线信号处理；路线冲突时不强行选边，沿用 S1-01 冲突口径。

## 9. 异常分类（PATH-007）

对齐计划 §2.3，路径定位异常独立归类，不直接算整轮硬失败：

| 情况 | 归类 | 记录口径 |
|---|---|---|
| 候选路径不存在（ENOENT / ENOTDIR） | 未发现 | `exists=false`，继续评估其他候选 |
| 存在但不可读/不可列（EACCES / EPERM） | 访问受限 | `readable=false`，告警 `access_limited`，状态 `partial/unverified` |
| 符号链接环 / 断链（ELOOP / 目标缺失） | 解析失败 | `realpath=null`，告警 `symlink_resolve_failed` |
| 路径超长（ENAMETOOLONG） | 解析失败 | 记录长度与告警，不截断猜测 |
| 多个有效候选无法裁决 | 候选冲突 | `ambiguous=true`，`jbroot=null` |
| 无任何候选 | 未定位 | `jbroot=null`，告警 `no_jbroot_candidate` |

## 10. jbrand 语义边界（PATH-008）

- **可由源码确认**：jbrand 是容器名后缀解析出的 16 位 hex 随机品牌值，带校验位；标准化 JBROOT 为 `<JB_ROOT_PARENT>/<JB_ROOT_PREFIX><JBRAND>`。
- **不得提前假设**：
  - 不把 jbrand 等同设备 UDID / 序列号 / 硬件标识；
  - 不假设其在重装、恢复、切换 Bootstrap 后保持不变；
  - 不从 jbrand 反推设备型号、iOS 版本或越狱版本。
- 命名校验失败时 `jbrand=null`，不输出截断或补零的猜测值。
- 更深语义列入 §13 真机待验证。

## 11. 结果输出（PATH-009）

- 唯一有效候选：输出 `jbroot` / `jbrand` / `realpath` 与命中候选记录。
- 受限/部分：输出已定位根 + `readable=false` 与告警，状态 `partial`。
- 冲突/未定位：`jbroot=null`，保留候选列表与失败原因，供下游按受限处理。
- 每条结果带证据对象 `{ value, status, evidenceType, evidenceSource }`；离线夹具统一 `evidenceType=fixture`。

## 12. 离线夹具规划（数据草案，本轮不落文件）

> 仅定义数据结构与样例；实际夹具文件须待离线测试授权后再创建。目录规划（对齐 S1-01 布局）：

```
Tests/Fixtures/S1-02/
├── rh-valid/          # 合法容器名 + 存在 + 结构旁证 + 可读 → 唯一定位
├── rh-multiple/      # 两个合法命名候选 → 冲突，不盲目选取
├── rh-badname/       # 前缀命中但 hex/校验位非法 → 命名无效
├── rh-name-only/     # 命名合法但目录不存在 → 拒绝
├── rh-unreadable/    # 存在但不可读 → 访问受限，partial
├── rh-broken-link/   # 候选为断链/链接环 → realpath 失败
├── rootless-varjb/   # /var/jb 候选 → 路线区分，非 RootHide JBROOT
├── rootful-root/     # / 候选 → rootful，非 RootHide
├── no-candidate/     # 无任何候选 → jbroot=null
└── realpath-privatevar/ # /var 前缀经 realpath → /private/var 规范路径
```

每组仍分离 `environment.json`（识别器/解析器输入）与 `metadata.json`（测试预期）；解析器不得读取 metadata。

## 13. 测试用例与断言

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| PATH-001 | 多来源候选收集（API / 扫描 / 旁路根） | 候选按来源记录，发现阶段不选定 | 必须通过 |
| PATH-002 | 候选目录真实性检查 | 不存在者 `exists=false`，真实目录 `exists=true` | 必须通过 |
| PATH-003 | `.jbroot-*` 命名合法与非法两组 | 合法通过校验；非法前缀/hex/校验位被拒 | 必须通过 |
| PATH-004 | 含 `.`、`..`、重复分隔符、尾斜杠的路径 | 词法规范化正确，不越界到根之上 | 必须通过 |
| PATH-005 | 符号链接与 `/var`→`/private/var` 映射 | realpath 输出规范路径；失败归类解析失败 | 必须通过 |
| PATH-006 | 多个有效候选并存 | 不盲目选取；无法裁决则 `ambiguous=true`、`jbroot=null` | 必须通过 |
| PATH-007 | 不存在 / 不可读 / 断链 / 超长 / 无候选 | 分别归入 §9 对应异常类，不崩溃、不臆造 | 必须通过 |
| PATH-008 | 合法与非法 jbrand 两组 | 合法输出 16 位大写 hex；非法 `jbrand=null`；不推断语义 | 必须通过 |
| PATH-009 | 各形态输出 PathResolver 报告 | 字段齐全、证据可追溯、未知项显式 null/unknown | 必须通过 |
| PATH-010 | `/var/jb`、`/` 候选 | 路线正确区分，不写入 RootHide `jbroot` | 必须通过 |
| PATH-011 | 相同候选重复解析 | 结果确定，路径与 jbrand 不产生随机变化（确定性） | 必须通过 |
| PATH-012 | metadata 与 environment 输入不一致 | 测试框架报错，不影响解析器判断 | 必须通过 |

### 13.1 断言要点

- 唯一候选必须同时有：命名合法 + 目录存在 + 结构/可读旁证；缺一不得标 `confirmed`。
- `realpath` 与 `readable` 必须独立记录，禁止由 realpath 成功推出可读。
- 冲突态保留全部候选；未定位态 `jbroot=null` 并带原因。
- RootHide 规则不得套用到 rootless / rootful 候选。

## 14. 真机待验证清单（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| 第三方 App 进程内 `jbroot()` / `__roothideinit_JBROOT` 是否可取 | 候选来源 A 可行性 | 旧报告有运行时旁证，新工程需只读复核 |
| 沙盒是否允许遍历 `/var/containers/Bundle/Application` | 候选来源 B 可行性 | 待真机只读探测 |
| JBROOT 目录可读/可列权限 | `readable` 判定 | 待真机；离线不得标可读 |
| 真机是否会出现多个容器并存 | 冲突裁决场景 | 待真机观察 |
| jbrand 跨重装/恢复/Bootstrap 切换的稳定性与语义 | jbrand 语义解释 | 待源码 + 真机确认 |
| `/var` ↔ `/private/var` realpath 在目标 iOS 版本稳定性 | realpath 口径 | 旧报告旁证，待复核 |
| `pkgmirror` 路径性质（软链 / 镜像 / 是否在注入链路） | 旁路路径排除 | 待真机，暂列未知项（跨 S1-03/S1-04） |

## 15. 通过与失败标准

### 15.1 通过条件

- 唯一有效候选能定位到规范绝对路径，并记录来源、jbrand、realpath 与校验记录；
- 冲突、受限、未定位、解析失败均按 §9 正确归类，不臆造路径；
- 词法规范化与 realpath 分离，realpath 不被当作权限证据；
- jbrand 仅按源码口径解析，不做语义外推；
- 候选收集与裁决全程只读，不修改设备文件；
- 相同输入结果确定；报告结构稳定、证据可追溯。

### 15.2 失败情形（任一即不通过）

- 未通过存在性/结构校验即把候选标为确认 JBROOT；
- 由 realpath 成功推断目录可读；
- 多有效候选时盲目选边或并列两套根；
- 将 `/var/jb` 或 `/` 当作 RootHide JBROOT；
- 对 jbrand 做设备标识/稳定性等未证实假设；
- 定位失败仍输出猜测路径或截断 jbrand。

## 16. 设计边界

- S1-02 只定位 JBROOT 根与 jbrand；**不做** TweakInject/DynamicLibraries 目录定位（S1-03）、不枚举插件（S1-04）、不解析 plist、不激活 Profile。
- 定位成功 ≠ 目录可访问 ≠ Adapter 完整兼容；CLI 定位结果不作为 GUI 进程权限证据。
- 本项离线夹具为合成样本；Rootless/Rootful 无真机背书，不把 RootHide 结论推广到其他路线。
- S1-02 离线测试须单独授权后再创建夹具与代码；在此之前不扩展 S1-03，不创建正式工程。

## 17. 离线执行记录（2026-11-15）

- 结论：**Synthetic Fixture Validation Passed（离线验收通过）**；正式验收记录 `Tests/S1-02/report/S1-02-acceptance.md`。
- 产物：十组夹具 `Tests/Fixtures/S1-02/<kind>/{environment.json, metadata.json}`；`Tests/S1-02/resolver.js`；`Tests/S1-02/run.js`；报告 `Tests/S1-02/report/S1-02-report.json`。
- 结果：PATH-001 ~ PATH-012 共 18 例执行全部通过；五种候选来源 `api / scan / bootstrap / rootless / rootful` 全覆盖；跨路线越界 0 例。
- 口径限制：全部为离线 fixture 合成样本；**不构成 RootHide 真机验证**，不代表目录可读或 GUI 有权限；harness 为离线测试实现，后续随工程落地迁移至 Core/Adapters。
- 待真机缺口见 §14；S1-03 尚未展开，须授权后进入。
