# FilterKit 0.1.2 实现说明（Safe Management & Operation Preview / 安全管理与操作预演版）

0.1.2 在 0.1.1 状态管理框架之上，补齐可验证的真实文件备份与恢复前校验、RootHelper 身份 / 签名 / 权限 / IPC 安全验证骨架，以及双重门槛操作准入控制。管理功能在界面完整可见（只读预演），真实特权操作默认关闭，全部安全门槛通过后才允许开放。版本号为 **0.1.2**，完整保留 0.1.1 状态 / 审计骨架、0.1.0 基础管理能力与 0.0.9 的 18 项诊断验收。

## 一、定位与边界

- **定位**：完成真实启停的安全基础设施——流式双摘要备份、备份完整性与恢复预览、Helper 信任验证、准入闸门；但**不以开放真实启停为发布目标**。
- **本轮落地范围**：A UI 入口与只读预演、B 流式哈希、C 真实文件备份、D 备份完整性与恢复预检查、E Helper 身份 / 签名 / 权限验证、F IPC 协议校验、G 双重门槛准入控制。
- **本版本不开放**：真实插件启停、安装 / 卸载、批量操作、Filter 配置修改、备份自动恢复、任何对越狱环境的写入。
- **保守信任原则**：身份缺官方渠道白名单、签名未接 SecStaticCode 签名链、权限未核对真实授权上下文、IPC 通道本轮未建立，信任结论保守停留在已发现 / 证据不足；准入闸门默认 `PreviewOnly`。
- **备份与系统修改分离**：越狱文件只读 → 复制进 App 沙盒备份目录；不存在 App 覆盖越狱插件文件的路径。
- **无任意命令执行器**：不存在 `executeCommand` / `system(` / `popen(` / `NSTask` / `posix_spawn` / `launchctl` 等任意命令、脚本或服务管理入口。

## 二、目录与分层

源文件按功能模块拆分到 `Sources/` 子目录（`App` / `Core` / `Models` / `Managers` / `Backup` / `Operation` / `Helper`），头文件经 Makefile `-I` 路径纳入搜索；本轮新增 9 组文件：

| 文件 | 职责 |
|---|---|
| `FKFileHasher.h/.m` | 64KB 分块流式读取；MD5 对照 dpkg `.md5sums`，SHA-256 用于备份一致性核对 |
| `FKBackupManifest.h/.m` | 备份清单与单文件条目模型：原始路径 / 备份相对路径 / 大小 / 类型 / 权限 / 所有者 / 修改时间 / 符号链接 / 双摘要；JSON 序列化与反序列化 |
| `FKBackupValidator.h/.m` | 备份目录重读 SHA-256 校验；恢复前冲突预览（六态结论 + 原因），不执行覆盖 |
| `FKHelperTrust.h/.m` | Helper 信任报告模型、逐级状态机与签名证据状态、状态文案 / 机器标识 |
| `FKHelperIdentityVerifier.h/.m` | 身份证据评估：路径存在、归属包、版本匹配；缺官方白名单时保守判未通过 |
| `FKHelperSignatureVerifier.h/.m` | 签名证据评估；未建立可验证签名链时标 `Unverified`，不凭已安装文件认定可信 |
| `FKHelperPermissionVerifier.h/.m` | 操作是否落在 Helper 白名单内；未核对真实授权上下文时保守判未通过 |
| `FKHelperTrustVerifier.h/.m` | 编排身份 → 签名 → 权限 → IPC 逐级定级，绑定具体候选路径与归属包 |
| `FKOperationGate.h/.m` | 准入闸门枚举、单项预检查模型、检查项汇总、资格判定与闸门文案 |

`FKBackupManager.h/.m` 在 0.1.1 操作前备份框架上扩展真实文件备份接口；`FKHelperProtocol.h/.m` 追加结构化请求 / 响应报文校验与时间戳防重放窗口。

## 三、真实文件备份（FKBackupManager 扩展）

