# Stage-1-CLI-Test-Plan.md — Stage 1 CLI 只读验证任务清单

- 状态：**任务拆解 / 测试计划草案**。本文件只定义工作范围、验收条件与交付物；**不修改 Dev-Preparation 0.1 基线，不编写功能代码，不创建工程，不编译**。
- 关联：[Dev-Preparation-0.1.md](./Dev-Preparation-0.1.md)、[PoC-0.1.0-Specification.md](./PoC-0.1.0-Specification.md)、[Plugin-Data-Model.md](./Plugin-Data-Model.md)、[Architecture.md](./Architecture.md)。
- 载体：Stage 1 为**越狱 shell 上下文运行的 CLI**，复用后续 Core/Models/Adapters；CLI 通过仅代表底层逻辑通过，**不代表 GUI App 权限通过**（见 Dev-Prep §7 Stage 1 边界）。

## 0. 当前进度状态（2026-11-15）

> S1-01 已在**离线夹具**环境执行并通过；仍不提前设计 S1-02。离线通过仅代表底层识别逻辑在合成样本上成立，**不等于 RootHide 真机验证通过**。

| 项目 | 状态 |
|---|---|
| Dev-Preparation-0.1 | 已冻结 |
| Stage-1-CLI-Test-Plan | 已建立 |
| S1-01 子规格 | 已冻结 |
| ENV-001 ~ 015 | 已定义并执行 |
| 六组夹具 | 已落地 `Tests/Fixtures/S1-01/`（离线合成样本） |
| S1-01 测试执行 | **离线 15/15 通过**，报告 `Tests/S1-01/report/S1-01-report.json`，验收记录 `Tests/S1-01/report/S1-01-acceptance.md` |
| S1-02 测试执行 | **离线 18/18 通过**，报告 `Tests/S1-02/report/S1-02-report.json`，验收记录 `Tests/S1-02/report/S1-02-acceptance.md` |
| S1-03 测试执行 | **离线 15/15 通过**，报告 `Tests/S1-03/report/S1-03-report.json`，验收记录 `Tests/S1-03/report/S1-03-acceptance.md` |
| S1-04 测试执行 | **离线 23/23 通过**，报告 `Tests/S1-04/report/S1-04-report.json`，验收记录 `Tests/S1-04/report/S1-04-acceptance.md` |
| S1-05 | **离线验收通过（15/15，Synthetic Fixture Validation Passed）**，已归档 |
| S1-06 | **离线验收通过（22/22，Synthetic Fixture Validation Passed）**，已归档 |
| S1-07 | **离线验收通过（14/14，Synthetic Fixture Validation Passed）**，已归档 |
| S1-08 | **离线验收通过（13/13，Synthetic Fixture Validation Passed）**，已归档；Stage 1 只读 CLI 验证链离线闭环 |
| Stage 2 计划 | `Spec/Stage-2/Stage-2-Implementation-Plan.md` 计划规格已冻结；`Spec/Stage-2/Stage-2.1-Project-Bootstrap.md` 2.1 子规格已冻结 |
| 2.1 骨架 | 离线目录/Models/Adapter/Core 协议/CI 草稿就位（`Tests/Stage2/2.1-bootstrap-acceptance.md`）；编译、启动、CI 待 macOS runner 验证；未迁移完整扫描逻辑、未扫真机、无写入/启停 |
| 2.1-B 准备 | SwiftPM 入口、隔离脚本、CI 任务矩阵、验收模板、边界清单就位；GitHub 未认证无远端，推送与 runner 构建待凭证后执行 |
| 功能代码 | 仅离线 harness（`Tests/S1-01~S1-08/`，非 App 运行时；后续迁移 Core/Adapters/Models） |
| 工程骨架 | 未创建 |
| 编译 | 未进行 |

**S1-01 离线执行记录**：

1. 创建六组离线测试夹具；
2. 校验输入与预期严格分离（识别器不读取 metadata.json）；
3. 执行 ENV-001 ~ 015，15/15 通过；
4. 版本五态与两类冲突覆盖齐全；
5. 生成离线测试报告；
6. 离线验收通过；真机背书待后续 RootHide 真机复核。

