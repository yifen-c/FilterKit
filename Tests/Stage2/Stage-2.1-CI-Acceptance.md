# Stage-2.1-CI-Acceptance.md — 2.1-B macOS CI 构建验收记录

- 归属：Stage 2.1-B（仍属 2.1，不是 2.2）。
- **当前结论：2026-11-16 授权闭环（保留观察项备注）**——第七轮 run 43736107678 复验通过：非界面层 Models/Adapters/Core 编译、4 个骨架单测、静态隔离、CI 可重复构建通过；App Target 工程生成、xcodebuild 编译、模拟器 install/launch、3s 存活复查、Dashboard 截图渲染与产物归档通过；2.1 验收标准 1–8 已取证闭环，观察项归档 2.4 / 后续真机（§8 与 Final-Acceptance §4）。2.2 编码未授权。
- 证据归档：
  - 第一轮 `Tests/Stage2/evidence/run-43720018216/`（build 失败）；
  - 第二轮 `Tests/Stage2/evidence/run-43722114624/`（build / test / isolation 通过）；
  - 第三轮 `Tests/Stage2/evidence/run-003-manifest-order/`（manifest 顺序失败）；
  - 第四轮 `Tests/Stage2/evidence/run-43727178213/`（六 job 复验通过，app-build 占位）；
  - 第五轮 `Tests/Stage2/evidence/run-43730012764/`（非界面层通过；app-build 在 XcodeGen 解析阶段失败）；
  - 第六轮 `Tests/Stage2/evidence/run-43731864270/`（工程生成/App 编译/模拟器安装启动/产物归档通过；渲染与常驻证据缺口显式记录）；
  - 第七轮 `Tests/Stage2/evidence/run-43736107678/`（A4 截图渲染、A6 存活复查加固复验通过）。

## 1. 运行环境（第二轮 runner 日志回填，两轮工具链一致）

| 项 | 记录值 | 证据 |
|---|---|---|
| GitHub Run ID | 43722114624（第二轮）；43720018216（第一轮） | artifact 下载 URL 日志 |
| 远端仓库 / 分支 | `yi-fen/002` / `main`（第二轮）；`yi-fen/001` / `main`（第一轮） | build/2_Checkout.txt |
| Git Commit SHA | `030e6e6098dc3a01c166b9c2ccc5125b3142ab71`（第二轮）；`7e6cf48af3b87b09e663fc498384090cd8aee38d`（第一轮） | build/2_Checkout.txt |
| Runner 操作系统 | macOS 26.7.2，Build 25G332，镜像 `macos-26-arm64` | environment/3、artifact/0 |
| Xcode 版本 | Xcode 26.6，Build 17F113 | environment/3 |
| Swift 版本 | Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101），Target arm64-apple-macosx26.0，swift-driver 1.148.6 | environment/3 |
| SDK 版本 | iOS 26.5（iphoneos26.5 / iphonesimulator26.5）；macOS / tvOS / visionOS / watchOS 26.5 | environment/3 |
| Theos / SDK 锚点 | 两轮均未参与（SwiftPM `swift build`，无 Theos 打包步骤） | workflow |

> SDK 口径提醒：runner 提供 iOS 26.5 SDK，与 Dev-Preparation-0.1 记载的 Theos patched SDK 最高 16.5 是两条工具链。本轮 SwiftPM 编译不能作为「16.5 SDK 对 iOS 17 向下兼容」的证据；Theos 打包链与 SDK 兼容待 2.1-E / 2.5 真机回填。

## 2. CI 任务结果（第二轮 run 43722114624）

