# FilterKit 0.1.13 实现说明

## 1. 版本定位

**Helper Transport Feasibility：传输安全模型与协议边界完善版**

本版以用户上传并确认在线编译成功的 `FilterKit-0.1.12-source.zip` 为唯一基线，保留原有 Helper、Discovery、Trust、Handshake、Operation、Audit 和 UI 类体系。新增通信安全基础模型，但不宣称已建立真实 IPC。

- App Version：`0.1.13`
- Build：`113`
- Helper 逻辑版本：`0.1.13`
- Helper Build ID：`FKH-0113`
- IPC Protocol：`1.0`
- 测试套件：27
- 静态登记断言：318

## 2. 新增模块

### 2.1 `FKHelperMessageAuthenticator`

使用系统 CommonCrypto 的 HMAC-SHA256，对原始报文执行消息认证。

认证输入由固定协议域、会话 ID、Key ID 和原始报文组成；会话 ID 与 Key ID 使用网络序长度前缀，避免字段拼接歧义。密钥长度至少 32 字节，报文上限 1 MiB。验证时固定遍历比较 64 字节十六进制签名，不接受大写或非十六进制字符。

边界：
- HMAC 只证明消息持有相同密钥，不证明密钥持有者身份可信。
- 密钥生成、协商、可信分发、轮换、撤销和安全存储尚未实现。
- 本版不在 App 内置密钥，也不把测试密钥用于生产通信。
- 必须先完成 Peer 身份验证，再由可信握手层提供会话密钥。

### 2.2 `FKHelperReplayProtector`

新增会话级 Request ID / Nonce 防重放管理：
- 同时登记请求 ID 与 Nonce。
- 校验时间戳有效窗口，拒绝过期和过度超前请求。
- 操作原子化，支持并发调用。
- 缓存有容量上限；缓存满时拒绝新请求，不淘汰仍有效的记录。
- 会话结束时显式清空。

该模块为本地模型，不等于已在真实 Helper 服务端启用。

### 2.3 `FKHelperFrameCodec`

增加四字节 Big Endian 长度前缀帧格式：

`[uint32_be payload_length][payload]`

严格拒绝空载荷、不完整帧头、零长度、超长、长度不匹配和尾随数据。默认最大载荷 1 MiB，构造与属性更新均限制最大值。

该类只负责完整帧编码/解码，不负责 Socket 读取循环、分片缓存、连接或重连。

### 2.4 `FKHelperTransportAssessment`

对 Mach Service 与 Unix Domain Socket 两个候选路径进行证据评估：

- Mach Service：注册观察、Peer Audit 验证、生命周期验证、平台支持证据。
- Unix Socket：端点观察、Socket 权限验证、Peer Credential 验证、生命周期验证。

只接受严格 CFBoolean 类型的 `YES`，字符串 `"YES"`、整数 `1` 和缺失字段均不算证据。唯一候选证据齐备时可给出候选建议；两个候选都通过或都未通过时保持 Undecided。候选建议不会创建端点或启动连接。

## 3. UI 接入

Helper 详情页增加“传输安全模型”区域，显示：
- HMAC-SHA256 模型状态及密钥分发缺口。
- Request ID / Nonce 防重放模型。
- 帧长度格式和 1 MiB 上限。
- Mach Service / Unix Socket 缺失证据。
- 真实连接仍未实现。

没有输入真实设备证据时，UI 默认展示未验证，不会自动探测或连接系统服务。

## 4. 测试

新增四个测试套件：

- `FKHelperAuthenticationTests`：签名生成、成功验证、会话绑定、Key ID 绑定、篡改、密钥长度、空报文、签名格式。
- `FKHelperReplayTests`：首次接受、重复 Request ID、重复 Nonce、过期、超前时间戳、空 ID、短 Nonce、会话重置。
- `FKHelperFrameTests`：帧编码/解码、空载荷、不完整帧头、超限、尾随数据、零长度、默认上限。
- `FKHelperTransportAssessmentTests`：缺失证据、Mach / Socket 候选、严格布尔值、双候选未决和报告结构。

四个套件合计新增 33 项静态登记断言，项目总计 27 套件 / 318 项。

## 5. 安全边界

本版继续只读扫描与操作预演：
- 不创建独立 Helper Target。
- 不创建、安装、启动 Root Daemon 或 launchd 服务。
- 不实现 NSXPC、Mach 或 Unix Socket 真实 Transport。
- 不执行 `launchctl`、命令行或特权进程操作。
- 不开放 `plugin.enable`、`plugin.disable`、注入、配置写入、安装卸载或系统文件恢复。
- 不把 Mock、候选评估或静态模型报告为真实 IPC。

## 6. 验证状态

本工作副本执行了：
- `node scripts/validate-project.js`：通过。
- JSON 配置解析：通过。
- Info.plist 解析：版本 `0.1.13` / Build `113`。
- Makefile：140 个 `.m` 引用，缺失 0、重复 0。
- 测试登记：27 套件 / 318 项。

未执行 Theos / iOS SDK 实际编译、Objective-C 测试运行、签名、打包安装或真机 IPC 验收。静态登记断言不等于运行通过。

## 7. 下一阶段建议

0.1.14 建议先补齐“认证握手与密钥生命周期设计”：可信 Peer 验证后才派生会话密钥，明确密钥来源、随机数质量、密钥派生、过期、轮换、撤销、断线清理和版本协商。完成设计评审后，再在独立测试目标中验证平台支持的 IPC API；不应先接入写操作。
