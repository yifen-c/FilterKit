# Stage-2.1-Project-Bootstrap.md — Stage 2.1 工程引导子规格（Spec 0.1 草案）

- 状态：**2.1 子规格设计冻结；仅规划，不创建 Xcode/Theos 工程、不写 Swift/Obj-C、不编译、不扫描真机。** 工程创建与骨架实现须单独授权。
- 上游：[Stage-2-Implementation-Plan.md](./Stage-2-Implementation-Plan.md) §5.1；架构 [Architecture.md](../Architecture.md)；模型 [Plugin-Data-Model.md](../Plugin-Data-Model.md)；编译基线 [Dev-Preparation-0.1.md](../Dev-Preparation-0.1.md) §3/§4。
- 范围：把 2.1 要落地的工程结构、模块边界、构建与 CI 规划、Models 对齐门槛、Adapter 隔离要求和权限预留口径定清楚；版本类取值不在本轮臆测，由 CI 构建与真机实测回填。

## 1. 阶段定位与边界

### 1.1 本阶段要回答的问题

1. 正式 App 工程的目录与模块如何划分；
2. 各模块对外接口形态与依赖方向；
3. 构建环境（CI、SDK、Swift、Target、Theos 角色、RootHide 依赖接入）如何规划；
4. UI 技术选型（SwiftUI / UIKit）的评估依据；
5. Bundle ID 与 Deployment Target 的决策流程；
6. Models 如何与 Stage 1 JSON Schema 对齐；
7. 双 Adapter 隔离在工程层面如何保证；
8. 签名与权限预留到什么程度（结论留待 2.4）。

### 1.2 边界（本轮不做）

- 不创建工程文件（`.xcodeproj` / `Makefile` / `control` 等）；
- 不写 Swift / Obj-C / C 功能代码；
- 不配置真实签名、不安装 entitlement、不打包 IPA/deb；
- 不编译、不跑真机、不做文件访问验证；
- 不设计插件写入、启停、安装/卸载入口。

> **2.1 规格细化 ≠ 2.1 工程创建授权。** 本文件冻结后，工程创建是下一次单独授权的工作。

## 2. 工程目录结构（蓝图）

沿用 [Architecture.md §6](../Architecture.md) 与 Stage 2 计划 §3，细化到模块级目录：

```
FilterKit/
├── App/                        # 正式 iOS App 入口与界面层（共享，不感知越狱类型）
│   ├── FilterKitApp.swift      # 应用入口（组合根：装配 Core / Adapter / ViewModel）
│   ├── Views/                  # Dashboard / Plugins / PluginDetail / Diagnostics
│   ├── ViewModels/             # 界面状态装配，调用 Core，不做底层判断
│   └── PermissionProbe/         # 2.4 GUI 进程内权限探针（2.1 仅预留目录与接口轮廓）
├── Core/                       # 共享管理核心
│   ├── Environment/           # 环境识别编排（调用 Adapter getEnvironment）
│   ├── PathResolver/           # JBROOT / ElleKit 目录 / 路径归一编排
│   ├── PluginScanner/          # 目录枚举、配对编排
│   ├── PluginPairing/          # dylib ↔ plist 配对与未配对分类
│   ├── PlistParser/            # plist 读取与类型校验编排
│   ├── OwnershipResolver/      # dpkg / 自管 / 导入 / unknown 归属编排
│   └── ReportExporter/         # 统一模型映射与 JSON 导出
├── Adapters/
│   ├── RootHide/               # RootHideDetector / PathResolver / ElleKit / FilterParser / IntegrityChecker
│   └── Rootless/               # RootlessDetector / PathResolver / UpstreamElleKit / FilterParser
├── Models/                     # Plugin / App / FilterRule / JailbreakEnvironment / Ownership / 报告信封
├── CLI/                        # Stage 1 只读验证载体（迁移后保留为回归入口，复用 Core/Models/Adapters）
└── Tests/
    ├── Stage1/                 # 既有离线夹具与 harness 回归基线（迁移后重跑 135 项）
    └── Stage2/                 # 迁移后单测、探针测试、真机验证记录
```

### 2.1 模块职责边界

