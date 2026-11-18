# FilterKit 0.1.0 里程碑验收计划（Milestone-Based Verification Policy）

- 状态：**计划规格冻结**。本文件只定义里程碑划分、验收分级、退出标准与门禁口径；不写生产代码、不编译、不调度 Runner、不扫描真机。
- 上游基线：`Spec/PoC-0.1.0-Specification.md`（只读范围与功能验收）；`Spec/Stage-2/Stage-2-Implementation-Plan.md`（子阶段、接口契约、风险与暂缓清单）；`Spec/Stage-2/Stage-2.2-D-Reporting-Implementation-Spec.md`（D1～D5 冻结规格）；第五轮验收证据 `Tests/Stage2/evidence/run-44106064051-acceptance/`。
- 本地基线 HEAD：`2c3d6a3`；第五轮 Runner `44106064051`（branch `D5`，检出 SHA `f4629f268e680bc0e25e911997d03959457263ec`）。
- 定位：本计划是项目管理与验收口径规格，**不替代**各子阶段实施规格；任一里程碑进入实现前仍按既有流程单独授权。

## 1. 目的

Core 主要建设已完成，后续工作按里程碑组织。核心原则：

- 小步骤开发、阶段内自检、里程碑统一 Runner 验收、版本发布前完整验收。
- 不取消测试、不降低质量；只减少每个小批次都启动 Runner 的频率。
- CLI 与 GUI 始终共用同一套已迁移验收的 Core，不在界面层另写扫描/解析器。

## 2. 验收分级（L1 / L2 / L3）

| 等级 | 方式 | 是否需要 Runner | 产出 |
|---|---|---|---|
| **L1 开发自检** | 代码结构、接口一致性、测试用例完整性、架构约束、Git Diff、冻结规格是否被改动、待验证项记录 | 否 | 自检记录与待验证清单；可在开发过程中持续补充 XCTest |
| **L2 阶段集成验收** | 阶段代码冻结后集中编译、单元测试、回归测试、双路线隔离、Core/App 构建 | 是，**每个里程碑结束时一次** | 阶段证据归档、门禁结论、阶段正式验收记录 |
| **L3 版本验收** | 0.1.0 发布前全量验收（见 §6） | 是 | 版本级验收报告、安装包与发布文档背书 |

**定向提前验证触发条件**：若阶段中途改动公共 Models、Adapter 七方法协议、Parser 语义或其他冻结接口，或出现高风险接口 / 基础构建问题，必须暂停并做针对性验证，不能机械等到阶段末尾。失败后允许针对失败项修复与定向复验，不必无条件重跑全部测试。

## 3. 里程碑划分（0.1-A ～ 0.1-E）

