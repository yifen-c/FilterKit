# Stage-2-Implementation-Plan.md — Stage 2 正式 App 工程与 GUI 基础实施计划（Spec 0.1 草案）

- 状态：**Stage 2 总体计划规格，设计冻结；仅规划，不写功能代码、不创建 Xcode 工程、不编译、不扫描真机。** 各子阶段进入实现前须单独授权。
- 上游基线：Stage 1 只读 CLI 验证链已离线闭环（135/135，见 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md) 与 `Tests/S1-01~S1-08/`）；架构见 [Architecture.md](../Architecture.md)，数据模型见 [Plugin-Data-Model.md](../Plugin-Data-Model.md)，准备基线见 [Dev-Preparation-0.1.md](../Dev-Preparation-0.1.md)。
- 适用范围：把 Stage 1 已验证的底层只读逻辑安全迁移到正式 iOS App，并在 GUI 进程内独立验证文件访问能力；本计划不包含插件写入、启停、安装/卸载功能。

## 1. 背景与基线结论

### 1.1 Stage 1 已证明的内容

- 环境识别、JBROOT 定位、ElleKit 目录定位、插件枚举、配对、plist/Filter 解析、来源识别、统一模型与 JSON 导出八条逻辑，在离线 fixture 合成样本上通过。
- 双路线 Adapter 隔离、三层状态分离、来源与权限分离、不确定状态保留、导出确定性等口径已固化在 Stage 1 规格与 harness 中。

### 1.2 Stage 1 未证明的内容（Stage 2 不得冒充已通过）

- **GUI 进程文件访问权限**：CLI 运行于越狱 shell 上下文，其可读路径/目录/plist/dpkg 不代表 GUI App 沙盒内具备相同能力。
- **Rootless 真机兼容**：当前仅合成样本覆盖，无 Rootless 真机。
- **真实插件加载行为**：`loaded` 无独立运行时证据，恒 `unknown`。
- **entitlement / 签名链 / sandbox / 容器可读性**：均为 `[权限待验证]`。

> 计数口径：Stage 1 离线用例合计 **135**（15+18+15+23+15+22+14+13），以各阶段 `*-report.json` 为准。

## 2. 冻结架构原则

1. **RootHide 与 Rootless Adapter 永远独立**：路径解析、目录识别、plist 校验、规则解析、配对口径、完整性检查按路线分离；公共层不散落 `if RootHide … else …` 底层判断。
2. **UI、Core、Models 共享**：同一套数据模型、管理核心与界面骨架，不随越狱类型重复开发。
3. **CLI 与 GUI 使用同一套 Core / Models / Adapters**：Stage 1 的 Node harness 是验证载体；迁移后正式 App 复用同一套逻辑，不允许 GUI 另写一套扫描/解析器。
4. **禁止 GUI 私有扫描器**：界面层只调用 Core 服务与 Adapter 契约，不直接拼 ElleKit 路径、不直接读对方路线规则。
5. **未知状态继续保留**：`unknown / partial / ambiguous / conflict / heuristic` 显式表达，不为界面规整强行归类。
6. **loaded 无独立运行时证据即保持 `unknown`**：不由文件在位、plist 合法、Bundles 命中或 dpkg 归属推断已加载。
7. **来源识别与管理授权继续分离**：`ownership.writablePolicy` 不决定 `managementPermission`；管理放行由后续门禁独立评估。

### 2.1 依赖方向

`App(UI/ViewModel) → Core → Models → Adapters`；Adapter 产出路线特有快照，公共模型不出现路线分支字段（对齐 [Architecture.md](../Architecture.md) §7）。

## 3. 目标工程结构（蓝图，本阶段不创建）

```
FilterKit/
├── App/                        # 正式 iOS App
│   ├── Views/                  # Dashboard / Plugins / PluginDetail / Diagnostics（首版只读）
│   ├── ViewModels/             # 界面状态装配，调用 Core，不做底层判断
│   └── PermissionProbe/         # GUI 进程内权限探针（2.4）
├── Core/                       # 共享管理核心（迁移自 Stage 1 逻辑）
│   ├── Environment/
│   ├── PathResolver/
│   ├── PluginScanner/
│   ├── PluginPairing/
│   ├── PlistParser/
│   ├── OwnershipResolver/
│   └── ReportExporter/
├── Adapters/
│   ├── RootHide/
│   └── Rootless/
├── Models/                     # Plugin / App / FilterRule / JailbreakEnvironment / Ownership
├── CLI/                        # Stage 1 只读验证载体（迁移后保留为回归入口）
└── Tests/
    ├── Stage1/                 # 既有离线夹具与 harness 回归基线
    └── Stage2/                 # 迁移后单测 / 探针测试 / 真机验证记录
```