## 1. 本计划定位

Stage 1 把 PoC 0.1.0 的只读数据链拆成 8 个可逐段验收的任务，严格顺序 `S1-01 → … → S1-08`。每个任务先定义输入、输出、异常情况与测试样本，通过后再进入下一项；不一开始就实现完整 CLI。

对应 PoC 范围：S1 环境识别 / S2 ElleKit 版本 / S3 JBROOT / S4 目录 / S5 扫描 / S6 配对 / E1 plist 解析 / E2 Filter 展示 / E3 来源识别 / E4 JSON 导出。

## 2. 全局规则

### 2.1 只读约束（CLI 不得做）

- 修改任何 plist / Bundles 规则；
- 创建、删除、移动任何文件；
- 修改插件关联规则或 ElleKit 配置；
- 安装、卸载插件；
- 修改 dpkg 数据库（status / info / list）；
- 修改 DynamicLibraries / TweakInject 软链；
- 执行注入、启停插件、安装常驻 Daemon。

所有文件操作仅限**读取、枚举、校验**。JSON 报告导出为只读产物，不回写设备插件目录。

### 2.2 证据等级（每条结果必须可标注）

| 标签 | 适用 |
|---|---|
| `[源码确认]` | 仅由本地/上游源码核对得出，未在真机运行 |
| `[RootHide 真机验证]` | RootHide 真机 shell 实测通过 |
| `[Rootless 合成样本验证]` | 固定夹具离线验证，非真机 |
| `[Rootless 真机待验证]` | 需 Rootless 真机，当前未验 |
| `[权限待验证]` | 权限/签名/容器访问待真机实测 |

> 离线 RootHide 夹具运行结果属本地构造样本，不得标 `[RootHide 真机验证]`；规则口径本身可标 `[源码确认]`。不能把路径猜测、文件存在或解析成功包装成运行时注入成功。

### 2.3 异常分类（异常不直接算硬失败）

| 情况 | 归类 | 处理 |
|---|---|---|
| 文件不存在 | 未发现 | 记录缺失项，继续扫描 |
| 权限拒绝 | 访问受限 | 标 `[权限待验证]` 类告警，继续扫描 |
| plist 格式错误 | 解析失败 | 记录告警，该插件 `filter=null`，不阻断其他条目 |
| dylib 与 plist 不配对 | 配对异常 | 按配对枚举标注，继续 |
| Mach-O 校验不符 | 单独记录 | 告警隔离，不直接认定整体扫描失败 |
| 未知文件来源 | 未知 | `source=unknown`，只读，不按文件名猜测归属 |
| 运行时加载状态无证据 | `loaded=unknown` | 禁止由在位/配置/Bundles 命中推断已加载 |

### 2.4 状态口径

- 三层状态独立：`installed`（文件在位可读）/ `configured`（配置有效可解析）/ `loaded`（独立运行时证据）；本版 `loaded` 一律 `unknown`。
- 未取到/未验证字段显式 `null` / `unknown`，不留空串冒充已知。
- 未知 Profile 降级只读保守模式，不出现任何写入入口。

## 3. 任务拆解

### S1-01 环境识别