| 任务 | 验收内容 | 结果 | 证据 / 备注 |
|---|---|---|---|
| environment | 记录 macOS / Xcode / Swift / SDK 版本 | **通过** | 版本全部落盘，无 error |
| build（Models） | Models 目标编译 | **通过** | 4 个 Models 文件编译完成并 `Emitting module Models` |
| build（Adapters） | RootHide / Rootless / 协议层独立编译 | **通过** | `Emitting module Adapters`，无类型不可见错误 |
| build（Core） | 核心协议与组合根编译 | **通过** | `Emitting module Core`；`Build complete! (13.24s)` |
| test | Models Codable 往返 / 枚举口径单测 | **通过** | `Executed 4 tests, with 0 failures`，0.003s；测试平台 arm64e-apple-macos14.0 |
| isolation | 两 Adapter 无交叉依赖（`scripts/check-adapter-isolation.sh`） | **通过（静态文本层面）** | 三项 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter。仅静态文本核对，不代表运行时隔离 |
| app-build | 最小 App 编译 | **未编译（占位）** | 步骤为 echo 占位；当前无 `.xcodeproj` / UI target，待 B4 选型与工程入口补齐 |
| artifact | 构建元数据留存 | **通过** | `filterkit-build-metadata.zip`，4 文件 / 4000 bytes，Artifact ID 14164612683，SHA256 `e5aadd4ceb59aa44a3e37380ef33ac014bb9913a5aedaad45a50cc29aaabe7cb` |

### 2.1 第二轮通过的 4 个骨架单测

| 用例 | 口径 |
|---|---|
| `testDefaultPluginStateIsUnknownAndUndetermined` | 默认 `loaded=.unknown`、`permission.decision=.undetermined` |
| `testEnvelopeRoundTrip` | 信封编码再解码字段不丢 |
| `testSourceTypeRawValues` | SourceType 枚举原始值与 Stage 1 口径一致 |
| `testWritablePolicyRawValues` | WritablePolicy 枚举原始值与 Stage 1 口径一致 |

> 说明：以上为骨架级 Codable / 枚举口径用例；除 `generatedAt` 外的确定性深比较、Stage 1 夹具行为回归属 2.2 接入范围。

### 2.2 第三轮（CI 配置复验，build job 失败）

- 远端仓库 / 分支：`yi-fen/003` / `main`；Commit SHA `e49f7c72ee38712188f6ed3053bd6a8fbe3d6e69`；触发方式 `workflow_dispatch`（手动）。
- 证据：`Tests/Stage2/evidence/run-003-manifest-order/build-job-logs.txt`（本轮仅提供 build job 日志，test / isolation / artifact / app-build 日志未提供）。

| 复验点 | 结果 | 证据 / 备注 |
|---|---|---|
| 1. `workflow_dispatch` 可触发 | ✅ 通过 | build job 正常排队并在 runner 启动 |
| 2. `checkout@v6` 正常运行 | ✅ 通过 | action SHA `d23441a48e516b6c34aea4fa41551a30e30af803`，Checkout 成功切到 main |
| 3. `upload-artifact@v7` 运行 | ⏸ 未验证 | build 在 manifest 阶段失败，artifact job 未取得日志 |
| 4. Node 20 deprecation 警告消失 | ✅ build job 未见 | 本 build job 日志无 `Node.js 20 is deprecated` 条目；其余 job 待日志复核 |
| 5. unhandled files 警告消失 | ⏸ 未观察到 | manifest 解析失败，未进入编译阶段，无法核对资源警告 |
| 6. Models / Adapters / Core 编译通过 | ❌ 失败 | manifest 未通过，未进入编译 |
| 7. 4 项骨架测试通过 | ⏸ 未执行 | test job 被阻塞，无日志 |

**失败根因（第三轮）**：`Package.swift` 的 Core 与 `Stage2Tests` target 把 `sources:` 写在 `exclude:` 之前；SwiftPM manifest API 要求 `exclude` 先于 `sources`，报 `argument 'exclude' must precede argument 'sources'`（Core 第 45 行、testTarget 第 62 行），manifest 编译即失败，exit 1。

**修复（本地，待下一次手动触发复验）**：两个 target 调整为 `exclude:` 在前、`sources:` 在后；`Stage2Tests` 排除清单补入 `Stage-2.1-Final-Acceptance.md`。未改动 Models 字段、枚举口径与业务逻辑。

### 2.3 第四轮（CI 配置复验通过，run 43727178213）

