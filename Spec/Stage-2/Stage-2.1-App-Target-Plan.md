# Stage-2.1-App-Target-Plan.md — App Target 技术方案（第七轮 runner 复验通过）

- 归属：Stage 2.1 任务 B（建立真正的 iOS App Target）；不进入 2.2。
- 状态：**2026-11-16 授权闭环（保留观察项备注）**。第七轮 runner（run 43736107678）已验证工程生成、xcodebuild 编译、模拟器安装启动、3s 存活复查、Dashboard 截图渲染与产物归档。本机 Linux 无 Xcode / Swift / simctl，工程结论以 macOS runner 日志为准；O1–O5 观察项归档 2.4 / 后续真机（见 Final-Acceptance §4）。
- 边界：最小 App 只启动并展示只读占位状态；不含扫描、解析、归属、启停、写入、删除、安装/卸载；不另写第二套扫描器。

## 1. 现状与缺口

非界面层已在 runner 取得真实证据：Models / Adapters / Core 编译通过、4 个骨架单测通过、静态隔离检查通过。第七轮 App Target 现状：

- `xcodegen generate` 成功产出 `FilterKit.xcodeproj`，`xcodebuild` iOS Simulator Debug `** BUILD SUCCEEDED **`，产出 `FilterKit.app`；
- 模拟器 `iPhone 17 Pro` install 无报错、`launch com.filterkit.manager` 返回 PID 4813，3s 后存活 PID 一致；`dashboard.png` 截图渲染标题/环境/权限占位与只读脚注，`.app`、日志与截图已归档；
- 观察项：包产品编译三元组为 SPM 默认 iOS 12.0，打包阶段复核；3s 存活窗口只证明未立即退出，不等于长期稳定性；
- UI 框架（B4 编译+渲染层已确认 SwiftUI）、Deployment Target（B2 草案 17.0）、Bundle ID（B3 占位）尚未冻结，待打包阶段/真机证据。

## 2. UI 技术选型（B4）

### 2.1 决策

**首选 SwiftUI；UIKit 作为兼容性回退。**

| 维度 | 核对结论 |
|---|---|
| 目标设备 | iPhone16,2 / iOS 17.0.2 / arm64e；SwiftUI 自 iOS 13 起可用，iOS 17 无框架最低版本缺口 |
| 界面复杂度 | 首版四页均为只读展示（Dashboard / Plugins / Detail / Diagnostics），无复杂手势、自定义渲染或绘图需求 |
| 工具链 | Xcode 26.6 / Swift 6.3.3（runner 已记录）原生支持 SwiftUI；Theos 下 SwiftUI 可用性不在本轮验证（见 §7 风险） |
| 互操作 | 若 2.3 某页面需 UIKit 容器，SwiftUI↔UIKit 可通过 `UIHostingController` 混编，成本可控 |

### 2.2 回退条件

出现任一情况则回退 UIKit，且 **Models / Core / Adapters 不随 UI 选型改变**：

1. SwiftUI 在选定 Deployment Target 或所选工具链下无法编译；
2. 模拟器启动后基础视图无法渲染；
3. 后续 Theos 打包链对 SwiftUI 运行时存在不可绕过的限制（2.1 不预判，留待打包阶段取证）。

## 3. Deployment Target（B2，待证据冻结）

### 3.1 决策链（对齐子规格 §6.2）

1. 已知真机：iOS 17.0.2（iPhone16,2，arm64e）；
2. 参照官方 RootHide Manager `MinimumOSVersion 15.0`（仅参照，不向下迁就本工程）；
3. 框架约束：SwiftUI 在 iOS 17 可用，无更低版本强制要求；
4. SDK 兼容：runner 为 iOS 26.5 SDK；Theos patched SDK 最高 16.5、无 17.x，两条链分开记录；
5. **工程草案取值：iOS 17.0**（与真机版本对齐）；最终值须在 runner 链接 + 2.5 真机运行证据回填后冻结。

### 3.2 不得做的推断

- 不假设 16.5 SDK 对 iOS 17 链接/运行必然兼容（B6，待 2.5 真机）；
- 不为让 CI 变绿而抬高或压低 Deployment Target；
- 不在证据缺失时把草案值写成已冻结结论。

## 4. Bundle ID（B3，待命名确认）

- 草案占位：`com.filterkit.manager`（与 `control` 草稿一致）；
- 决策流程：反向域名前缀 → 产品名 → 与 Bootstrap 安装路径（`JBROOT/Applications`）、entitlement 标识核对；
- 本轮**不冻结**最终 Bundle ID；工程定义中保留占位并标注待确认。

## 5. 工程生成方式

### 5.1 选型：XcodeGen 在 runner 生成 `.xcodeproj`

本机无 Xcode，手写 `project.pbxproj` 无法校验有效性，硬交一个不可打开的工程风险高。采用：

