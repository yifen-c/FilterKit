# LOCAL-REVIEW.md — B3 本地验收（方案 B：Runner 证据延后 B5 集中归档）

- 基准提交：`3e878cb`（2.2-B3 JBROOT 校验与裁决本地落地，代码冻结点）
- 本地验收归档提交：`8043372`（仅文档与本记录；`3e878cb..8043372` 之间 Core/Models/Adapters/测试源码无变动）
- 验收方式：**本地静态核对**；本机 Linux 无 `swift` / `swiftc` / `xcodebuild`，未执行编译与测试运行。
- 状态标记（按方案 B，**不标记正式闭环**）：

| 项 | 状态 | 说明 |
|---|---|---|
| B3 Implementation | ✅ Complete | 5 个 Core 文件 + 1 个测试文件落地，Package 接线完成 |
| Local Static Review | ✅ Passed | 文件完整性、测试计数、规则对齐、接线、隔离静态自查通过 |
| Local Test Execution | ⏸ Not run | 本机无 Swift 工具链；未跑 `swift test`，无本地执行日志 |
| CI Runner | ⏸ Deferred | Runner 日志/元数据/截图延后 B5 集中归档，本批次不上传 |
| Independent Build | ⏸ Pending | 独立 CI 构建待 B5 |
| Final Acceptance | ⏸ Pending | B5 完整回归通过前，B3 不标记正式验收通过 |

## 1. 文件完整性核对

### 1.1 B3 新增 Core（`Core/PathResolver/JBRoot/`）

| 文件 | 职责 | 存在 |
|---|---|---|
| `JBRootNameValidator.swift` | 命名校验（前缀/16 hex/非零/校验位异或）+ jbrand 大写解析 | ✅ |
| `JBRootStatusClassifier.swift` | 六态分类（基线优先级顺序） | ✅ |
| `JBRootValidator.swift` | 五项三态位回填 + 调用分类器；软链失败 realpath 置 nil | ✅ |
| `JBRootDecisionResolver.swift` | 裁决结果结构 + 多候选裁决 | ✅ |
| `JBRootResolver.swift` | 收集→校验→裁决编排，信号配对，告警合并 | ✅ |

B2 既有文件未重写/移动：`JBRootCandidateSnapshot.swift`、`JBRootCandidateCollector.swift`。

### 1.2 测试文件

- `Tests/Stage2/JBRootValidationTests.swift`：18 个测试方法。

## 2. 测试计数映射（目标累计 56 例；B5 集中执行）

| 测试文件 | 方法数 | 阶段 | 本地计数 | 执行证据 |
|---|---|---|---|---|
| `ModelsCodableTests.swift` | 21 | 2.2-A Codable | ✅ 21 | 待 B5 runner |
| `EnvironmentDetectionTests.swift` | 7 | B1 环境识别 | ✅ 7 | 待 B5 runner |
| `JBRootCandidateCollectionTests.swift` | 10 | B2 候选收集 | ✅ 10 | 待 B5 runner |
| `JBRootValidationTests.swift` | 18 | B3 校验裁决 | ✅ 18 | 待 B5 runner |
| **合计** | **56** | — | ✅ 56 | 待 B5 runner |

> 口径纠正：48 项是 Stage 1 原始行为基线数量（ENV/PATH/DIR）；B5 完整回归为 **71 项** = 21 Codable + 7 B1 + 10 B2 + 18 B3 + 15 B4，须逐阶段映射，不能只跑总套件宣称全过。

## 3. 规则对齐静态核对（对照 `Tests/S1-02/resolver.js`）

### 3.1 命名校验

- 前缀 `.jbroot-`、后缀恰 16 位 hex（大小写均可）、数值非零；
- 校验位：位移 8/16/24/32/40/48/56 异或，低 8 位相等；
- 已用独立脚本复算：`9C414BB7D5DCECC4`、`D87B48653D7178BA` 通过；`76484591DA3078C2`（坏校验位）、全零后缀失败。

### 3.2 六态优先级（顺序不可调换）

1. rootless → `cross_route` + `rootless_route_not_jbroot`
2. rootful → `cross_route` + `rootful_route_not_jbroot`
3. broken/loop → `resolve_failed` + `symlink_resolve_failed`
4. nameValid=false → `rejected_invalid` + `invalid_container_name`
5. exists!=true → `rejected_missing` + `candidate_missing`
6. readable!=true → `partial` + `access_limited`
7. 其余 → `confirmed`

### 3.3 多候选裁决优先级

>1 有效 roothide → `ambiguous`（不选边）；=1 → `resolved`/`partial`；有 `resolve_failed`；仅跨路线 → `cross_route_only`；空 → `no_candidate`；其余 → `no_candidate`。

### 3.4 三态与红线

- 未验证位保持 `nil`，不转 `false`；realpath 成功不等于可读；前缀命中不等于确认；jbrand 不猜语义；跨路线候选证据保留不删除。

## 4. 隔离与冻结面核对

- 隔离脚本 `scripts/check-adapter-isolation.sh`：三向 OK（RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter）。
- 相对 B2 归档 `bde210c`：`Models/`、`Adapters/`、`Core/CoreServices.swift`、`Tests/S1-02/`、`Tests/Fixtures/S1-02/` 无改动。
- `Package.swift`：Core 纳入 5 个 B3 源文件；Stage2Tests 纳入 `JBRootValidationTests.swift`。
- 未新增 Core 服务协议；裁决结果为 Core 内部结构，未装配进 `EnvironmentPaths`/导出信封（归 B5）。

## 5. B5 追溯要求（方案 B 保护措施）

B5 集中验收时必须能证明：

1. B3 提交 `3e878cb` 确实包含在最终代码中；
2. B4 未改变 B3 六态优先级；
3. B4 未改变 B2 收集规则（顺序/去重/多来源保留/未知告警）；
4. 最终回归覆盖 B1~B4 逐阶段（71 项映射）；
5. 各阶段测试证据可追溯；B5 失败时能区分是 B3、B4 还是集成问题。

## 6. 本批次未保留（延后 B5）

- Runner 构建/测试日志、runner 元数据、App 截图、独立 CI 构建产物；
- 真机写入/启停/扫描/权限探针：本批次未接入，后续亦按只读边界执行。