- 远端仓库 / 分支：`yi-fen/003` / `main`；Commit SHA `69e65489d5803647a1276ae51c74dec99f389ef2`；触发方式 `workflow_dispatch`（手动）。
- 证据：`Tests/Stage2/evidence/run-43727178213/`（六 job 日志 + 元数据四文件 + `RUN-METADATA.md`）。

| 任务 | 验收内容 | 结果 | 证据 / 备注 |
|---|---|---|---|
| environment | 记录工具链版本 | ✅ 通过 | macOS 26.7.2 / Xcode 26.6 (17F113) / Swift 6.3.3 / SDK 26.5 |
| build | Models / Adapters / Core 编译 | ✅ 通过 | `Build complete! (12.43s)`，三模块 Emitting module；无类型不可见错误 |
| test | Models Codable / 枚举口径单测 | ✅ 通过 | `Executed 4 tests, with 0 failures`（0.007s），平台 arm64e-apple-macos14.0 |
| isolation | 双 Adapter 无交叉依赖 | ✅ 通过（静态文本层面） | 三项 OK；运行时隔离不在本轮 |
| artifact | 构建元数据留存 | ✅ 通过 | `filterkit-build-metadata.zip`，4 文件 / 4322 bytes，Artifact ID 14166902901，SHA256 `0d88934be1d0f659bbffe50ea9014e9976cd264a9de8b42783b992b6bdb7c373` |
| app-build | 最小 App 编译 | ⏸ 占位 | 仍为 echo TODO；工程生成 / `xcodebuild` / 模拟器启动未执行 |

| 复验点 | 结果 | 证据 |
|---|---|---|
| 1. `workflow_dispatch` 可触发 | ✅ | 六 job 正常排队启动；workflow 已移除 push / pull_request |
| 2. `checkout@v6` 正常运行 | ✅ | action SHA `d23441a4`，各 job checkout 成功 |
| 3. `upload-artifact@v7` 正常运行 | ✅ | action SHA `cf430e03`，metadata artifact 成功归档 |
| 4. Node 20 deprecation 警告消失 | ✅ | 全部日志无 `Node.js 20 is deprecated` 条目 |
| 5. unhandled files 警告消失 | ✅ | build / test 日志无未处理资源警告 |
| 6. Models / Adapters / Core 编译通过 | ✅ | 见 build 任务行 |
| 7. 4 项骨架测试通过 | ✅ | 见 test 任务行 |

**次要遗留（第四轮观察，已在本地修复，待下次 runner 确认）**：test job 的 `filterkit-test-log` artifact 原路径 `.build/*.log` 无匹配文件，触发 `if-no-files-found: warn`；已改为 `swift test 2>&1 | tee .build/test-log.txt` 并上传该实际日志文件，空归档告警待下次日志复核。

**App Target 接入（本地落地，待下次 runner 复验）**：`app-build` job 已从 echo 占位替换为 XcodeGen 工程生成 → xcodebuild iOS Simulator 编译 → simctl boot/install/launch 步骤，并归档编译日志、启动日志与 `.app` 产物；编译/启动结论以下一次 `workflow_dispatch` 日志为准，见 `Stage-2.1-Final-Acceptance.md §3`。

**元数据一致性**：归档的 `Package.swift` / `Makefile` / `control` / workflow 与本地工作区逐字节一致；第三轮 `exclude`/`sources` 顺序修复在本轮生效，manifest 未再报错。

### 2.4 第五轮（App Target 首跑，run 43730012764）

- 远端仓库 / 分支：`yi-fen/004` / `main`；Commit SHA `e2a019a40d4214ebc2ab8af6493e00cdfe1abaec`；触发方式 `workflow_dispatch`（手动）。
- 证据：`Tests/Stage2/evidence/run-43730012764/`（六 job 日志 + 元数据五文件 + `RUN-METADATA.md`）。

