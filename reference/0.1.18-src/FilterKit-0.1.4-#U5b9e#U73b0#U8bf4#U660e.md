# FilterKit 0.1.4 实现说明（Compatibility & Security Verification / 兼容性与安全验证版）

0.1.4 在 0.1.3 稳定性与模块化基线之上，从普通插件管理工具转向安全管理工具：建立越狱环境与注入器证据模型，补齐 RootHelper 身份 / 签名 / 权限可信验证与证据留存，完善安全准入闸门，设计标准化 IPC 协议模型并落地追加式安全审计报告。管理功能继续保持只读预演（PreviewOnly），未经验证不开放真实特权启停。版本号为 **0.1.4**。

## 一、定位与边界

- **定位**：回答「当前越狱环境、注入器与 RootHelper 是否可被准确识别，并有足够可信证据判断未来能否安全执行插件操作」。
- **三条不可破原则**：
  1. 发现不等于可信——找到 RootHelper 不代表它是可信的；
  2. 签名有效不等于操作安全——还需验证身份、权限与具体操作策略；
  3. 安全检查通过不等于自动开放操作——真实启停由 0.2.0 的独立安全验收决定。
- **本版本不开放**：真实插件启停、安装 / 卸载、任意命令执行、Filter 配置修改、备份自动恢复、任何对越狱环境的写入。
- **保守信任原则**：当前设备未确认官方签名链 / 可信发行者公钥 / 确认包来源时，身份与签名保守标记 `Unverified`，不臆断 Passed；准入闸门默认 `preview_only`，即使检查齐备也不进入 `ready`。
- **无任意命令执行器**：不存在 `installPackage` / `uninstallPackage` / `launchctl` / `system(` / `popen(` / `NSTask` / `posix_spawn` / `executeCommand` 等特权写或命令执行入口。

## 二、目录与分层

在既有 `App` / `Core` / `Models` / `Managers` / `Backup` / `Operation` / `Helper` / `Views` / `ImportExport` / `Utils` 基础上新增 `Environment` / `Injector` / `Security` / `Tests` 四个目录，新增与扩展文件如下。

| 模块 | 文件 | 职责 |
|---|---|---|
| Environment | `FKEnvironmentCompatibility.h/.m` | 环境兼容性五态（Unknown / Passed / Partial / Failed / Unsupported）与码值、文案；为旧代码保留类型与宏别名 |
| Environment | `FKEnvironmentEvidence.h/.m` | 单项探测证据：键、路径、存在性、目录、可读、来源、置信度、备注；JSON 往返 |
| Environment | `FKEnvironmentModel.h/.m` | 最终环境汇总：越狱类型码 / 展示名、jbroot、注入器名版本、兼容性、原因、证据、原始字典 |
| Environment | `FKEnvironmentValidator.h/.m` | 依据证据充分性保守派生兼容性；路径不可读归 Partial / Unknown，不直接判环境不兼容 |
| Environment | `FKEnvironmentDetector.h/.m` | 从扫描环境字典构建模型；jbroot 经 FileManager 只读探测 exists / isDirectory / readable |
| Injector | `FKInjectorProfile.h/.m` | 注入器能力画像：Filter 解析、App 定向、全局注入、启停能力、管理方式与是否已验证 |
| Injector | `FKInjectorModel.h/.m` | 识别结果：注入器 ID / 名 / 版本 / 包 ID / 版本来源 / 证据级别 / 是否识别 / 原始字典 |
| Injector | `FKInjectorCompatibility.h/.m` | 兼容性四态（Unknown / Compatible / Partial / Incompatible）与原因 |
| Injector | `FKInjectorRegistry.h/.m` | 内置 libhooker / ElleKit / Substrate / Substitute 基线画像；画像查询与按插件核对兼容性 |
| Injector | `FKInjectorDetector.h/.m` | 从环境注入器字典构建识别模型 |
| Helper | `FKHelperEvidence.h/.m` | Helper 验证证据：路径、文件类型、归属包、包来源、版本、可执行、摘要、签名、签名主体、信任链来源、验证时间 |
| Helper | `FKHelperTrustStore.h/.m` | 可信锚点策略与策略版本；本期无可信锚点，恒返回未信任，不把单次摘要当成可信凭据 |
| Helper | `FKHelperTrustEvaluator.h/.m` | 综合评估入口：复用身份 / 签名 / 权限验证器，采集证据并逐级定级；状态不按顺序自动推进；IPC 恒未验证 |
| Helper | `FKIPCRequest.h/.m` | 结构化请求模型：协议版本、请求 ID、操作、插件 ID、时间戳、nonce、授权上下文；本地结构校验 |
| Helper | `FKIPCResponse.h/.m` | 结构化响应模型：协议版本、请求 ID、状态、结果、错误；本地结构校验 |
| Operation | `FKOperationRequirement.h/.m` | 准入必要条件定义：条件 ID、标题、是否必需、摘要 |
| Operation | `FKOperationPolicy.h/.m` | 默认策略：`preview_only`、`allowsRealOperation = NO`、必要条件 ID 列表 |
| Operation | `FKOperationEligibility.h/.m` | 准入结论：模式、是否合格、状态、单项检查、阻止原因、生效策略 |
| Security | `FKSecurityEvent.h/.m` | 安全事件：事件 ID、类型（9 类）、时间、目标、结果、原因、证据；JSON 往返 |
| Security | `FKSecurityEvidenceStore.h/.m` | 追加式存储，锁保护；按类型 / ID 查询；不提供修改或删除历史接口 |
| Security | `FKSecurityReport.h/.m` | 汇总事件、按类型 / 结果计数、生成时间 |
| Security | `FKSecurityAuditManager.h/.m` | 门面：记录事件并生成安全报告 / JSON |
| Tests | `FKTestRunner.h/.m` | 汇总各测试套件并返回失败描述 |
| Tests | `FKModelTests` / `FKBackupTests` / `FKJSONTests` / `FKOperationTests` | 模型往返、备份清单往返、非法输入安全忽略、协议与闸门最小校验 |

