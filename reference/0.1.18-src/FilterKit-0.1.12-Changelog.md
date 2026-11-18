# FilterKit 0.1.12 变更摘要

## 新增
- Helper 部署可行性证据模型与严格字段校验。
- Mach Service 名称格式校验。
- Helper 部署配置档案与双环境验收矩阵。
- 12 项部署边界测试。

## 优化
- 将部署前置条件拆分为可独立验收的证据项。
- 未知证据键、错误类型和缺失证据一律阻止就绪。
- 即使证据完整，也不自动开放 Daemon 部署、特权启动、真实 IPC 或写操作。
- 明确 App / Helper Entitlements 分离，避免未来 Helper 继承 App 私有权限。

## 未实现
- 独立 Helper Target、launchd 注册、Mach IPC / Unix Socket Transport。
- 真实签名锚点、Helper 签名验证、Peer 验证。
- 生命周期、崩溃恢复与设备侧双环境验收。
- 插件启停、按 App 注入、安装卸载及任何系统写操作。

## 版本
App 0.1.12 / Build 112；Helper Identity 0.1.12 / FKH-0112；Protocol 1.0。
测试登记：23 套件 / 285 项静态声明断言。