| 任务 | 验收内容 | 结果 | 证据 / 备注 |
|---|---|---|---|
| environment | 记录工具链版本 | ✅ 通过 | macOS 26.7.2 / Xcode 26.6 (17F113) / Swift 6.3.3 / SDK 26.5 |
| build | Models / Adapters / Core 编译 | ✅ 通过 | `Build complete! (14.56s)`，三模块 Emitting module |
| test | Models Codable / 枚举口径单测 | ⚠️ 用例通过，job 退出 1 | `Executed 4 tests, with 0 failures`；退出 1 为 tee 打不开 `.build/test-log.txt`（目录尚未创建）被 pipefail 放大，非测试失败 |
| isolation | 双 Adapter 无交叉依赖 | ✅ 通过（静态文本层面） | 三项 OK |
| app-build | XcodeGen 生成工程 + xcodebuild 编译 + 模拟器启动 | ❌ 失败 | XcodeGen 2.46.0 安装成功；`xcodegen generate` 解析 `project.yml` 失败，未进入编译/启动；产物空归档告警 |
| artifact | 构建元数据留存 | ✅ 通过 | `filterkit-build-metadata.zip`，5 文件 / 6019 bytes，Artifact ID 14167928081，SHA256 `e0d1652110acd850008d8872bf50a97f465063c6b5dcc55cd4458c1ea68cbbb5` |

| 复验点 | 结果 | 证据 |
|---|---|---|
| 1. `workflow_dispatch` 可触发 | ✅ | 六 job 正常排队启动 |
| 2. `checkout@v6` 正常运行 | ✅ | action SHA `d23441a4`，各 job checkout 成功 |
| 3. `upload-artifact@v7` 正常运行 | ✅ | action SHA `cf430e03`，metadata 成功归档；app-build 因无产物触发 warn |
| 4. Node 20 deprecation 警告消失 | ✅ | 全部日志无 Node 20 条目 |
| 5. unhandled files 警告消失 | ✅ | build / test 日志无未处理资源警告 |
| 6. Models / Adapters / Core 编译通过 | ✅ | 见 build 任务行 |
| 7. 4 项骨架测试通过 | ✅（用例）/ ⚠️ job 退出 1 | 用例 0 失败；退出码问题见下，已本地修复 |

**app-build 失败根因（第五轮）**：`Parsing project spec failed: Decoding failed at "path": Nothing found`（exit 1）。核对 XcodeGen 2.46.0 `Plist` 模型：`targets.<T>.info:` 段对应 `Plist`，其 `path` 为非可选必填解码字段，`properties` 可选。本轮 `project.yml` 的 `info:` 仅写 `properties:`、缺 `path:`，解码在 `path` 取到空值失败；后续 `xcodebuild` / simctl 步骤未执行，`.app` 与两份日志均未生成。

**test job 退出 1 根因（第五轮）**：`swift test 2>&1 | tee .build/test-log.txt` 在 `.build/` 目录尚未由 SwiftPM 创建时即由 tee 打开输出文件，日志报 `tee: .build/test-log.txt: No such file or directory`；`set -o pipefail` 下 tee 失败使整条管道退出 1。测试本体 4/4 通过，`.build/test-log.txt` 未生成导致 test-log artifact 空归档告警。

**修复（本地，待下一次手动触发复验）**：
1. `project.yml`：`info:` 补 `path: App/Info.plist`（XcodeGen 把合并后的默认属性写入该路径并设为 `INFOPLIST_FILE`）；sources excludes 增加 `Info.plist`；
2. `.gitignore`：忽略 XcodeGen 生成的 `App/Info.plist`；
3. workflow `test` job：tee 前 `mkdir -p .build`，消除目录竞态与误退 1。

未改动 Models 字段、枚举口径、Deployment Target 草案值或业务语义；未迁移 Stage 1 扫描逻辑。

### 2.5 第六轮（App Target 编译/启动首通，run 43731864270）

- 远端仓库 / 分支：`yi-fen/004` / `main`；Commit SHA `7ee7880cb443c77e888c6a8d78f6650af24b9821`；触发方式 `workflow_dispatch`（手动）。
- 证据：`Tests/Stage2/evidence/run-43731864270/`（六 job 日志 + 元数据五文件 + test-log + `RUN-METADATA.md`）。