| 里程碑 | 对应既有阶段 | 主要内容 | L2 Runner / 验收范围 | 当前状态（2026-11-17） |
|---|---|---|---|---|
| **0.1-A** Engine C2 收口 | Stage 2.2-C3 Engine | C2-A～D 测试与代码收口、C2-E 证据体系、RootHide/Rootless Parser 集成、Engine 完整链路、三向架构隔离 | 全量 XCTest、Core Build、App Build、双路线隔离脚本 | ✅ **已闭环**：run `44106064051`，379 例 0 fail / 0 skip，Core 0 error / 0 warning，App BUILD SUCCEEDED、PID 3508 存活，隔离六项 OK；C-G1～G7 判为 passed。**仅 CI/Simulator 口径**，非真机权限、真实加载或 Rootless 真机兼容证据 |
| **0.1-B** 统一报告与 JSON 导出 | Stage 2.2-D | Report Models 审计、Report Builder、Report Validator、JSON Exporter、Report Service；确定性排序与三态保留 | 阶段末一次 Runner：D1～D5 用例 + 既有回归无损伤 + JSON 确定性深比较 | ✅ **已闭环（CI/Simulator 口径）**：第四轮 Runner run `44224350333`（SHA `9a3f087`，macos-26 / Xcode 26.6 / Swift 6.3.3），非 UI Build `Build complete! (19.62s)` 0 error / 0 warning；全量 **397 例 0 failures / 0 skipped**（既有回归 379 + Reporting 18：Builder 6 / Validator 4 / Exporter 5 / Service 3）；S1-05 独立过滤 15 例 0 failure；隔离四项 OK；App `** BUILD SUCCEEDED **`，PID 4096 存活，只读骨架截图归档；第三轮两处断言失败（`installed` nil 显式落 `null`、RV-003 样本保留 nil 路径证据）复验通过。历程：首轮 SHA `117a5df` Core 4 处 `lastPathComponent` 误当 `String` 成员（提交 `b8ba3f3`）；二轮 run `44217387852` SHA `5fcb00e` 测试目标编译错误（提交 `4c95e30`）；三轮 run `44221150319` SHA `d08f04f` 2 例断言失败（提交 `94bd7f2`）；四轮全绿。证据 `Tests/Stage2/evidence/run-44224350333-acceptance/`。**仅 CI/Simulator 口径**，非真机权限、真实加载或 Rootless 真机兼容证据。`Core/OwnershipResolver/` 仍占位未迁移，`loaded` 恒 unknown |
| **0.1-C** GUI 完整建设 | Stage 2.3 | Dashboard、Plugins 列表、Plugin Detail、Diagnostics、JSON 导出入口、加载/未知状态展示、空态/错误态/权限不足提示 | 阶段末一次 Runner：App Build、ViewModel 与 Core 快照一致性、页面只读约束核对 | 🟡 **Implementation Landed / Runner Pending**（2026-11-18）：C1～C6 代码与 GUI-01～08 Presentation 单测已落盘；`AppPresentation` 纯映射目标接入 SwiftPM，隔离脚本 GUI 禁止面扩展。本机 Linux 无 Swift 工具链未本地编译，编译/渲染/交互以阶段末 Runner 为准；合成信封仅预览，非真机权限/真实加载/Rootless 真机兼容证据。`OwnershipResolver` 未迁移、`loaded` 恒 unknown、PARSE-009-B 挂起 |
| **0.1-D** 权限探针与真机验证 | Stage 2.4 + 2.5 | GUI 进程内访问 JBROOT、TweakInject、dylib/plist 枚举、plist 读取、dpkg 来源识别、`jbroot()` 调用、冷启动后权限保持；RootHide 真机一轮完整只读扫描并与已知环境数据对比 | 真机证据为主；Runner 仅覆盖离线 / 模拟器可验证部分；Rootless 结果独立标记，不以 RootHide 代替 | ⬜ 未进入；当前最大风险项 |
| **0.1-E** 发布准备与完整验收 | 0.1.0 L3 | Bug 修复、界面打磨、安装包、版本信息、发布说明；L3 全量验收 | §6 全部退出项 + 安装包可正常安装启动 + 发布文档完整 | ⬜ 未进入 |

## 4. 里程碑固定流程

```
阶段开始
   ▼
冻结本阶段规格
   ▼
拆分开发批次
   ▼
批次 1 开发 ── L1 自检
   ▼
批次 2 开发 ── L1 自检
   ▼
批次 3 开发 ── L1 自检
   ▼
阶段代码冻结
   ▼
统一 L2 Runner 验收
   ├── 失败 → 定向修复 → 定向复验
   ▼
证据归档
   ▼
阶段正式验收
   ▼
进入下一里程碑
```

补充规则：

1. 每个里程碑允许包含多个独立开发批次；普通批次不要求启动 Runner。
2. 同一里程碑的相关改动尽量合并到一个 Runner 验收基线。
3. 阶段验收通过才正式关闭该里程碑；未运行 / 跳过 / 待验收一律不计通过。
4. 真机权限与注入行为不得用离线测试或 CI 结果代替。

## 5. 0.1.0 正式定义

**FilterKit 0.1.0 — RootHide Read-Only Plugin Manager**。本版不定义为完整插件管理器，必须具备：

- 正确识别 RootHide / ElleKit 环境；
- 正确定位 JBROOT 与 TweakInject；
- 枚举 dylib 与 plist，正确配对插件文件；
- 按 RootHide 规则解析 Filter；
- 识别插件来源与所有权；
- 展示插件列表、详情与诊断信息；
- 导出 JSON 诊断报告；
- 在 RootHide 真机 GUI 环境完成只读验证；
- 未确认状态明确显示，不伪造 `loaded`；
- 不修改插件文件、不修改注入规则、不执行启停操作。

