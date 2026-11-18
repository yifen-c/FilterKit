# FilterKit 0.1.1 实现说明（Plugin State Manager / 插件状态管理与安全操作版）

0.1.1 在 0.1.0 基础插件管理之上，新增插件状态识别、受控操作流程骨架（预检查 → 预演 → 确认 → 备份 → 白名单执行 → 验证 → 审计）、操作前备份与恢复前冲突校验、追加式操作历史，以及 Helper 协议 / 校验 / 客户端骨架。版本号为 **0.1.1**，完整保留 0.1.0 全部基础管理能力与 0.0.9 的 18 项诊断验收。

## 一、定位与边界

- **定位**：在只读诊断与查看基础上，先把状态识别、操作预检查、预演、备份框架与审计链路搭扎实；为后续 Helper 验证后的受控启停建立统一底层机制。
- **本轮落地范围**：A 状态识别、C 操作预检查、D 备份恢复框架、F 预演 / 历史 UI，以及 B 阶段的协议、校验与客户端骨架。
- **本版本不开放**：真实插件启停、安装 / 卸载、修改 Filter 配置、RootHelper 特权命令、备份自动恢复、任何对越狱环境的写入。
- **Helper 未验证原则**：RootHelper 身份、签名、权限与通信协议尚未验证，不进入 E 阶段开放真实启停。Helper 客户端 `available` 恒为 NO，所有真实操作在本地预校验后被安全拒绝；不连接、不发命令、不改系统。
- **无任意命令执行器**：Helper 只接受白名单操作枚举，不存在 `executeCommand` / `system(` / `popen(` / `NSTask` / `posix_spawn` 等任意命令或脚本入口。

## 二、目录与分层

源文件仍平铺在 `Sources/`，便于 Theos 编译；本轮新增 7 组文件：

| 文件 | 职责 |
|---|---|
| `FKOperationModels.h/.m` | 状态 / 请求 / 结果 / 审计记录模型，枚举与 JSON 导出，ISO-8601 时间 |
| `FKHelperProtocol.h/.m` | Helper 错误域与错误码、白名单操作枚举与操作名、白名单判定 |
| `FKHelperValidator.h/.m` | 请求字段校验、目标路径标准化与可信根前缀校验；身份验证标记骨架 |
| `FKHelperClient.h/.m` | 受控 Helper 客户端；`available` 恒 NO，本地预校验后安全拒绝，预留受控 IPC 接入点 |
| `FKAuditManager.h/.m` | 追加式操作记录，按插件 / 类型 / ID 查询，JSON 导出，锁保护 |
| `FKStateManager.h/.m` | 证据驱动的插件状态识别，每次扫描重新判定 |
| `FKOperationManager.h/.m` | 统一受控操作流程：前置检查 → 预演 → 备份 → 白名单执行 → 回填 → 审计 |

`FKBackupManager.h/.m` 在 0.1.0 六段备份基础上扩展操作前备份与恢复前冲突校验；原有只读备份 / SHA-256 校验逻辑保留不变。

## 三、操作数据模型（FKOperationModels）

### 状态枚举 `FKPluginStatus`
`Unknown` / `Enabled` / `Disabled` / `PartiallyEnabled` / `Pending` / `Failed` / `Unsupported`。`statusText:` 提供中文展示；无可靠证据时归 Unknown，不凭 dylib 存在推断已启用。

### 操作类型 `FKOperationType`
`Enable` / `Disable` / `Validate` / `Restore`，对应白名单操作；`operationText:` 输出 `enable` / `disable` / `validate` / `restore`。

### FKPluginState
`pluginID` / `status` / `evidence`（证据来源描述）/ `lastChecked` / `injector` / `supported`（当前环境是否支持受控管理）/ `unsupportedReason`（不支持原因）。

### FKOperationRequest
`requestID`（UUID）/ `pluginID` / `operation` / `reason` / `backupID` / `createdAt`。请求只携带插件 ID 与操作类型，**不允许 App 直接传入文件路径**。

