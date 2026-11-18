# Architecture.md — FilterKit 整体软件架构（Spec 0.1 草案）

- 状态：**技术规格冻结阶段草案**；本文件定模块边界、职责与接口契约。**尚未落地功能代码、未编译、未创建源码目录。**
- 上游基线：[`Research/Architecture/FilterKit-Two-Route-Architecture.md`](../Research/Architecture/FilterKit-Two-Route-Architecture.md)；证据溯源见 [`Research/R&D 0.2/`](../Research/R&D%200.2/)。
- 适用范围：RootHide 优先，Rootless 预留；两条路线在第一版不得产生难以拆分的耦合。

## 1. 架构立场

FilterKit 是**一个**多越狱环境插件管理平台：

- **统一产品**：同一套 UI、数据模型、管理核心。
- **共享管理核心（Core）**：产品层能力不随越狱类型重复开发。
- **两条独立 Adapter 路线**：Rootless / RootHide 各自负责自己的 ElleKit 实现、路径解析、规则解析与行为兼容。
- **版本 Profile 层**：在越狱类型之上识别 ElleKit 实现与版本，映射到具体 Profile，不把"RootHide"等同于某个固定行为。

## 2. 顶层分层

```
┌──────────────────────────────────────────────┐
│ UI（共享）  PluginList / Detail / AppAssociation / Settings │
├──────────────────────────────────────────────┤
│ Core（共享）  PluginManager / PluginDatabase / AppDiscovery / PluginState │
├──────────────────────────────────────────────┤
│ Models  Plugin / App / FilterRule / JailbreakEnvironment / Ownership │
├──────────────────────────────────────────────┤
│ Adapter 层  ElleKitAdapter 抽象               │
│   ├── RootlessAdapter（上游 ElleKit / /var/jb）│
│   └── RootHideAdapter（roothide/ellekit / jbroot()）│
└──────────────────────────────────────────────┘
```

依赖方向：`UI → Core → Models → Adapter`；UI 与 Core **不**直接拼 ElleKit 路径、不直接解析对方路线的规则。

## 3. 模块职责

### 3.1 Core（共享）

| 模块 | 职责 | 不负责 |
|---|---|---|
| PluginManager | 插件编排：扫描汇总、关联/启停/卸载的流程编排（写入受阶段门禁） | 不实现某路线的路径与规则细节 |
| PluginDatabase | 插件信息、来源、状态、归属的存储与查询 | 不直接读设备文件（经 Adapter） |
| AppDiscovery | 已安装 App 枚举、Bundle ID / 可执行名提取与展示 | 不做命中判定（判定走 Adapter/规则模型） |
| PluginState | 三层状态（文件 / 关联 / 运行）建模与一致性判定 | 不把 plist 存在当成已加载 |

### 3.2 Models（共享，见 [Plugin-Data-Model.md](./Plugin-Data-Model.md)）

跨路线通用的实体与 JSON 结构；路线特有字段放在 Adapter 产出的 Profile 快照中，不污染公共模型。

### 3.3 Adapter（分路线）

| 能力 | RootlessAdapter | RootHideAdapter |
|---|---|---|
| 环境识别 | 上游 rootless 环境探测 | `.jbroot-<jbrand>` 容器、`/var/jb` 软链归一 |
| 路径解析 | `/var/jb` 前缀 | `jbroot()` 路径翻译（接入方式待真机复核） |
| 目录识别 | 上游 TweakInject 定位 | RootHide TweakInject 定位 |
| 规则解析 | 上游 Filter 语义 | 严格类型校验 + RootHide Filter 语义 |
| 配对/扫描 | 上游同名配对 | 1.2-3 严格同名配对 |
| 完整性核对 | 上游口径 | DynamicLibraries 软链只读核对 |
| 安全模式 | 上游 Safe Mode | RootHide Safe Mode（`.eksafemode` 仅 UI 进程） |

## 4. Adapter 抽象接口（契约）

### 4.1 PoC 只读阶段接口

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

- 所有方法在只读阶段不得产生设备写入。
- `validatePlugin` / `parseFilter` 的口径由各自 Profile 决定，公共层只接收结果与告警。

### 4.2 PoC 0.1.0 完整只读数据链

0.1.0 不是单纯目录扫描器，而是一条完整只读分析链（只读，无任何系统修改能力）：