- 仓库保留 `project.yml`（XcodeGen 定义）；
- runner 步骤执行 `xcodegen generate` 生成 `FilterKit.xcodeproj`；
- 生成产物不提交入库（`.gitignore` 排除 `*.xcodeproj/`、`DerivedData/`）。

备选：若后续在装有 Xcode 的机器上用 IDE 打开并提交工程文件，则以 IDE 生成的 pbxproj 为准，`project.yml` 退为同步参考；二者口径须一致。

### 5.2 模块接入

`Package.swift` 补充 library products，App target 链接本地包产品：

```
App(UI/ViewModel) → Core → Models → Adapters
```

- App target 依赖产品：`Models`、`Adapters`、`Core`；
- App 不直接判断越狱路线、不拼路径、不读设备文件；路线选择只经过 Core 的 `AdapterResolver`；
- SwiftPM 现有非界面层 target 编译路径（`swift build` / `swift test`）保持不变。

## 6. 目录与最小页面

```
App/
├── FilterKitApp.swift          # @main SwiftUI 入口；保留组合根占位 AppAssembly
├── Views/
│   └── DashboardView.swift     # 最小只读 Dashboard：名称 + 环境/权限占位状态
├── ViewModels/                  # 2.3 接入只读 ViewModel；2.1 占位
└── PermissionProbe/             # 2.4 GUI 进程内探针预留；2.1 无实现
```

最小 Dashboard 展示口径：

- 标题 `FilterKit`；
- 环境：**尚未检测**（未知状态保留，不推断已识别 RootHide/Rootless）；
- 权限：**尚未验证（2.4 探针）**（不展示“已获权限/可读写”）；
- 脚注：本阶段为只读骨架，不含扫描、启停或写入功能。

其余三页（Plugins / Detail / Diagnostics）属 2.3，本轮不建视图。

## 7. CI 编译与模拟器启动步骤（已写入 workflow `app-build` job，待 runner 复验）

下列步骤已落地到 `.github/workflows/filterkit-build.yml` 的 `app-build` job，结论以下一次 `workflow_dispatch` 日志为准：

1. `actions/checkout@v6`；
2. 安装 XcodeGen：缺失时 `brew install xcodegen`，并记录 `xcodegen --version`；
3. 生成工程：`xcodegen generate`；
4. 编译（iOS Simulator）：
   `xcodebuild -project FilterKit.xcodeproj -scheme FilterKit -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath build/DerivedData build`，输出 tee 到 `build/app-xcodebuild.log`；
5. 启动模拟器：选取 `xcrun simctl list devices available` 中首个可用 iPhone 模拟器，解析其 **UDID**（避免同名模拟器歧义）后 `boot`；
6. 安装：`xcrun simctl install <device-udid> <FilterKit.app 路径>`；
7. 启动：`xcrun simctl launch <device-udid> com.filterkit.manager`，解析 PID 并输出到 `build/sim-launch.log`；
8. 存活复查：冷启动窗口（3s）后 `xcrun simctl spawn <device-udid> launchctl list` 核对 bundle/可执行名仍在列、PID 非 `-`；未存活则 `::error::` 失败；
9. 截图：`xcrun simctl io <device-udid> screenshot build/dashboard.png`；
10. 归档：xcodebuild 日志、sim-launch 日志、截图与 `FilterKit.app` 作为 `filterkit-app-build` artifact 留存。

> 存活复查只证明 App 未在冷启动窗口内立即退出，不等于长期稳定性；截图只证明模拟器产出 UI 帧，**均不代表越狱文件访问权限通过**；权限结论属 2.4 真机探针。

> **第五轮（run 43730012764）首跑记录**：XcodeGen 2.46.0 安装成功，但 `xcodegen generate` 报 `Decoding failed at "path": Nothing found`。根因：`project.yml` 的 `info:` 段对应 XcodeGen `Plist` 模型，`path` 为非可选必填字段，初稿只写了 `properties:`、漏 `path:`。已本地修复：`info:` 补 `path: App/Info.plist`（生成文件加入 `.gitignore`，sources excludes 增加 `Info.plist`）。

> **第六轮（run 43731864270）复验结果**：`xcodegen generate` 成功产出 `FilterKit.xcodeproj`；`xcodebuild` iOS Simulator Debug `** BUILD SUCCEEDED **`（arm64/x86_64，App target ios17.0）；`iPhone 17 Pro` install 无报错、`launch com.filterkit.manager` 返回 PID 8676；`filterkit-app-build` artifact 14169270900 归档编译日志、启动日志与 `.app`。遗留缺口：无截图/视图转储（渲染可见性未取证）、无 PID 存活复查（常驻未断言）；包产品编译三元组为 SPM 默认 iOS 12.0，打包阶段复核。

