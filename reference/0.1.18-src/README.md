# FilterKit 0.1.18（Unix Domain Socket IPC Transport）

基于用户上传并确认的 FilterKit 0.1.17 源码与设备报告增量开发，优先处理 Helper 通信 Transport。

## 版本
- App：0.1.18 / Build 118
- Helper 逻辑标识：FKH-0118
- IPC Protocol：1.0
- 测试登记：42 套件 / 468 项断言（新增 1 套件 / 9 项）

## 本版新增
- Unix Domain Socket Transport 客户端与 Helper 侧 Listener。
- Darwin `getpeereid()` Peer UID 校验；可配置预期 UID。
- 4 字节网络序长度前缀帧，最大 1 MiB。
- 收发超时、完整读写循环、EINTR 处理和明确的连接/失败/断开状态。
- Listener 的 UID 白名单、父目录权限检查、拒绝覆盖非 Socket 文件、0600 默认权限；可显式配置 0660 + GID。
- 本地 Socket echo 集成测试，覆盖连接、UID 匹配/不匹配、报文往返、超限拒绝、断开和 Endpoint 缺失。
- 修复 0.1.17 设备报告中 `REL1708` 断言条件写反的问题。

## 当前通信边界
Transport 代码已经实现，但项目仍只有 FilterKit App Target，没有独立 Helper Target，也没有在 Helper 进程中启动 Listener。没有真实 Helper 服务和配置 Endpoint 时，设备 UI 仍应显示 Endpoint Unavailable / Connection 不可用。`getpeereid()` 只验证内核提供的 Peer UID，不等同于 Helper 发布签名、进程 PID、代码完整性或完整 Peer 身份认证。消息 HMAC/握手模型也尚未与 Socket 运行时打通。

因此 `realIPCReady`、只读能力、写操作能力仍全部关闭。插件启用/禁用、配置修改、Injector 写入和任意注入继续禁止。本版不创建 launchd Daemon，不自动启动特权进程。

## 验证边界
本次完成项目静态 Validator、JavaScript 语法、plist、JSON、Makefile 源文件引用、测试登记统计与 ZIP 完整性检查。42 套件 / 468 项是登记数量，不代表本开发环境实际执行通过。未执行 Theos Objective-C 编译或 iOS 真机测试；需由用户在线编译并运行本机 Socket 集成测试。
