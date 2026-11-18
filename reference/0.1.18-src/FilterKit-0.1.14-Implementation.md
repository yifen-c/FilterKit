# FilterKit 0.1.14 实现说明

## 版本定位
Authenticated Handshake Foundation：认证握手基础模型完善版。以 0.1.13 用户上传且确认修复后可在线编译的源码为唯一基线。

- App：0.1.14 / Build 114
- Helper 逻辑标识：FKH-0114
- IPC Protocol：1.0（本版不升级线上协议）
- 测试登记：31 套件 / 355 项

## 新增模块

### 1. HKDF-SHA256 会话密钥派生
`FKHelperKeyDerivation` 按 RFC 5869 实现 Extract/Expand，限制输入密钥至少 256 bit、输出 1…8160 字节。会话派生输入绑定客户端随机数、Helper 随机数、Peer ID 和协议版本，使用长度前缀避免字段拼接歧义。

### 2. 会话密钥生命周期
`FKHelperKeyLifecycle` 使用系统 `arc4random_buf` 生成 256 bit 内存密钥，支持有效期、到期失效、轮换和撤销，并覆盖标准 HKDF 测试向量及旧密钥清理检查。Key ID 使用独立随机值，不暴露密钥材料。替换、到期和撤销时尽力清零内部可变缓冲区。密钥不写磁盘，也不跨进程分发。调用方不得长期持有 `keyData` 引用。

### 3. 协议版本协商
`FKHelperProtocolNegotiator` 严格校验双方版本列表，拒绝空列表、重复条目、布尔值、浮点数、越界版本和未知结构；只接受双方共同支持的精确版本，优先最高主版本和次版本。没有交集即拒绝，不静默降级。

### 4. UI 状态
Helper 详情增加认证握手、会话密钥生命周期和协议协商状态说明。当前显示均为模型能力，不代表真实 Helper 握手已经完成。

### 5. 握手转录绑定
`FKHelperHandshakeTranscript` 对双方 ID、Build ID、Nonce、协议版本及只读能力生成规范 JSON 和 SHA-256 摘要。能力列表排序后参与摘要；未知字段、重复能力、写能力和非法版本直接拒绝。该摘要可用于后续双向 Key Confirmation，但当前尚未接入真实握手。

## 测试
新增四套：
- `FKHelperKeyDerivationTests`：9 项
- `FKHelperKeyLifecycleTests`：11 项
- `FKHelperProtocolNegotiationTests`：8 项
- `FKHelperHandshakeTranscriptTests`：9 项

新增 37 项静态登记断言；总计 31 套件 / 355 项。

## 安全边界
- 未实现密钥协商或安全跨进程传输；HKDF 的输入密钥必须来自未来已验证的可信握手，禁止使用硬编码或测试密钥。
- 未接入 Keychain、Secure Enclave 或 Helper 端密钥仓库。
- 未实现真实握手状态机联动、双向确认、密钥确认 MAC 或真实 IPC。
- 不创建 Helper Target / Daemon，不执行 launchctl，不修改 Injector 规则。
- 不开放插件启停、注入、配置写入、安装卸载或恢复。

## 验证状态
仅进行项目静态检查、版本/JSON/Makefile/测试登记/ZIP 完整性检查。未执行 Theos 编译、Objective-C 测试运行、签名、部署或真机测试。静态登记数量不等于运行通过。