| 模块 | 职责 | 禁止 |
|---|---|---|
| App/Views | 展示 Core/Models 产出的状态与告警 | 不拼路径、不判路线、不读设备文件 |
| App/ViewModels | 把模型装配成界面状态；转发用户只读操作 | 不实现扫描/解析/归属逻辑 |
| Core | 编排 Adapter 调用、聚合模型、维护三层状态 | 不写路线特有规则；不散落路线分支判断 |
| Models | 跨路线公共实体、枚举、Codable 结构 | 不放路线特有分支字段 |
| Adapters/RootHide | RootHide 路径/目录/校验/规则/完整性口径 | 不复用 Rootless 规则代码 |
| Adapters/Rootless | Rootless 上游口径；Swift Codable 为准，C injector 仅记兼容风险 | 不把双实现合并成宽松规则 |

## 3. 模块接口设计（规划契约）

### 3.1 依赖方向

`App → Core → Models → Adapters`；App 与 Core 不直接拼接 ElleKit 路径、不直接解析对方路线规则（对齐 [Architecture.md §2](../Architecture.md)）。

### 3.2 Adapter 协议（只读阶段，沿用冻结契约）

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

- 路线选择由 Profile 识别结果决定；Core 只持有 `ElleKitAdapter` 协议引用，不持有具体路线类型。
- 未识别 / 识别失败 Profile：降级只读保守模式，**不执行扫描**，仅展示文件/配置层信息并标注"规则语义未确认"。
- 预留写入接口（`applyAssociation / setEnabled / installPackage / uninstallPackage`）在 2.1 不声明实现，仅在架构文档中保留位置。

### 3.3 Core 服务轮廓（规划，实现细节在 2.2 冻结）

| Core 服务 | 输入 | 输出 |
|---|---|---|
| EnvironmentService | Adapter 实例 | `JailbreakEnvironment` |
| PathResolutionService | 环境快照 | `EnvironmentPaths`（含证据与告警） |
| PluginScanService | 路径快照 | `[PluginCandidate]` + 未配对/孤儿/歧义记录 |
| PluginParseService | 候选插件 | `Plugin`（含 Filter、Validation） |
| OwnershipService | 插件文件集合 | `Ownership` + 冲突/混合/损坏细节 |
| ReportExportService | 聚合结果 | 报告信封（`schemaVersion` 等，见 §7） |

### 3.4 组合根

- `FilterKitApp` 作为唯一装配点：按环境/Profile 选择 Adapter，注入 Core 服务与 ViewModel。
- ViewModel 不自行 new Adapter；便于测试时注入夹具 Adapter。

## 4. 构建环境规划

### 4.1 已冻结基线（来自 Dev-Prep §4）

- CI：GitHub Actions，Runner `macos-latest`；Node 仅用于 CI 脚本/打包，**不进入 App 运行时**。
- Theos 分两套：RootHide `roothide/theos @ 958fea4`，scheme `roothide`，`arm64e arm64`，定义 `THEOS_PACKAGE_SCHEME_ROOTHIDE=1`；Rootless 上游 theos，scheme `rootless`，`arm64`。
- 共用 SDK：`theos/sdks @ 0222fd54`，patched iPhoneOS 9.3~16.5，**无 17.x SDK**。

### 4.2 待 CI / 实测定值项（本轮不猜版本）

| 项 | 决策依据 | 现状 |
|---|---|---|
| Xcode 版本 | Runner 可用工具链与 SDK 兼容 | 待 CI 构建记录 |
| Swift 版本 | 所选 Xcode 工具链；Codable / UI 框架要求 | 待 CI 构建记录 |
| iOS Deployment Target | 设备 iOS 17.0.2；官方 Manager MinOS 15.0 可参照；UI 框架最低版本约束 | 见 §6.2 决策流程 |
| Theos 在本工程的角色 | 仅打包/链接，还是承担工程骨架；Swift 在 Theos 下的工具链配置（`vendor/swift-support`） | 待 2.1 工程创建阶段验证 |
| RootHide 专用依赖接入 | libroothide 弱链接、rpath `@loader_path/.jbroot/usr/lib`、跳过 `-lroot` 口径 | 参照旧 PoC 与 Dev-Prep §4.2，待工程验证 |
| arm64e 切片在 16.5 SDK + iOS 17 链接/加载表现 | 真机与链接记录 | `[权限待验证]` 旁的工具链风险 |

### 4.3 构建分层规划

1. **骨架构建**：空 App + 模块边界 + Models Codable，先在 CI 完成可重复构建；
2. **依赖接入**：再接入 RootHide 弱链接与路线依赖；
3. **回归构建**：2.2 迁移后纳入 Stage 1 夹具回归。

> 工具链任一项不成立时，记录失败原因与回退路径；不在规格阶段假定其必然可用。