### FKOperationResult
`requestID` / `success` / `errorCode` / `message` / `previousState` / `currentState` / `backupID` / `completedAt`。请求被接受不等于启停成功，结果以 Helper 实际返回与后续状态核对为准。

### FKOperationRecord
`operationID` / `pluginID` / `operation` / `previousState` / `currentState` / `result`（success / failed / cancelled）/ `verification`（passed / failed / pending / none）/ `backupID` / `timestamp` / `errorMessage`。追加写入，普通操作不覆盖历史。

## 四、Helper 骨架（协议 / 校验 / 客户端）

### FKHelperProtocol
- 错误域 `FKHelperErrorDomain`；错误码 `Unavailable` / `Unauthorized` / `UnknownOperation` / `PathOutOfBounds` / `InvalidRequest` / `Timeout` / `Incompatible`。
- 白名单操作：`GetStatus` / `Validate` / `Enable` / `Disable` / `Verify` / `Restore`，对应操作名 `get_status` / `validate_operation` / `enable_plugin` / `disable_plugin` / `verify_operation` / `restore_operation`。
- `FKHelperOperationName()` 取操作名；`FKHelperOperationIsAllowed()` 判定操作名是否在白名单内。

### FKHelperValidator
- `validateRequest:operationName:error:`：插件 ID 非空 + 操作白名单。
- `validateTargetPath:withinRoot:error:`：`stringByStandardizingPath` 解析 `..`，补齐根目录边界后做前缀可信校验，越界拒绝。
- `identityVerified` 为身份 / 签名校验预留标记，当前恒 NO。

### FKHelperClient
- `available` 当前恒 NO；`performOperation:completion:` 先本地校验请求，不可用返回 `helper_unavailable`，不发起真实连接。
- 业务操作枚举在内部映射到 Helper 白名单枚举；预留受控 IPC 接入点注释。无任意命令接口。

## 五、管理器接口

### FKStateManager
- `initWithPlugins:injector:`；`stateForPluginID:`；`allStates`。
- 证据派生：规则 `enabled=@NO` → Disabled；`enabled=@YES` 且有关联 → PartiallyEnabled（静态配置，运行时未验证）；其余归 Unknown，因当前不支持管理置 Unsupported，并记录证据与不支持原因。

### FKOperationManager
- 装配：`initWithPluginManager:stateManager:auditManager:helperClient:backupManager:`。
- `previewForPluginID:operation:`：走完身份 / 兼容性 / 完整性 / 状态检查，生成 `eligible` / `reasons` / `target_state` / `current_state` / `backup_available` / `risk` / `impact` / `note`，不执行、不落地备份。
- `validatePlugin:`：受控操作资格校验。
- `enablePlugin:completion:` / `disablePlugin:completion:` / `restoreOperation:completion:`。
- 固定流程：重复请求防护（pending 集合 + 锁）→ 前置检查 → 不合格记审计失败并回调 → 操作前备份 → Helper 执行 → 回填前后状态 → 记审计 → 收尾移出 pending。

### FKAuditManager
- `appendRecord:` 追加不覆盖；`records`（时间排序）；`recordsForPluginID:`；`recordsForOperation:`；`recordForID:`；`JSONDictionary`。记录在内存跨多次扫描保留；持久化到沙盒留待后续版本。

## 六、操作前备份与恢复前校验（FKBackupManager 扩展）

- `createOperationBackupForRequest:`：记录原始配置引用（Filter / dylib 路径、Bundles / Executables / Classes）、修改前状态、完整性快照（文件状态、包归属、关联类型）与时间；返回备份 ID。不复制文件到原插件目录；文件 SHA-256 摘要留占位，待真实受控操作前由校验流程补算。
- `operationBackupWithID:`：按 ID 取备份记录。
- `validateOperationBackup:error:`：必备段完整性检查 + 与当前扫描路径 / 包归属冲突比对；路径或归属不一致、插件已不在扫描结果中均判为冲突，拒绝自动覆盖，返回 `valid` / `reasons` / `conflicts`。

