# run-43727178213 — 第四轮 CI 元数据（2026-11-15）

- Run ID：43727178213；仓库 `yi-fen/003`；分支 `main`；Commit SHA `69e65489d5803647a1276ae51c74dec99f389ef2`。
- 触发：`workflow_dispatch`（手动）。
- Runner：macOS 26.7.2 Build 25G332，macos-26-arm64，region westus MacCloud；Runner 2.338.2。
- 工具链：Xcode 26.6 Build 17F113；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101），Target arm64-apple-macosx26.0，swift-driver 1.148.6；iOS/macOS/tvOS/visionOS/watchOS SDK 26.5。
- Actions：`actions/checkout@v6`（SHA d23441a48e516b6c34aea4fa41551a30e30af803）；`actions/upload-artifact@v7`（SHA cf430e030ddbb5b0abf93d22962f4752f3646cd9）。
- Artifact：`filterkit-build-metadata.zip`，4 文件 / 4322 bytes，Artifact ID 14166902901，SHA256 `0d88934be1d0f659bbffe50ea9014e9976cd264a9de8b42783b992b6bdb7c373`。
- 六 job 结论：environment ✅、build ✅、test ✅（4/4，0 失败）、isolation ✅（静态三向）、artifact ✅、app-build ⏸ 占位 echo（未编译 App）。
- 唯一告警：test job 的 `filterkit-test-log` artifact 路径 `.build/*.log` 无匹配文件（`if-no-files-found: warn`，不阻断）；build-metadata artifact 正常上传。
- 元数据四文件（Package.swift / Makefile / control / workflow）与本地工作区逐字节一致。

## 复验七项

| # | 复验点 | 结果 | 证据 |
|---|---|---|---|
| 1 | workflow_dispatch 可触发 | ✅ | 六 job 正常排队启动 |
| 2 | checkout@v6 正常 | ✅ | 各 job checkout 成功切到 69e6548 |
| 3 | upload-artifact@v7 正常 | ✅ | metadata artifact 上传成功并归档 |
| 4 | Node 20 deprecation 警告消失 | ✅ | 全部日志无 Node.js 20 条目 |
| 5 | unhandled files 警告消失 | ✅ | build/test 日志无未处理资源警告 |
| 6 | Models / Adapters / Core 编译通过 | ✅ | `Build complete! (12.43s)`，三模块 Emitting module |
| 7 | 4 项骨架测试通过 | ✅ | `Executed 4 tests, with 0 failures`（0.007s） |

## 仍未闭环

- App Target 未编译、模拟器未启动（app-build 仍为 echo 占位）；
- 隔离仅静态文本层面；运行时隔离与 GUI 进程权限探针属 2.4；
- test-log artifact 路径无文件匹配，属次要配置项，不影响本轮编译/测试结论。
