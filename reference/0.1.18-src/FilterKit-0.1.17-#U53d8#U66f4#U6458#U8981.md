# FilterKit 0.1.17 变更摘要

- 版本升至 0.1.17 / Build 117，Helper Build ID `FKH-0117`。
- 新增可信锚点模型与只读仓库，默认不配置生产公钥，测试锚点不能用于生产放行。
- 新增正式发布验证协调器，绑定 Helper ID、Build ID、Release 通道、架构产物 SHA-256 与签名验证接口。
- 新增 Peer Credential 证据模型，Mock / 自报 / Unsupported 均不能通过真实身份验证。
- 新增 Transport 就绪评估和统一 Readiness 报告，缺失证据时 fail-closed。
- Helper 详情页增加可信通信就绪度展示。
- 新增 5 套测试，42 项登记断言；全项目 41 套件 / 459 项登记断言。
- 未实现真实签名验证适配器、系统 Peer Credential 采集器、Helper Target、Daemon 或真实 IPC；所有操作权限继续关闭。