> 子规格：[Stage-1/S1-01-Environment-Detection.md](./Stage-1/S1-01-Environment-Detection.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **子规格已冻结；离线验证通过** |
| 测试用例 | ENV-001 ~ ENV-015（15/15 通过） |
| 夹具规划 | 六组（roothide / rootless / rootful / unknown / incomplete / conflicting），输入与预期严格分离 |
| 版本覆盖 | 五态全部覆盖（`parsed / not_installed / unreadable / unparsable / conflicted`） |
| 冲突覆盖 | 两类冲突（路线信号冲突、实现-版本冲突） |
| 执行状态 | 离线夹具执行完成；harness 位于 `Tests/S1-01/`（`detector.js` / `run.js`），非 App 运行时 |
| 验收状态 | **离线验收通过（Synthetic Fixture Validation Passed）**，15/15；验收记录 `Tests/S1-01/report/S1-01-acceptance.md`；RootHide 真机背书、Rootless 真机兼容待后续验证 |
| 下一步 | S1-01 已正式验收归档；待授权进入 S1-02，当前保持未启动 |

- **验证内容**：识别 RootHide / Rootless（当前真机仅 RootHide）、设备架构、iOS 版本、Bootstrap 组件、ElleKit 实现与版本，映射 Profile。
- **输入（只读）**：设备运行环境、dpkg status 只读读取（ellekit / roothide core / manager / patchloader 版本旁证）。
- **输出交付物**：`Environment JSON`，对应 `JailbreakEnvironment`：
  `jailbreakType`、`architecture`、`iosVersion`、`ellekitImplementation`、`ellekitVersion`、`profileId`、`evidenceLevel`。
- **通过条件**：
  1. RootHide 真机上类型判定为 `roothide`，架构/iOS 版本读出；
  2. ElleKit 实现/版本能由 dpkg 或版本文件取得，取不到显式 `null`；
  3. 版本映射不出时 `profileId=unknown-profile`，走只读降级；
  4. 二手内省/旁证不得标 `verified`。
- **异常**：版本文件缺失 → 用 dpkg 包版本旁证并降级 `partial`；类型无法判定 → `jailbreakType=unknown`。
- **测试样本**：RootHide 真机环境；Rootless 合成环境描述（离线，`[Rootless 合成样本验证]`）。
- **对应**：PoC S1 / S2；模型 §2.1。

**状态区别（不得混用）**：

- 子规格已冻结 ≠ 测试已执行；
- 测试执行通过 ≠ RootHide 真机验证通过；
- Rootless 合成样本通过 ≠ Rootless 真机兼容。

### S1-02 JBROOT 定位

> 子规格：[Stage-1/S1-02-JBROOT-Path-Resolution.md](./Stage-1/S1-02-JBROOT-Path-Resolution.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **子规格已冻结；离线验收通过（Synthetic Fixture Validation Passed，18/18）** |
| 测试用例 | PATH-001 ~ PATH-012（18 例执行） |
| 夹具规划 | 十组（rh-valid / rh-multiple / rh-badname / rh-name-only / rh-unreadable / rh-broken-link / rootless-varjb / rootful-root / no-candidate / realpath-privatevar），输入与预期分离 |
| 核心规则 | `.jbroot-*` 前缀不等于确认 JBROOT；realpath 不等于可读；jbrand 不提前假设语义；多候选冲突不盲目选边 |
| 执行状态 | 离线夹具执行完成；harness 位于 `Tests/S1-02/`（`resolver.js` / `run.js`），非 App 运行时 |
| 验收状态 | **离线验收通过**，验收记录 `Tests/S1-02/report/S1-02-acceptance.md`；真机进程内 `jbroot()`、目录可读、多容器并存等待后续验证 |
| 下一步 | S1-05 已正式验收归档；待授权进入 S1-06，当前保持未启动 |

- **验证内容**：候选路径发现、目录真实性、`.jbroot-*` 命名校验、词法规范化、realpath 解析、候选冲突裁决、jbrand 提取与边界。
- **输入（只读）**：候选 JBROOT 路径、进程内路径解析口径（弱链接 `jbroot()` 或自行发现容器，待只读探测复核）。
- **输出交付物**：`PathResolver 报告`：`jbroot` 绝对路径、`jbrand`、解析来源、`realpath` 结果、候选路径校验记录。
- **通过条件**：
  1. 定位到唯一有效 JBROOT，路径归一不并列两套根；
  2. 记录路径来源（API / 候选发现 / 软链）与证据等级；
  3. 定位失败显式 `jbroot=null`，给出失败原因，不臆造路径。
- **异常**：候选目录不存在 → 未发现；不可读 → 访问受限；符号/解析失败 → 记录并标 `[权限待验证]`。
- **测试样本**：RootHide 真机容器；离线夹具构造 `.jbroot-*` 目录结构。
- **对应**：PoC S3；模型 §2.1 `jbroot/jbrand`。

### S1-03 ElleKit 目录定位

> 子规格：[Stage-1/S1-03-ElleKit-Directory-Resolution.md](./Stage-1/S1-03-ElleKit-Directory-Resolution.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **离线验收通过（15/15 例执行，DIR-001~013 全覆盖）**，已归档 |
| 测试用例 | DIR-001 ~ DIR-013（15 例执行） |
| 夹具 | 十一组已落地 `Tests/Fixtures/S1-03/`，输入与预期分离 |
| 核心规则 | 三路线前缀各自独立；exists/readable/enumerable/realpath 分层；软链五态；RootHide 禁止回退 /var/jb 或 / |
| 报告 / 验收 | `Tests/S1-03/report/S1-03-report.json`、`Tests/S1-03/report/S1-03-acceptance.md` |
| 回归 | S1-01 15/15、S1-02 18/18 保持通过 |
| 下一步 | S1-04（插件枚举）保持未启动，待单独授权 |

- **验证内容**：定位 TweakInject 目录与 DynamicLibraries 软链，确认目录可读/可枚举，记录路径来源与软链目标。
- **输入（只读）**：S1-02 产出的 JBROOT；`jbroot("/usr/lib/TweakInject/")` 口径；`Library/MobileSubstrate/DynamicLibraries` 软链。
- **输出交付物**：`Directory Report`：TweakInject 绝对路径、软链 realpath、可读性/可枚举性、路径来源、异常告警。
- **通过条件**：
  1. TweakInject 目录定位成功并可枚举；
  2. DynamicLibraries 软链目标经 realpath 核对，软链异常单独记录；
  3. 目录不可读/不可枚举时进入 `warnings`，后续任务按受限处理。
- **异常**：目录缺失、软链断链、权限拒绝分别归类（§2.3）。
- **测试样本**：RootHide 真机 TweakInject；离线夹具含正常/断链软链两种。
- **对应**：PoC S4；RootHide Adapter 软链完整性检查。

### S1-04 插件枚举

> 子规格：[Stage-1/S1-04-Plugin-Enumeration.md](./Stage-1/S1-04-Plugin-Enumeration.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **离线验收通过（23/23 例执行，ENUM-001~015 全覆盖）**，已归档 |
| 测试用例 | ENUM-001 ~ ENUM-015（23 例执行） |
| 夹具 | 十三组已落地 `Tests/Fixtures/S1-04/`，输入与预期分离 |
| 核心规则 | 单层非递归 scandir；dylib/plist/目录/软链/其他分类；条目按完整路径保留；访问失败 ≠ 不存在；不推断 installed/configured/loaded |
| 报告 / 验收 | `Tests/S1-04/report/S1-04-report.json`、`Tests/S1-04/report/S1-04-acceptance.md` |
| 回归 | S1-01 15/15、S1-02 18/18、S1-03 15/15 保持通过 |
| 下一步 | S1-05（插件配对）保持未启动，待单独授权 |

- **验证内容**：枚举目录内 dylib 与 plist，记录文件类型、存在性、可读性、是否软链；处理非插件文件与异常条目。
- **输入（只读）**：S1-03 目录路径。
- **输出交付物**：`Plugin Inventory`：条目清单（路径、扩展名、类型、存在性、可读性、软链标记、原始文件记录）。
- **通过条件**：
  1. 仅 `.dylib` 进入插件候选枚举（与 1.2-3 injector 口径一致）；plist 独立列出；
  2. 每个条目记录存在性/可读性，不可读不中断整轮枚举；
  3. 未知扩展名/目录/其他文件归入 `unknownItems`。
- **异常**：目录不可枚举 → 全局告警 + 空清单说明；单条目不可读 → 单独记录。
- **测试样本**：RootHide 真机目录；离线夹具含 dylib/plist/孤儿/坏权限/杂项文件。
- **对应**：PoC S5。

### S1-05 插件配对

> 子规格：[Stage-1/S1-05-Plugin-Pairing.md](./Stage-1/S1-05-Plugin-Pairing.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **离线验收通过（15/15 例执行，PAIR-001~014 全覆盖）**，已归档 |
| 测试用例 | PAIR-001 ~ PAIR-014（15 例执行） |
| 夹具 | 十三组已落地 `Tests/Fixtures/S1-05/`，输入与预期分离 |
| 核心规则 | dylib 驱动派生基名；同目录精确文件名、大小写敏感；paired/missing_plist/orphan_plist/ambiguous/uncertain 互斥；不读 plist 内容、不推断来源与加载状态 |
| 报告 / 验收 | `Tests/S1-05/report/S1-05-report.json`、`Tests/S1-05/report/S1-05-acceptance.md` |
| 回归 | S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23 保持通过 |
| 下一步 | S1-06（plist/Filter 解析）保持未启动，待单独授权 |

- **验证内容**：以 dylib 为主键检查同名 `X.dylib` ↔ `X.plist`，区分完整配对与各类缺失/异常。
- **输入（只读）**：S1-04 清单。
- **输出交付物**：`Pairing Report`：每条 `pairing` = `paired / missing_plist / orphan_plist / missing_dylib`，附两端路径与缺失原因。
- **通过条件**：
  1. 同名配对严格匹配；缺 plist 的 dylib、孤儿 plist 分别标注；
  2. 配对状态与文件层 `installed` 区分，不混为配置状态；
  3. 大小写/同名歧义在报告中显式记录，不做静默回退假设。
- **异常**：配对异常归入 §2.3；坏 plist 仍先完成文件层配对标注，解析留待 S1-06。
- **测试样本**：正常配对、缺 plist、孤儿 plist、缺 dylib 各至少一夹具。
- **对应**：PoC S6；模型 §2.2 `pairing`。

### S1-06 plist 与 Filter 解析

> 子规格：[Stage-1/S1-06-Plist-Filter-Parsing.md](./Stage-1/S1-06-Plist-Filter-Parsing.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **离线验收通过（22/22 例执行，PARSE-001~017 全覆盖）**，已归档 |
| 测试用例 | PARSE-001 ~ PARSE-017（22 例执行） |
| 夹具 | 十六组已落地 `Tests/Fixtures/S1-06/`，输入与预期分离 |
| 核心规则 | 双路线独立 Adapter；RootHide 严格类型核对，Rootless 按 Codable 模型；valid/parse_failed/type_mismatch/read_failed/not_parsed 互斥；解析失败不删除条目；不判来源、`loaded=unknown` |
| 报告 / 验收 | `Tests/S1-06/report/S1-06-report.json`、`Tests/S1-06/report/S1-06-acceptance.md` |
| 回归 | S1-01 15/15、S1-02 18/18、S1-03 15/15、S1-04 23/23、S1-05 15/15 保持通过 |
| 下一步 | S1-07（来源识别）保持未启动，待单独授权 |

- **验证内容**：按路线 Profile 解析顶层字典、`Filter` 字典、`IsTweakManager` 及 Bundles/Classes/Executables/CoreFoundationVersion；类型不符生成告警并保留证据。
- **输入（只读）**：S1-05 已配对 plist 文件（`pairs[]`）；未配对条目原样进 `notParsed`。
- **输出交付物**：`Parsed Plugin Model`：`FilterRule`（bundles/classes/executables/coreFoundationVersion/otherKeys）、`isTweakManager`、`validation`（状态 + 告警 + 跳过字段）。
- **通过条件**：
  1. 字段按路线规则类型校验；类型错误标告警且不当合法配置；
  2. 未知字段记入 `otherKeys`，只读记录不臆测语义；
  3. 解析失败 `filter=null` 并带失败原因；`configured` 按“plist 存在且 Filter 可解析”口径判定；
  4. 读取失败 / 解析失败 / 类型不符 / 未配对四类原因互斥；单条失败不中断整轮。
- **异常**：格式错误/类型错误/缺字段/空配置/未知版本分别记录（§2.3、PoC §6.3）。
- **测试样本**：正常多 App 插件、含 Classes/Executables、版本门槛、坏 plist、类型错误、未知字段、Rootless 模型样本。
- **对应**：PoC E1 / E2；模型 §2.2/§2.3。

### S1-07 来源识别

> 子规格：[Stage-1/S1-07-Plugin-Source-Identification.md](./Stage-1/S1-07-Plugin-Source-Identification.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **离线验收通过（14/14，Synthetic Fixture Validation Passed）**，已归档 |
| 测试用例 | OWN-001 ~ OWN-013 |
| 夹具规划 | 十二组（src-dpkg-owned / src-dpkg-multi-file / src-filterkit-managed / src-manual-import / src-unknown / src-dpkg-conflict / src-mixed-ownership / src-dpkg-unavailable / src-marker-corrupt / src-marker-absent / src-route-guard / determinism），输入与预期分离 |
| 核心规则 | dpkg `.list` 精确路径命中优先；包归属/自管/导入/未知互斥；冲突不选边、混合来源分文件保留；标记损坏不提升归属；来源识别 ≠ 管理授权；`loaded=unknown` |
| 执行状态 | 已执行：14/14 通过，三路线覆盖，mutualLeakCount=0，前序 S1-01~S1-06 回归全 passed |
| 验收状态 | 已归档：`Tests/S1-07/report/S1-07-report.json`、`S1-07-acceptance.md` |
| 下一步 | S1-08（统一模型 / JSON 导出）保持未启动，须单独授权 |

- **验证内容**：识别 dpkg 管理 / FilterKit 自管 / 用户导入 / 未知；优先 dpkg `.list` 精确命中归属包；分文件归属与多包冲突记录。
- **输入（只读）**：S1-06 Parsed Plugin Model 条目路径；dpkg status 与 info `.list`、本地管理标记信号（离线注入）。
- **输出交付物**：`Source Report`：`sourceType`、`ownership`、`packageID/packageVersion/architecture/listPath`、`fileOwnership`、`confidence`、`writablePolicy`、`markers`、`conflicts`。
- **通过条件**：
  1. dpkg `.list` 精确命中 + installed → `exact_record`；无记录且无有效标记 → `unknown`，不按文件名/位置猜测；
  2. 归属与可写策略一致：包管理/未知默认 `read_only`，FilterKit 自管 `managed` 仍受后续门禁约束；
  3. 冲突多包不选边；dylib/plist 混合归属分文件保留；标记损坏降级 unknown；
  4. 本版不做任何安装/卸载/改写判定落地，不产出操作放行结论。
- **异常**：dpkg 数据库不可读 → `dpkg_unavailable` 整体降级 unknown 并告警；`.list` 缺失/标记损坏分别记录（§2.3、PoC §6.3）。
- **测试样本**：单包命中、多包、自管标记、导入标记、无归属无标记、冲突、混合归属、数据库不可读、损坏/缺失标记、路线隔离、确定性。
- **对应**：PoC E3；模型 §2.4 / §4。

### S1-08 统一模型与 JSON 导出

> 子规格：[Stage-1/S1-08-Unified-Model-JSON-Export.md](./Stage-1/S1-08-Unified-Model-JSON-Export.md)。

| 字段 | 内容 |
|---|---|
| 状态 | **离线验收通过（13/13，Synthetic Fixture Validation Passed）**，已归档 |
| 测试用例 | EXPORT-001 ~ EXPORT-013 |
| 夹具规划 | 十组（export-full-roothide / export-rootless / export-partial-failures / export-conflict-mixed / export-dpkg-unavailable / export-unknown-profile / export-missing-upstream / export-evidence-preservation / export-determinism / export-state-separation），输入与预期分离 |
| 核心规则 | 证据不丢失；installed/configured/loaded 三层不互推；来源与权限分离；不确定状态保留；信封版本化且除 generatedAt 外确定性可重复 |
| 执行状态 | 已执行：13/13 通过，RootHide/Rootless 覆盖，前序 S1-01~S1-07 回归全 passed |
| 验收状态 | 已归档：`Tests/S1-08/report/S1-08-report.json`、`S1-08-acceptance.md` |
| 下一步 | Stage 1 离线闭环；正式 App 工程、Core/Models/Adapters 迁移、GUI、权限探针与管理授权设计均须后续独立授权 |

- **验证内容**：汇总环境、插件、Filter、来源、未知项与告警，按数据模型生成统一报告并导出只读 JSON。
- **输入（只读）**：S1-01 ~ S1-07 全部产物快照。
- **输出交付物**：`JSON Report`，对应 Report 信封：`schemaVersion` / `generatorVersion` / `profile` / `generatedAt` / `environment` / `plugins` / `unknownItems` / `warnings`。
- **通过条件**：
  1. 结构符合 [Plugin-Data-Model.md](./Plugin-Data-Model.md) §2.0/§5 草图；
  2. 所有 `loaded=unknown`、`permission.decision=undetermined`；未取到项显式 `null/unknown`；
  3. 异常条目进入 `unknownItems` / `warnings`，报告可完整生成；前序告警/冲突/扩展键/跳过字段不丢失；
  4. 相同输入除时间戳外可重复导出；导出为只读产物，不回写设备。
- **异常**：单插件解析失败不阻断整份报告；全局不可读目录进 `warnings`；上游阶段缺失不反推补齐。
- **测试样本**：汇总前述全部夹具快照；RootHide 真机一轮完整导出待后续真机阶段。
- **对应**：PoC E4；模型 §2.0 / §2.1 / §2.2 / §2.4 / §5。

## 4. Stage 1 验收清单

完成时应能够：

1. 在 RootHide 越狱 shell 环境识别当前环境；
2. 正确定位并验证 ElleKit 插件目录；
3. 枚举并配对插件文件；
4. 解析有效 plist 和 Filter；
5. 对异常文件提供明确诊断；
6. 生成统一数据模型；
7. 导出完整 JSON 报告；
8. 全程不修改越狱环境中的任何文件。

## 5. 明确不验收（Stage 1 边界）

- GUI 权限与特殊 entitlement 放行；
- `jbroot()` 在 **GUI 进程**内的可用性（Stage 2 权限探针负责）；
- 实际注入状态 / 运行时加载取证；
- Rootless 真机兼容性（当前仅离线/合成样本，`[Rootless 真机待验证]`）；
- 任何写入、启停、安装卸载、规则编辑、常驻 Daemon。

## 6. 开发顺序与门禁

- 严格顺序：`S1-01 → S1-02 → S1-03 → S1-04 → S1-05 → S1-06 → S1-07 → S1-08`。
- 每个任务门禁：先定义输入、输出、异常情况、测试样本；任务通过后再进入下一项。
- 任务间产物单向流转：上游报告作为下游输入；下游不得绕过上游结果自行猜测路径。

## 7. 待真机缺口（影响结论背书，不改本计划范围）

| 缺口 | 影响任务 | 现状 |
|---|---|---|
| TweakInject 全量目录列表 | S1-03 / S1-04 / S1-05 | 旧报告枚举不全，待真机全量采集 |
| ≥1 个 plist 原文 | S1-06 | 待真机样本 |
| `.version-roothide` 版本文件原文 | S1-01 | 暂以 dpkg 包版本旁证 |
| dpkg 归属全量 `.list` | S1-07 | 待真机只读核对 |
| pkgmirror 镜像路径性质 | S1-03 / S1-04 | 性质未定，暂列未知项 |
| 进程内路径解析接入方式 | S1-02 | 弱链接 vs 自行发现，待只读探测复核 |

## 8. 与后续阶段衔接

- Stage 1 CLI 验证通过后，Stage 2 建 GUI 工程并复用同一 Core/Models/Adapters，另设独立 PermissionProbe；Stage 1 的 CLI 结果不得作为 GUI 权限证据。
- Rootless Adapter 仅做离线夹具回归，真机验证待设备到位后单独验收，不以 RootHide 结果覆盖。