## 七、UI 调整（保留四 Tab）

- **插件详情**：新增状态区——当前状态、状态证据、状态管理说明；仅当 `supported=YES` 才出现可进入预演的操作行，不支持时只展示原因，不呈现看起来可用的按钮。
- **操作预演确认页**：展示插件、当前状态、目标状态、兼容性、备份可用性、风险、预计影响、前置检查原因与说明；未确认不执行；确认后进入受控流程，当前 Helper 不可用时结果以安全拒绝提示呈现并写入审计。
- **操作历史页**：设置 Tab 入口；追加式记录列表（操作、插件、结果、验证、备份、时间），点击查看 JSON 详情。
- 0.1.0 的 App / 插件列表、搜索筛选、详情、备份导出、导入校验预览保持不变。

## 八、验收映射（0.1.1 规划 48 项）

| 分组 | 编号 | 本轮落地情况 |
|---|---|---|
| 状态识别 ST001–006 | 已启用 / 已停用 / 部分启用 / 未知 / 不支持 / 重扫一致 | 模型与证据派生骨架落地；运行时状态与真实启用证据待 Helper / 进程级验证后补全 |
| 操作安全 OP001–010 | 前检查、用户确认、非法 ID / 类型拒绝、重复请求、并发、超时、权限不足 | 前置检查、非法字段 / 类型本地拒绝、重复请求防护、并发锁已落地；超时、真实权限判定随 Helper 接入补全 |
| 备份恢复 BK001–008 | 操作前备份、完整性、损坏检测、恢复前验证、冲突拒绝、恢复后校验、失败不破坏、备份引用清理 | 备份元数据框架与恢复前冲突校验落地；真实文件备份 / 恢复 / 摘要比对待受控阶段 |
| Helper RH001–008 | 身份验证、请求验证、白名单、路径越界、任意命令不存在、未授权拒绝、超时、异常不崩溃 | 协议枚举、白名单、请求 / 路径校验、无任意命令接口骨架落地；身份 / IPC / 超时 / 异常处理待真实接入 |
| 日志 LG001–006 | 成功 / 失败 / 取消记录、查询、关联备份、历史不被覆盖 | 追加式审计、按插件 / 类型 / ID 查询、关联备份 ID、不覆盖历史已落地；取消记录由后续流程补 |
| 回归 RG001–010 | 扫描 / Filter / dpkg / MD5 / JSON 导出 / 备份 / 双架构真机 | 本地静态回归通过；RootHide / Rootless 真机验收待 Actions 构建后进行 |

## 九、保留的诊断能力

0.0.9 的 18 项验收 ID 全部保留：`jbroot`、`dynamic_paths`、`dylib_scan`、`plist_read`、`filter_parse`、`dpkg_status`、`dpkg_ownership`、`ellekit_version`、`app_enumeration`、`app_metadata`、`plugin_association`、`dpkg_metadata`、`dpkg_state`、`dpkg_file_integrity`、`dpkg_checksum`、`plugin_source`、`ownership_conflict`、`roothelper_preflight`。MD5 三级分类、Conffiles 双渠道识别与保守未确认策略不变。

## 十、已知限制与待验证

- 本地无 Theos / iOS SDK，仅通过 `node scripts/validate-project.js` 静态检查；未实编译，需 GitHub Actions 构建与 RootHide / Rootless 真机验收。
- Helper 身份 / 签名 / IPC 协议未验证前，真实启停、安装卸载、Filter 修改、备份自动恢复均不开放；操作摘要与状态为静态证据派生，不代表运行时注入结果。
- 操作备份的文件 SHA-256 摘要当前为空占位；真实受控操作前由校验流程补算。
- 审计历史当前为内存数组，跨扫描保留但不持久化到沙盒；持久化与导出随后续版本补充。
- 图标 `CFBundleIconName`（Assets.car）跨 bundle 读取受沙盒 / entitlement 限制，本版本未处理。
