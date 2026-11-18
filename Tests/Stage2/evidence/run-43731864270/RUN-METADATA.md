# run-43731864270 — 第六轮 CI 元数据（2026-11-15）

- Run ID：43731864270；仓库 `yi-fen/004`；分支 `main`；Commit SHA `7ee7880cb443c77e888c6a8d78f6650af24b9821`。
- 触发：`workflow_dispatch`（手动）。
- Runner：macOS 26.7.2 Build 25G332，macos-26-arm64；Xcode 26.6 Build 17F113；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；iOS Simulator SDK 26.5。
- Actions：`actions/checkout@v6`（SHA d23441a48e516b6c34aea4fa41551a30e30af803）；`actions/upload-artifact@v7`（SHA cf430e030ddbb5b0abf93d22962f4752f3646cd9）；XcodeGen 2.46.0（brew bottle arm64_tahoe）。

## Artifact

| Artifact | ID | 大小 | SHA256 |
|---|---|---|---|
| `filterkit-build-metadata` | 14168419130 | 6039 bytes（5 文件） | `eba49c58ac2a85931b5993757af34bf2c9558d7413de7bb09d7ca40149cc299b` |
| `filterkit-test-log` | 14168636892 | 910 bytes | （test-log.txt，无空归档告警） |
| `filterkit-app-build` | 14169270900 | 385898 bytes（8 文件） | `6a39de510844d1f8c39303a51ee81e2df1e4dfc211d6ffff229dff90449f450a` |

## Job 结论

| Job | 结果 | 证据 |
|---|---|---|
| environment | ✅ | 工具链版本落盘 |
| build（非界面层） | ✅ | `Build complete! (6.54s)`，Models/Adapters/Core Emitting module |
| test | ✅ | `Executed 4 tests, with 0 failures`（0.011s）；test-log artifact 正常上传，无 tee 告警、job 退出 0 |
| isolation | ✅ | 静态三向 OK |
| app-build | ✅ 编译/安装/启动/归档成功 | 见下 A3–A7 |
| artifact | ✅ | metadata 归档成功 |

## App Target 证据（app-build job）

- **A3 工程生成**：`xcodegen generate` → `Generating plists...` / `Generating project...` / `Writing project...` → `Created project at /Users/runner/work/004/004/FilterKit.xcodeproj`；第五轮 `info.path` 修复生效，无解析错误。
- **A5 App 编译**：`xcodebuild -scheme FilterKit -destination 'generic/platform=iOS Simulator' -configuration Debug` → `** BUILD SUCCEEDED **`；产物 `build/DerivedData/Build/Products/Debug-iphonesimulator/FilterKit.app`（FilterKit 可执行 123808 bytes、`FilterKit.debug.dylib` 1474864 bytes、`__preview.dylib`、Info.plist、PkgInfo）。
  - App target 编译三元组：`arm64-apple-ios17.0-simulator`、`x86_64-apple-ios17.0-simulator`（B2 草案 17.0 已作用于 App target）。
  - 编译源：`App/FilterKitApp.swift`、`App/PermissionProbe/PermissionProbe.swift`、`App/Views/DashboardView.swift`，arm64 + x86_64 双架构。
  - 显式依赖：App → Models/Adapters/Core 产品；Core → Models；Adapters → Models；Models 无依赖。架构方向与冻结口径一致。
  - 唯一告警：`appintentsmetadataprocessor: Metadata extraction skipped. No AppIntents.framework dependency found`（无害，骨架未用 AppIntents）。
- **A6 模拟器安装启动**：选中 `iPhone 17 Pro`（iOS 26.5 模拟器族）；`simctl install` 无报错；`simctl launch com.filterkit.manager` 返回 PID `8676`；设备列表显示一台 `iPhone 17 Pro`（FCC5F673…）处于 `Booted`。
- **A7 归档**：`filterkit-app-build` 含 `app-xcodebuild.log`、`sim-launch.log`、`FilterKit.app`，8 文件 / 385898 bytes，artifact ID 14169270900。

## 显式记录的缺口（不夸大）

1. **A4 界面渲染未见截图/UI 转储**：日志只证明进程被拉起，未捕获模拟器屏幕截图或视图层级；Dashboard 标题/占位文案「尚未检测」「尚未验证（2.4 探针）」的实际渲染可见性本轮无直接证据。
2. **A6 进程常驻未做存活复查**：`simctl launch` 返回 PID 8676 后，未再查询该 PID 是否仍在运行；未排除启动后立即退出/崩溃。无 crash 日志线索，但也无存活断言。
3. **包产品编译三元组为 SPM 默认 iOS 12.0**：Models/Adapters/Core 编译命令目标三元组 `arm64/x86_64-apple-ios12.0-simulator`（本地包默认最低版本）；App target 为 17.0。Package.swift 未显式声明平台最低版本，记录待观察，不构成本轮编译失败。
4. **B2/B3/B4 冻结状态**：App target 17.0 编译通过、Bundle ID `com.filterkit.manager` 在模拟器可解析启动、SwiftUI 在 Xcode 26.6 编译通过；仍为草案/占位口径，命名与最低版本待打包阶段与真机证据确认。
5. 模拟器启动成功**不代表越狱文件访问权限通过**；JBROOT/TweakInject/entitlement/sandbox/`jbroot()` 结论属 2.4 真机探针。

## 边界

- 未迁移 Stage 1 完整扫描逻辑（2.2）；未真机扫描或权限探针（2.4）；无启停/写入/删除/装卸入口。
