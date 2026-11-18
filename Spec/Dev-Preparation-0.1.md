# Dev-Preparation-0.1 — FilterKit 开发前准备基线（Dev-Preparation 0.1）

- 状态：**开发前准备基线，已冻结**。本阶段不写功能代码、不堆 UI、不创建源码骨架、不编译；先固化基线并验证底层可行性。
- 关联：[PoC-0.1.0-Specification.md](./PoC-0.1.0-Specification.md)、[Architecture.md](./Architecture.md)、[Plugin-Data-Model.md](./Plugin-Data-Model.md)。
- 仓库锚点：`roothide/theos @ master 958fea4`（本地 `research/roothide-theos-src`）；`theos/sdks @ master 0222fd54`（未拉取大体积 SDK）。

## 1. 已确认决策（2026-11-15）

| 项 | 决定 |
|---|---|
| 编译方式 | **GitHub 在线编译**（macos-latest runner，Theos 交叉打包） |
| 测试真机 | **仅 RootHide 真机**一台；Rootless 无设备，相关验证延后（合成样本 / 后续设备） |
| 最终形态 | **越狱文件访问 App**；分阶段验证，不一开始陷入权限与部署问题 |
| 部署研究优先级 | 先核对特殊权限 App 与 Bootstrap 部署机制可行性；**不假设普通签名 IPA 就能访问 `/var/jb` 或隐藏容器** |

### 1.1 部署架构正式定案

最终采用：**特殊权限 App（最终运行形态）+ Bootstrap 安装通道（装入 JBROOT 并注册）+ 权限真机验证**。CLI 仅作第一阶段逻辑验证载体。

| 项目 | 定位 | 决策 |
|---|---|---|
| 普通 IPA | 不具备目标文件访问能力的默认方案 | **不作为部署前提** |
| 特殊权限 App | FilterKit 最终运行形态 | **采用**，权限待真机验证 |
| Bootstrap 安装通道 | 将 App 安装到 JBROOT 并注册 | **采用** |
| CLI | 验证底层文件访问与解析逻辑 | **仅 Stage 1 使用** |

> **关键边界：通过 Bootstrap 安装成功 ≠ App 自动获得文件访问权限。** 安装位置、代码签名、entitlements、sandbox 策略、进程内路径解析是**不同问题，必须分别验收**，不得用其中一项通过推断另一项。

## 2. 阶段目标

产品定位、双路线研究、架构、数据模型、PoC 规格已冻结。本基线固化：技术栈落地口径、底层六项能力验证计划、样本与工程结构、部署方案与验收原则。T1–T6 与权限通路在对应阶段通过后，再正式建立源码工程。

## 3. 技术栈基线（提议，待编译/真机验证）

| 项 | 提议 | 备注 |
|---|---|---|
| UI | Swift + UIKit | 倾向方案；SwiftUI 备选，待工程验证 |
| 核心逻辑 | Swift | 扫描、建模、编排 |
| 底层路径 / 文件系统适配 | 必要时 Objective-C / C | 对接 libroothide、POSIX、CF 类型校验处 |
| 数据模型 | Swift Models + Codable | 对齐 [Plugin-Data-Model.md](./Plugin-Data-Model.md) |
| 最低 iOS 版本 | 待定（建议先 15.0 起步） | 设备 iOS 17.0.2；官方 Manager MinOS 15.0 可参照 |
| 目标架构 | arm64e 主（RootHide），arm64 次（Rootless） | 与双路线一致 |
| 应用运行时 | Swift | Node.js 不进入 App 运行时 |

## 4. 编译与 CI 环境基线

### 4.1 CI 运行时

- 平台：**GitHub Actions 在线编译**，Runner `macos-latest`。
- Node.js：**latest**，仅用于 CI 脚本 / 打包工具链；不作为 App 运行时。
- 本 Linux 云主机不承担 iOS 编译；交叉编译/打包在 macOS runner 完成。

### 4.2 Theos 按越狱环境分两套