## 4. Stage 1 → Core 迁移映射

| Stage 1 harness（Node，验证载体） | 目标 Core / Adapter 模块 | 迁移口径 |
|---|---|---|
| S1-01 `detector.js` | `Core/Environment` + Adapter 环境识别 | 环境类型、架构、iOS 版本、ElleKit 实现/版本、Profile 识别口径不变 |
| S1-02 `resolver.js` | `Core/PathResolver`（JBROOT） | 候选隔离、命名/结构校验、歧义不选边、jbrand 不补零 |
| S1-03 `resolver.js` | `Core/PathResolver`（ElleKit 目录） | 三路线目录状态、软链状态、回退限制；路线隔离 |
| S1-04 `enumerator.js` | `Core/PluginScanner` | 单层非递归、扩展名口径、排序确定性、软链不跟随、部分失败不阻断 |
| S1-05 `pairing.js` | `Core/PluginPairing` | 同名配对、未配对/孤儿/歧义/不确定分类 |
| S1-06 `parser.js` | `Core/PlistParser` + Adapter Filter 解析 | RootHide 严格校验 / Rootless Codable 双实现差异保留；C injector 仅作兼容风险记录 |
| S1-07 `resolver.js` | `Core/OwnershipResolver` | dpkg 精确命中、冲突不选边、混合分文件、标记损坏降级、来源/权限分离 |
| S1-08 `exporter.js` | `Core/ReportExporter` + `Models` | 信封版本化、证据保留、三层状态分离、除时间戳外确定性导出 |

> 迁移为**行为保持**重构：输出模型、分类口径、告警与不确定状态必须与 Stage 1 夹具预期一致；不得借迁移放宽校验或合并路线规则。

## 5. 子阶段定义

### 5.1 Stage 2.1 — Project Bootstrap

**目标**：建立正式 iOS App 工程骨架与模块边界，接入 Models 与 Core/Adapter 目录约定；不实现扫描业务逻辑。子规格细化见 [Stage-2.1-Project-Bootstrap.md](./Stage-2.1-Project-Bootstrap.md)；App Target 选型/工程生成/模拟器验证方案见 [Stage-2.1-App-Target-Plan.md](./Stage-2.1-App-Target-Plan.md)。

**主要工作**

- Xcode / Theos 工程结构、Bundle ID、Deployment Target、架构（arm64e 主 / arm64 次）配置方案。
- Git 仓库结构与 CI（macos-latest；Node 仅 CI 脚本/打包，不进入 App 运行时）。
- Swift App 入口；Core / Adapters / Models / App / Tests 模块边界与依赖方向落地。
- 接入 Stage 1 数据模型（`Models` 对齐 [Plugin-Data-Model.md](../Plugin-Data-Model.md) §2/§4）。

**依赖**：Stage 1 闭环；Dev-Prep 编译/SDK 基线。

**验收标准**

- 工程可在 CI 配置下完成骨架编译（不要求业务功能）；模块依赖方向符合 §2.1。
- Models 枚举与字段与冻结数据模型一致；无路线分支字段泄漏进公共模型。
- 未引入任何设备写入接口或私有扫描逻辑。

**门禁**：骨架结构与 Models 对齐通过后，才进入 2.2。

### 5.2 Stage 2.2 — Core / Models Migration

**目标**：把 Stage 1 已验证逻辑迁入正式 Core / Adapter / Models，CLI 与 App 共用同一套核心。

**子规格**：[Stage-2.2-Core-Models-Migration.md](./Stage-2.2-Core-Models-Migration.md)（2026-11-16 设计层冻结；Models/协议修改、实现代码、Swift 回归执行均未授权，按五批次单独授权）。

**主要工作**

- 按 §4 映射迁移八个环节；Adapter 双路线独立，Core 共享。
- 复用 Stage 1 夹具作为行为回归基线；迁移后重跑 Stage 1 全部 **135** 项用例，确保行为未变。
- 明确 CLI 入口与 App 入口都调用同一 Core 服务，不复制第二套扫描/解析实现。

**验收标准**

- 迁移后 Core 输出与 Stage 1 模型/分类/告警/不确定状态一致；135 项回归保持通过。
- 双路线规则未被合并；RootHide 严格校验与 Rootless Codable 口径差异仍分别保留。
- 未新增 GUI 专用扫描器；未实现启停/写入。

