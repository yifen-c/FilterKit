# FilterKit 0.1.0 实现说明（Basic Plugin Manager）

0.1.0 在 0.0.9 全部诊断能力之上，提供只读的基础插件管理：查看与管理已安装插件、查看插件与 App 关联、查看 Filter 规则、完整性与异常状态、App 注入配置视图，以及插件信息备份与校验。版本号为 **0.1.0**，保留 0.0.9 的 18 项诊断验收。

## 一、定位与边界

- **定位**：基础管理工具——可以查看、整理、关联、备份插件；不做受控的特权写操作。
- **本版本不开放**：插件启用/停用、安装/卸载、修改 Filter 配置、RootHelper 特权命令、备份自动恢复、任何对越狱环境的写入。
- **只读原则**：所有管理界面只读取扫描结果；备份导出写入应用临时目录用于分享，不覆盖任何系统文件；导入仅解析与校验，不恢复、不部署。
- **关联 ≠ 注入**：静态 Filter 匹配只代表配置上指向该 App；没有进程级运行时证据时，UI 一律标注“运行时未验证”，不报为已注入。

## 二、目录与分层

在不推翻现有四 Tab 结构的前提下，新增模型层与管理器层（源文件仍平铺在 `Sources/`，便于 Theos 编译）：

| 文件 | 职责 |
|---|---|
| `FKManageModels.h/.m` | Filter / Package / Plugin / App 四个数据模型，含稳定 ID、派生状态与 JSON 导出 |
| `FKPluginManager.h/.m` | 插件查询、筛选、搜索；只读，不含任何写操作 |
| `FKAppManager.h/.m` | App 查询、反向关联插件、App 级注入摘要 |
| `FKBackupManager.h/.m` | 备份组装、原子导出、SHA-256 分块校验与旧版报告兼容识别 |

原有 `FKScanner` / `FKDPKGAnalyzer` / `FKModels` / `FKMainViewController` 保留；扫描与诊断链路不变。

## 三、数据模型

### FKFilterModel
- `bundles` / `executables` / `classes`：三类官方规则键（与 Theos packaging 文档一致）。
- `otherKeys` / `rawRules`：未归类字段与原始规则原样保留，不丢弃未知键。
- `global`：是否全局规则；`parseError`：解析失败原因。

### FKPackageModel
- 映射 dpkg 包的 `Package` / `Version` / `Status` / `Architecture` / `Maintainer` / `Description` / `Homepage` / `Section`。

### FKPluginModel
- `pluginID`：稳定内部 ID，优先「软件包标识:文件名基名」，避免重名冲突；不用插件名称代替 Bundle ID。
- `identifier`（Identifier，可能为空）、`name`、`version`、`packageID`、`packageCandidates`。
- `dylibPath` / `filterPath` / `source` / `fileStatus` / `duplicateFlags`。
- 关联结果：`associatedBundleIDs`、`unmatchedBundleIDs`、`matchedExecutables`、`unmatchedExecutables`、`isGlobal`。
- `associationType`：`filter_match` / `global` / `unmatched` / `unknown`。
- `integrity` / `integrityStatus`：`完整` / `警告` / `异常` / `未知`，由文件配对状态、配置有效性、重复标记与未匹配规则派生。
- `raw`：保留原始插件字典作为全部诊断证据。

### FKAppModel
- `bundleID` / `name` / `version` / `versionSource` / `buildVersion` / `bundlePath` / `executable`（`CFBundleExecutable`）/ `isSystem` / `iconPath` / `iconSource` / `pluginIDs`。

## 四、管理器接口

### FKPluginManager
- `allPlugins`；`pluginsForBundleID:`；`pluginForID:`。
- `associatedPlugins`（已关联 App）、`globalPlugins`、`unmatchedPlugins`、`pluginsWithIntegrityWarnings`、`abnormalPlugins`。
- `pluginsWithFilter:`：全部 / 已关联 / 全局 / 未匹配 / 异常 / 警告。
- `search:`：按名称、插件 ID、软件包、dylib 路径、版本搜索；在已扫描结果内过滤，不重新扫描。

### FKAppManager
- `allApps`；`appForBundleID:`；`pluginsForApp:`。
- `injectionSummaryForApp:`：输出静态匹配插件、是否被全局覆盖、`runtime_injection_verified=NO`、`injection_state`（`static_global` / `static_associated` / `none`）与说明文案。

### FKBackupManager
- `createPluginBackup`：组装 `manifest` / `apps` / `plugins` / `packages` / `filters` / `diagnostics` 六段。
- `exportBackupToURL:error:`：JSON 原子写入（`NSDataWritingAtomic`），失败不留部分文件。
- `validateBackupAtURL:error:`：解析 JSON、校验 manifest 与各分块 SHA-256；无 manifest 的旧版扫描报告识别为 `legacy-report` 并给出提示。
- 备份不含私密密钥、令牌或不必要的个人数据；**恢复功能本版本不开放**。

## 五、UI 调整（保留四 Tab）

- **App Tab**：列表展示图标、名称、Bundle ID、版本、关联插件数；详情含基本信息、可执行文件、注入状态、运行时验证标记、关联插件与说明。
- **插件 Tab**：顶部分段筛选（全部 / 已关联 / 全局 / 未匹配 / 异常 / 警告），搜索不重扫；列表展示名称、包、版本、完整性、关联数与匹配目标；详情含基本信息、文件路径、完整性、关联类型、Filter 三键与已匹配可执行、配置状态、归属证据。
- **导入 Tab**：支持选择 `.json` 备份/报告做只读校验预览；`.dylib` / `.plist` / `.zip` / `.deb` 仍仅文件信息预览。不自动恢复或修改环境。
- **设置 Tab**：运行环境、扫描统计（App / 插件含关联·全局·未匹配计数 / dpkg 包 / 验收结果 / MD5 完整性）、安全边界；导航栏提供“导出报告”与“导出备份”。

## 六、安全与只读边界（对应验收 S001–S010）

- 不修改越狱文件、App、DynamicLibraries、Filter plist 或注入配置。
- 不启停、不安装、不卸载插件；不执行 RootHelper 特权命令；不发送未经授权的 IPC；不调用 `launchctl`。
- 备份不覆盖原始配置；导入不自动恢复系统文件；不请求不必要权限。
- 备份导出使用原子写入，失败不留部分文件。

## 七、保留的诊断能力

0.0.9 的 18 项验收 ID 全部保留：`jbroot`、`dynamic_paths`、`dylib_scan`、`plist_read`、`filter_parse`、`dpkg_status`、`dpkg_ownership`、`ellekit_version`、`app_enumeration`、`app_metadata`、`plugin_association`、`dpkg_metadata`、`dpkg_state`、`dpkg_file_integrity`、`dpkg_checksum`、`plugin_source`、`ownership_conflict`、`roothelper_preflight`。MD5 三级分类、Conffiles 双渠道（status 字段 + `info/<pkg>.conffiles`）、RootHelper 只读预检策略不变。

## 八、已知限制与待验证

- 本地无 Theos / iOS SDK，仅通过 `node scripts/validate-project.js` 静态检查；未实编译，需 GitHub Actions 构建与 RootHide / Rootless 真机验收。
- 图标 `CFBundleIconName`（Assets.car）跨 bundle 读取受沙盒 / entitlement 限制，本版本未处理。
- 静态关联不等于运行时注入；进程级注入状态需后续版本在受控架构下补充。
- 备份恢复、插件启停、安装卸载、Filter 编辑均留给后续受控版本（0.2.x）。