| 任务 | 验收内容 | 结果 | 证据 / 备注 |
|---|---|---|---|
| environment | 记录工具链版本 | ✅ 通过 | macOS 26.7.2 / Xcode 26.6 (17F113) / Swift 6.3.3 / SDK 26.5 |
| build | Models / Adapters / Core 编译 | ✅ 通过 | `Build complete! (6.54s)`，三模块 Emitting module |
| test | Models Codable / 枚举口径单测 | ✅ 通过 | `Executed 4 tests, with 0 failures`（0.011s）；test-log artifact 14168636892（910 bytes）正常上传，无 tee 告警、job 退出 0 |
| isolation | 双 Adapter 无交叉依赖 | ✅ 通过（静态文本层面） | 三项 OK |
| app-build | XcodeGen 生成 → xcodebuild 编译 → 模拟器安装启动 → 归档 | ✅ 通过（编译/启动/归档）；渲染与常驻见缺口 | `xcodegen generate` 成功产出 `FilterKit.xcodeproj`；`** BUILD SUCCEEDED **`；`iPhone 17 Pro` install 无报错、launch PID 8676；artifact 14169270900（8 文件 / 385898 bytes） |
| artifact | 构建元数据留存 | ✅ 通过 | metadata artifact 14168419130，5 文件 / 6039 bytes，SHA256 `eba49c58ac2a85931b5993757af34bf2c9558d7413de7bb09d7ca40149cc299b` |

| 复验点 | 结果 | 证据 |
|---|---|---|
| 1. `workflow_dispatch` 可触发 | ✅ | 六 job 正常排队启动 |
| 2. `checkout@v6` 正常运行 | ✅ | action SHA `d23441a4`，切到 `7ee7880c` 成功 |
| 3. `upload-artifact@v7` 正常运行 | ✅ | action SHA `cf430e03`，metadata / test-log / app-build 三类 artifact 均归档 |
| 4. Node 20 deprecation 警告消失 | ✅ | 全部日志无 Node 20 条目 |
| 5. unhandled files 警告消失 | ✅ | build / test 日志无未处理资源警告 |
| 6. Models / Adapters / Core 编译通过 | ✅ | 见 build 任务行 |
| 7. 4 项骨架测试通过 | ✅ | 4/4，0 失败（0.011s） |

**App Target 编译细节**：App target 编译三元组 `arm64/x86_64-apple-ios17.0-simulator`；`FilterKitApp.swift` / `DashboardView.swift` / `PermissionProbe.swift` 双架构编译；显式依赖 App → Models/Adapters/Core，Core → Models，Adapters → Models，Models 无依赖，与冻结架构一致。唯一无害告警：AppIntents 元数据提取跳过（骨架未用 AppIntents）。

**显式记录的缺口（第六轮未取得直接证据；加固已写入本地 workflow，待下次 runner）**：
1. 界面渲染：无截图/UI 转储，Dashboard 占位文案实际渲染可见性未直接验证；workflow 已补 `simctl io screenshot build/dashboard.png` 并纳入 artifact；
2. 进程常驻：launch 返回 PID 8676 后未做存活复查；workflow 已补 3s 后 `launchctl list` 核对（PID 非 `-`，未存活判失败）；设备选择改取 UDID 避免同名歧义；
3. 包产品编译三元组为 SPM 默认 iOS 12.0（App target 为 17.0），Package.swift 未显式声明平台最低版本，记录待观察；
4. B2/B3/B4 仍为草案/占位口径，待打包阶段与真机证据冻结；模拟器启动不等于越狱权限通过（2.4）。

### 2.6 第七轮（A4/A6 加固复验，run 43736107678）

- 远端仓库 / 分支：`yi-fen/004` / `main`；Commit SHA `82430230b017380913c6c11befb0c41336dbe963`；触发方式 `workflow_dispatch`（手动）。
- 证据：`Tests/Stage2/evidence/run-43736107678/`（六 job 日志 + 元数据五文件 + test-log + app-build 日志/截图 + `RUN-METADATA.md`）。

