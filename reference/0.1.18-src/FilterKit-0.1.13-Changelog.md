# FilterKit 0.1.13 变更摘要

## 新增
- `FKHelperMessageAuthenticator`：会话 ID / Key ID 绑定的 HMAC-SHA256 消息认证。
- `FKHelperReplayProtector`：Request ID 与 Nonce 原子防重放、时间窗及缓存上限。
- `FKHelperFrameCodec`：四字节网络序长度头、完整帧严格校验。
- `FKHelperTransportAssessment`：Mach Service / Unix Socket 候选证据评估。
- Helper 详情页“传输安全模型”展示。
- 四个测试套件，新增 33 项静态登记断言。

## 加固
- 严格密钥长度、会话标识、Key ID、签名格式与报文大小校验。
- 防重放缓存满时拒绝，不淘汰有效期内记录。
- 帧长度上限在初始化与属性更新时均受限。
- 传输证据只接受严格布尔类型，缺失证据保持未验证。
- 构建工作流、版本元数据和 Helper 开发态清单同步到 0.1.13 / 113 / FKH-0113。

## 保持不变
- 只读扫描和操作预演。
- 不创建 Helper Target / Root Daemon / launchd 服务。
- 不实现真实 IPC Transport。
- 不开放插件启停、注入、配置写入、安装卸载或系统文件恢复。

## 验证
- 静态项目校验通过。
- 27 个测试套件登记 318 项断言。
- 未执行 Theos 编译、Objective-C 测试运行或真机验收。
