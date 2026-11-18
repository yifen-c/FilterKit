# FilterKit 0.1.3 实现说明（Stability & Modularization / 稳定性完善与模块化重构版）

0.1.3 在 0.1.2 安全管理与操作预演版之上，进入稳定性与模块化阶段：备份改为异步执行并提供进度 / 状态反馈，界面控制器按职责拆分到独立目录，操作历史记录字段完善，环境兼容性结论基于证据保守派生。管理功能仍为只读预演，真实特权操作默认关闭。

> 安全口径：本版本**不以开放真实启停为发布目标**。Helper 身份缺官方渠道白名单、签名未接 SecStaticCode 签名链、权限未核对真实授权上下文、IPC 通道本轮未建立，因此信任结论保守停留在已发现 / 证据不足；准入闸门默认 `PreviewOnly`。备份只写入 App 沙盒，不覆盖越狱文件；恢复仅生成预览，不执行系统文件覆盖。

## 一、0.1.3 新增

- **备份异步化（`FKBackupResult` / `FKBackupOperation` / `FKBackupManager` 扩展）**：备份任务进入串行后台队列执行收集、复制、哈希、校验与清单提交；逐文件进度与完成状态回调回主线程，状态区分等待 / 备份中 / 校验中 / 完成 / 失败 / 已取消；取消仅清理未提交的半成品目录，不触碰历史备份。原有同步接口保留为兼容包装。
- **控制器模块化拆分（`Sources/Views/`）**：主标签、App / 插件列表、详情、导入、设置、操作预演确认、操作历史、备份列表、备份详情分别落到 `Main / List / Detail / Import / Settings / Operation / Backup` 子目录；只搬迁结构与职责，不改既有业务逻辑与界面行为。
- **操作历史完善（`FKOperationRecord` 扩展）**：记录追加操作模式、检查项、阻止 / 存疑原因与 Helper 状态字段，JSON 向后兼容；备份操作结果也写入审计历史。
- **环境兼容性识别（`FKScanner` 环境段）**：依据根目录与注入器证据派生 `passed / partial / unknown` 结论及原因列表；证据不足归 Unknown / Partial，不因未发现 Helper 直接判 Failed。

## 二、保留的 0.1.2 能力

- **流式双摘要（`FKFileHasher`）**：64KB 分块读取，不把整个 dylib / 资源一次性载入内存；MD5 对照 dpkg `.md5sums` 既有格式，SHA-256 用于备份前后内容一致性核对。MD5 弃用告警在调用函数内局部抑制，不全局放宽 `-Werror`。
- **备份清单（`FKBackupManifest` / `FKBackupFileEntry`）**：逐条记录原始路径、备份相对路径、大小、粗类型、权限位、所有者、修改时间、符号链接目标、MD5 与 SHA-256；清单记录插件、软件包、操作类型、时间与格式版本。权限 / 所有者 / mtime / 链接信息仅记录留档，不自动应用到系统文件。
- **真实文件备份（`FKBackupManager` 扩展）**：把插件直接关联的 dylib 与 Filter plist 复制到受保护沙盒目录，计算双摘要并重读校验；原子写入，失败清理半成品目录，重复备份不覆盖旧记录；索引持久化到 `index.json`。
- **恢复预检查（`FKBackupValidator`）**：重读备份目录文件重算 SHA-256 比对；结合备份清单与当前扫描模型给出六态结论（理论可恢复 / 目标已改动 / 备份损坏 / 归属变化 / 路径不匹配 / 证据不足）与原因列表，只生成预览，不覆盖系统文件。
- **Helper 信任层（`FKHelperTrust` / 三个独立验证器 / `FKHelperTrustVerifier`）**：身份、签名、权限分别验证，编排逐级状态机；签名状态区分已验证 / 未验证 / 未知；协议层追加结构化请求 / 响应报文校验与时间戳防重放窗口。
- **准入闸门（`FKOperationGate` / `FKOperationPreflight`）**：汇总插件身份、路径、归属、注入器、格式、操作方法、备份可用性、影响可评估性与 Helper 安全门槛；输出通过 / 警告 / 不满足 / 证据不足 / 已阻断单项结论，综合判定 `PreviewOnly` / `Blocked` / `Enabled`，只输出准入判断，不直接执行操作。
- **界面**：插件详情始终展示启用 / 停用 / 备份 / 历史四个入口；预演页分区展示操作目标、安全检查项、预计影响与准入结论；备份列表与备份详情（清单条目 + 恢复预览）；设置页展示 Helper 信任状态并进入备份管理。

## 三、保留的 0.1.1 状态管理框架

- **状态识别（`FKStateManager` / `FKPluginState`）**：基于 Filter 规则与可获得证据派生状态；不凭 dylib 文件存在推断已启用，无可靠证据归 Unknown / Unsupported。
- **受控操作流程（`FKOperationManager`）**：固定前置检查顺序与预演结构；重复请求防护；操作前备份、Helper 白名单执行、结果回填与审计记录骨架。
- **审计日志（`FKAuditManager`）**：追加式记录，按插件、操作类型、操作 ID 查询；JSON 导出。
- **Helper 协议骨架（`FKHelperProtocol` / `FKHelperValidator` / `FKHelperClient`）**：错误码、白名单操作枚举、目标路径越界校验；不提供任意命令执行器。

## 四、保留的 0.1.0 基础管理与 0.0.9 诊断能力

0.1.0 的模型层、只读管理器、筛选、备份导出与校验全部保留；18 项诊断验收全部保留：JBROOT 定位、DynamicLibraries 枚举、dylib / plist 扫描、Filter 解析、注入器识别、dpkg 状态 / 归属 / 元数据 / 文件完整性 / MD5 校验、插件来源、归属冲突、RootHelper 只读预检、App 枚举与元数据、插件关联。MD5 三级分类、Conffiles 双渠道识别与保守未确认策略不变。

## 五、只读与安全边界

- 不修改越狱文件、目标 App、DynamicLibraries、Filter plist 或注入配置；不启停、不安装、不卸载插件。
- 不启动 RootHelper、不执行特权命令、不发送未授权 IPC、不调用 `launchctl`；不存在任意命令 / 脚本执行入口。
- 备份只写 App 沙盒，不覆盖原始配置；导入不自动恢复系统文件；静态 Filter 关联不等于运行时注入成功。
- 真实受控启停、安装卸载、Filter 修改与 Helper 特权命令，待身份 / 签名 / 权限 / 协议验证并在测试环境验证后再逐步开放。

## 六、构建与验证

运行 `node scripts/validate-project.js` 进行静态检查。再通过 GitHub Actions 手动选择 RootHide 或 Rootless 构建，并在目标设备验收。静态检查不代表 Theos 编译成功或真机验收通过。

官方资料：
- RootHide Developer API：<https://github.com/roothide/Developer/blob/main/interface.md>
- RootHide 路径约定：<https://github.com/RootHide/Developer/blob/main/roothide.md>
- Theos packaging：<https://theos.dev/docs/packaging>
