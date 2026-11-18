# S1-01 Environment Detection — 环境识别子规格

- 状态：**Stage 1 子规格已冻结；离线夹具验证已执行并通过（15/15）**。隶属 [Stage-1-CLI-Test-Plan.md](../Stage-1-CLI-Test-Plan.md)。本文件只展开 S1-01，不进入 S1-02（JBROOT 定位）；离线 harness 位于 `Tests/S1-01/`，属测试工具链，非 App 运行时，识别逻辑后续迁移 Core/Adapters；不创建正式工程，不编译。
- 关联：[PoC-0.1.0-Specification.md](../PoC-0.1.0-Specification.md) §2 S1/S2、[Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.1、[Dev-Preparation-0.1.md](../Dev-Preparation-0.1.md)。
- 运行上下文：Stage 1 CLI，越狱 shell；本项识别结果**不代表目录可访问、不代表 Adapter 完整兼容**。

## 1. 测试目标

识别当前运行环境，建立后续 Adapter Profile 选择依据；**只识别环境并提出 Profile 候选**，真正的 Profile 激活留待后续 Adapter 能力检查。

### 1.1 输出字段

| 字段 | 内容 | 模型对齐 |
|---|---|---|
| `jailbreakType` | `roothide` / `rootless` / `rootful` / `unknown` | 模型 §2.1 `jailbreakType`（`rootful` 为本项补充的已识别不支持类型） |
| `architecture` | `arm64` / `arm64e` / `unknown` | 模型 §2.1 `architecture` |
| `iosVersion` | iOS 版本 | 模型 §2.1 `iosVersion` |
| `bootstrap` | Bootstrap 类型及版本（如 Dopamine-roothide） | 模型扩展子对象，待数据模型定稿 |
| `ellekitImplementation` | `roothide` / `upstream` / `unknown` | 模型 §2.1 `ellekitImplementation` |
| `ellekitVersion` | ElleKit 版本，如 `1.2-3` | 模型 §2.1 `ellekitVersion` |
| `adapterProfile` | 对应 Adapter Profile（候选），如 `RootHideProfile_1_2_3` | 模型 §2.1 `profileId` |
| `evidence` | 每个字段的证据来源记录 | 模型 §2.1 `evidenceLevel` 的逐字段细化 |
| `warnings` | 无法确认或存在冲突的信息 | 模型 §2.0 `warnings` |

> 未取到/未验证字段显式 `null` / `unknown`，不留空串冒充已知。

### 1.2 识别信号（只读探测，多信号组合判定）

| 类型 | 候选信号（只读） | 备注 |
|---|---|---|
| RootHide | `.jbroot-<jbrand>` 容器；libroothide `jbroot()`；dpkg roothide core / patchloader / manager 包；`.version-roothide`；ElleKit roothide fork 包 | 容器前缀 `.jbroot-` 见 `DOBootstrapper.m:879`；jbrand 取自容器末段 |
| Rootless | `/var/jb`；上游 ElleKit；libroot；rootless dpkg 布局 | 当前无真机，仅离线夹具 |
| Rootful | 真实根文件系统 `/`；经典 `/Applications`；旧 Substrate 布局 | 识别后归为不支持 Profile |

> **硬规则：不能只凭路径特征判断越狱类型。** 发现 `/var/jb` 不足以证明是 Rootless；发现 `.jbroot-*` 也不能单独证明 ElleKit 是 RootHide 实现。类型判定需组合路径、包管理记录、实现标识等多个信号；信号相互冲突时按 §4 冲突处理。

## 2. 离线测试夹具

> 以下为模拟环境数据定义，**不是真机证据**；夹具已落地 `Tests/Fixtures/S1-01/`，识别器与执行器位于 `Tests/S1-01/`（离线 harness）。

```
Tests/
└── Fixtures/
    └── S1-01/
        ├── roothide/      # environment.json（输入）+ metadata.json（预期）
        ├── rootless/      # environment.json + metadata.json
        ├── rootful/       # environment.json + metadata.json
        ├── unknown/       # environment.json + metadata.json
        ├── incomplete/    # environment.json + metadata.json
        └── conflicting/   # environment.json + metadata.json
```

### 2.1 文件职责与隔离规则

- `environment.json`：环境识别器**实际接收**的模拟输入；值是测试输入，不代表真实设备采集结果。
- `metadata.json`：**测试预期结果**，由测试框架读取并按 `fixtureId` 配对比对；**识别器不得读取 metadata.json**，避免测试程序直接读取答案造成失真。
- 两份文件严格分离；`fixtureId` 为唯一配对键。

### 2.2 输入信号结构（environment.json）

```json
{
  "fixtureId": "S1-01-ROOTHIDE-001",
  "fixtureKind": "roothide",
  "signals": {
    "jailbreakType": { "value": "roothide", "source": "fixture", "present": true },
    "architecture": { "value": "arm64e", "source": "fixture", "present": true },
    "iosVersion": { "value": "17.0.2", "source": "fixture", "present": true },
    "bootstrap": { "name": "dopamine-roothide", "version": "3.0.13-30", "source": "fixture", "present": true },
    "ellekitImplementation": { "value": "roothide", "source": "fixture", "present": true },
    "ellekitVersion": { "value": "1.2-3", "source": "fixture", "present": true, "readability": "readable", "raw": "1.2-3" }
  }
}
```

信号字段约定：`present`（是否存在）、`readability`（`readable / unreadable / absent`）、`raw`（不可解析时保留原始串）。版本五态由识别器依据这些信号推导，不由输入直接给定。

### 2.3 预期结果结构（metadata.json）

```json
{
  "fixtureId": "S1-01-ROOTHIDE-001",
  "expected": {
    "jailbreakType": "roothide",
    "architecture": "arm64e",
    "iosVersion": "17.0.2",
    "bootstrap": { "name": "dopamine-roothide", "version": "3.0.13-30" },
    "ellekitImplementation": "roothide",
    "ellekitVersion": "1.2-3",
    "ellekitVersionStatus": "parsed",
    "adapterProfile": "RootHideProfile_1_2_3"
  },
  "expectedWarnings": [],
  "expectedOutcome": "profile_candidate"
}
```

`expectedOutcome` 取值：`profile_candidate` / `unsupported_profile` / `unknown` / `conflict_no_profile` / `partial`。

### 2.4 六组样本草案

#### 2.4.1 roothide — 完整 RootHide 环境（ENV-001）

`environment.json`：

```json
{
  "fixtureId": "S1-01-ROOTHIDE-001",
  "fixtureKind": "roothide",
  "signals": {
    "jailbreakType": { "value": "roothide", "source": "fixture", "present": true },
    "architecture": { "value": "arm64e", "source": "fixture", "present": true },
    "iosVersion": { "value": "17.0.2", "source": "fixture", "present": true },
    "bootstrap": { "name": "dopamine-roothide", "version": "3.0.13-30", "source": "fixture", "present": true },
    "ellekitImplementation": { "value": "roothide", "source": "fixture", "present": true },
    "ellekitVersion": { "value": "1.2-3", "source": "fixture", "present": true, "readability": "readable", "raw": "1.2-3" }
  }
}
```

`metadata.json`：

```json
{
  "fixtureId": "S1-01-ROOTHIDE-001",
  "expected": {
    "jailbreakType": "roothide",
    "architecture": "arm64e",
    "iosVersion": "17.0.2",
    "bootstrap": { "name": "dopamine-roothide", "version": "3.0.13-30" },
    "ellekitImplementation": "roothide",
    "ellekitVersion": "1.2-3",
    "ellekitVersionStatus": "parsed",
    "adapterProfile": "RootHideProfile_1_2_3"
  },
  "expectedWarnings": [],
  "expectedOutcome": "profile_candidate"
}
```

#### 2.4.2 rootless — 完整 Rootless 环境（ENV-002）

`environment.json`：

```json
{
  "fixtureId": "S1-01-ROOTLESS-001",
  "fixtureKind": "rootless",
  "signals": {
    "jailbreakType": { "value": "rootless", "source": "fixture", "present": true },
    "architecture": { "value": "arm64", "source": "fixture", "present": true },
    "iosVersion": { "value": "17.0.2", "source": "fixture", "present": true },
    "bootstrap": { "name": "procursus", "version": "fixture-version", "source": "fixture", "present": true },
    "ellekitImplementation": { "value": "upstream", "source": "fixture", "present": true },
    "ellekitVersion": { "value": "1.0.0", "source": "fixture", "present": true, "readability": "readable", "raw": "1.0.0" }
  }
}
```

`metadata.json`：

```json
{
  "fixtureId": "S1-01-ROOTLESS-001",
  "expected": {
    "jailbreakType": "rootless",
    "architecture": "arm64",
    "iosVersion": "17.0.2",
    "bootstrap": { "name": "procursus", "version": "fixture-version" },
    "ellekitImplementation": "upstream",
    "ellekitVersion": "1.0.0",
    "ellekitVersionStatus": "parsed",
    "adapterProfile": "RootlessProfile_upstream"
  },
  "expectedWarnings": [],
  "expectedOutcome": "profile_candidate"
}
```

> Rootless 当前无真机；本夹具为 `[Rootless 合成样本验证]`，Profile 标识 `RootlessProfile_upstream` 为草案命名，待 Rootless 版本 Profile 定稿。

#### 2.4.3 rootful — 完整 Rootful 环境（ENV-003）

`environment.json`：

```json
{
  "fixtureId": "S1-01-ROOTFUL-001",
  "fixtureKind": "rootful",
  "signals": {
    "jailbreakType": { "value": "rootful", "source": "fixture", "present": true },
    "architecture": { "value": "arm64", "source": "fixture", "present": true },
    "iosVersion": { "value": "15.0", "source": "fixture", "present": true },
    "bootstrap": { "name": null, "version": null, "source": "fixture", "present": false },
    "ellekitImplementation": { "value": "unknown", "source": "fixture", "present": false },
    "ellekitVersion": { "value": null, "source": "fixture", "present": false, "readability": "absent" }
  }
}
```

`metadata.json`：

```json
{
  "fixtureId": "S1-01-ROOTFUL-001",
  "expected": {
    "jailbreakType": "rootful",
    "architecture": "arm64",
    "iosVersion": "15.0",
    "bootstrap": { "name": null, "version": null },
    "ellekitImplementation": "unknown",
    "ellekitVersion": null,
    "ellekitVersionStatus": "not_installed",
    "adapterProfile": null
  },
  "expectedWarnings": ["unsupported_rootful"],
  "expectedOutcome": "unsupported_profile"
}
```

#### 2.4.4 unknown — 无法识别的环境（ENV-004）

`environment.json`：

```json
{
  "fixtureId": "S1-01-UNKNOWN-001",
  "fixtureKind": "unknown",
  "signals": {
    "jailbreakType": { "value": null, "source": "fixture", "present": false },
    "architecture": { "value": "unknown", "source": "fixture", "present": false },
    "iosVersion": { "value": "unknown", "source": "fixture", "present": false },
    "bootstrap": { "name": null, "version": null, "source": "fixture", "present": false },
    "ellekitImplementation": { "value": "unknown", "source": "fixture", "present": false },
    "ellekitVersion": { "value": null, "source": "fixture", "present": false, "readability": "absent" }
  }
}
```

`metadata.json`：

```json
{
  "fixtureId": "S1-01-UNKNOWN-001",
  "expected": {
    "jailbreakType": "unknown",
    "architecture": "unknown",
    "iosVersion": "unknown",
    "bootstrap": { "name": null, "version": null },
    "ellekitImplementation": "unknown",
    "ellekitVersion": null,
    "ellekitVersionStatus": "not_installed",
    "adapterProfile": null
  },
  "expectedWarnings": ["no_jailbreak_signals"],
  "expectedOutcome": "unknown"
}
```

#### 2.4.5 incomplete — 缺少部分信息（ENV-005 / ENV-006 / ENV-007 / ENV-010 / ENV-014）

`environment.json`：

```json
{
  "fixtureId": "S1-01-INCOMPLETE-001",
  "fixtureKind": "incomplete",
  "signals": {
    "jailbreakType": { "value": "roothide", "source": "fixture", "present": true },
    "architecture": { "value": "arm64e", "source": "fixture", "present": true },
    "iosVersion": { "value": "17.0.2", "source": "fixture", "present": true },
    "bootstrap": { "name": null, "version": null, "source": "fixture", "present": false },
    "ellekitImplementation": { "value": "unknown", "source": "fixture", "present": false },
    "ellekitVersion": { "value": null, "source": "fixture", "present": true, "readability": "readable", "raw": "???" }
  }
}
```

`metadata.json`：

```json
{
  "fixtureId": "S1-01-INCOMPLETE-001",
  "expected": {
    "jailbreakType": "roothide",
    "architecture": "arm64e",
    "iosVersion": "17.0.2",
    "bootstrap": { "name": null, "version": null },
    "ellekitImplementation": "unknown",
    "ellekitVersion": null,
    "ellekitVersionStatus": "unparsable",
    "adapterProfile": null
  },
  "expectedWarnings": ["bootstrap_missing", "implementation_missing", "version_unparsable"],
  "expectedOutcome": "partial"
}
```

> 已确认字段（类型/架构/iOS）保留；缺失与不可解析字段独立降级，不拖垮整轮识别。

#### 2.4.6 conflicting — 多种信号互相冲突（ENV-008 / ENV-009）

`environment.json`（含两类冲突组合）：

```json
{
  "fixtureId": "S1-01-CONFLICT-001",
  "fixtureKind": "conflicting",
  "signals": {
    "jailbreakType": { "value": "roothide", "source": "fixture", "present": true },
    "rootlessPathPresent": { "value": true, "source": "fixture", "present": true },
    "architecture": { "value": "arm64e", "source": "fixture", "present": true },
    "iosVersion": { "value": "17.0.2", "source": "fixture", "present": true },
    "bootstrap": { "name": "dopamine-roothide", "version": "3.0.13-30", "source": "fixture", "present": true },
    "ellekitImplementation": { "value": "upstream", "source": "fixture", "present": true },
    "ellekitVersion": { "value": "1.2-3", "source": "fixture", "present": true, "readability": "readable", "raw": "1.2-3" }
  }
}
```

`metadata.json`：

```json
{
  "fixtureId": "S1-01-CONFLICT-001",
  "expected": {
    "jailbreakType": "unknown",
    "architecture": "arm64e",
    "iosVersion": "17.0.2",
    "bootstrap": { "name": "dopamine-roothide", "version": "3.0.13-30" },
    "ellekitImplementation": "unknown",
    "ellekitVersion": null,
    "ellekitVersionStatus": "conflicted",
    "adapterProfile": null
  },
  "expectedWarnings": ["route_signal_conflict", "impl_version_conflict"],
  "expectedOutcome": "conflict_no_profile"
}
```

> 两类冲突：① 路线信号冲突（roothide 类型信号 + rootless 路径信号并存）；② 实现-版本冲突（upstream 实现 + roothide 版本号并存）。两类均不得强行选边。

## 3. 测试用例

| ID | 输入样本 | 预期结果 | 判定 |
|---|---|---|---|
| ENV-001 | RootHide 完整环境（2.4.1） | 识别 `roothide`，提出 RootHide Profile 候选 | 必须通过 |
| ENV-002 | Rootless 完整环境（2.4.2） | 识别 `rootless`，提出 Rootless Profile 候选 | 必须通过 |
| ENV-003 | Rootful 完整环境（2.4.3） | 识别 `rootful`，归为不支持 Profile | 必须通过 |
| ENV-004 | 无越狱特征（2.4.4） | `jailbreakType=unknown` | 必须通过 |
| ENV-005 | 缺少 ElleKit 版本 | 版本 `not_installed`，产生警告 | 必须通过 |
| ENV-006 | 缺少 Bootstrap 信息 | `bootstrap=unknown` | 必须通过 |
| ENV-007 | 架构无法识别 | `architecture=unknown` | 必须通过 |
| ENV-008 | RootHide 与 Rootless 特征冲突 | 不强行选择 Profile，标冲突告警 | 必须通过 |
| ENV-009 | ElleKit 版本与实现来源不匹配 | 标记冲突，Profile 不激活 | 必须通过 |
| ENV-010 | 不完整环境信息（2.4.5） | 保留已确认字段，缺失项显式未知 | 必须通过 |
| ENV-011 | 输入数据格式错误 | 返回结构化错误，不崩溃 | 必须通过 |
| ENV-012 | 环境信息不可读取 | 标记访问受限，进入告警；版本态 `unreadable` | 必须通过 |
| ENV-013 | 相同环境信号重复输入 | 结果确定，识别结果与 Profile 候选不产生随机变化 | 必须通过 |
| ENV-014 | 单个信号缺失，其他信号完整 | 保留其他已确认字段，缺失项独立降级 | 必须通过 |
| ENV-015 | metadata 与 environment 输入不一致 | 测试框架报错；识别器判断不受影响 | 必须通过 |

### 3.1 版本五态覆盖矩阵

| 版本态 | 覆盖来源 |
|---|---|
| `parsed` | 2.4.1 roothide、2.4.2 rootless |
| `not_installed` | 2.4.3 rootful、2.4.4 unknown |
| `unreadable` | ENV-012 读取受限场景（运行时用例，不单列夹具文件） |
| `unparsable` | 2.4.5 incomplete |
| `conflicted` | 2.4.6 conflicting |

## 4. 重点断言

### 4.1 Profile 选择

只有同时满足必要识别条件，才允许提出对应 Adapter Profile 候选：

- `roothide` + roothide 实现 + 已支持版本 → RootHide Adapter Profile；
- `rootless` + upstream 实现 + 已支持版本 → Rootless Adapter Profile；
- 其他情况 → `unknown` / unsupported Profile。

**未知 Profile 不允许自动降级为 RootHide 或 Rootless。** 冲突信息不强行选边（ENV-008 / ENV-009）。

### 4.2 版本识别（五态区分）

必须区分以下状态，**不能把无法读取版本当作未安装**：

| 状态 | 含义 |
|---|---|
| `not_installed` | 未安装（无对应包/文件） |
| `unreadable` | 存在但无法读取（权限/读取失败） |
| `unparsable` | 文件存在但版本号无法解析 |
| `parsed` | 版本成功解析 |
| `conflicted` | 版本与实现来源冲突 |

### 4.3 证据来源

每个字段记录证据对象：

```json
{
  "value": "roothide",
  "status": "confirmed",
  "evidenceType": "fixture",
  "evidenceSource": "S1-01/roothide/environment.json"
}
```

- `status`：`confirmed / partial / unverified / unknown`；
- `evidenceType`：`fixture / device / source`；
- 离线夹具统一标 `fixture`，**不得标 `[RootHide 真机验证]`**；真机运行结果方可标 `device`。

## 5. 输出结构草案（Environment 快照）

```json
{
  "jailbreakType": { "value": "roothide", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" },
  "architecture":  { "value": "arm64e", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" },
  "iosVersion":    { "value": "17.0.2", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" },
  "bootstrap":     { "type": { "value": "dopamine-roothide", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" }, "version": { "value": "3.0.13-30", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" } },
  "ellekitImplementation": { "value": "roothide", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" },
  "ellekitVersion": { "value": "1.2-3", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "S1-01/roothide/environment.json" },
  "adapterProfile": { "value": "RootHideProfile_1_2_3", "status": "confirmed", "evidenceType": "fixture", "evidenceSource": "profile-mapping" },
  "warnings": []
}
```

> 该结构为 S1-01 子规格草案；逐字段证据对象若被后续采纳，回写 [Plugin-Data-Model.md](../Plugin-Data-Model.md) §2.1。

## 6. S1-01 通过条件

### 6.1 功能验收

- [x] 六种环境状态（roothide / rootless / rootful / unknown / incomplete / conflicting）均有测试覆盖。
- [x] RootHide、Rootless、Rootful 能正确区分。
- [x] 缺失信息不会导致整个环境识别失败。
- [x] 冲突信息不会强行选择 Profile。
- [x] 版本识别能区分缺失、不可读、解析失败、成功、冲突五态（见 §3.1 矩阵）。
- [x] 每个识别结果都有证据来源（逐字段 `evidence` 对象，离线标 `fixture`）。
- [x] 相同输入得到相同识别结果与 Profile 候选（ENV-013 确定性）。
- [x] 所有测试均不需要修改真实越狱文件。
- [x] JSON 输出结构稳定。

### 6.2 夹具验收标准

- [x] 六组环境样本齐备。
- [x] 每组包含输入（environment.json）与预期结果（metadata.json）。
- [x] 版本五态全部覆盖。
- [x] Profile 候选与 Unknown 状态均覆盖。
- [x] 冲突信息至少两种组合（路线冲突、实现-版本冲突）。
- [x] 测试输入与预期答案严格分离，识别器不读取 metadata.json。
- [x] 所有样本均明确标记 `fixture`。

### 6.3 离线执行记录（2026-11-15）

- 结论：**Synthetic Fixture Validation Passed（离线验收通过）**；正式验收记录 `Tests/S1-01/report/S1-01-acceptance.md`。
- 产物：`Tests/Fixtures/S1-01/<kind>/{environment.json, metadata.json}` ×6；`Tests/S1-01/detector.js`；`Tests/S1-01/run.js`；报告 `Tests/S1-01/report/S1-01-report.json`。
- 结果：ENV-001 ~ 015 共 15 例全部通过；版本五态 `parsed / not_installed / unreadable / unparsable / conflicted` 全覆盖；两类冲突 `route_signal_conflict / impl_version_conflict` 均出现。
- 口径限制：全部为离线 fixture 合成样本；**不构成 RootHide 真机验证**，Rootless 结果不代表 Rootless 真机兼容；harness 为离线测试实现，后续随工程落地迁移至 Core/Adapters。
- 待真机缺口见 §8；S1-02 尚未展开，须授权后进入。

## 7. 设计边界（特别注意）

- S1-01 **只负责识别环境和提出 Profile 候选**；真正的 Profile 激活还要经过后续 Adapter 能力检查。
- 识别环境 ≠ 验证目录可访问 ≠ 验证 Adapter 完整兼容。避免环境识别正确，却因后续路径或权限问题被错误标为可用。
- 本项**不做**：JBROOT 路径定位（S1-02）、目录枚举、文件读取、Profile 激活判定。
- S1-01 验收前不扩展 S1-02，不创建正式工程。

## 8. 待真机缺口（影响背书，不改本规格范围）

| 缺口 | 影响 | 现状 |
|---|---|---|
| `.version-roothide` 文件原文 | Bootstrap / 版本精确判定 | 未读取，暂以 dpkg 包版本旁证 |
| ElleKit 实现标识的真机取法 | `ellekitImplementation` 判定 | 离线先定口径，真机复核 |
| Bootstrap 类型/版本来源 | `bootstrap` 字段 | 真机只读探测确认 |
| Rootless / Rootful 真机 | ENV-002 / ENV-003 真机背书 | 当前仅夹具，`[Rootless 真机待验证]` |