- `backupPlugin:error:`：定位插件直接关联的 dylib 与 Filter plist → 校验存在且可读 → 流式计算 MD5 / SHA-256 → 复制到沙盒 `Library/Application Support/FilterKit/Backups/<plugin>/<backupID>/files/` → 重读备份文件重算 SHA-256 比对 → 原子写入 `manifest.json` → 追加 `index.json` 索引。
- **失败不留半成品**：复制、哈希、清单写入任一环节失败即清理半成品目录，不生成看似完整的备份记录；重复备份不覆盖旧记录。
- **元数据留档**：条目记录权限位（八进制）、所有者 `uid:gid`、修改时间、符号链接目标；0.1.2 仅记录，不自动应用到系统文件。
- 目录结构：`Backups/index.json` + `Backups/<pluginID>/<backupID>/manifest.json` + `files/`。备份只写 App 沙盒。
- 接口：`allBackups`（按时间倒序）、`backupWithID:`、`backupDirectoryForID:`。

## 四、备份完整性与恢复预检查（FKBackupValidator）

- `validateBackupAtDirectory:manifest:error:`：逐条重读备份文件重算 SHA-256，与清单条目比对；缺失或摘要不一致返回损坏结论。
- `restorePreviewForManifest:currentModel:`：结合清单与当前扫描模型给出六态结论：
  - `SAFE_TO_RESTORE` 备份完整且当前目标未被改动；
  - `TARGET_MODIFIED` 备份后当前目标已被其他程序修改；
  - `BACKUP_CORRUPTED` 备份缺失或摘要不一致；
  - `PACKAGE_MISMATCH` 软件包归属与备份时不一致；
  - `PATH_MISMATCH` 路径不一致或插件已不在扫描结果；
  - `UNKNOWN` 证据不足。
- 只读比对路径、归属、当前文件哈希、权限位与文件类型；不一致仅在原因列表提示，0.1.2 不执行恢复。

## 五、Helper 信任层

### 状态机 `FKHelperTrustState`
`NotFound` → `Discovered` → `IdentityVerified` → `SignatureVerified` → `PermissionVerified` → `IPCVerified` → `OperationReady`；验证失败 `Rejected`。只有全部必要验证通过才进入 `OperationReady`；结果绑定具体候选路径与归属包，不作为所有插件通用授权。

### 签名证据 `FKSignatureStatus`
`Unknown` / `Verified` / `Unverified`；无可验证签名链时必须标 `Unverified`。

### 协议校验（FKHelperProtocol 扩展）
- `FKHelperValidateRequest:`：协议版本、请求 ID、操作白名单、插件 ID、时间戳有效性；超过 `FKHelperRequestMaxAge`（300 秒）判为过期或疑似重放并拒绝。
- `FKHelperValidateResponse:`：协议版本、请求 ID 回带、状态字段完整性校验。

## 六、双重门槛准入（FKOperationGate / FKOperationPreflight）

- **第一层 Helper 安全门槛**：身份、签名、权限、IPC 综合为 `helper_trust` 检查项。
- **第二层 插件操作门槛**：插件身份、文件路径、软件包归属、注入器兼容性、插件格式、操作方法、操作前备份、操作影响可评估性。
- 单项结论 `Passed` / `Warning` / `Failed` / `Unknown` / `Blocked`；`isOperationEligible:` 不存在 Failed / Blocked 即具备资格；`gateForChecks:` 综合判定：
  - 有 Blocked / Failed → `Blocked`；
  - 无 Unknown 且 Helper 就绪 → `Enabled`；
  - 其余 → `PreviewOnly`（默认）。
- 准入判断只输出结论，不直接执行操作；`Enabled` 不通过普通 UI 设置切换。

## 七、UI 调整（保留四 Tab）

