# Stage-2.1-Final-Acceptance.md — 2.1 最终验收记录

- 归属：Stage 2.1 闭环验收；2.2 Core/Models Migration 须在本验收闭环后另行授权。
- 状态：**2026-11-16 授权闭环（保留观察项备注）**。第七轮 run 43736107678 复验：非界面层编译/测试/隔离通过；App Target 工程生成、编译、模拟器安装启动、3s 存活复查、Dashboard 截图渲染、产物归档全链路通过。验收标准 1–8 全部取证并闭环；观察项归档至 2.4 / 后续真机阶段（见 §4），不再作为 2.1 未完成门禁。2.2 编码须在本闭环后另行单独授权。
- 历史证据（不覆盖）：
  - 第一轮 `Tests/Stage2/evidence/run-43720018216/`（build 失败，已复盘）；
  - 第二轮 `Tests/Stage2/evidence/run-43722114624/`（非界面层通过）；
  - 第三轮 `Tests/Stage2/evidence/run-003-manifest-order/`（build manifest 失败，exclude/sources 顺序，已修复）；
  - 第四轮 `Tests/Stage2/evidence/run-43727178213/`（六 job：build/test/isolation/artifact 通过，app-build 占位）；
  - 第五轮 `Tests/Stage2/evidence/run-43730012764/`（非界面层通过；app-build 在 `xcodegen generate` 失败，已本地修复待复验）；
  - 第六轮 `Tests/Stage2/evidence/run-43731864270/`（工程生成/App 编译/模拟器安装启动/归档通过；渲染与常驻缺口显式记录）；
  - 第七轮 `Tests/Stage2/evidence/run-43736107678/`（A4 截图渲染、A6 存活复查加固复验通过；标准 6 闭环）。

## 1. 最终验收标准（8 条）

| # | 标准 | 状态 | 证据 / 备注 |
|---|---|---|---|
| 1 | SwiftPM 模块全部编译成功（Models / Adapters / Core） | ✅ 通过 | run 43736107678 build 日志：`Build complete! (9.38s)`，三模块 Emitting module |
| 2 | Models Codable 测试通过 | ✅ 通过 | run 43736107678 test 日志：`Executed 4 tests, with 0 failures`（0.005s）；test-log artifact 14170388786 正常上传 |
| 3 | RootHide / Rootless 隔离检查通过 | ✅ 通过（静态文本层面） | isolation 日志三向 OK；运行时隔离不在本轮 |
| 4 | GitHub Actions 可手动重复构建 | ✅ 通过 | 第七轮手动 `workflow_dispatch` 拉起六 job；checkout@v6 / upload-artifact@v7 正常，无 Node20 警告、无 unhandled files 警告（§2） |
| 5 | Xcode App Target 成功编译 | ✅ 通过 | run 43736107678：`xcodegen generate` 产出 `FilterKit.xcodeproj`；`xcodebuild` iOS Simulator Debug `** BUILD SUCCEEDED **`，产出 `FilterKit.app`；App target 三元组 ios17.0-simulator，双架构 arm64/x86_64 |
| 6 | iOS Simulator 成功启动并渲染 Dashboard | ✅ 通过 | run 43736107678：`iPhone 17 Pro`（UDID 98A0BFA3…）install 无报错、`launch` 返回 PID 4813；3s 后 `launchctl list` 存活 PID 4813 与启动 PID 一致；`dashboard.png`（1206×2622）渲染标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」与只读脚注，文案与源码逐字一致。模拟器启动不等于越狱权限通过 |
| 7 | 构建产物与测试报告归档 | ✅ 通过 | metadata artifact 14170409389（6594 bytes）；test-log artifact 14170388786（906 bytes）；`filterkit-app-build` artifact 14170656670（449341 bytes，含编译日志、启动日志、截图、`FilterKit.app`） |
| 8 | 无插件写入、启停、安装或卸载功能 | ✅ 边界核对 | 骨架仅只读占位；未实现启停/改 plist/删 dylib/改软链/装卸/dpkg 写入/自动修复 |

## 2. CI 配置复验清单（对应标准 4，第七轮 run 43736107678 复验通过）

| # | 复验点 | 通过判据 | 结果 |
|---|---|---|---|
| 1 | `workflow_dispatch` 可正常触发 | 手动运行产生新 run，job 正常排队/启动 | ✅ 第七轮六 job 正常启动；push/PR 已移除 |
| 2 | `checkout@v6` 正常运行 | Checkout 步骤成功无报错 | ✅ checkout@v6 切到 `82430230` 成功 |
| 3 | `upload-artifact@v7` 正常运行 | artifact 上传成功可下载 | ✅ v7 归档 metadata / test-log / app-build 三类 artifact |
| 4 | Node 20 deprecation 警告消失 | 日志无 `Node.js 20 is deprecated` | ✅ 全部日志无该条目 |
| 5 | `unhandled files` 警告消失 | build/test 不再列出 README/evidence/.gitkeep | ✅ build/test 日志无未处理资源警告 |
| 6 | Models / Adapters / Core 编译仍通过 | 三模块 Emitting module，`Build complete` | ✅ `Build complete! (9.38s)` |
| 7 | 4 项骨架测试仍通过 | `Executed 4 tests, with 0 failures` | ✅ 4/4，0 失败（0.005s） |

## 3. App Target 集成清单（对应标准 5、6、7）

步骤已写入 workflow `app-build` job（XcodeGen → xcodebuild → simctl → 存活复查 → 截图）；第七轮 run 43736107678 回填结果如下：