```
环境识别 → ElleKit 识别 → 插件目录扫描 → dylib/plist 配对
        → plist 解析 → Filter 规则解析 → 来源识别 → 统一数据模型 → JSON 导出
```

- 链路上每一步由对应模块/Adapter 产出模型记录；异常条目记录告警后继续，不中断整体扫描。
- 详细范围、验收与禁止项见 [PoC-0.1.0-Specification.md](./PoC-0.1.0-Specification.md)。

### 4.3 预留写入接口（后续阶段，本版不实现）

```
    ├── applyAssociation(...)      # 0.6.0 关联/启停
    ├── setEnabled(...)
    ├── installPackage(...)        # 0.7.0 安装/卸载
    └── uninstallPackage(...)
```

> 写入接口出现前，Adapter 不暴露任何"改文件"能力；来源所有权策略见 [PoC-0.1.0-Specification.md §5](./PoC-0.1.0-Specification.md)。

## 5. Profile 识别链

```
Jailbreak Type → ElleKit Implementation → ElleKit Version → Adapter Profile → 规则口径
```

| 环境 | Profile |
|---|---|
| Rootless + 上游 1.x | `UpstreamProfile` |
| Rootless + 其他分支 | 独立 Profile（新增，不改核心） |
| RootHide + 1.2-3 | `RootHideProfile_1_2_3` |
| RootHide + 后续版本 | 新 Profile |

- Profile 封装：路径规则、校验口径、匹配语义、加载顺序模型、安全模式判定、完整性检查项。
- **未知 / 识别失败 Profile**：降级只读保守模式，仅展示文件/配置层信息，禁止写入并标注"规则语义未确认"。

## 6. 目标工程目录（蓝图，暂不创建）

```
FilterKit/
├── Core/        PluginManager / PluginDatabase / AppDiscovery / PluginState
├── Adapters/
│   ├── Rootless/  RootlessDetector / RootlessPathResolver / UpstreamElleKit / RootlessFilterParser
│   └── RootHide/  RootHideDetector / RootHidePathResolver / RootHideElleKit / RootHideFilterParser / RootHideIntegrityChecker
├── Models/      Plugin / App / FilterRule / JailbreakEnvironment / Ownership
└── UI/         PluginList / PluginDetail / AppAssociation / Settings
```

## 7. 共享与分离边界

**共享（不感知越狱类型）**：列表/详情/搜索、App 列表、Bundle ID 识别展示、关联与启停界面、JSON 模型、来源归类框架、三层状态展示。

**必须分离**：路径解析、目录识别、plist 校验、规则解析、加载顺序建模、安全模式判定、完整性检查。

## 8. 非目标与反模式

- ❌ 在 Core / UI 散落 `if RootHide { … } else { … }` 底层判断。
- ❌ 用同一套 Filter 解析器靠改路径兼容两条路线。
- ❌ 把越狱类型直接等同于 ElleKit 行为，跳过实现/版本识别。
- ❌ 为快速双环境支持，把路径/规则/校验差异压进公共层。
- ❌ 未知 Profile 默认放开写入。
- ❌ 修改目标 App Bundle、重签名、自研注入引擎、常驻 Daemon。

## 9. 证据溯源

| 架构关注点 | 依据 |
|---|---|
| RootHide 路径走 `jbroot()` | `R&D 0.2/Path-Resolution.md` |
| 匹配/校验/加载/安全模式/软链自检差异 | `R&D 0.2/Upstream-vs-RootHide.md` D1–D15 |
| 进程内扫描、无缓存、冷启动生效、无常驻 daemon | `R&D 0.2/Injection-Lifecycle.md` |
| plist 字段与严格类型口径 | `R&D 0.2/Filter-Rules.md` |
| 加载批次与上限 | `R&D 0.2/Plugin-Loading-Order.md` |
| 引导层 JBROOT / spawn 挂钩 / dpkg 环境 | `R&D 0.2/Dopamine-Roothide-Bootstrap.md` |

## 10. 当前状态

- Spec 0.1 已冻结；0.1.0 范围 = 完整只读扫描 + 解析 + 分析 + 导出（S1–S6 + E1–E4）。
- **未开始功能编码、未编译、未创建上述源码目录。**
- 下一里程碑 0.1.0：RootHide 完整只读链验收优先，Rootless 基础识别分别验收。
