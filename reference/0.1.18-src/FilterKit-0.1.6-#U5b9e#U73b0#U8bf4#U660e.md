# FilterKit 0.1.6 实现说明 — Plugin Management Framework（插件管理框架）

## 一、版本定位

0.1.6 在 0.1.5 只读预检主流程之上，把工具从"越狱环境诊断"过渡到"以 App 为入口的插件管理框架"。本版本搭建管理关系、插件选择、兼容性评估、配置预览、Helper 安全状态与审计闭环；**管理关系与配置预览可建，真实系统修改一律不开放**。

安全口径延续 PreviewOnly：

- 不修改注入器配置文件；
- 不真实启用 / 禁用插件；
- 不连接未经验证的 Helper，不建立真实 IPC；
- 不真实恢复系统文件；
- 不导入自定义 dylib（推迟 0.1.8）。

## 二、四 Tab 结构

| Tab | 控制器 | 职责 |
|---|---|---|
| 首页 | `FKHomeViewController` | 设备 / 越狱环境、注入器、Helper 安全状态、扫描统计、最近活动 |
| App | `FKDataListController`（mode=apps） | App 搜索、管理关系 / 静态匹配计数、进入 App 详情 |
| 插件 | `FKDataListController`（mode=plugins） | 插件搜索、分类筛选、进入插件详情 |
| 设置 | `FKSettingsController` | 环境 / 注入器 / Helper、备份、操作历史、安全报告、关于 |

0.1.5 的"导入"Tab 下线；导入自定义 dylib 推迟 0.1.8。

## 三、数据模型（`Sources/Models/`）

### FKAppPluginAssociation（App ↔ 插件管理关系）

- 字段：`associationID` / `appBundleID` / `pluginID` / `createdAt` / `updatedAt` / `source` / `status`。
- `source=manual`：用户在 FilterKit 内手动建立；`status=associated`。
- 仅描述 FilterKit 内管理关系，与注入器真实配置、运行时加载状态相互独立。
- 支持 `associationFromDictionary:` 反序列化与 `JSONDictionary` 导出。

### FKInjectionPreview（配置预览快照）

- 字段：`previewID` / `appBundleID` / `pluginID` / `dylibPath` / `injectorType` / `checks` / `warnings` / `createdAt` / `previewOnly` / `systemModified` / `result`。
- `previewOnly` 恒 YES，`systemModified` 恒 NO。
- `result`：`preview_ready` / `preview_warnings` / `preview_blocked`。
- 检查项状态：`pass` / `warn` / `fail` / `unknown`。

### FKPluginCompatibility（兼容性结论）

- 五态：`Compatible` / `PartiallyCompatible` / `Incompatible` / `Unknown` / `Unsupported`。
- 逐项检查保留独立结论，不合并为单一布尔；`checks` / `conflicts` / `warnings` 分别留存。

### 三态区分（App 详情）

| 状态 | 含义 | 0.1.6 判定口径 |
|---|---|---|
| Associated 已关联 | FilterKit 内存在管理关系 | `FKAssociationManager` 关联记录数 > 0 |
| Configured 已配置 | 注入器配置中存在可验证对应配置 | 0.1.6 未读取真实注入器配置，保守显示"需要验证" |
| Active 已生效 | 有运行时证据证明已加载 | 无进程级证据时显示"未确认" |

不因添加关联就显示"已启用"，也不因配置文件存在插件名就判定已生效。

## 四、管理器与持久化（`Sources/Managers/`）

### FKAssociationManager

- 管理关系 CRUD：`addAssociationForApp:plugin:`（重复返回 nil）、`removeAssociationForApp:plugin:`、`hasAssociationForApp:plugin:`、按 App / 插件反查。
- 收藏：`toggleFavoriteApp:` / `isFavoriteApp:` / `favoriteApps`。
- 最近使用：`recordRecentApp:`（置顶去重，上限 20）/ `recentApps`。
- 沙盒持久化目录：`Library/Application Support/FilterKit/Relations/`
  - `associations.json` / `favorites.json` / `recent_apps.json`。
- 串行队列原子写、启动加载、`schema_version`、损坏文件改名隔离不清历史。

### FKInjectionPreviewManager

