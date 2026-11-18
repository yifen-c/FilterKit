# FilterKit 0.1.18 实现说明

## 源码基线与报告发现
- 基线：用户上传的 `FilterKit-0.1.17-source.zip` 与 `FilterKit-0.1.17-report.zip`。
- 报告的 Helper 状态为 DISCOVERED，reason `system_tool_candidate`；IPC `UNAVAILABLE`，Identity 未验证，Signature unsupported，真实操作关闭。
- 0.1.17 报告的运行时测试：459 项中 458 通过、1 失败；失败为 `REL1708 未验证结果不得放行`。检查源码发现该断言条件写反，本版已修复。

## 本版通信实现
新增 `FKHelperUnixSocketTransport.h/.m`：
- Unix Domain Socket stream 客户端与 Helper 侧 Listener。
- 连接前验证 endpoint 是 socket 文件；拒绝非 socket 文件和不安全路径。
- 使用 Darwin `getpeereid()` 校验连接对端 UID；记录 observed peer UID。
- 4 字节网络序长度前缀，最大 1 MiB；完整读写循环处理 EINTR / 短读短写。
- 设置收发超时；连接、发送、断开有明确状态。
- Listener 只允许指定 UID 的 Peer；Socket 父目录要求当前用户拥有且不可被组/其他用户写入；socket 权限 0600。
- 新增本机临时 Socket echo 集成测试，覆盖连接、Peer UID、帧往返、超限拒绝、断开和 endpoint 缺失。

## 重要限制
这版实现了真实 Unix Socket 传输代码，但当前工程仍只有 App Target；没有独立 Helper Target，也没有把 Listener 在 Helper 进程中启动。因此不能声称设备上已有可连接 Helper 服务。默认 Endpoint 未配置时，UI 仍应显示不可用。getpeereid 只证明内核提供的 Peer UID，不等于 Helper 发布签名、进程身份、代码完整性或完整 Peer Credential 验证。

真实 IPC Ready 仍关闭，原因包括生产发布锚点/签名验证、系统 Peer Credential 采集、独立 Helper 产物和真机生命周期证据未齐备。所有插件启停、配置修改、Injector 写入及任意注入仍禁止。

## 测试与验收
- 新增 1 套 Socket 集成测试，9 项登记断言。
- 修复 REL1708 反向断言。
- 全项目登记：42 套件 / 468 项。
- 本地可执行静态 Validator、JSON/plist、Makefile 引用和 ZIP 完整性检查。
- 未在本环境执行 Theos Objective-C 编译或 iOS 真机测试；登记断言数不是本环境实际运行通过数。