## 6. L3 退出标准（0.1.0 验收项）

| 验收项 | 要求 |
|---|---|
| Stage 1 回归 | 135/135 保持通过 |
| Models | 全部通过；公共契约未被界面层改动 |
| Core | 全部通过；行为与 Stage 1 基线一致 |
| Engine | 全部通过；双路线隔离未被合并 |
| Exporter | 全部通过；JSON 结构与冻结契约一致，确定性可复现 |
| GUI | 构建成功；Dashboard / Plugins / Detail / Diagnostics 功能完整；数据全部来自 Core |
| RootHide Adapter | 真机只读验证通过 |
| Rootless Adapter | 合成样本验证通过；真机状态如实标记，不被 RootHide 结果覆盖 |
| 权限 | RootHide GUI 进程内权限探针结论明确，受限项记录原因 |
| JSON | 导出结构与内容正确；Optional 三态不丢失；数组排序确定 |
| 架构隔离 | 双路线隔离、App→Core 私有扫描/解析隔离通过 |
| 安装包 | 可正常安装、启动；版本信息完整 |
| 发布文档 | 范围、已知限制、证据标签与未决项完整 |

任一退出项未达标，不授予 0.1.0 标签。

## 7. 风险与进度口径

主要风险（沿用 Stage-2 计划 §9，不新增范围）：

| 风险 | 说明 | 现状 |
|---|---|---|
| GUI 权限 | CLI 越狱 shell 可读不代表 GUI App 可读 `.jbroot-*` 与 TweakInject；安装成功也不代表权限授予 | `[权限待验证]`，0.1-D 真机探针 |
| RootHide 路径适配 | `jbroot()` 实际调用、私有 entitlement、sandbox 放行需在 GUI 进程内验证 | `[权限待验证]`，0.1-D 探针 |
| GUI 与 Core 一致性 | 不得为快速显示另写扫描器；GUI 必须消费已迁移验收的 Core，避免 CLI/GUI 结果不一致 | 架构约束，0.1-C 验收核对 |

进度估算（概览口径，**工作日估算，非承诺排期**；各阶段可能返工）：开发节奏稳定约 4～8 周；真机权限或部署受阻可能 8～12 周以上。估算不构成交付承诺，实际以各里程碑 L2/L3 证据为准。

## 8. 证据标签与计数纪律

- 沿用证据标签：`[源码确认]` / `[RootHide 真机验证]` / `[Rootless 合成样本验证]` / `[Rootless 真机待验证]` / `[权限待验证]`；离线、CI、Simulator 与真机结论不得混标。
- XCTest 实际执行数、基线覆盖数、各模块专项数、既有回归数、静态检查数五类分列，不相加。
- `loaded` 无独立运行时证据恒 `.unknown`；`permission` 未授权前恒 `undetermined`；未知 / 冲突 / 失败状态原样保留，不推断、不美化。

## 9. 边界与未决项

- 0.1-B 报告/导出实现已闭环（CI/Simulator 口径，见 run `44224350333` 证据归档）；0.1-C GUI Foundation 代码已落盘待阶段末 Runner 验收；0.1-D 探针与真机验证仍需单独授权。
- **PARSE-009-B**：元素级下标 / 观测类型词与 Stage1 粗粒度报告口径差异继续独立挂起；独立授权前不改 Parser 与基线期望。
- **归属分类器**：`Core/OwnershipResolver/` 尚未迁移，单列批次；0.1-B 的 D2/D5 归属由已解析快照注入。
- **`pluginID` 稳定标识规则**：0.2.0 定稿；离线按优先级规则生成。
- **运行时加载取证**：`loaded` 脱离 `unknown` 待后续阶段接口。
- 暂缓功能（启停、写 plist、删 dylib、改软链、装卸载、dpkg 写入、Daemon / 自研注入 / 重签名）沿用 Stage-2 计划 §8，权限通路闭合与管理门禁定义前不进入界面与接口设计。

## 10. 与既有规格的关系

- 本计划不重复各子阶段实现细节；接口与字段口径以 `Stage-2-Implementation-Plan.md`、`Plugin-Data-Model.md`、2.2-D 实施规格为准。
- 后续若真机或 CI 实测结论与本计划冲突，以实测证据回填修订；本文件随里程碑闭环状态更新。
