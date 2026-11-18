# LOCAL-REVIEW.md — B4 本地验收（方案 B：Runner 证据延后 B5 集中归档）

- 基准提交：`1803c2e`（B3 本地验收归档补记，B4 开工前锚点）；B4 代码冻结点：`6bbd64f`（本记录与规格文档随代码一并提交）
- 验收方式：**本地静态核对**；本机 Linux 无 `swift` / `swiftc` / `xcodebuild`，未执行编译与测试运行。
- 状态标记（按方案 B，**不标记正式闭环**）：

| 项 | 状态 | 说明 |
|---|---|---|
| B4 Implementation | ✅ Complete | 6 个 Core 文件 + 1 个测试文件落地，Package 接线完成；Models 纯追加两个证据结构 |
| Local Static Review | ✅ Passed | 文件完整性、测试计数、规则对齐、接线、隔离静态自查通过 |
| Local Test Execution | ⏸ Not run | 本机无 Swift 工具链；未跑 `swift test`，无本地执行日志 |
| CI Runner | ⏸ Deferred | Runner 日志/元数据/截图延后 B5 集中归档，本批次不上传 |
| Independent Build | ⏸ Pending | 独立 CI 构建待 B5 |
| Final Acceptance | ⏸ Pending | B5 完整回归通过前，B4 不标记正式验收通过 |

## 1. 文件完整性核对

### 1.1 B4 新增 Core（`Core/PathResolver/ElleKit/`）

| 文件 | 职责 | 存在 |
|---|---|---|
| `ElleKitDirectorySnapshot.swift` | 离线信号快照（upstream / fs.tweakInject / fs.dynamicLibraries）解码 | ✅ |
| `ElleKitPathDeriver.swift` | 路线 → TI/DL 路径纯函数推导（rootless/rootful/roothide/未知） | ✅ |
| `ElleKitDirectoryValidator.swift` | 目录状态校验（unresolved/not_found/partial/confirmed）与目录告警 | ✅ |
| `ElleKitSymlinkInspector.swift` | 软链五态、targetMatch 词法比较与软链告警 | ✅ |
| `ElleKitDirectoryResolution.swift` | 裁决结果结构（Core 内部） | ✅ |
| `ElleKitDirectoryResolver.swift` | 编排与裁决优先级；告警合并去重 | ✅ |

B3 既有目录未重写/移动：`Core/PathResolver/JBRoot/` 七文件。

### 1.2 测试文件

- `Tests/Stage2/ElleKitDirectoryTests.swift`：15 个测试方法。

### 1.3 Models 纯追加

- `PathLocationEvidence`（契约 §5.1，D9）、`SymlinkEvidence`（契约 §5.2，D10）；既有字段、枚举、协议无改动（`git diff` 无删除行）。

## 2. 测试计数映射（目标累计 71 例；B5 集中执行）

| 测试文件 | 方法数 | 阶段 | 本地计数 | 执行证据 |
|---|---|---|---|---|
| `ModelsCodableTests.swift` | 21 | 2.2-A Codable | ✅ 21 | 待 B5 runner |
| `EnvironmentDetectionTests.swift` | 7 | B1 环境识别 | ✅ 7 | 待 B5 runner |
| `JBRootCandidateCollectionTests.swift` | 10 | B2 候选收集 | ✅ 10 | 待 B5 runner |
| `JBRootValidationTests.swift` | 18 | B3 校验裁决 | ✅ 18 | 待 B5 runner |
| `ElleKitDirectoryTests.swift` | 15 | B4 目录/软链 | ✅ 15 | 待 B5 runner |
| **合计** | **71** | — | ✅ 71 | 待 B5 runner |

> 口径纠正：48 项是 Stage 1 原始行为基线数量（ENV/PATH/DIR）；B5 完整回归为 **71 项** = 21 Codable + 7 B1 + 10 B2 + 18 B3 + 15 B4，须逐阶段映射，不能只跑总套件宣称全过。

## 3. 规则对齐静态核对（对照 `Tests/S1-03/resolver.js`）

