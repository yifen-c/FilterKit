# FilterKit 0.1.5 实现说明（Integration & Verification / 主流程集成与验收版）

0.1.5 在 0.1.4 兼容性与安全验证骨架之上，把已写好但未接线的环境、注入器、Helper、闸门、审计、测试六模块真正接入 Scanner 主流程、报告 JSON、UI 与审计闭环。核心口径：**类存在并编译通过 ≠ 功能落地**；每个新结论都要能在扫描产物中找到对应键值，单模块失败隔离不崩扫描，未执行验收项标 `NotTested`，不凭编译通过预填通过。版本号为 **0.1.5**。

## 一、定位与边界

- **定位**：回答「0.1.4 骨架产出的环境 / 注入器 / Helper / 闸门 / 审计 / 测试结论，是否真正进入了扫描主流程、报告 JSON 与用户可见界面，形成可追溯闭环」。
- **只读预检（PreviewOnly）**：不开放真实启停、不连接未验证 Helper IPC、不修改任何越狱环境文件；备份只写 App 沙盒，不恢复、不覆盖旧备份。
- **保守结论原则**：无可信 Helper 锚点即 `Unverified`；启停 / 卸载能力未经真实验证恒 `Unknown`；环境 / 注入器兼容性 / 用户授权在预演中保守按未满足处理，闸门不据此放行真实操作。
- **本版本仍不开发（推迟 0.2.0+）**：真实 Helper IPC、插件真实启停 / 卸载、真实恢复备份、RootHelper / Daemon、注入器自动修改、自动修复越狱环境。
- **无任意命令执行器**：不存在 `installPackage` / `uninstallPackage` / `launchctl` / `system(` / `popen(` / `NSTask` / `posix_spawn` / `executeCommand` 等特权写或命令执行入口。

## 二、主流程接线（相对 0.1.4 的变化）

### 1. 环境与注入器画像接入扫描结果

- `FKScanReport` 新增 `environmentAssessment` / `injectorAssessment` 结构化评估字典。
- Scanner 末尾：
  - `FKEnvironmentDetector modelFromEnvironment:filesystem:` 生成环境模型；
  - `FKInjectorDetector modelFromDictionary:` 识别注入器，再由 `FKInjectorRegistry profileForInjector:` 补充能力画像；
  - 两个私有辅助方法各自 `@try/@catch` 隔离，单模块异常只回填降级字典，不影响其余扫描结果。
- 注入器解析 / 定向 / 全局能力取自注册表基线规则（YES→Passed，NO→Failed）；启停 / 禁用 / 卸载三项恒 `Unknown`。

### 2. Helper 信任评估与新准入闸门

- 主控制器 trustReport 改由 `FKHelperTrustEvaluator evaluateCandidates:store:` 汇总身份 / 签名 / 权限 / IPC 证据；旧 `FKHelperTrustVerifier` 类保留不删。
- 预演确认页切换到高层 `FKOperationPreflight eligibilityForPlugin:operation:environmentOK:injectorCompatible:helperReport:backupAvailable:userAuthorized:`，准入结论与阻止原因取结构化 `FKOperationEligibility`；环境 / 注入器兼容 / 用户授权在预演中保守传 `NO`。

### 3. 审计持久化与安全报告闭环

- `FKOperationRecord` 补 `recordFromDictionary:` 反序列化。
- `FKAuditManager` 改为沙盒 JSON 持久化：启动加载、串行队列原子写、损坏文件改名隔离不覆盖、`schema_version`、append-only、持久化状态摘要（含是否隔离损坏文件、最近一次写入错误）。
- `FKSecurityAuditManager` 绑定环境 / 注入器 / Helper / 闸门 / 测试快照；事件类型扩充扫描开始 / 完成 / 备份 / 测试执行 / 报告导出。
- 主控制器扫描开始记 `ScanStarted`；`attachSecurityAuditToReport:` 汇总各评估事件、运行测试、生成 `securityReport` 与 `testSummary` 回写报告。

### 4. 备份审计回写

- 备份取消 / 失败 / manifest 失败均清理半成品目录；重复备份使用新 UUID 目录不覆盖；SHA-256 重读不一致标失败（沿用 0.1.2 / 0.1.3 既有路径）。
- 新增备份成功 / 失败 / 取消回写操作历史：`FKBackupManager` 弱引用注入 `FKAuditManager`，任务完成回调统一调 `recordBackupAuditWithResult:error:`；Helper 未验证前 `helperStatus` 恒记 `unverified`。

### 5. 自动化测试汇总

- 四套件（Model / Backup / JSON / Operation）补 `checkCount` 用例计数（5 / 5 / 7 / 8）。
- `FKTestRunner` 保留 `runAllChecks`，新增 `runSummary` 结构化汇总：逐套件 `@try` 隔离，`passed = count - failed`，输出 `executed / total / passed / failed / skipped / status / suites`。
- 扫描后实际运行 `runSummary`，回填安全审计快照与报告顶层 `test_summary`。

## 三、报告 JSON 顶层段

0.1.5 报告顶层在既有 `version / generated_at / environment / tests / app_enumeration / filesystem / plugins / association / summary` 基础上，新增或回填：

| 键 | 来源 | 说明 |
|---|---|---|
| `environment_assessment` | 环境模型 JSON | 兼容性五态、原因、证据 |
| `injector_assessment` | 注入器模型 + 注册表画像 | 识别结果、能力基线、启停能力 Unknown |
| `helper_trust` | 信任评估报告 | 状态码 / 文案 / 签名 / 身份 / 原因 / 证据 |
| `security_report` | 安全审计管理器 | 事件链、四桶计数、各快照、测试摘要 |
| `test_summary` | 测试运行器汇总 | 执行 / 通过 / 失败 / 跳过 / 分套件明细 |

## 四、UI 接线与缺陷修复

- 修复 App 列表 `appsController` 只注入 `appManager` 的缺陷，补齐 state / operation / audit / backup / trustReport，与插件列表页一致；从 App 或插件任一入口进入详情页功能相同。
- 详情页在操作 / 备份管理器缺失时弹提示，不再静默跳过；备份审计回写前判空。
- 设置页补充「环境兼容性」「自动化测试」两行展示；导出报告 / 备份成功后记录 `ReportExport` / `Backup` 安全事件并刷新安全报告快照。

## 五、校验与回归

- `scripts/validate-project.js` 新增 0.1.5 接线断言：报告 JSON 五段、主控制器评估器 / 测试汇总 / 备份审计回写 / 导出事件、预演页新闸门、测试汇总计数、审计持久化字段；安全边界扫描保持无特权入口。
- 本地静态回归：源码 `.m` 与 Makefile 清单一致、`#import` 可解析、`@interface/@implementation` 与 `@end` 配平、花括号配平、版本三处（control / Info.plist / Scanner）一致。
- 本地无 Theos / SDK / 设备，**编译与真机结论以远端 CI 与真机导出 JSON 为准**；本说明与静态校验不代表 Theos 编译通过或真机验收。

## 六、未决与下一轮

- 真机导出报告需核对：五个新段键值非空、测试汇总数字与套件明细一致、审计历史在沙盒持久化并可回读。
- 0.1.5 独立验收编号（INT / ENV / INJ / HTR / OP / AUD / BK / TST）逐项在真机标注 Passed / Failed / NotTested，未执行项不得标通过。
- 真实 Helper IPC、真实启停 / 卸载、真实恢复备份、RootHelper / Daemon 推迟 0.2.0+。