| Profile | Theos 源 | 打包方案 | 架构 | 关键链接口径 |
|---|---|---|---|---|
| RootHide | `https://github.com/roothide/theos.git`（master `958fea4`） | `THEOS_PACKAGE_SCHEME=roothide` | `arm64e arm64` | iphone 目标下跳过 `-lroot`；定义 `THEOS_PACKAGE_SCHEME_ROOTHIDE=1`（`rules.mk:141,147`） |
| Rootless | 上游 `https://github.com/theos/theos.git`（默认分支，版本待固定） | `rootless` | `arm64` | 标准上游链接口径；**当前无真机，仅离线/合成验证** |

### 4.3 SDK（双路线共用）

- 源：`https://github.com/theos/sdks.git`（master `0222fd54`），patched iOS SDK（含私有符号）。
- 可用 iPhoneOS SDK：`9.3 / 10.3 / 11.4 / 12.4 / 13.7 / 14.5 / 15.6 / 16.5`；**无 17.x SDK**。
- 待实测：16.5 SDK 编译、部署目标向下兼容到 iOS 17.0.2 设备的链接与运行；FilterKit 只读文件、不依赖最新私有 API，风险可控。

### 4.4 待确认工具链项

- 上游 theos 默认分支与固定版本号。
- arm64e 切片在 16.5 SDK + iOS 17 设备上的链接/加载表现。
- Swift 在 Theos 工程下的工具链配置（`vendor/swift-support`）是否满足 UIKit + Codable。

## 5. 技术可行性验证 T1–T6（全部只读）

| 编号 | 验证项 | 验收目标 | 路线 | 现状依据 |
|---|---|---|---|---|
| T1 | RootHide 环境识别 | 正确判定 `roothide`，读出类型/架构/iOS 版本 | RootHide | 真机报告旁证 `jailbreak_type=roothide` |
| T2 | Rootless 环境识别 | 正确判定 `rootless` | Rootless | **无真机**，延后至合成样本/后续设备 |
| T3 | JBROOT 定位 | 找到正确越狱根目录（路径归一、可枚举） | RootHide 先验；Rootless 延后 | RootHide 路径已旁证 |
| T4 | ElleKit 路径解析 | 定位正确 TweakInject 目录与软链目标 | RootHide 先验；Rootless 延后 | RootHide 软链→TweakInject 已旁证 |
| T5 | 文件扫描 | 枚举目录内 dylib / plist，记录存在性/可读性/类型 | RootHide 先验 | 旧报告枚举不全，需全量复核 |
| T6 | plist 读取解析 | 正确解析真实插件 Filter 字段并做类型告警 | RootHide 先验 | 待真实 plist 原文样本 |

> T3、T4 设计上要求双路线分别验证；当前仅有 RootHide 真机，Rootless 项标记 `[Rootless 真机待验证]`，不以 RootHide 结果替代。

## 6. 部署方式可行性核对（方案 1 / 2 / 3）

### 6.1 三方案比较

| 方案 | 说明 | 优点 | 缺点 / 风险 | 结论 |
|---|---|---|---|---|
| 1 普通 IPA + 越狱签名 | 常规签名安装，不附加私有权限 | 开发/部署简单 | 仍在默认沙盒，**不能**默认访问 `/var/jb` 或 `.jbroot-*` 隐藏容器 | **不采用为前提**；未验证可读，不假设可行 |
| 2 特殊权限 App | 携带额外 entitlement / 平台能力的 App | 最终产品形态，可读取越狱文件 | 需解决 entitlement 放行、签名链、容器可读性 | **最终方向**，可行性待真机验证 |
| 3 Bootstrap 工具链/部署机制 | 经越狱打包与安装通道装入 JBROOT | 与官方 Manager/Sileo 同一套落地方式 | 依赖越狱 bootstrap 的包管理与注册机制 | **方案 2 的部署通道**，与 2 互补 |

### 6.2 本地源码/包证据

- **官方 RootHide Manager（`roothideapp.deb`，本地解包核对）**：
  - 安装位置：deb 根相对 `Applications/RootHide.app`；`postinst` 执行 `uicache -p /Applications/RootHide.app` 注册。
  - 二进制内嵌 entitlement：`platform-application`、`com.apple.private.security.no-sandbox`、`com.apple.private.security.storage.AppBundles`、`com.apple.private.security.storage.AppDataContainers`。
  - `MinimumOSVersion 15.0`；架构 arm64。