| 任务 | 验收内容 | 结果 | 证据 / 备注 |
|---|---|---|---|
| environment | 记录工具链版本 | ✅ 通过 | macOS 26.7.2 / Xcode 26.6 (17F113) / Swift 6.3.3 / SDK 26.5 |
| build | Models / Adapters / Core 编译 | ✅ 通过 | `Build complete! (9.38s)`，三模块 Emitting module |
| test | Models Codable / 枚举口径单测 | ✅ 通过 | `Executed 4 tests, with 0 failures`（0.005s）；test-log artifact 14170388786（906 bytes）正常上传 |
| isolation | 双 Adapter 无交叉依赖 | ✅ 通过（静态文本层面） | 三项 OK |
| app-build | 工程生成 → 编译 → install/launch → 存活复查 → 截图 → 归档 | ✅ 通过 | `xcodegen generate` 成功；`** BUILD SUCCEEDED **`；`iPhone 17 Pro`（UDID 98A0BFA3…）install 无报错、launch PID 4813；3s 后存活 PID 4813 与启动 PID 一致；`dashboard.png` 1206×2622；artifact 14170656670（449341 bytes） |
| artifact | 构建元数据留存 | ✅ 通过 | metadata artifact 14170409389，5 文件 / 6594 bytes，SHA256 `37d439f45e706f267c8c63343062368a0b365cc8e6d91926187c9fb62d7ae503` |

| 复验点 | 结果 | 证据 |
|---|---|---|
| 1. `workflow_dispatch` 可触发 | ✅ | 六 job 正常排队启动 |
| 2. `checkout@v6` 正常运行 | ✅ | 切到 `82430230` 成功 |
| 3. `upload-artifact@v7` 正常运行 | ✅ | metadata / test-log / app-build 三类 artifact 均归档 |
| 4. Node 20 deprecation 警告消失 | ✅ | 全部日志无 Node 20 条目 |
| 5. unhandled files 警告消失 | ✅ | build / test 日志无未处理资源警告 |
| 6. Models / Adapters / Core 编译通过 | ✅ | 见 build 任务行 |
| 7. 4 项骨架测试通过 | ✅ | 4/4，0 失败（0.005s） |

**A4 渲染证据**：截图画面为标题 `FilterKit`、「环境 / 尚未检测」、「权限 / 尚未验证（2.4 探针）」、脚注「本阶段为只读骨架；不含扫描、启停或写入功能。」，与 `DashboardView.swift` 源码逐字一致，中文渲染正常，无崩溃/黑屏。
**A6 常驻证据**：启动后 3s 窗口 `launchctl list` 命中 `4813 0 UIKitApplication:com.filterkit.manager[4d34][rb-legacy]`，存活 PID 与启动 PID 一致、非 `-`；该窗口只证明未立即退出，不等于长期稳定性。

**第七轮遗留观察项（不阻塞 2.1 编译/启动/渲染口径）**：包产品三元组仍为 SPM 默认 iOS 12.0；B2/B3/B4 命名与真机兼容待打包阶段/2.5；模拟器运行不等于越狱权限通过（2.4）；Rootless 无真机；运行时隔离不在本轮。

### 2.7 第八轮（2.2-A Codable 测试复验，run 43741322151）

- 远端仓库 / 分支：`yi-fen/005` / `master`；Commit SHA `f28b67001f5201ffbf6d51e8715bdab5d1b6b3e4`（镜像提交，对应本地 `ddd042f`）；触发方式 `workflow_dispatch`（手动）。
- 证据：`Tests/Stage2/evidence/run-43741322151/`（六 job 日志 + 元数据五文件 + test-log + app-build 日志/截图 + `RUN-METADATA.md`）。
- 本轮归属：2.2-A 仅测试补齐复验，不属 2.1 范围；2.1 闭环结论不变。

