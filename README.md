# FilterKit — RootHide & ElleKit Plugin Manager

> 本工程为 **从 0 重建** 的全新基线。前期 `reference/0.1.18-src` 仅作历史参考，不作为新代码基线。

## 一、产品定位（定稿）

FilterKit 是 RootHide 生态下的 ElleKit 插件管理器：提供类似 TrollFools 的"按 App 管理插件"体验，但**不修改目标 App Bundle、不重签名、不自研注入引擎**，通过管理 ElleKit 全局动态库与原生注入规则完成部署。

- 越狱环境：RootHide 优先（arm64e 主版本，arm64 预留）；架构上预留 Rootless 独立适配路线（见第三节）
- 注入框架：ElleKit（权威分支 `roothide/ellekit @ 16e3e7e / 1.2-3`；上游 `opa334/ElleKit @ 4825b07` 仅参照）
- 插件形式：dylib + 同名 plist
- 注入执行：ElleKit 负责；FilterKit 只管理配置与文件
- 常驻进程：不需要；特权操作走按需 Helper（v1.1 阶段，待真机验证）

## 二、版本规则（本次重建确定）

- 内部迭代从 **0.0.1** 起编（0.0.1 → 0.0.2 …）。
- **0.1.0 标签仅在"环境检测 + 插件扫描 + plist 解析 + 来源识别 + JSON 导出"完整只读链落地并通过验收时授予**；未达里程碑前不提前挂 0.1.0。
- 后续里程碑版本见第五节路线图。版本号不代表功能已实现或可行性已验证。

## 三、目标架构（开发目标，非现状）

统一产品 + 共享管理核心 + 两条独立 Adapter 路线 + 版本 Profile 层。详见 [`Research/Architecture/FilterKit-Two-Route-Architecture.md`](Research/Architecture/FilterKit-Two-Route-Architecture.md)。

```
┌──────────────────────────────┐
│            UI（共享）          │  列表 / 详情 / 搜索 / 关联 / 设置
├──────────────────────────────┤
│     Core（共享管理核心）       │  PluginManager / Database / AppDiscovery / PluginState
├──────────────────────────────┤
│            Models             │  Plugin / App / Filter / JailbreakEnvironment
├──────────────────────────────┤
│        ElleKit Adapter 层     │  按越狱类型 + ElleKit 实现/版本选 Profile
├───────────────┬──────────────┤
│  Rootless Adapter            │  RootHide Adapter
│  上游 ElleKit / /var/jb      │  roothide/ellekit / jbroot() 路径
└───────────────┴──────────────┘
```

约束：UI/Core 不直接操作 ElleKit 文件，底层差异收口在各自 Adapter；不在公共层散落 `if RootHide` 判断；RootHide 不复用 Rootless 的 Filter 解析器。

## 四、三层数据模型（不可混淆）

| 层 | 实体 | 对应 ElleKit 真实物 |
|---|---|---|
| 插件文件层 | dylib | `…/usr/lib/TweakInject/X.dylib` |
| App 关联层 | Filter.Bundles 数组 | 同目录 `X.plist` 的 `Filter` |
| 运行状态层 | 进程是否真加载 | 只能在目标进程冷启动后外部验证 |

铁律：**发现插件 ≠ 管理插件 ≠ 成功注入插件**。规则写入 ≠ 已加载；L4 加载 / L5 运行状态在无特权验证前一律标 UNKNOWN。

## 五、版本路线图（Spec 0.1 冻结）

| 版本 | 目标 | 是否改系统文件 |
|---|---|---|
| 0.0.x | 研究资料库、规格冻结（未达里程碑） | 否 |
| 0.1.0 | 环境检测、插件扫描、plist 解析、来源识别、JSON 导出（完整只读链） | 否 |
| 0.2.0 | App 识别、Bundle ID 管理、关联预览 | 否 |
| 0.3.0 | 插件数据库、详情展示、状态管理 | 否 |
| 0.4.0 | 完整插件管理 UI | 否 |
| 0.5.0 | Filter 规则编辑与变更预览（暂不写入） | 否 |
| 0.6.0 | 插件关联、启用、停用 | 是 |
| 0.7.0 | 插件安装、卸载 | 是 |
| 0.8.0 | dpkg 冲突检测、安全回滚 | 是 |
| 0.9.0 | 兼容性与异常恢复测试 | 是 |
| 1.0.0 | 正式版本 | 是 |

## 六、当前状态

