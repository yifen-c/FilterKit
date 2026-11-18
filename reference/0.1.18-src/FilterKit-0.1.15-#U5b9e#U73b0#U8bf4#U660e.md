# FilterKit 0.1.15 实现说明

## 版本定位
Authenticated Handshake Completion：双向密钥确认、严格握手状态机、Peer 绑定与会话生命周期。基线为用户上传且在线编译成功的 0.1.14。

## 0.1.14 设备报告核对
上传报告记录于 2026-11-14，环境识别为 RootHide，注入器为 ElleKit 1.2-3；扫描到 2 个插件。Helper 信任状态为 `DISCOVERED`，签名不支持、Manifest 不可用、IPC 不可用，`real_operation_allowed=false`。测试汇总为 355 项，350 通过、5 失败。

报告中的 5 个失败项为：PRO805（协议版本错误码）、PRO806（Request ID 错误码）、PRO812（测试响应缺少完整字段）、RTE912（无 Provider 时未校验 pluginID）、DEP1204（缺失证据分类不符合测试预期）。本版逐项修复，未通过放宽响应校验来消除失败。

## 本版新增
- `FKHelperKeyConfirmation`：基于 HMAC-SHA256 的客户端/Helper 双向确认，角色域分离，并绑定 Session ID 与转录摘要。
- `FKHelperHandshakeStateMachine`：严格顺序状态机，必须逐步提供严格布尔证据；不允许跳步或字符串 YES 冒充证据。
- `FKHelperPeerBinding`：绑定 Helper ID、Build ID、外部系统 Peer 凭据摘要及握手转录摘要。凭据摘要必须由未来真实 Transport 提供，本模块不会伪造。
- `FKHelperSessionLifecycle`：要求 Peer 验证和双方密钥确认后才能建立会话，支持最大寿命、空闲超时和主动失效。
- Helper 详情页增加上述四项能力与认证审计状态。

## 对报告失败项的修复
上传的 0.1.14 设备报告显示 355 项中 350 通过、5 失败：PRO805、PRO806、PRO812、RTE912、DEP1204。本版逐项处理：
1. PRO805：协议主版本错误返回 `UnsupportedProtocol`。
2. PRO806：缺失 Request ID 返回 `InvalidRequestID`。
3. PRO812：测试响应补齐 method 与 `ok` 状态，保持响应验证严格，不降低校验标准。
4. RTE912：`plugin.inspect` 参数在 Provider 分支之前校验；无 Provider 也拒绝缺少 pluginID。
5. DEP1204：未知证据键明确阻止评估通过。

另将 Nonce 缓存达到 4096 上限时的行为改为 fail-closed：不淘汰有效期内的记录，直接拒绝新请求。

## 安全边界
本版只增加协议与生命周期模型，不实现真实 Transport、系统 Audit Token 采集、Helper 进程、密钥跨进程分发、签名锚点或生产级密钥协商。HMAC Key Confirmation 只证明双方持有相同会话密钥；不能替代可信密钥来源或 Peer 验证。真实 IPC、特权启动和插件写操作仍关闭。

## 版本
App 0.1.15 / Build 115；Helper Build ID `FKH-0115`；协议仍为 1.0；发布通道 development。