**门禁**：行为回归全绿后，才进入 2.3 GUI 基础。

### 5.3 Stage 2.3 — GUI Foundation（首版全部只读）

**目标**：建立第一版只读图形界面，展示 Core 产出的环境、插件、规则、归属与诊断信息。

**页面**

| 页面 | 只读功能 |
|---|---|
| Dashboard | 环境类型、ElleKit 实现/版本、Profile、扫描概览与告警 |
| Plugins | 插件列表、搜索、来源/归属标签、三层状态展示 |
| Plugin Detail | dylib/plist 路径、Filter 规则、归属与冲突/混合细节、证据标签 |
| Diagnostics | 验收状态、异常与未知项、JSON 导出（只读快照） |

**验收标准**

- 界面数据全部来自 Core/Models；ViewModel 不做路径拼接或规则判定。
- 未知/冲突/失败状态如实展示，不强行归类；`loaded=unknown`、`permission=undetermined` 原样呈现。
- 页面无启用/禁用/编辑/删除/安装入口；JSON 导出为只读快照，不回写设备。

**门禁**：只读界面与 Core 数据一致后，才进入 2.4 权限探针。

### 5.4 Stage 2.4 — Permission Probe（Stage 2 关键里程碑）

**目标**：在**真实 GUI App 自身进程内**独立验证文件访问能力；结果独立于 CLI，不得用 CLI 结论冒充 GUI 权限。

**探针项（逐项记录成功/失败与 errno/原因）**

1. 进程内自身运行环境识别；
2. JBROOT 定位与可达性；
3. TweakInject 目录访问；
4. dylib / plist 枚举；
5. plist 读取；
6. dpkg 数据库（status / info `.list`）读取；
7. `jbroot()` 符号可用性与路径解析结果；
8. App 冷启动后权限是否保持（非单次挂载残留）。

**附加核对**：entitlement 是否被签名链保留、amfid/ldid 是否放行、sandbox/容器限制、是否需要额外 sandbox 例外（对齐 Dev-Prep §6.3）。

**验收标准**

- 每项探针有 GUI 进程内运行证据；证据标签区分 `[RootHide 真机验证]` / `[权限待验证]`。
- 权限受限项明确记录失败原因，不推断为可读；CLI 通过的项在 GUI 未验证前仍标 `[权限待验证]`。
- 探针为只读探测，不修改设备、不写 dpkg、不改软链。

**硬门禁**：2.4 通过之前，**不设计、不实现插件写入与启停功能**。权限通路未闭合前，管理功能无可靠基础。

### 5.5 Stage 2.5 — Real Device Validation

**目标**：在真实 RootHide 设备上完成一轮完整只读扫描，与 Stage 1 fixture 预期对比。

**核对项**

- 真实路径是否符合预期（JBROOT / TweakInject / 软链目标）；
- 真实插件数量、配对情况与未配对/孤儿/歧义分布；
- plist 格式与解析成功率；
- dpkg 所有权映射与冲突/混合归属；
- 真实 JSON 导出完整性；
- 权限受限时的异常处理是否符合降级口径。

**验收标准**

- 真机结果与模型口径一致；异常条目有明确诊断，不崩溃、不中断整轮。
- Rootless 真机验证**独立标记**，不以 RootHide 结果代替；无设备项继续 `[Rootless 真机待验证]`。

## 6. 接口契约（规划口径，实现时细化）

### 6.1 Adapter 协议（对齐 Architecture §4.1，只读阶段）

```
ElleKitAdapter
  ├── getEnvironment() -> JailbreakEnvironment
  ├── resolvePaths()  -> EnvironmentPaths
  ├── scanPlugins()   -> [PluginCandidate]
  ├── readPlugin(candidate) -> Plugin?
  ├── validatePlugin(plugin) -> ValidationReport
  ├── parseFilter(plugin)    -> FilterRule?
  └── resolvePath(relative)  -> AbsolutePath
```

- 只读阶段不暴露写入接口；预留的 `applyAssociation / setEnabled / installPackage / uninstallPackage` 不在 Stage 2 实现。
- 路线特有字段由 Adapter 产出 Profile 快照，不污染公共 Models。

### 6.2 PermissionProbe 结果模型（规划）

