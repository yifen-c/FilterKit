# FilterKit 0.1.17 实现说明

## 基线
- 源码基线：用户上传并确认在线编译成功的 `FilterKit-0.1.16-source.zip`。
- 报告基线：`FilterKit-0.1.16-report.zip` 中的 `FilterKit-0.1.16-report.json`。
- 0.1.16 报告登记 36 套件 / 417 项断言，但 `executed=false`；Objective-C 编译和真机测试字段为未执行。用户在本轮确认 0.1.16 在线编译成功。

## 本版新增
1. `FKHelperTrustAnchor` / `FKHelperTrustAnchorStore`：公钥锚点模型与仓库，默认空仓库；测试锚点不能作为生产锚点。
2. `FKHelperReleaseVerifier`：验证 Helper ID、Build ID、发布通道、架构产物 SHA-256 和签名接口；无生产锚点时保持 Unknown。当前没有内置生产公钥，也没有实现实际签名算法适配器。
3. `FKHelperPeerCredentialEvidence` / `FKHelperPeerCredentialVerifier`：明确区分 Unsupported、Mock、自报凭据；当前所有来源均不能升级为 Verified，系统凭据采集器尚未实现。
4. `FKHelperTransportEvidence` / `FKHelperTransportReadinessEvaluator`：只构造 Mock / Unsupported 证据；要求生产 Transport 证明、端点、连接、生命周期、时效、Peer Credential 与发布信任全部具备。当前不会就绪。
5. `FKHelperReadinessReport` / `FKHelperReadinessEvaluator`：汇总阻断原因；真实 IPC、真实只读能力和写能力全部保持关闭。
6. Helper 详情页增加可信通信就绪度状态行；新增 `helper-readiness-profile.json`。
7. 新增 5 套测试套件、42 项登记断言。

## 安全边界
- 不创建 Helper Target / Daemon / launchd 项。
- 不实现 Mach IPC 或 Unix Socket 真实 Transport。
- 不采集系统 Peer Credential。
- 不配置生产公钥、不伪造签名验证成功。
- 不开放真实 IPC、插件启停、Injector 配置写入、任意注入或系统文件修改。

## 验证边界
本开发环境仅进行静态项目检查、JSON / plist 检查、源文件引用检查、测试登记统计与 ZIP 完整性检查。未执行 Theos Objective-C 编译、未执行 iOS 运行时单元测试、未进行真机测试。测试登记数不是实际通过数。