- **引导层安装通道**：内置 `sileo.deb / zebra.deb / roothideapp.deb` 经 `jbctl internal install_pkg` / dpkg 装入 JBROOT（`DOBootstrapper.m:483,1405`）。
- **旧 0.1.18 PoC（仅参考）**：Theos `application.mk`，`INSTALL_PATH=/Applications`，`-weak-lroothide`，rpath `@loader_path/.jbroot/usr/lib`，`-Sentitlements.plist`；entitlement 集合与官方 Manager 一致。但其 Helper/IPC 未验证通过，文件读取部分经 `jbroot()` 完成——**旧工程结论不作新基线**。
- **BaseBin 守护进程 entitlement**（更强，仅供参照，不等同 App 可用）：另含 `no-container`、`task_for_pid-allow`、`system-task-ports` 等。

### 6.3 待真机验证的权限通路

1. 携带 §6.2 那组 entitlement 的 **GUI App** 进程内，能否读 `.jbroot-*` 容器与 `TweakInject`。
2. 越狱 amfid / 签名链是否放行这些私有 entitlement（ldid 签名是否被认可）。
3. App 装入 `JBROOT/Applications` 后 `uicache` 注册、冷启动是否正常。
4. 是否还需要 `no-container` 或额外 sandbox exception 才能访问隐藏容器。
5. 进程内弱链接 libroothide、调用 `jbroot()` 的符号可用性。

> 任一项不成立时，回退路径（CLI 经越狱 shell 运行 / 按需 Helper）在后续阶段评估；本版不实现常驻 Daemon。

## 7. 三阶段实施（B 为最终目标）

### Stage 1：CLI 只读技术验证

目标：证明底层技术逻辑正确。运行于越狱 shell 上下文。

- JBROOT 路径定位与规范化。
- RootHide ElleKit 插件目录定位。
- dylib/plist 枚举与配对。
- plist 读取与解析、Filter 规则解析。
- 插件来源初步识别。
- 统一数据模型与 JSON 导出。
- 异常处理：文件不存在、权限拒绝、格式错误等记录后继续。

> **通过标准仅限底层逻辑通过，不代表 App 权限通过。** CLI 在 shell 中的文件权限不等同最终 GUI App 沙盒环境。

### Stage 2：GUI App 工程与功能验证

目标：建立真正的 FilterKit App，接入 Stage 1 已验证的底层模块。

- App 工程与基础 UI、环境信息展示。
- 插件列表、插件详情、Filter 规则展示、扫描报告、JSON 导出（只读）。
- **独立权限探针（PermissionProbe）**：在 GUI App **自身进程内**逐项测试，结果独立于 CLI：
  1. 能否访问 `.jbroot-*`；
  2. 能否读取 TweakInject；
  3. 能否读取 dylib 与 plist；
  4. 能否解析 `jbroot()`；
  5. 能否访问必要的 dpkg 数据。

> GUI App 的访问测试必须独立于 CLI 结果，不得拿 CLI 执行结果冒充 GUI 权限。

### Stage 3：权限与兼容性完善

目标：解决真实设备上的部署与权限问题；只有本阶段完成，才确认部署链路真正可用。

- entitlement 是否被签名工具保留。
- amfid / ldid 是否接受目标权限。
- Bootstrap 安装与 uicache 注册、安装后冷启动行为。
- sandbox / container 限制；`no-container` 或额外 sandbox 例外是否必要。
- RootHide 不同版本兼容性；Rootless 路径适配（待设备/样本）。
- 权限异常检测、文件访问失败处理、双路线回归测试。

## 8. 验收原则

### 原则 A：权限不能靠推断

以下每一项都必须有**实际运行证据**，不得由相关现象推断：

- 二进制包含 `platform-application` entitlement，不代表系统一定授予。
- 安装到 `/Applications`，不代表能读取隐藏容器。
- `jbroot()` 符号存在，不代表运行时一定能成功解析路径。
- `uicache` 注册成功，不代表 App 能正常启动。

### 原则 B：CLI 与 GUI 共用同一套 Core

CLI 不单独实现一套扫描/解析逻辑，GUI 也不复制第二套；二者共用 Core、Models、Adapters。权限探针由 GUI App 自己执行。

### 原则 C：Rootless 不能被 RootHide 验收结果覆盖

当前只有 RootHide 真机是明确测试边界。报告统一使用以下证据标签：