```
PermissionProbeReport
  ├── processContext: { sandboxed, platformApplication, entitlements: [] }
  ├── probes: [ { item, reached: bool, readable: bool, errno?, reason?, evidence: EvidenceTag } ]
  ├── jbroot: { symbolAvailable: bool, resolvedPath: string?, reason? }
  ├── coldStartRetained: bool | unknown
  └── overall: { granted: bool, limitations: [] }
```

> `overall.granted` 仅汇总探针事实，不等于管理授权；管理门禁属后续阶段。

## 7. 迁移与测试策略

- **行为保持**：Stage 1 夹具作为 2.2 回归基线；迁移前后模型输出深比较（除时间戳外）。
- **测试分层**：Core/Adapter 单测复用夹具；ViewModel 测试用注入的 Core 快照；PermissionProbe 与真机验证记录在 `Tests/Stage2/`。
- **证据标签**：沿用 `[源码确认]` / `[RootHide 真机验证]` / `[Rootless 合成样本验证]` / `[Rootless 真机待验证]` / `[权限待验证]`；离线与真机结论不得混标。
- **工具链**：Node 仅用于 CI 脚本与打包；App 运行时为 Swift（必要时 Obj-C/C 对接 libroothide/POSIX/CF）。

## 8. 暂缓功能（Stage 2 不实现、不设计入口）

- 插件启用 / 禁用；
- 修改 Filter plist、自动添加 Bundle ID；
- 删除 dylib、修改软链接；
- 自动安装/卸载插件；
- dpkg 数据库写入；
- 自动修复 ElleKit 配置；
- 常驻 Daemon、自研注入引擎、修改目标 App Bundle / 重签名。

> 上述功能的前提是 2.4 权限通路闭合与后续管理授权门禁定义；在那之前不进入界面与接口设计。

## 9. 风险与待验证项

| 风险 / 缺口 | 影响 | 现状 |
|---|---|---|
| GUI App entitlement / 签名链 / sandbox 放行 | 能否读取隐藏容器与 TweakInject | `[权限待验证]`，2.4 真机探针 |
| 进程内 `jbroot()` 符号与路径解析 | RootHide 路径对接 | `[权限待验证]`，2.4 探针 |
| 16.5 SDK 对 iOS 17.0.2 的链接/运行兼容 | 编译与启动 | Dev-Prep §4.3，待 CI/真机实测 |
| Swift 在 Theos 工程下的工具链配置 | UIKit + Codable 落地 | Dev-Prep §4.4 待确认 |
| Rootless 真机适配 | 第二路线背书 | 无设备，合成样本 + `[Rootless 真机待验证]` |
| 真机全量清单与异常样本 | 2.5 对比基线 | 待真机只读采样 |

## 10. 验收原则（延续 Stage 1）

- **权限不靠推断**：entitlement 存在、安装到 `/Applications`、符号存在、uicache 注册成功，均不代表对应能力已授予。
- **CLI/GUI 同一 Core**：不在 GUI 复制第二套扫描/解析逻辑；权限探针由 GUI 进程自行执行。
- **Rootless 不被 RootHide 覆盖**：RootHide 通过不标记 Rootless 通过。
- **未知即保留**：无证据不归类、不推断、不美化。

## 11. 阶段门禁与授权要求

| 子阶段 | 进入前提 | 授权要求 |
|---|---|---|
| 2.1 Bootstrap | 本计划冻结 | 单独授权后创建工程骨架 |
| 2.2 迁移 | 2.1 骨架与 Models 对齐通过 | 单独授权；135 项回归全绿 |
| 2.3 GUI 基础 | 2.2 行为回归通过 | 单独授权；只读范围 |
| 2.4 权限探针 | 2.3 只读界面可用 | 单独授权；真机证据 |
| 2.5 真机验证 | 2.4 探针结论明确 | 单独授权；RootHide 优先，Rootless 独立 |

- 本计划冻结 **不等于** 任一子阶段已实现；Stage 2 各子阶段仍按“规格/骨架 → 实现 → 回归 → 验收”逐段授权。
- Stage 2 退出条件：只读链在正式 App 内可运行、GUI 进程权限探针结论明确、RootHide 一轮真机只读扫描通过；管理写入功能不在退出范围内。

## 12. 本计划边界

- 产出：工程结构蓝图、模块映射、接口契约、迁移与测试策略、验收门槛、暂缓清单与风险表。
- 不做：Swift/Obj-C 编码、Xcode/Theos 工程创建、编译打包、真机扫描、设备写入、GUI 启停功能设计。
- 后续：各子阶段实现方案与接口细节在对应授权阶段展开；本文件随真机与 CI 实测结论回填修订。
