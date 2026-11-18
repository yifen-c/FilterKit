# FilterKit 0.1.11 实现说明

## 版本定位

**0.1.11 — Helper Discovery Evidence**

本版本以用户上传的 `FilterKit-0.1.10-source.zip` 为唯一代码基线。用户确认 0.1.10 已在线编译成功；本轮在该源码包上继续增量开发，不回退到 0.1.9，也不改写历史版本说明。

| 项目 | 0.1.11 |
|---|---|
| App Version | 0.1.11 |
| CFBundleVersion / DEB Version | 111 / 0.1.11 |
| Helper Identity | 0.1.11 / FKH-0111 |
| Protocol | 1.0（兼容，不升级） |
| Manifest | development；无 Helper artifact / 无可信签名锚点 |
| 运行策略 | preview_only；真实操作关闭 |

## 一、主要改进

### 1. 候选元数据严格校验

修改 `Sources/Helper/FKHelperMetadata.h/.m`：
- 增加 `candidateSchemaValid`、`validationIssues`、`fileType`、`pathIsAbsolute`、`pathHasTraversal`。
- `exists`、`regular_file`、`executable` 必须是值为 0/1 的 NSNumber；不再对任意对象调用 `boolValue` 后静默接受。
- 校验路径必须为绝对路径，拒绝 `..` 路径穿越。
- 校验文件类型、大小、包 ID 列表、版本、Helper ID、协议版本的数据类型。
- `missingFields` 与 `validationIssues` 分开：前者表示证据缺项，后者表示输入结构/安全校验失败。
- 文件可读性只作为只读观察字段，不作为身份可信证据。

### 2. Discovery 状态更保守

修改 `FKHelperDiscovery` / `FKHelperServiceDiscovery`：
- 路径不安全、字段类型错误、非普通文件 → Invalid。
- 文件存在但不可执行 → Incomplete。
- 系统工具候选继续单独降级。
- Scanner 的 RootHelper 只读预检改用 `lstat`，明确区分 regular / symlink / directory / other，并把逐候选报告写入 `roothelper_preflight.discovery_report`。
- 对结构不安全的候选，不再调用 `isReadableFileAtPath:`；避免可读性探测跟随未经校验的符号链接。
- 只有路径、文件形态、可执行性、身份/版本/包归属/协议元数据齐备时才返回 Found。
- Discovery 永远不返回 Verified；Found 仅是候选形态匹配，不代表签名、完整性、Peer 或 IPC 已通过。

### 3. 新增可导出的发现证据报告

在现有 `FKHelperServiceDiscovery` 上新增 `discoveryReportForCandidates:`，不新建重复 Discovery 类。报告包含：
- schemaVersion、生成时间、候选总数；
- Found / Incomplete / Invalid / NotFound 计数；
- 每个候选的 endpoint 与完整 metadata JSON；
- 最优匹配候选路径；
- `trustStatus=unknown`、`realIPCReady=false`、`writeOperationsAllowed=false`；
- 下一步动作提示。

报告不会连接候选服务，不会执行候选文件，也不会推断真实 Helper 已安装。

### 4. 不安全候选早停

修改 `FKHelperTrustEvaluator`：对路径不安全、元数据结构错误、非普通文件、不可执行文件、系统工具候选，在文件摘要/签名/身份验证读取前结束评估。保留发现状态与原因码，避免把未经验证的候选路径传递给后续文件读取验证器。

### 5. 测试扩展

扩展既有 `FKHelperDiscoveryTests`，新增 SRV909–SRV916：
- 相对路径拒绝；
- 路径穿越拒绝；
- 字段类型错误拒绝；
- 不可执行候选降级；
- 发现报告计数与安全边界；
- 混合非法候选批量处理不崩溃、不提升为 Found/Verified；不存在的文件正确归 NotFound；符号链接不冒充普通文件。

发现套件由 8 项登记断言增加至 16 项；全项目静态登记断言由 264 增至 272。断言登记数不等于实际执行通过数。

## 二、版本与文件

- `FilterKit-Info.plist`：0.1.11 / 111。
- `control`：DEB Version 0.1.11。
- `Sources/Core/FKScanner.m`：报告版本 0.1.11。
- `FKHelperIdentity` 与 `FKHelperTrustEvaluator`：FKH-0111。
- `helper-release-manifest.json`：0.1.11 / FKH-0111，仍为 development，artifacts 为空。
- GitHub Actions artifact 名称更新为 `FilterKit-0.1.11-*`。
- 保持既有 `Sources/Helper/` 平铺结构和现有类名，无新增编译源文件。

## 三、安全边界

本版本仍不包含：
- 真实 Helper Target / Root Daemon / launchd 服务注册；
- 真实 Mach IPC / Unix Socket Transport；
- 真实签名链与可信公钥锚点；
- 真实插件/配置读取 Provider；
- 插件启停、Injector 配置修改、Filter 写入、系统文件恢复、任意命令执行。

发现报告中的 `Found` 不可用作操作授权；`trustStatus` 保持 `unknown`，真实 IPC 与写操作保持关闭。

## 四、验证状态

本轮应执行：
1. `node scripts/validate-project.js`（检查 22 套件/272 项静态断言登记）；
2. `unzip -t FilterKit-0.1.11-source.zip`；
3. 检查 plist、DEB control、扫描报告、Helper Identity、Manifest 版本一致；
4. 检查 Makefile 所有 `.m` 引用存在，测试套件登记一致。

用户已确认 0.1.10 在线编译成功；**0.1.11 本轮未在本执行环境中运行 Theos / 在线 CI / 真机编译**。因此不能将 0.1.11 描述为已编译通过。交付后请用相同 RootHide arm64e 在线构建流程验证。

## 五、下一版本建议

0.1.12 优先做 Helper Deployment Feasibility 的静态/受控探针设计：梳理 App 与 Helper 的目标形态、运行身份、Mach Service 名称约束、entitlements 需求和服务生命周期验证清单。先不创建持久化 Root Daemon，不安装、不启动、不调用 launchctl。只有用户确认平台能力与权限模型后，再实现真实 Transport。
