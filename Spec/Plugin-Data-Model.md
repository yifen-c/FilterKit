# Plugin-Data-Model.md — 插件数据模型（Spec 0.1 草案）

- 状态：规格草案；模型为跨路线公共结构，路线特有口径由 Adapter/Profile 产出。
- 三层铁律：**文件层 ≠ 关联层 ≠ 运行层**；发现插件 ≠ 管理插件 ≠ 成功注入。

## 1. 三层状态映射

| 层 | 实体 | 对应真实物 | 字段 | 取值口径 |
|---|---|---|---|---|
| 文件层 | dylib | `…/usr/lib/TweakInject/X.dylib` | `installed` | dylib 在位、可读即 true；不代表有配置 |
| 关联层 | Filter.Bundles 等 | 同目录 `X.plist` | `configured` | plist 存在且 Filter 可解析；不代表已生效 |
| 运行状态层 | 进程是否真加载 | 目标进程冷启动后的外部取证 | `loaded` | **必须有独立运行时证据**；无证据 = `unknown`，禁止由 plist/已安装推断 |

## 2. 实体与字段

### 2.0 Report 信封（JSON 导出顶层）

| 字段 | 类型 | 说明 |
|---|---|---|
| `schemaVersion` | string | 数据模型版本，如 `0.1.0` |
| `generatedAt` | string | 导出时间（ISO 8601） |
| `environment` | JailbreakEnvironment | 环境快照 |
| `plugins` | Plugin[] | 扫描/解析出的插件记录 |
| `unknownItems` | object[] | 无法归类/无法解析的条目（路径、原因） |
| `warnings` | object[] | 全局告警（目录不可读、Profile 未知、软链异常等） |

## 2.1 JailbreakEnvironment

| 字段 | 类型 | 说明 | 未知口径 |
|---|---|---|---|
| `jailbreakType` | enum | `roothide` / `rootless` / `unknown` | 识别失败 = `unknown` |
| `ellekitImplementation` | string | ElleKit 实现/分支标识 | 未识别 = `null` |
| `ellekitVersion` | string | 如 `1.2-3` | 未取到 = `null` |
| `profileId` | string | 映射的 Adapter Profile，如 `RootHideProfile_1_2_3` | 未知版本 = `unknown-profile` |
| `jbroot` | string | JBROOT 绝对路径 | 未定位 = `null` |
| `jbrand` | string | RootHide 16 位 hex 标识 | 非 RootHide / 未取 = `null` |
| `iosVersion` | string | 设备 iOS 版本 | — |
| `architecture` | string | 如 `iphoneos-arm64e` | — |
| `evidenceLevel` | enum | `verified` / `partial` / `unverified` | 二手内省不得标 `verified` |

### 2.2 Plugin

| 字段 | 类型 | 层 | 说明 |
|---|---|---|---|
| `pluginID` | string | — | 稳定唯一标识；优先 `dpkg 包名:插件基名`，回退基名；生成规则在 0.2.0 定稿 |
| `name` | string | — | 展示名（dpkg Name / plist 基名） |
| `version` | string | — | 包版本或插件版本，可空 |
| `dylibPath` | string | 文件层 | dylib 绝对路径；缺失 = `null` |
| `plistPath` | string | 关联层 | plist 绝对路径；缺失 = `null` |
| `pairing` | enum | 文件层 | `paired` / `missing_plist` / `orphan_plist` / `missing_dylib` |
| `source` | enum | — | 见 §4 SourceType |
| `ownership` | Ownership | — | 文件归属与可写策略，见 §2.4 |
| `filter` | FilterRule? | 关联层 | 解析出的规则；解析失败 = `null` 并带告警 |
| `isTweakManager` | bool | — | 顶层 `IsTweakManager`；缺失 = false |
| `loadCategory` | enum | — | `manager` / `oldabi` / `tweak` / `unknown`（建模用，不等同运行结果） |
| `installed` | bool | 文件层 | dylib 在位可读 |
| `configured` | bool | 关联层 | plist 存在且 Filter 可解析 |
| `loaded` | enum | 运行层 | `unknown` / `loaded` / `not_loaded`；默认 `unknown` |
| `validation` | ValidationReport | 关联层 | 类型不符/缺字段/异常告警 |
| `profileId` | string | — | 产出该记录的 Profile |

### 2.3 FilterRule

