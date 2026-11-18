# run-43730012764 — 第五轮 CI 元数据（2026-11-15）

- Run ID：43730012764；仓库 `yi-fen/004`；分支 `main`；Commit SHA `e2a019a40d4214ebc2ab8af6493e00cdfe1abaec`。
- 触发：`workflow_dispatch`（手动）。
- Runner：macOS 26.7.2 Build 25G332，macos-26-arm64，region westus MacCloud；Runner 2.338.2。
- 工具链：Xcode 26.6 Build 17F113；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；iOS Simulator SDK 26.5。
- Actions：`actions/checkout@v6`（SHA d23441a48e516b6c34aea4fa41551a30e30af803）；`actions/upload-artifact@v7`（SHA cf430e030ddbb5b0abf93d22962f4752f3646cd9）。
- Metadata artifact：`filterkit-build-metadata.zip`，5 文件 / 6019 bytes，Artifact ID 14167928081，SHA256 `e0d1652110acd850008d8872bf50a97f465063c6b5dcc55cd4458c1ea68cbbb5`。

## Job 结论

| Job | 结果 | 证据 / 备注 |
|---|---|---|
| environment | ✅ | 工具链版本落盘 |
| build | ✅ | `Build complete! (14.56s)`，Models/Adapters/Core Emitting module |
| test | ⚠️ 用例通过但 job 退出 1 | `Executed 4 tests, with 0 failures`；退出 1 由 tee 无法打开 `.build/test-log.txt`（目录尚不存在）触发，pipefail 放大；非测试失败 |
| isolation | ✅ | 静态三向 OK |
| app-build | ❌ 失败 | XcodeGen 2.46.0 安装成功；`xcodegen generate` 解析 project.yml 失败 |
| artifact | ✅ | metadata 归档成功；app-build 产物因未生成，空归档告警 |

## app-build 失败根因

`Parsing project spec failed: Decoding failed at "path": Nothing found`（exit 1）。

核对 XcodeGen 2.46.0 `Plist` 模型（`Sources/ProjectSpec/Plist.swift`）：`info:` 段对应 `Plist`，其 `path` 为非必填解码字段——必须给出 `path`（生成的 Info.plist 路径），`properties` 可选。本轮 `project.yml` 的 `info:` 只写了 `properties:`、缺 `path:`，解码在 `path` 处取到空值而失败。

### 修复（本地，待下次 runner 复验）

- `project.yml`：`info:` 补 `path: App/Info.plist`；sources excludes 增加 `Info.plist`；
- `.gitignore`：忽略 XcodeGen 生成的 `App/Info.plist`；
- `test` job：tee 前 `mkdir -p .build`，避免目录不存在导致 tee 失败、pipefail 使 job 误退 1。

## 复验要点（下次手动触发）

1. `xcodegen generate` 成功产出 `FilterKit.xcodeproj`；
2. `xcodebuild` iOS Simulator Debug 编译成功，产出 `FilterKit.app`；
3. 模拟器 boot/install/launch 成功并记录 PID；
4. `filterkit-app-build` artifact 归档编译日志、启动日志与 `.app`；
5. test-log artifact 正常上传 `.build/test-log.txt`，无空归档告警、job 退出 0。

## 边界

- 模拟器启动成功不代表越狱文件访问权限通过；权限探针属 2.4；
- 本轮未迁移扫描逻辑、未真机扫描、无写入/启停功能。