- `buildPreviewForApp:plugin:injectorType:compatibility:trustReport:` 汇总五组检查。
- `savePreview:` 留存历史预览；按 App / 插件反查；持久化 `FilterKit/Previews/previews.json`。

### FKCompatibilityManager

- `evaluatePlugin:forApp:injectorType:alreadyAssociated:` 逐项评估文件存在 / 可读 / Mach-O / 架构 / Install Name / 依赖 / Injector / Filter / App。
- `detectConflictsAmongPlugins:` 跨插件识别重复 dylib、共享 Filter 目标。
- Mach-O 类型 / 架构 / Install Name / 动态依赖在 0.1.6 不做二进制深度解析，证据不足归 Unknown；静态检查通过不保证运行时可运行。
- 冲突判断保守：无法证明冲突时归"需要确认"，不直接判冲突。

## 五、添加插件流程

App 详情 → `+ 添加插件` → `FKAddPluginViewController`（选择插件）→ `FKInjectionPreviewViewController`（兼容性 + 配置预览）→ 保存管理关系。

- 插件选择页：搜索名称 / 包名 / dylib；标注已关联、来源、完整性；已关联与用户导入记录不可选；重复关联拦截。
- 配置预览页：目标 App / 插件、文件信息、五组检查、警告与冲突、安全边界说明；不兼容（blocked）禁用保存；保存仅写管理关系与预览记录。
- 0.1.6 仅开放系统发现插件（`source=dpkg`）；用户导入 dylib 推迟 0.1.8。

## 六、审计事件（`Sources/Security/`）

在 0.1.5 事件链基础上新增九类：

`app_opened` / `app_searched` / `plugin_selected` / `association_previewed` / `association_created` / `association_removed` / `injection_preview_created` / `compatibility_checked` / `operation_denied`。

- 保存管理关系记 `association_created`，**不记录真实启用事件**。
- 兼容性不通过阻断保存时记 `operation_denied`，拒绝原因可追踪并入审计链。
- 既有扫描 / 备份 / 测试 / 导出事件与安全报告快照口径保持不变。

## 七、安全边界（0.1.6 不开放）

| 功能 | 状态 |
|---|---|
| App / 插件搜索、详情 | 开放（只读） |
| App 关联插件 | 开放，仅管理关系 |
| 注入配置预览 | 开放，仅预览 |
| 兼容性 / 冲突检测 | 开放，保守结论 |
| Helper 发现 / 身份评估 | 开放，只读评估 |
| 真实 Helper IPC | 不开放 |
| 修改注入器配置 | 不开放 |
| 真实启用 / 禁用 | 不开放 |
| 真实恢复系统文件 | 不开放 |
| 导入 / 注入自定义 dylib | 不开放（0.1.8） |

## 八、工程配置

- 版本三处：`control` `Version: 0.1.6`、`FilterKit-Info.plist` `CFBundleShortVersionString 0.1.6`、`FKScanner.m` `FKVersion = @"0.1.6"`；workflow 产物前缀 `FilterKit-0.1.6-`；导出文件名 `FilterKit-0.1.6-report.json` / `FilterKit-0.1.6-backup.json`。
- 新增 `.m` 已逐个登记进 `Makefile` 的 `FilterKit_FILES`，头文件搜索路径补充 `Sources/Views/Home`、`Sources/Views/Apps`。
- `scripts/validate-project.js` 同步新文件、关键类 / 方法、持久化文件名、三态文案、审计事件与特权入口禁扫断言。

## 九、已知限制与后续衔接

- Mach-O 架构 / Install Name / 动态依赖、真实注入器配置读取、运行时加载证据在 0.1.6 均保守归 Unknown / 需要验证，待后续版本接入二进制静态分析与可信 Helper 验证。
- 管理关系移除的滑动删除入口、App 收藏 / 最近使用的列表筛选段在本版本管理器接口已就绪，UI 交互可在 0.1.7 补全。
- 0.1.7 在本管理框架上增加经安全验证的真实操作能力；0.1.8 开放自定义 dylib 导入与静态分析。

> 本说明对应源码静态盘点与本地静态校验；本地无 Theos / SDK / 设备，编译与真机结论以远端 CI 与真机导出 JSON 为准，未执行项不预填通过。