| 字段 | 类型 | 说明 |
|---|---|---|
| `bundles` | string[] | Bundle ID 数组，可多个（单插件多 App） |
| `classes` | string[] | ObjC 类名数组 |
| `executables` | string[] | 可执行文件名数组 |
| `coreFoundationVersion` | object? | `{ mode: "max"|"range", min?: number, max?: number }`；缺失 = `null` |
| `otherKeys` | string[] | 1.2-3 未覆盖的扩展字段名（只读记录，不臆测语义） |

### 2.4 Ownership

| 字段 | 类型 | 说明 |
|---|---|---|
| `sourceType` | enum | 见 §4 |
| `packageID` | string? | dpkg 归属包；非包管理 = `null` |
| `listPath` | string? | dpkg `.list` 清单路径（精确命中依据） |
| `confidence` | enum | `exact_record` / `heuristic` / `unknown` |
| `writablePolicy` | enum | `read_only` / `managed` / `confirmed_managed` / `forbidden` |

## 3. 运行状态独立性（loaded 原则）

- `loaded` **只能**来自独立运行时证据（跨进程取证 / 注入镜像检查等）；0.1.0–0.4.0 阶段无取证手段时一律 `unknown`。
- 禁止由以下任一条件推断 `loaded`：dylib 在位、plist 存在、Bundles 命中本机 App、dpkg 已安装。
- `runtime_injection_verified = false` 时，UI 不得呈现"已注入/已生效"。

## 4. 枚举定义

```
SourceType      = dpkg_sileo | filterkit | manual | unknown
OwnershipStatus = owned_package | filterkit_managed | manual_import | unknown
LoadCategory    = manager | oldabi | tweak | unknown
LoadedState     = unknown | loaded | not_loaded
EvidenceLevel   = verified | partial | unverified
WritablePolicy  = read_only | managed | confirmed_managed | forbidden
```

## 5. JSON 序列化草图

```json
{
  "schemaVersion": "0.1.0",
  "generatedAt": "2026-11-15T01:30:00+08:00",
  "environment": {
    "jailbreakType": "roothide",
    "ellekitImplementation": "roothide/ellekit",
    "ellekitVersion": "1.2-3",
    "profileId": "RootHideProfile_1_2_3",
    "jbroot": "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
    "jbrand": "9C414BB7D5DCECC4",
    "iosVersion": "17.0.2",
    "architecture": "iphoneos-arm64e",
    "evidenceLevel": "partial"
  },
  "plugins": [
    {
      "pluginID": "z.weifeng:weifengqad",
      "name": "威锋去广告",
      "version": "1.5",
      "dylibPath": "<JBROOT>/Library/MobileSubstrate/DynamicLibraries/weifengqad.dylib",
      "plistPath": "<JBROOT>/Library/MobileSubstrate/DynamicLibraries/weifengqad.plist",
      "pairing": "paired",
      "source": "dpkg_sileo",
      "ownership": {
        "sourceType": "dpkg_sileo",
        "packageID": "z.weifeng",
        "listPath": "<JBROOT>/var/lib/dpkg/info/z.weifeng.list",
        "confidence": "exact_record",
        "writablePolicy": "read_only"
      },
      "filter": {
        "bundles": ["com.feng.New.WPForumClient"],
        "classes": [],
        "executables": [],
        "coreFoundationVersion": null,
        "otherKeys": []
      },
      "isTweakManager": false,
      "loadCategory": "tweak",
      "installed": true,
      "configured": true,
      "loaded": "unknown",
      "validation": { "status": "valid", "warnings": [] },
      "profileId": "RootHideProfile_1_2_3"
    }
  ],
  "unknownItems": [
    { "path": "<JBROOT>/usr/lib/TweakInject/Orphan.plist", "reason": "missing_dylib" }
  ],
  "warnings": [
    { "code": "profile_unknown", "message": "ElleKit 版本未识别，规则语义按未确认处理" }
  ]
}
```

## 6. 建模约束

1. 公共模型不出现路线特有分支字段；RootHide 特有信息（如完整性核对结果）放 Adapter 产出的扩展快照。
2. 所有"未取到/未验证"字段显式置 `null` / `unknown`，不得留空串冒充已知。
3. 规则解析告警必须区分"类型错误会被跳过"与"字段缺失可容忍"。
4. JSON 导出为只读产物；导出本身不回写设备。