> **第七轮（run 43736107678）加固复验结果**：`iPhone 17 Pro`（UDID `98A0BFA3-CEC3-4FD6-9916-5A2149774DBF`）launch PID **4813**；3s 后 `launchctl list` 存活 PID 4813 与启动 PID 一致、非 `-`；`dashboard.png`（1206×2622）渲染标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」与只读脚注，与源码逐字一致；artifact 14170656670 含编译日志、启动日志、截图与 `.app`。A4/A6 缺口补齐；包产品 iOS 12.0 三元组仍为观察项。

## 8. 复验清单（第七轮 run 43736107678 已回填，结论见 `Tests/Stage2/Stage-2.1-Final-Acceptance.md §3`）

| # | 复验点 | 通过判据 | 第七轮结果 |
|---|---|---|---|
| 1 | `workflow_dispatch` 可正常触发 | Actions 页面手动运行产生新 run，各 job 正常排队/启动 | ✅ 六 job 正常启动 |
| 2 | `checkout@v6` 正常运行 | Checkout 步骤成功，无 action 报错 | ✅ 切到 `82430230` 成功 |
| 3 | `upload-artifact@v7` 正常运行 | 元数据/测试日志/App 产物 artifact 上传成功并可下载 | ✅ 三类 artifact 归档 |
| 4 | Node 20 deprecation 警告消失 | 完整日志无 `Node.js 20 is deprecated` 条目 | ✅ 无该条目 |
| 5 | `unhandled files` 警告消失 | `swift build` / `swift test` 不再列出 README/evidence/*.gitkeep 等未处理文件 | ✅ 无未处理资源警告 |
| 6 | Models / Adapters / Core 编译仍通过 | 三模块 Emitting module，`Build complete` | ✅ `Build complete! (9.38s)` |
| 7 | 4 项骨架测试仍通过 | `Executed 4 tests, with 0 failures` | ✅ 4/4，0 失败（0.005s） |
| 8 | XcodeGen 工程生成成功 | `xcodegen generate` 无报错，产出 `FilterKit.xcodeproj`；记录 XcodeGen 版本 | ✅ XcodeGen 2.46.0 |
| 9 | App Target 编译成功 | `xcodebuild` iOS Simulator Debug 编译成功，产出 `FilterKit.app`；记录 Xcode/Swift/SDK 版本 | ✅ `** BUILD SUCCEEDED **`；Xcode 26.6 / Swift 6.3.3 / SDK 26.5 |
| 10 | 模拟器安装并启动 | 记录模拟器型号与系统版本；install 成功；launch 返回 PID | ✅ iPhone 17 Pro；PID 4813 |
| 11 | App 产物与日志归档 | `filterkit-app-build` artifact 含编译日志、启动日志、`.app`；记录最终 Commit SHA | ✅ artifact 14170656670；SHA `82430230` |
| 12 | 进程存活复查 | 启动 3s 后 `launchctl list` 仍在列、PID 非 `-`；未存活判失败 | ✅ 存活 PID 4813 与启动 PID 一致 |
| 13 | Dashboard 截图归档 | `build/dashboard.png` 进入 `filterkit-app-build` artifact，可核对标题与占位文案渲染 | ✅ 1206×2622，文案与源码一致 |

## 9. 风险与待确认项映射

| 编号 | 项 | 现状 | 归属 |
|---|---|---|---|
| B1 | Xcode / Swift 版本 | runner 已记录 26.6 / 6.3.3 | 已取证据，回填工程配置 |
| B2 | Deployment Target 定值 | 草案 17.0，待链接/真机证据 | 2.1 末段 / 2.5 |
| B3 | Bundle ID 命名 | 占位 `com.filterkit.manager` | 工程创建前确认 |
| B4 | SwiftUI / UIKit | 首选 SwiftUI，回退 UIKit | 本轮方案；runner 编译确认 |
| B5 | Theos 在工程中的角色 / Swift 工具链 | 本轮 Xcode + SwiftPM 编译；Theos 打包链未接入 | 打包阶段 |
| B6 | 16.5 SDK 对 iOS 17 兼容 | 未实测 | 2.5 真机 |
| B7 | entitlement / sandbox / 容器 / `jbroot()` | 未探针 | 2.4 |
| B8 | Rootless 真机适配 | 无设备 | 后续 Rootless 设备 |

## 10. 边界确认

- 未迁移 Stage 1 完整扫描逻辑（属 2.2）；
- 未执行真机扫描或 GUI 进程权限探针（属 2.4）；
- 未实现启停、改 plist、加 Bundle ID、删 dylib、改软链、安装/卸载、dpkg 写入、自动修复；
- 未改目标 App Bundle、未重签名、未建常驻 Daemon、未自研注入引擎；
- 未修改 Models 字段语义、枚举取值或三层状态口径。