既有 `FKHelperIdentityVerifier` / `FKHelperSignatureVerifier` / `FKHelperPermissionVerifier` / `FKHelperTrustVerifier` / `FKHelperProtocol` / `FKOperationGate` / `FKHelperTrust` 在原类上扩展，未重复实现底层引擎。

## 三、A 环境识别与兼容性

- 环境证据不只记录结论：jbroot 与注入器分别留存路径、存在性、目录、可读、来源、置信度等可核对字段。
- 兼容性五态保守派生：环境识别成功且必要目录可访问为 Passed；部分目录不可访问为 Partial；明确检测到不兼容条件为 Failed；证据不足为 Unknown；不在支持范围为 Unsupported。
- **不因单项权限不足误判整体环境**：文件访问失败可能来自沙盒权限、路径映射或系统版本差异，只归 Partial / Unknown，不直接判 Failed。
- jbroot 定位使用 FileManager 只读探测；`filesystem` 字典作为补充证据入口保留，本期以环境字典与只读探测为准。

## 四、B 注入器识别与兼容性

- 能力以 Profile 表达，不把能力写死在判断代码里；内置四类常见注入器基线画像，后续可逐步扩充。
- **启停能力必须由真实验证结果决定**：0.1.4 未接入已验证的启停机制，`pluginEnable` / `pluginDisable` 恒为 NO，`managementVerified` 为 NO；不因注入器支持 Filter 就推断它支持安全启停。
- 兼容性按规则解析、App 定向、全局注入三项能力核对；证据级别不足时降为 Partial / Unknown，不臆断完全兼容；不因 dylib 存在推断插件已启用。
- 未登记注入器归 Unknown，返回证据不足原因。

## 五、C RootHelper 身份与签名验证

- 身份核对至少覆盖：实际路径、文件类型、归属软件包、包来源、版本、可执行权限、文件摘要、代码签名、签名主体、信任链来源。
- 可信来源分三档：官方可验证签名与信任链、已确认发行者可信公钥可进入可信验证流程；仅有文件名 / 路径或普通 MD5 不足以建立身份信任。MD5 / SHA-256 用于记录身份与变化，本身不证明发布者身份。
- **无可信锚点不判定可信**：本期未配置官方签名链或可信公钥，`FKHelperTrustStore` 恒返回未信任；签名验证需要可信锚点，有有效自签名也不视为可信，结论保守为 Unverified。
- 信任策略带版本管理，不把一次扫描得到的文件摘要永久当作可信凭据。
- 状态逐级推进但不自动跳级：发现 Helper 不等于身份验证成功；签名通过也不代表权限模型安全；每个状态都有独立证据。IPC 通道本轮未建立，恒标记未验证。

## 六、D 安全准入闸门