| 任务 | 验收内容 | 结果 | 证据 / 备注 |
|---|---|---|---|
| environment | 记录工具链版本 | ✅ 通过 | macOS 26 arm64 / Xcode 26.6 / Swift 6.3.3 / SDK 26.5 |
| build | Models / Adapters / Core 编译 | ✅ 通过 | `Build complete! (4.47s)`，三模块 Emitting module |
| test | Stage2Tests Codable 用例 | ✅ 通过 | `Executed 21 tests, with 0 failures (0 unexpected) in 0.011 (0.013) seconds`；test-log artifact 14172795167（1184 bytes） |
| isolation | 双 Adapter 无交叉依赖 | ✅ 通过（静态文本层面） | 三向 OK |
| app-build | 工程生成 → 编译 → install/launch → 存活复查 → 截图 → 归档 | ✅ 通过 | `** BUILD SUCCEEDED **`；PID 4693，3s 后存活 PID 4693 一致；`dashboard.png` 1206×2622；artifact 14172880428（449101 bytes，9 文件） |
| artifact | 构建元数据留存 | ✅ 通过 | metadata artifact 14172851309，5 文件 / 6594 bytes，SHA256 `d763df6aded2fe0f33eb5500e974b9937dc801a583b58b5592debba8b7cb0d2d`；五文件与本地逐字节一致 |

- 2.2-A 覆盖：9 枚举原始值、全模型往返（FilterRule/Ownership/Plugin/Envelope）、nil/null/缺失、Optional Bool 三态、空数组编码；R6 未知枚举解码默认行为本轮未实测、未修改。
- 全日志无 Node 20 deprecation、无 unhandled files 警告；唯一无害告警为 AppIntents 元数据提取跳过。
- 边界：本轮未改 Models 字段/枚举/原始值/解码行为，未改协议，未改 Stage 1 基线；未接入 Stage 1 fixture 行为深比较（2.2-E）。

## 3. 第一轮失败复盘（run 43720018216，已在第二轮消除）

### 3.1 现象

build exit 1：Adapters 目标报 `cannot find type 'JailbreakEnvironment' / 'Plugin' / 'ValidationReport' / 'FilterRule' / 'ReportWarning' in scope`；`EnvironmentPaths` / `PluginCandidate` 不满足 `Equatable`。Models 模块本身编译通过。

### 3.2 根因

SwiftPM 每个 target 是独立编译模块。`Package.swift` 已声明 `dependencies: ["Models"]`，但 Adapters / Core 源文件缺少 `import Models`，Models 的 `public` 类型不进入作用域；Equatable 报错是 `ReportWarning` 不可见后的下游连带，不是 Models 类型缺少 Equatable 实现。

### 3.3 修复与复验

- 已补导入：`Adapters/ElleKitAdapter.swift`、`Adapters/RootHide/RootHideAdapter.swift`、`Adapters/Rootless/RootlessAdapter.swift`、`Core/CoreServices.swift`（`import Models`；Core 另加 `import Adapters`）；`App/FilterKitApp.swift` 补 `import Models / Core / Adapters`（App 尚未纳入 SwiftPM target）。
- 第二轮 runner 复验：Models / Adapters / Core 全部发出模块，类型不可见与 Equatable 错误均未复现。
- 未改动任何 Models 字段、枚举原始值、Deployment Target 或业务语义；未迁移 Stage 1 扫描逻辑。

## 4. CI 配置变更（第四轮 run 43727178213 已复验通过）

以下变更在第二轮日志之后落地，**第四轮已由 runner 复验通过**（见 §2.3）：

1. **触发方式改为仅手动**：`on:` 移除 `push` 与 `pull_request`，仅保留 `workflow_dispatch`；上传文件 / 提 PR 不再自动编译，build 与 isolation 均由手动触发执行。第四轮手动触发正常拉起六 job。
2. **Action 升级到 Node 24 主版本**（消除 Node.js 20 deprecation 警告）：
   - `actions/checkout@v4` → `actions/checkout@v6`（action.yml 声明 `using: node24`）；
   - `actions/upload-artifact@v4` → `actions/upload-artifact@v7`（action.yml 声明 `using: node24`）。
   - 第四轮日志无 Node 20 deprecation 条目，metadata artifact 由 v7 正常归档。