- 研究基准（P0）：`roothide/ellekit @ 16e3e7e（1.2-3）`；上游 `opa334/ElleKit @ 4825b07` 为 P1 参照；真机文件系统为 P2 最终依据。
- 研究报告：`Research/R&D 0.2/RootHide-ElleKit-1.2-3.md`（含路径、规则、顺序、生命周期、引导层子文档）；架构基线见 `Research/Architecture/`；上游历史结论归档于 `Research/R&D 0.1/`。
- 规格冻结（Spec 0.1，未编码）：`Spec/Architecture.md`、`Spec/ElleKit-Compatibility.md`、`Spec/Plugin-Data-Model.md`、`Spec/PoC-0.1.0-Specification.md`；E1–E4 已并入 0.1.0，0.1.0 = 完整只读扫描 + 解析 + 分析 + 导出。
- Stage 1 进度：S1-01 环境识别**离线验收通过（15/15）**；S1-02 JBROOT 路径定位**离线验收通过（18/18）**；S1-03 ElleKit 目录定位**离线验收通过（15/15）**；S1-04 插件枚举**离线验收通过（23/23）**；S1-05 插件配对**离线验收通过（15/15）**；S1-06 Plist/Filter 解析**离线验收通过（22/22）**；S1-07 来源识别**离线验收通过（14/14）**；S1-08 统一模型/JSON 导出**离线验收通过（13/13）**。Stage 1 只读 CLI 验证链离线闭环，合计 **135/135**；离线通过不等于真机验证通过。
- Stage 2 进度：`Spec/Stage-2/Stage-2-Implementation-Plan.md` 计划规格已冻结（2.1 Bootstrap → 2.2 Core/Models 迁移 → 2.3 GUI 基础 → 2.4 权限探针 → 2.5 真机验证）；`Spec/Stage-2/Stage-2.1-Project-Bootstrap.md` 2.1 子规格已冻结。
- 2.1 骨架：App/Core/Adapters/Models 目录、Models Codable 类型、Adapter/Core 协议、App 占位与 CI 草稿（见 `Tests/Stage2/2.1-bootstrap-acceptance.md`）。编译/测试/隔离/CI 可重复构建已由 macOS runner 第七轮验证；本机 Linux 无 Swift/Xcode 工具链，结论以 runner 日志为准；未迁移完整扫描逻辑、未扫真机、无写入/启停功能。**2.1 已于 2026-11-16 授权闭环（保留观察项备注，O1–O5 归档 2.4 / 后续真机）。**
- 2.1-B CI 七轮记录：首轮 run 43720018216 build 失败（缺 `import Models`，已修）；第二轮 run 43722114624（`yi-fen/002` @ `030e6e60`）非界面层通过；第三轮 `yi-fen/003` @ `e49f7c72` manifest 失败（`exclude` 须先于 `sources`，已修）；第四轮 run 43727178213（`yi-fen/003` @ `69e6548`）六 job 复验通过；第五轮 run 43730012764（`yi-fen/004` @ `e2a019a4`）非界面层通过、app-build 在 XcodeGen 解析失败（`info.path` 缺失，已修）；第六轮 run 43731864270（`yi-fen/004` @ `7ee7880c`）App Target 首通；**第七轮 run 43736107678（`yi-fen/004` @ `82430230`）A4/A6 加固复验通过**——`Build complete! (9.38s)`、4 用例 0 失败、静态隔离 OK；`** BUILD SUCCEEDED **`、iPhone 17 Pro launch PID 4813、3s 存活复查 PID 一致、`dashboard.png` 渲染标题/环境/权限占位与只读脚注、`filterkit-app-build` artifact 14170656670。证据见 `Tests/Stage2/Stage-2.1-CI-Acceptance.md` 与 `Tests/Stage2/evidence/`。
- CI 触发：**仅手动 `workflow_dispatch`**，push / PR 不自动构建；action 为 Node 24 主版本（checkout@v6、upload-artifact@v7）；第七轮全部日志无 Node20 deprecation 警告、无 unhandled files 警告；test-log artifact 正常上传（14170388786），目录竞态修复生效。
- App Target 方案：首选 SwiftUI / UIKit 兜底，草案 Deployment Target iOS 17.0、Bundle ID 占位（B2/B3/B4 待打包阶段与真机证据冻结）；第七轮 XcodeGen 2.46.0 生成工程、xcodebuild iOS Simulator 双架构编译成功、模拟器安装启动、存活复查与 Dashboard 截图渲染通过并归档 `.app`。方案见 `Spec/Stage-2/Stage-2.1-App-Target-Plan.md`，验收见 `Tests/Stage2/Stage-2.1-Final-Acceptance.md`。
- 真机已知：iOS 17.0.2 / iPhone16,2（arm64e）/ RootHide / ellekit 1.2-3 / 已识别 265 App；JBROOT 与软链目标已由 0.1.18 报告旁证（`Research/Validation/Device-Report-0.1.18-Findings.md`）
- P0 资料缺口：见 `docs/P0-CHECKLIST.md` 与 `Research/Validation/`
- **当前阶段：Stage 1 离线闭环（135/135）；Stage 2.1 已闭环（标准 1–8，第七轮 run 43736107678；观察项归档 2.4 / 后续真机）；2.2-A 仅测试补齐已由第八轮 run 43741322151 复验通过（21 例 0 失败，R6 未知枚举解码未实测未修改）；2.2-B 数据契约已定稿冻结（`Spec/Stage-2/Stage-2.2-B-Data-Contract-Freeze.md`）；2.2-B1 环境识别已由第十一轮 run-43793314782 runner 验收通过（build 通过、28 例 0 失败、隔离三向 OK、App 构建启动存活；`Spec/Stage-2/Stage-2.2-B1-Environment-Detection.md`）；2.2-B2 JBROOT 候选收集已由第十二轮 run-118584150452 runner 验收通过（build 通过、38 例 0 失败、隔离三向 OK、App 构建启动存活；`Spec/Stage-2/Stage-2.2-B2-Candidate-Collection.md`，只收集不裁决）；2.2-B3 JBROOT 校验与裁决本地验收通过（方案 B，基准提交 `3e878cb`；本地静态核对 56 例计数/规则/隔离通过，CI Runner、独立构建与正式闭环延后 B5 集中回归，71 项逐阶段映射；`Spec/Stage-2/Stage-2.2-B3-Validation-Adjudication.md`）；B4/B5、Models 增补落地验收、2.2-C 及以后未授权，未进入 2.3。**

