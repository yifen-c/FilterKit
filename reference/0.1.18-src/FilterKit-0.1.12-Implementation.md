# FilterKit 0.1.12（Helper Deployment Feasibility / 部署可行性评估版）

0.1.12 基于用户上传且已在线编译成功的 0.1.11 源码增量开发。此版本不创建、不安装、不启动 Root Helper 或 launchd Daemon；先把部署前置条件变成可审计的结构化证据，避免把计划、静态配置或模拟数据误报为真机能力。

## 本版改动

- 新增 `FKHelperDeploymentAssessment`：集中评估独立 Helper Target、可信签名锚点、签名、独立 Entitlements、Mach Service、Peer 身份、Transport、生命周期，以及 RootHide arm64e / rootless arm64 两套真机证据。
- 证据必须是严格的布尔值；缺失、字符串、非 0/1 数值和未知键均不能通过。
- 新增 Mach Service 名称格式校验；只验证命名格式，不代表服务已注册。
- 新增 `helper-deployment-profile.json`，记录目标形态、未决事项和平台矩阵。
- 新增 13 项 DEP1201–DEP1213 测试，测试套件增加到 23 个，静态登记断言为 285 项。
- App 与 Helper 的 Entitlements 明确分离原则；不复制现有 App 的私有 / platform entitlement 到未来 Helper。当前配置仍需安全审查，不据此推断任何 entitlement 已获系统授权。

## 目标形态与决策

- App：继续作为普通 UI / 扫描客户端。
- Helper：未来独立可执行 Target，使用独立签名与最小权限 Entitlements；本版没有创建该 Target。
- 服务发现：Mach Service 名称 `com.filterkit.helper` 仅作为待评估命名，不代表 launchd 注册存在。
- Transport：Mach IPC 与 Unix domain socket 仍是候选方案；未在 RootHide arm64e 和 rootless arm64 真机比较，暂不选型。
- 生命周期：拉起、退出、崩溃恢复、重连和升级兼容均未实现。
- 身份信任：Manifest 仍为 development、artifacts 为空、可信公钥锚点为空；不建立信任结论。

## 安全边界

`daemonDeploymentAllowed=false`、`privilegedLaunchAllowed=false`、`realIPCReady=false`、`writeOperationsAllowed=false` 固定保持关闭。即使传入完整证据使可行性状态显示 `feasibility_evidence_complete`，也只代表证据字段齐全，不代表发布批准、部署授权或写操作许可。

本版没有调用 `launchctl`、没有创建 LaunchDaemon plist、没有添加 Helper Target、没有新增特权命令执行入口，也没有实现插件启停、注入器配置写入或系统文件恢复。

## 构建信息

- App Version：0.1.12
- Build：112
- Helper 逻辑版本：0.1.12 / FKH-0112
- IPC Protocol：1.0
- 测试套件：23
- 静态登记断言：285

## 验收说明

`node scripts/validate-project.js` 用于静态结构、版本、源文件和测试登记检查。未在当前环境运行 Theos 编译或真机测试；请分别在线编译 RootHide arm64e 与 rootless arm64 包，再在真机核对 App entitlements 与文件访问行为。静态检查不等于 Objective-C 测试执行通过。