3. **清理未处理文件警告**：`Package.swift` 为 Core target 排除 `README.md` 与各 `.gitkeep`；为 `Stage2Tests` 排除 `evidence/` 目录与 `*.md` 验收文档；`exclude` 先于 `sources`（第三轮顺序问题已修复）。第四轮 build / test 日志无未处理资源警告。

## 5. Models 对齐核对

- [x] Codable 往返：信封编码再解码字段不丢（`testEnvelopeRoundTrip`，第二轮通过）；
- [x] 枚举原始值与 Stage 1 导出口径一致（SourceType / WritablePolicy 用例通过；其余枚举在 2.2 补全用例）；
- [x] 默认口径：`loaded=.unknown`、`permission.decision=.undetermined`（用例通过）；
- [ ] 除 `generatedAt` 外重复导出确定性深比较（2.2 接 Stage 1 夹具后执行）。

## 6. 已知未通过 / 风险项

| 项 | 现状 | 处理口径 |
|---|---|---|
| App target 编译/启动/渲染 | 第七轮 run 43736107678：工程生成、xcodebuild 编译、模拟器 install/launch、3s 存活复查（PID 一致）、Dashboard 截图渲染、产物归档均通过 | 编译/启动/渲染层口径已取证；长期稳定性、真机兼容与权限不属本轮 |
| Theos 工具链 / 打包 SDK | 本轮未参与 | 打包阶段确认；iOS 17 兼容待 2.5 真机 |
| Rootless 真机适配 | 无设备 | `[Rootless 真机待验证]`，不以 RootHide 结果代替 |
| App 工程配置项 | B2 Deployment Target / B3 Bundle ID / B4 SwiftUI 编译确认待证据 | 草案保留标注，证据不足不冻结 |
| 测试覆盖有限 | 仅 4 个骨架用例，未接 Stage 1 夹具 | 2.2 迁移逻辑时补全回归 |

## 7. 边界确认（2.1-B 全程保持）

- 未迁移 Stage 1 完整扫描逻辑（属 2.2）；
- 未执行真机扫描或 GUI 进程权限探针（属 2.4）；
- 未实现插件启停、配置写入、删除、安装/卸载；
- 未改目标 App Bundle、未重签名、未建常驻 Daemon；
- 未为让 CI 变绿而降低 Deployment Target、修改 Models 字段或放宽枚举口径。

## 8. 闭环判定

2.1 闭环须同时满足：Models / Core / Adapters 在真实 Apple 工具链编译通过、Models 测试通过、隔离检查通过、CI 可重复执行、App 入口状态明确（编译通过或显式记录缺口与补齐计划）。

**闭环结论（2026-11-16 授权，保留观察项备注）**：非界面层构建 / 骨架测试 / 静态隔离 / CI 配置，以及 App Target 工程生成、编译、模拟器安装启动、存活复查、Dashboard 截图渲染与产物归档，均在第七轮 run 43736107678 取得真实通过证据；标准 1–8 闭环，判定以 `Stage-2.1-Final-Acceptance.md` 为准。

**归档观察项（不阻塞 2.1，转后续阶段）**：

| # | 观察项 | 归档阶段 |
|---|---|---|
| O1 | GUI 进程真实文件访问权限 | 2.4 权限探针 |
| O2 | entitlement / sandbox 放行 | 2.4 权限探针 |
| O3 | `jbroot()` 真实调用验证 | 2.4 权限探针 |
| O4 | Rootless 真机验证（无设备） | 具备设备后 |
| O5 | 插件实际加载行为（`loaded` 恒 unknown） | 后续真机验证 |

2.2 Core/Models Migration 的实现代码、135 项 Swift 回归执行与 2.3 进入均未授权；当前仅授权 2.2 冻结规格起草。