### 3.1 路径推导

- `rootless` → `/var/jb` + TI/DL 后缀；`rootful` → 后缀本身；`roothide` → jbroot 非空 + 后缀，jbroot 空 → `nil`；未知 → `nil`。
- RootHide 禁止回退 `/var/jb` 或 `/`；rootless 路径不作 RootHide 备用路径。

### 3.2 目录状态优先级（顺序不可调换）

1. `tiPath == nil` → `unresolved` + `directory_unresolved`
2. `exists != true` → `not_found` + `directory_not_found`
3. `readable != true || enumerable != true` → `partial` + `access_limited`
4. 其余 → `confirmed`

### 3.3 软链五态与 targetMatch

- 五态：`resolved / broken / loop / denied / not_symlink`；缺省 `not_symlink`；五态外取值原样保留。
- `targetMatch`：仅 `resolved` 且有目标与预期路径时，复用 `JBRootCandidateCollector.normalizeLexical` 规范化比较；其余 `false`。
- 告警：`broken→symlink_broken`、`loop→symlink_loop`、`denied→symlink_target_denied`、`not_symlink && exists→not_a_symlink`、`resolved && tPath && !targetMatch→structure_conflict`；`rootful→rootful_route_not_profile`。

### 3.4 裁决优先级（顺序不可调换）

1. `tiPath == nil` → `unresolved`
2. 目录 `not_found` → `not_found`
3. `dlState == resolved && !targetMatch` → `structure_conflict`
4. `route == rootful` → `rootful_diagnostic`
5. 目录 `confirmed` 且 `resolved` 且 `targetMatch` → `resolved`
6. 其余 → `partial`

### 3.5 三态与红线

- 未验证位保持 `nil`，不转 `false`；`readable` 与 `enumerable` 独立记录；realpath/存在 不推出可读/可枚举；路径存在不等于软链；软链解析成功不等于目标正确。
- 11 组夹具 expected（路径/各位/状态/软链/匹配位/告警/outcome）与基线 `S1-03-report.json`（15 例全过、三路线覆盖、fallbackLeakCount=0、layerViolationCount=0）逐组核对一致。

## 4. 隔离与冻结面核对

- 隔离脚本 `scripts/check-adapter-isolation.sh`：三向 OK（RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter）。
- 相对 B3 归档 `1803c2e`：`Adapters/`、`Core/CoreServices.swift`、`Core/Environment/`、`Core/PathResolver/JBRoot/`、`Tests/S1-03/`、`Tests/Fixtures/S1-03/` 无改动；Models 仅纯追加。
- `Package.swift`：Core 纳入 6 个 B4 源文件；Stage2Tests 纳入 `ElleKitDirectoryTests.swift`。
- 未新增 Core 服务协议；裁决结果为 Core 内部结构，未装配进 `EnvironmentPaths`/导出信封（归 B5）。
- B4 Core/测试无 `FileManager`/进程/环境变量/真机权限探针；事实全部来自离线夹具信号。

## 5. B5 追溯要求（方案 B 保护措施）

B5 集中验收时必须能证明：

1. B3 提交 `3e878cb`（及其归档 `8043372`）确实包含在最终代码中；
2. B4 未改变 B3 六态优先级与 B2 收集规则（顺序/去重/多来源保留/未知告警）；
3. 最终回归覆盖 B1~B4 逐阶段（71 项映射），S1-03 15 例与基线报告深比较一致；
4. 各阶段测试证据可追溯；B5 失败时能区分是 B3、B4 还是集成问题；
5. 双 Adapter 隔离、Core 不实例化 Adapter、独立 App Build 与截图在 B5 runner 复核。

## 6. 本批次未保留（延后 B5）

- Runner 构建/测试日志、runner 元数据、App 截图、独立 CI 构建产物；
- B3 确认 jbroot → B4 目录定位的 Pipeline 串联、结果装配进 `EnvironmentPaths`/导出信封；
- 真机写入/启停/扫描/权限探针：本批次未接入，后续亦按只读边界执行。