- **插件详情**：启用 / 停用 / 备份 / 操作历史四个入口始终可见；启用、停用标注「只读预演 · 真实操作待 RootHelper 安全验证」，备份标注复制与摘要校验，历史进入该插件的审计记录。
- **操作预演页**：分四块——操作目标（名称 / 版本 / 软件包 / 目标文件 / 当前状态 / 目标状态）、安全检查项（标题 + 结论 + 原因）、预计影响、准入结论与未通过 / 存疑原因；非 `Enabled` 点击仅提示「暂不可执行」，不触发写操作，不误报成功。
- **备份列表页**：展示沙盒内全部备份（插件、包、文件数、时间），空态有引导说明。
- **备份详情页**：展示备份摘要、恢复预览结论与原因、逐条文件条目（原始路径 / 类型 / 大小 / 权限 / MD5 / SHA-256）；明确标注只读预览、不自动恢复。
- **设置页**：新增 Helper 信任状态行（信任级别 + 签名状态）与备份管理入口；操作历史入口保留。

## 八、验收映射（0.1.2 规划 63 项）

| 分组 | 编号 | 本轮落地情况 |
|---|---|---|
| UI 与预演 UI001–010 | 四入口可见、预演页、检查项、失败原因、未验证提示、不误报成功、跳转 | 详情四入口、预演四分区、备份 / 历史 / 详情跳转已落地；结论以闸门为准，非就绪不执行 |
| 文件备份 BK001–012 | plist / dylib 一致、大小、MD5、SHA-256、重读一致、清单完整、多文件、重复不覆盖、失败不留记录、流式、沙盒写入 | 流式分块、双摘要、重读校验、原子写入、失败清理、沙盒目录已落地；大文件阻塞与异步化待真机评估 |
| 恢复预检 RS001–008 | 备份校验、损坏识别、原文件变化、路径变化、归属变化、权限信息、预览显示、禁止真实恢复 | 六态预览 + 权限 / 类型只读比对已落地；真实恢复本版本禁止 |
| Helper 安全 RH001–012 | 发现、归属追溯、身份证据、签名识别、未知签名未验证、权限模型、IPC 结构、非法请求、重放、未授权、异常、版本兼容 | 三验证器 + 编排定级 + 报文 / 版本 / 时间戳校验骨架落地；身份白名单、签名链、真实授权上下文与受控 IPC 待后续接入 |
| 操作准入 OP001–008 | 默认 PreviewOnly、Helper 未验证禁止、不兼容禁止、备份失败禁止、路径异常禁止、未确认禁止、状态有据、非白名单拒绝 | 九项检查 + 闸门判定落地；用户确认以预演页确认为准，闸门未就绪不进入执行 |
| 安全与回归 SEC001–006 / REG001–009 | 只读扫描、备份限沙盒、无未授权写入、无任意命令、无任意路径覆盖、不改原始配置；扫描 / Filter / dpkg / MD5 / JSON / 四 Tab / 双架构 | 边界检查脚本覆盖；本地静态回归通过；RootHide / Rootless 真机验收待 Actions 构建后进行 |

## 九、保留的诊断能力

0.0.9 的 18 项验收 ID 全部保留：`jbroot`、`dynamic_paths`、`dylib_scan`、`plist_read`、`filter_parse`、`dpkg_status`、`dpkg_ownership`、`ellekit_version`、`app_enumeration`、`app_metadata`、`plugin_association`、`dpkg_metadata`、`dpkg_state`、`dpkg_file_integrity`、`dpkg_checksum`、`plugin_source`、`ownership_conflict`、`roothelper_preflight`。MD5 三级分类、Conffiles 双渠道识别与保守未确认策略不变。

## 十、已知限制与待验证

- 本地无 Theos / iOS SDK，仅通过 `node scripts/validate-project.js` 静态检查；未实编译，需 GitHub Actions 构建与 RootHide / Rootless 真机验收。
- Helper 身份白名单、SecStaticCode 签名链、真实授权上下文与受控 IPC 通道尚未接入；信任结论保守未通过，真实启停不开放。
- 真实备份在主线程同步复制，大 dylib 的 UI 阻塞风险未评估；后续按需改为后台队列 + 进度回调。
- Helper 信任报告与审计历史当前为内存对象，未持久化到沙盒；每次准备操作时应重新验证关键条件，持久化缓存随后续版本补充。
- 备份元数据（权限 / 所有者 / mtime / 链接）仅记录留档，不自动应用到系统文件。