## 七、目录约定

```
FilterKit/
├── README.md                  # 本文件：项目基线与规则
├── docs/
│   └── P0-CHECKLIST.md         # 前置资料清单（已具备 / 待补 / 待验证）
├── Spec/                      # 技术规格冻结草案（未编码）
│   ├── Architecture.md         # 整体软件架构与 Adapter 契约
│   ├── ElleKit-Compatibility.md # 双路线兼容规范
│   ├── Plugin-Data-Model.md    # 插件/环境/归属数据模型
│   ├── PoC-0.1.0-Specification.md # 第一版只读 PoC 规格
│   ├── Dev-Preparation-0.1.md  # 开发前准备基线：三阶段路线/部署定案/验收原则
│   └── Stage-1-CLI-Test-Plan.md # Stage 1 CLI 只读验证任务清单 S1-01~S1-08
│       └── Stage-1/             # 各任务子规格（S1-01 环境识别）
│       └── Stage-2/             # Stage 2 正式 App 工程与 GUI 基础实施计划（含 2.1 子规格）
├── Research/                  # 研发知识库（只读研究产物）
│   ├── Architecture/           # 双路线适配器 + 版本 Profile 架构基线
│   ├── R&D 0.1/               # 上游 4825b07 历史结论归档
│   ├── R&D 0.2/               # RootHide 1.2-3 权威结论 + 子文档
│   └── Validation/             # 真机验证清单与采集表
├── App/ Core/ Adapters/ Models/ # 2.1 骨架（runner 第六轮已编译/启动；协议/类型/占位，见 Tests/Stage2/）
├── project.yml                # XcodeGen 工程定义（runner 生成 .xcodeproj，产物不入库）
├── Tests/                     # Stage 1 离线测试产物（夹具 + harness + 报告）
│   ├── Fixtures/S1-01/         # 六组离线夹具（environment 输入 / metadata 预期分离）
│   └── S1-01/                 # 识别 harness 与测试报告、验收记录
├── research/                  # 源码克隆（本地证据，非交付文档）
│   ├── roothide-ellekit-src/  # P0：roothide/ellekit @ 16e3e7e
│   ├── dopamine-roothide-src/  # 引导层：Dopamine-roothide @ 9617d75
│   ├── roothide-theos-src/     # 构建系统：roothide/theos @ 958fea4
│   ├── ellekit-src/           # P1：opa334/ElleKit @ 4825b07
│   └── libroothide-src/       # A7：路径解析库
└── reference/
    └── 0.1.18-src/            # 历史版本，仅参考，不作基线
```