| 标签 | 含义 |
|---|---|
| `[源码确认]` | 仅由上游/本地源码核对得出 |
| `[RootHide 真机验证]` | RootHide 真机运行实测通过 |
| `[Rootless 合成样本验证]` | 固定夹具离线验证，非真机 |
| `[Rootless 真机待验证]` | 需 Rootless 真机，当前未验 |
| `[权限待验证]` | 权限/签名/容器访问待真机实测 |

> 不得因 RootHide 通过，就把 Rootless Adapter 标记为通过。

## 9. 测试样本库规划（回归基线）

### 9.1 RootHide 样本

| 样本 | 用途 |
|---|---|
| 正常 Sileo 插件 | 标准配对 + Bundles 命中 |
| 多 App 关联插件 | 单插件 Bundles 列多个 ID |
| 含 Classes / Executables 插件 | 非 Bundles 规则解析 |
| 异常 plist | 损坏 / 类型错误 / 未知字段，验证告警不崩溃 |
| 缺配对文件 | 缺 plist 的 dylib、孤儿 plist |

### 9.2 Rootless 样本

对应准备同类样本；当前无真机，先以固定夹具（Fixtures）离线回归，真机验证延后。

- 样本作为 `Tests/Fixtures` 只读固定数据；每次改 Adapter 跑同一组回归。
- 现有真机旁证样本 2 个（`z.weifeng`、`com.dao.filzacrack`，见 Validation 回写文档），缺原文与异常样本，待补采/构造。

## 10. 工程蓝图（暂不创建源码）

```
FilterKit/
├── Core/
│   ├── Environment/       # 环境识别
│   ├── PathResolver/     # JBROOT / 路径归一 / jbroot() 对接
│   ├── PluginScanner/     # 目录枚举与配对
│   ├── PlistParser/      # plist 读取与类型校验
│   ├── FilterParser/     # Filter 规则解析
│   └── ReportExporter/   # 统一模型与 JSON 导出
├── Adapters/
│   ├── RootHide/
│   └── Rootless/
├── Models/                # Plugin / FilterRule / JailbreakEnvironment
├── CLI/                   # Stage 1 只读验证载体（复用 Core/Models/Adapters）
├── App/
│   ├── Views/
│   ├── ViewModels/
│   └── PermissionProbe/   # Stage 2 GUI 进程内权限探针
└── Tests/
    ├── RootHideTests/
    ├── RootlessTests/
    └── Fixtures/
```

> 与 [Architecture.md](./Architecture.md) 的 Core/Adapters/Models/UI 划分一致；`CLI` 与 `App` 复用同一 Core/Models/Adapters，不重复实现逻辑。目录在 Stage 1 验证通过后再落地。

## 11. PoC 0.1.0 开发顺序（逐模块验收）

1. 环境识别 → 2. 路径解析 → 3. 插件目录扫描 → 4. dylib/plist 配对 → 5. plist 解析 → 6. Filter 展示 → 7. 来源识别 → 8. JSON 导出 → 9. 双路线回归测试。

每完成一个模块即验收一个模块，不一次性堆积全部功能。

## 12. 基线完成状态

| 项目 | 状态 |
|---|---|
| 产品定位 | 已确定 |
| 双 Adapter 架构 | 已确定 |
| RootHide 源码基准 | 已确定 |
| Rootless 测试边界 | 已确定 |
| 编译平台 | 已确定 |
| 最终 App 形态 | 已确定 |
| Bootstrap 安装方向 | 已确定 |
| CLI 第一阶段 | 已确定 |
| 特殊权限放行 | `[权限待验证]` |
| GUI 文件访问能力 | `[权限待验证]` |
| jbroot() 进程内调用 | `[权限待验证]` |

## 13. 本阶段冻结边界

- 产出：环境基线、验证计划、部署可行性分析、验收原则、样本规划、工程蓝图。
- 不做：功能编码、UI 实现、编译打包、创建源码目录、任何设备写入。
- 下一步：固化本基线后进入 **Stage 1**，制作范围严格受限的 CLI 只读验证程序；不提前编写 FilterKit 功能代码。
- 进入 GUI 工程编码的前提：Stage 1 底层逻辑通过 + Stage 2 权限探针在 GUI 进程内验证 + 部署通道（方案 2/3）落定。
