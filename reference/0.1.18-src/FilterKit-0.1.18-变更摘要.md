# FilterKit 0.1.18 变更摘要

- App 版本 0.1.18 / Build 118；Helper 逻辑 Build ID `FKH-0118`。
- 新增 Unix Domain Socket Transport 客户端与 Helper 侧 Listener。
- 使用 `getpeereid()` 校验 Peer UID；限制 Socket 路径、父目录权限、Socket 文件权限（默认 0600，可显式设为 0660 + 指定 GID）与 1 MiB 帧上限。
- 实现 4 字节网络序帧读写、收发超时、短读短写与 EINTR 处理。
- 新增 9 项 Socket 集成测试。
- 修复 0.1.17 报告中的 REL1708 断言方向错误。
- 全项目 42 套件 / 468 项登记断言。
- 真实 Helper Target/Daemon 尚未创建，Listener 未在独立进程启动；未开放写操作。