## 5. UI 技术选型（SwiftUI / UIKit）

### 5.1 倾向与理由

附件倾向 **SwiftUI**：Dashboard 概览、插件列表搜索/筛选、详情分组展示、JSON 报告展示都较易实现。但选型须先过兼容性门槛，不在本轮直接冻结。

### 5.2 评估维度

| 维度 | 核对点 |
|---|---|
| 最低 iOS 版本 | SwiftUI 可用版本与选定 Deployment Target 是否兼容；旧版本缺失能力是否有 UIKit 兜底 |
| 目标设备 | iPhone16,2 / iOS 17.0.2；arm64e |
| 界面复杂度 | 首版四页均为只读展示，无复杂手势/自定义渲染需求 |
| 工具链 | SwiftUI 在 Theos / 所选工具链下的可用性 |
| 互操作 | 若部分页面需 UIKit 容器，SwiftUI↔UIKit 混编成本 |

### 5.3 决策口径

- 选型在 2.1 工程创建阶段，结合 CI 可编译性与 Target 兼容性冻结；
- 若 SwiftUI 工具链或 Target 不满足，回退 UIKit；Models/Core 不随 UI 选型改变；
- 首版界面全部只读，选型不影响 §7 模型对齐要求。

## 6. Bundle ID 与 Deployment Target 决策流程

### 6.1 Bundle ID

- 决策流程：确定反向域名前缀 → 结合产品名定 Bundle ID → 与后续 Bootstrap 安装路径（`JBROOT/Applications`）、entitlement 标识核对；
- 本轮**不填具体值**；需在工程创建阶段确认命名规范与是否需要与旧 PoC 区分。

### 6.2 Deployment Target

决策顺序：

1. 已知设备：iOS 17.0.2（iPhone16,2，arm64e）；
2. 参照官方 RootHide Manager `MinimumOSVersion 15.0`；
3. 受所选 UI 框架最低版本、SDK 覆盖范围（最高 16.5 SDK，向下兼容到 17 设备待实测）约束；
4. 在"设备实际版本 / 框架最低版本 / SDK 兼容实测"三者取交集后定值；
5. 定值记录进工程配置与本规格回填，标注依据与证据标签。

> 不假设 16.5 SDK 对 iOS 17 链接/运行必然兼容；该项列入 §10 待确认清单。

## 7. Models 对齐硬门槛

### 7.1 对齐要求

正式 App 的 Models 必须与 Stage 1 输出 JSON Schema 对齐；**不得因 GUI 展示需要擅自修改字段语义、枚举取值或三层状态口径**。

### 7.2 必须对齐的结构（来自 [Plugin-Data-Model.md](../Plugin-Data-Model.md)）

**报告信封**：`schemaVersion`、`generatedAt`、`environment`、`plugins`、`unknownItems`、`warnings`。

**枚举（取值不得增删改义）**：

```
SourceType      = dpkg_sileo | filterkit | manual | unknown
OwnershipStatus = owned_package | filterkit_managed | manual_import | unknown
LoadCategory    = manager | oldabi | tweak | unknown
LoadedState     = unknown | loaded | not_loaded
EvidenceLevel   = verified | partial | unverified
WritablePolicy  = read_only | managed | confirmed_managed | forbidden
```

**核心实体**：`JailbreakEnvironment`、`Plugin`、`FilterRule`、`Ownership` 字段与可空口径按模型文档 §2.1~§2.4 落地；未取到显式 `null` / `unknown`，不留空串冒充已知。

### 7.3 对齐校验

- Models 与 Stage 1 fixture 导出 JSON 做 Codable 往返与字段深比较（除 `generatedAt` 外稳定）；
- 路线特有信息（如 RootHide 完整性核对结果）放 Adapter 扩展快照，不进公共模型；
- 迁移后 135 项 Stage 1 回归作为模型行为不变的基线（2.2 执行，2.1 先留好校验位置）。

## 8. 双 Adapter 隔离工程要求

1. `Adapters/RootHide` 与 `Adapters/Rootless` 为独立模块/目录，互不引用对方规则代码；
2. UI 不判断越狱类型；Core 通过统一 `ElleKitAdapter` 协议调用；
3. 同一解析器不得靠改路径兼容两条路线；
4. 未识别 Profile 不执行扫描，按保守只读模式处理；
5. RootHide 严格类型校验、Rootless Codable 为准（C injector 仅记兼容风险）的差异在工程结构上保留为两套实现；
6. 反模式禁止：Core/UI 散落路线 `if/else`、把越狱类型等同 ElleKit 行为、为双环境把差异压进公共层、未知 Profile 默认放开写入（对齐 [Architecture.md §8](../Architecture.md)）。