- 准入条件覆盖：环境已识别且兼容、注入器支持目标插件、插件身份确认、路径确认、包归属无冲突、完整性无未解释严重异常、Helper 身份 / 签名 / 权限验证、IPC 验证、操作策略有依据、备份完整且验证通过、用户明确授权。任一必要条件不满足即不能进入真实操作。
- 高层评估接口 `eligibilityForPlugin:operation:environmentOK:injectorCompatible:helperReport:backupAvailable:userAuthorized:` 汇总既有基础检查与新增环境、注入器兼容性、授权检查项。
- **闸门由证据动态计算**：UI 不能直接 `operationGate.enabled = YES`；结论依据 Helper 验证结果、插件兼容性、操作策略、备份结果与当前授权状态得出。
- 0.1.4 策略不允许真实操作：存在阻断项为 `blocked`；无阻断项但策略不开放真实操作时停留在 `preview`，不进入 `ready`。

## 七、E Helper IPC 协议

- 本期只完成协议数据模型、请求 / 响应解析、版本兼容检查、白名单策略、非法请求拒绝与超时 / 错误状态处理；不接入真实 Helper 端点。
- 请求结构：`protocol_version` / `request_id` / `operation` / `plugin_id` / `timestamp` / `nonce` / `authorization`；响应结构：`protocol_version` / `request_id` / `status` / `result` / `error`。
- 校验复用既有协议层：协议版本、操作白名单、插件 ID 非空、时间戳窗口。
- **边界说明**：`request_id` / `timestamp` / `nonce` 只是协议辅助字段，不构成身份认证；nonce 本期仅记录，缓存去重与窗口校验待接入可信端点时实现。真正身份认证依赖可信 IPC 端点、调用者身份与双方认可的认证机制。
- 不执行：特权文件写入、插件启停、任意命令、任意路径操作、未经验证的 IPC 调用。

## 八、F 安全证据、日志与报告

- 记录类型覆盖：环境探测、注入器识别、Helper 发现、身份验证、签名验证、权限验证、IPC 验证、准入判断、准入拒绝。
- 审计记录采用追加方式，普通操作流程不能修改或删除历史事件；报告保留证据来源与验证时间，避免把旧验证结果误当成当前状态。
- 报告按事件类型与结果分类计数，附生成时间，可导出 JSON。

## 九、最小自动化测试骨架

- 完整测试体系原计划 0.3.0；0.1.4 提前建立最小骨架，覆盖模型序列化、备份清单往返、非法 / 空输入安全忽略、协议非法请求拒绝、未授权与未验证闸门不放行、IPC 请求本地校验。
- 测试纯 Foundation 实现，不依赖 XCTest；`FKTestRunner` 汇总各套件，返回失败描述数组，空数组表示通过。

## 十、备份 P1 收尾

- 备份完成（成功 / 失败 / 取消）发送统一通知 `FKBackupDidFinishNotification`；进度更新发送 `FKBackupProgressNotification`；备份列表监听通知自动重读索引并刷新，失败记录同样展示。
- 进行中行内展示状态、进度百分比与当前处理文件；完成行展示包归属、文件数、总大小与 SHA-256 摘要记录状态。
- 备份仍只写 App 沙盒，不覆盖旧备份，不恢复或修改系统文件。

## 十一、安全边界与待验证口径

- **本地静态检查不代表 Theos 编译或真机验收**：本地无编译工具链与设备，编译结论以 CI 日志为准，真机项只能标记待验证。
- 验收编号分类：环境 ENV201–212、注入器 INJ201–212、Helper HTR201–216、准入 OP201–212、协议 PRO201–208、审计 AUD201–206、测试 TST201–205、安全边界 SEC201。
- IPC 8 项在没有真实可信 Helper 接口前只完成协议模型与模拟测试，真实端点验证标记待验证，不算真实 IPC 通过；RootHide / Rootless 双环境回归均需真机验证。
- 0.1.3 遗留（App 列表管理器注入缺失、历史记录持久化、只读预演不入历史等）整体归入 0.1.5，不在 0.1.4 回补。

## 十二、后续版本衔接

- **0.1.5 Management Experience**：备份管理、操作历史、UI 与错误处理完善。
- **0.2.0 Controlled Plugin Operations**：满足安全门槛后开放受控启停；接入可信 Helper 端点与 nonce 防重放缓存。
- **0.3.0 Testing & Ecosystem**：完整自动化测试体系、日志体系与兼容性扩展。
- **1.0.0 Stable Release**：正式稳定版。
