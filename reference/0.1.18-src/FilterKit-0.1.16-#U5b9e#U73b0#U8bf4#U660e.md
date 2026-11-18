# FilterKit 0.1.16 实现说明

## 基线
- 源码：用户上传 `FilterKit-0.1.15-source.zip`。
- 设备报告：用户上传 `FilterKit-0.1.15-report.zip`，版本 0.1.15。
- 报告记录 402 项测试已执行、402 通过、0 失败；Helper 状态仍为 `DISCOVERED`，签名 `unsupported`，Manifest / IPC `unavailable`，`real_operation_allowed=false`。
- 本版只在该源码副本上增量修改。

## 统一协调器
新增 `FKHelperAuthenticatedSessionManager`：
1. 统一持有握手状态机、Peer Binding、Key Confirmation、Session Lifecycle 与 Key Lifecycle。
2. 只接受 `FKHelperKeyLifecycle` 创建并持有的会话密钥。
3. 校验 Helper ID、Build ID、外部凭据摘要；再验证 client/helper 两个角色的 HMAC 确认码。
4. 严格顺序推进状态机，完成双向确认后才建立本地只读会话。
5. 活跃会话拒绝覆盖和重复建立；锁保护握手竞争。
6. 断线、超时、时钟倒退和认证失败撤销密钥、清空会话 ID 并记录审计。
7. `source` 仅允许 `mock` 与 `unsupported`，调用方不能将本地模型伪装为 `real_ipc`。

## 新增测试
`FKHelperAuthenticatedSessionTests` 新增 15 项登记断言，覆盖：
- 初始状态与只读授权门槛；
- 完整双向确认、重复握手与会话覆盖拒绝；
- 活跃会话触达；
- 断线失效和密钥撤销；
- 断线后的重新握手；
- Helper Build ID 错配；
- 错误确认码与失败态；
- 禁止伪造 `real_ipc` 来源；
- 两个并发握手只能有一个成功建立。

## 安全边界
本版没有实现真实 Helper Target、Daemon、Mach IPC / Unix Socket、系统 Peer Credential 采集、可信密钥分发或真实 IPC ready。认证协调器是本地模型，不授予真实系统操作能力。插件启停、Injector 配置写入、注入与系统文件修改仍关闭。