## 9. 签名与权限预留（结论留待 2.4）

### 9.1 2.1 允许做的

- 在工程配置规划中预留 entitlement / 签名位的说明位置；
- 预留 `PermissionProbe` 目录与接口轮廓（2.4 实现）；
- 记录官方 Manager 参照 entitlement：`platform-application`、`com.apple.private.security.no-sandbox`、`com.apple.private.security.storage.AppBundles`、`com.apple.private.security.storage.AppDataContainers`（仅参照，见 Dev-Prep §6.2）。

### 9.2 2.1 禁止假定

- 不假定上述 entitlement 一定被 amfid / ldid / 签名链放行；
- 不假定装入 `JBROOT/Applications` 即可读隐藏容器；
- 不假定 `jbroot()` 符号在 GUI 进程内一定可解析；
- 权限结论一律留到 2.4 GUI 进程内探针取证；2.1 文档与界面不出现"已获权限/可读写"表述。

## 10. CI 构建方案（规划）

### 10.1 流水线阶段（2.1 骨架阶段）

1. 检出工程与 Stage 1 夹具基线；
2. 安装工具链 / SDK / Theos 基线（版本按 §4.2 定值后固定）；
3. 构建空 App + 模块骨架 + Models；
4. Models Codable 往返与 Schema 对齐校验；
5. 产出可重复构建记录（构建成功 ≠ 权限通过）。

### 10.2 可重复要求

- 工具链版本、SDK 版本、Theos scheme/架构在 CI 配置中固定可追溯；
- 同一提交重复构建结果一致；
- Node 脚本仅参与 CI 编排/打包，不进入 App 运行时。

## 11. 2.1 验收门禁

2.1 工程创建与骨架实现完成时，必须满足：

1. 正式 App 工程在 CI 能够成功构建；
2. App 能正常启动（骨架页面，无业务数据也不崩溃）；
3. Core / Models / Adapters / App 模块边界与依赖方向符合 §2/§3；
4. RootHide / Rootless 无混合实现，协议隔离成立；
5. Models 与 Stage 1 输出 Schema 对齐（§7 校验通过）；
6. GitHub Actions 可重复构建；
7. 未引入插件写入、启停、安装/卸载功能。

> **工程构建成功 ≠ 越狱权限通过。** 权限、容器可读性、`jbroot()` 可用性均为 2.4 探针范围。

## 12. 与 2.2 的交接条件

- 2.1 验收门禁 1~7 全部满足并归档；
- Models 结构冻结，Stage 1 夹具回归入口就绪；
- Adapter 协议与 Core 服务轮廓稳定，2.2 可按 [Stage 2 计划 §4](./Stage-2-Implementation-Plan.md) 映射迁移八个环节；
- 工具链与 Target 取值已在工程配置中固化并记录依据；
- 未决权限/真机项仍标注对应证据标签，不带入 2.2 当作已验证结论。

## 13. 暂缓与禁止项（2.1 全程）

- 不实现启用/禁用、改 Filter plist、加 Bundle ID、删 dylib、改软链、安装/卸载、dpkg 写入、自动修复 ElleKit；
- 不设常驻 Daemon、不自研注入引擎、不改目标 App Bundle、不重签名；
- 不在 2.1 做真机文件访问测试或权限放行结论；
- 不提前展开 2.2 迁移实现或 2.3 界面业务逻辑。

## 14. 待确认清单（回填来源）

| 编号 | 待确认项 | 回填阶段 |
|---|---|---|
| B1 | Xcode / Swift 版本 | 2.1 工程创建 + CI 记录 |
| B2 | Deployment Target 定值与依据 | 2.1 §6.2 流程 |
| B3 | Bundle ID 命名 | 2.1 工程创建 |
| B4 | SwiftUI / UIKit 最终选型 | 2.1 工程创建（§5） |
| B5 | Theos 在工程中的角色与 Swift 工具链配置 | 2.1 工程创建 |
| B6 | 16.5 SDK 对 iOS 17 链接/运行兼容 | CI + 2.5 真机 |
| B7 | entitlement 放行 / sandbox / 容器 / `jbroot()` | 2.4 探针 |
| B8 | Rootless 真机适配 | 后续 Rootless 设备 |
