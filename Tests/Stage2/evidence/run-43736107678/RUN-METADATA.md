# RUN-METADATA.md — 第七轮（run 43736107678）A4/A6 加固复验

## 基本信息

- Run：`43736107678`；仓库 `yi-fen/004`；最终 Commit SHA `82430230b017380913c6c11befb0c41336dbe963`；触发方式：手动 `workflow_dispatch`（push / PR 不触发）。
- Runner：macOS 26.7.2 Build 25G332，arm64；Xcode 26.6 Build 17F113；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK 26.5（iphoneos26.5 / iphonesimulator26.5）；XcodeGen 2.46.0。
- metadata 五文件（`Package.swift` / `project.yml` / `Makefile` / `control` / `.github/workflows/filterkit-build.yml`）与本地工作区逐字节一致。

## 六 job 结论

| job | 结论 | 证据 |
|---|---|---|
| environment | ✅ 通过 | 记录 macOS 26.7.2 / Xcode 26.6 (17F113) / Swift 6.3.3 / SDK 26.5 |
| build | ✅ 通过 | `Build complete! (9.38s)`；Emitting module Models / Adapters / Core |
| test | ✅ 通过 | `Executed 4 tests, with 0 failures (0 unexpected) in 0.005s`；平台 arm64e-apple-macos14.0；test-log 正常上传 |
| isolation | ✅ 通过（静态文本层面） | RootHide 未引用 Rootless、Rootless 未引用 RootHide、Core 未实例化具体 Adapter，三向 OK |
| artifact | ✅ 通过 | metadata artifact 归档成功 |
| app-build | ✅ 通过 | 工程生成 → xcodebuild 编译 → 模拟器 install/launch → 存活复查 → 截图 → 归档，全链路无失败 |

## App Target 证据（app-build job）

- 工程生成：`xcodegen generate` → `Created project at FilterKit.xcodeproj`。
- 编译：`** BUILD SUCCEEDED **`；App target 三元组 `arm64 / x86_64-apple-ios17.0-simulator`；`FilterKitApp.swift` / `DashboardView.swift` / `PermissionProbe.swift` 双架构编译；显式依赖 App → Models/Adapters/Core，Core → Models，Adapters → Models，Models 无依赖。
- 产物 `FilterKit.app`：`FilterKit` 可执行 123808 bytes、`FilterKit.debug.dylib` 1474864 bytes、`__preview.dylib` 83952 bytes、`Info.plist` 756 bytes、`PkgInfo` 8 bytes；`Info.plist`：`CFBundleIdentifier=com.filterkit.manager`、`CFBundleName=FilterKit`、`MinimumOSVersion=17.0`、`UIDeviceFamily=1,2`。
- 模拟器：`iPhone 17 Pro`，UDID `98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`（按 UDID 选择，避免同名歧义）；install 无报错。
- 启动：`launch com.filterkit.manager` 返回 PID **4813**。
- 存活复查（A6）：2026-11-15T16:38:07Z（启动后 3s 窗口）`simctl spawn <udid> launchctl list` 命中 `4813	0	UIKitApplication:com.filterkit.manager[4d34][rb-legacy]`；存活 PID **4813** 与启动 PID **4813** 一致，非 `-`；job 未触发存活失败分支。
- 截图（A4）：`simctl io screenshot build/dashboard.png`，PNG 1206×2622；画面渲染：标题 `FilterKit`；行「环境 / 尚未检测」；行「权限 / 尚未验证（2.4 探针）」；脚注「本阶段为只读骨架；不含扫描、启停或写入功能。」——与 `DashboardView.swift` 源码文案逐字一致，中文渲染正常，无崩溃/黑屏。

## Artifact 归档

| artifact | ID | 大小 | SHA256 |
|---|---|---|---|
| `filterkit-build-metadata` | 14170409389 | 6594 bytes | `37d439f45e706f267c8c63343062368a0b365cc8e6d91926187c9fb62d7ae503` |
| `filterkit-test-log` | 14170388786 | 906 bytes | `a0db3d20b6fa191b107fc965e8c3bdc6292a4f13277278482919b57278210f1d` |
| `filterkit-app-build` | 14170656670 | 449341 bytes | `df812d8dece5c271a6f4ba50d2ad6908b9084d07125079684f3f945946c93bf8` |

## 告警扫描

- 无 `Node.js 20 is deprecated` 条目；无 `unhandled files` 资源警告；无编译错误。
- 唯一无害告警：AppIntents 元数据提取跳过（骨架未使用 AppIntents）。

## 遗留观察项（不阻塞 2.1 编译/启动/渲染口径）

1. 包产品（Models/Adapters/Core）编译三元组为 SPM 默认 iOS 12.0，App target 为 17.0；`Package.swift` 未显式声明平台最低版本，打包阶段复核。
2. B2（Deployment Target 草案 17.0）、B3（Bundle ID 占位 `com.filterkit.manager`）、B4（SwiftUI 编译+渲染层确认）仍待打包阶段/真机证据冻结命名与兼容性。
3. 模拟器启动与 3s 存活窗口只证明未立即退出，不等于长期稳定性；模拟器运行不等于越狱文件访问权限通过，权限结论属 2.4 真机探针。
4. Rootless 无真机；运行时隔离不在本轮（本轮为静态文本层面）。