| A# | 工作 | 状态 | runner 证据 / 缺口 |
|---|---|---|---|
| A1 | 核对依赖关系与构建方案 | ✅ 已验证 | 编译日志显式依赖：App → Models/Adapters/Core 产品；Core → Models；Adapters → Models；Models 无依赖；未复制第二套 Core/Models |
| A2 | SwiftUI / UIKit 选型 | ✅ 编译+渲染层确认 | SwiftUI 在 Xcode 26.6 / Swift 6.3.3 编译通过；未触发 UIKit 回退；第七轮截图确认界面正常渲染 |
| A3 | XcodeGen 配置可生成工程 | ✅ 已验证 | XcodeGen 2.46.0；`xcodegen generate` 成功产出 `FilterKit.xcodeproj`，生成 plists |
| A4 | 最小 App 显示 Dashboard | ✅ 已验证 | `dashboard.png`（1206×2622）：标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」、只读脚注，与 `DashboardView.swift` 逐字一致，中文渲染正常 |
| A5 | xcodebuild 编译成功 | ✅ 已验证 | `** BUILD SUCCEEDED **`；iOS Simulator Debug，arm64 + x86_64，App target 三元组 ios17.0；产物 `FilterKit.app`；Xcode 26.6 / Swift 6.3.3 / SDK 26.5 |
| A6 | 模拟器安装并启动 | ✅ 已验证 | 模拟器 `iPhone 17 Pro`（UDID 98A0BFA3…）install 无报错、`launch` 返回 PID 4813；3s 后 `launchctl list` 存活 PID 4813 与启动 PID 一致，非 `-` |
| A7 | CI 归档 | ✅ 已验证 | `filterkit-app-build` artifact 14170656670（449341 bytes，含 xcodebuild 日志、sim-launch 日志、`dashboard.png`、`FilterKit.app`）；metadata 14170409389；test-log 14170388786；最终 SHA `82430230b017380913c6c11befb0c41336dbe963` |

回填后核对：B2（App target 草案 17.0，编译三元组已作用）、B3（Bundle ID `com.filterkit.manager` 模拟器可解析启动）、B4（SwiftUI 编译+渲染通过）取得编译/启动/渲染层证据；命名冻结、包产品平台最低版本与真机兼容仍待打包阶段/2.5 证据，证据不足继续保留草案标注。

## 4. 闭环结论与观察项归档

**闭环判定（2026-11-16 授权）**：标准 1–8 已在第七轮 run 43736107678 取得真实通过证据；A4 渲染可见性、A6 进程存活两项缺口已由加固步骤补齐（截图归档 + 3s 存活复查，PID 一致）。2.1 目标为工程引导与非界面层/App 编译启动验收，不是越狱权限验证；以下观察项不属于 2.1 门禁，归档到对应后续阶段。

| # | 观察项 | 现状（2.1 口径） | 归档阶段 |
|---|---|---|---|
| O1 | GUI 进程真实文件访问权限 | 模拟器启动/存活/渲染已取证；沙盒内读不到隐藏容器，真实访问未探针 | 2.4 权限探针 |
| O2 | entitlement / sandbox 放行 | 未申请、未验证 | 2.4 权限探针 |
| O3 | `jbroot()` 真实调用验证 | 未在真机进程内调用 | 2.4 权限探针 |
| O4 | Rootless 真机验证 | 无 Rootless 设备；结果不以 RootHide 覆盖 | 具备 Rootless 设备后 |
| O5 | 插件实际加载行为 | 无独立运行时证据；`loaded` 恒 `unknown` | 后续真机验证 |

其余记录：
- 包产品（Models/Adapters/Core）编译三元组为 SPM 默认 iOS 12.0，App target 为 17.0；Package.swift 未显式声明平台最低版本，打包阶段复核；
- B2/B3/B4 仅取得编译/启动/渲染层证据，命名冻结与真机兼容待打包阶段/2.5；模拟器启动与 3s 存活窗口不等于长期稳定性，不等于越狱权限通过（2.4）；
- 若后续 SwiftUI 渲染不满足门槛，按方案 §2.2 回退 UIKit，不动 Models/Core/Adapters。

**2.1 已闭环；2.2 规格起草属设计授权，2.2 实现代码、135 项 Swift 回归执行、进入 2.3 均未授权（见 `Spec/Stage-2/Stage-2.2-Core-Models-Migration.md §13`）。**

## 5. 边界确认（持续保持）

- 未迁移 Stage 1 完整扫描逻辑（属 2.2）；
- 未执行真机扫描或 GUI 进程权限探针（属 2.4）；
- 未实现插件启停、配置写入、删除、安装/卸载；
- 未改目标 App Bundle、未重签名、未建常驻 Daemon、未自研注入引擎；
- 未修改 Models 字段语义、枚举取值或三层状态口径。

## 6. 后续批次记录（不改变 2.1 闭环判定）

- **2.2-A（仅测试补齐）复验：第八轮 run 43741322151**，`yi-fen/005` @ `f28b6700`；Stage2Tests 21 例 0 失败（枚举原始值 11、全模型往返 4、nil/缺失 2、Optional Bool 并入缺失用例、空数组 2、骨架口径 2），Models/Adapters/Core 编译通过，App Target 沿用 2.1 口径复验通过（PID 4693，截图 1206×2622）。证据 `Tests/Stage2/evidence/run-43741322151/`；明细见 `Spec/Stage-2/Stage-2.2-A-Preflight-Audit.md §7`。
- 边界：R6 未知枚举解码默认行为本轮未实测、未修改；本轮未改 Models/协议/Stage 1 基线。2.2-A 验收后暂停，2.2-B 须单独授权。
