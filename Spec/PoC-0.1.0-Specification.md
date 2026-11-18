# PoC-0.1.0-Specification.md — 第一版只读 PoC 开发规格（Spec 0.1 已冻结）

- 状态：**Spec 0.1 已冻结**；本版为完整只读的 ElleKit 插件环境检测工具，**不修改越狱环境、不写 plist、不碰 dpkg 数据库、不执行注入。**
- 关联：[Architecture.md](./Architecture.md)、[ElleKit-Compatibility.md](./ElleKit-Compatibility.md)、[Plugin-Data-Model.md](./Plugin-Data-Model.md)。
- 版本门禁：0.1.0 标签仅在下列只读能力落地并通过验收后授予；未达标不提前挂版本号。

## 1. 目标

在 RootHide 环境完整落地只读数据链，Rootless 预留基础识别；输出"当前环境 / ElleKit 版本 / 插件目录 / 已装插件 / 配对缺失 / 关联 App / 来源 / 已确认与未知项"的完整只读画像。增加信息读取与分析能力，**不增加任何系统修改能力**。

## 2. 正式范围（全部纳入 0.1.0）

| 编号 | 功能 | 纳入 0.1.0 | 说明 |
|---|---|---|---|
| S1 | 越狱环境识别 | 是 | `jailbreakType`、`architecture`、`iosVersion` |
| S2 | ElleKit 版本识别 | 是 | `ellekitImplementation` / `ellekitVersion` / `profileId` |
| S3 | JBROOT 定位 | 是 | 容器绝对路径、jbrand；路径解析走对应 Adapter |
| S4 | 插件目录定位 | 是 | 定位 TweakInject 目录并确认可读/可枚举 |
| S5 | dylib/plist 扫描 | 是 | 枚举目录内 dylib 与 plist 条目 |
| S6 | 文件配对检查 | 是 | `X.dylib` ↔ `X.plist` 同名配对，标注缺 plist / 孤儿 plist |
| E1 | plist 解析 | 是 | 按 Profile 口径解析 Filter 字段与类型校验告警 |
| E2 | Filter 规则展示 | 是 | Bundles/Classes/Executables/版本门槛只读展示 |
| E3 | 插件来源初步识别 | 是 | dpkg / FilterKit / 手动 / 未知 归类与归属包 |
| E4 | JSON 导出 | 是 | 按数据模型导出只读 JSON 产物 |

## 3. 完整只读数据链

```
环境识别 → ElleKit 识别 → 插件目录扫描 → dylib/plist 配对
        → plist 解析 → Filter 规则解析 → 插件来源识别
        → 统一数据模型 → JSON 导出
```

1. **环境识别**：Adapter 探测越狱类型、ElleKit 实现与版本，映射 Profile；失败则 `unknown-profile` 降级只读。
2. **路径解析**：RootHide 经 `jbroot()` 口径定位；Rootless 经 `/var/jb` 前缀；路径归一（`realpath`），不并列两套根。
3. **目录扫描**：枚举 TweakInject 目录；记录条目存在性、可读性、是否目录/软链。
4. **配对检查**：以 dylib 为主键找同名 plist；标注 `paired / missing_plist / orphan_plist / missing_dylib`。
5. **规则解析**：按 Profile 严格类型口径解析；类型不符生成告警，不当合法配置。
6. **来源识别**：优先 dpkg `.list` 精确命中归属包；无记录归 `unknown`，不按文件名猜测。
7. **统一建模与导出**：写入 `Plugin-Data-Model.md` 模型，导出只读 JSON；不回写设备。

## 4. 输入与输出

**输入（设备只读）**：JBROOT 容器、TweakInject 目录、dpkg status/info（归属查询）、已安装 App 列表（识别展示用）。

**输出（只读产物）**：
- 环境快照（环境模型）
- 插件记录列表（含配对、规则、归属、状态、告警）
- 未知项与告警清单
- 只读 JSON 文件

## 5. 文件所有权策略（安全底线）

| 来源 | 查看 | 关联管理 | 删除/改写 |
|---|---|---|---|
| Sileo / dpkg 管理 | ✓ | 本版不操作 | **默认禁止** |
| FilterKit 自管 | ✓ | 后续阶段 | 无关联引用后允许（后续阶段） |
| 用户手动导入 | ✓ | 确认后管理（后续阶段） | 谨慎（后续阶段） |
| 来源不明 | ✓ | 只读并提示风险 | **默认禁止** |

原则：**不能因为能改某个文件，就默认拥有该文件的管理权。** FilterKit 不接管 dpkg 软件包生命周期。

## 6. 验收标准

### 6.1 功能验收

1. 输出环境快照：越狱类型、ElleKit 实现/版本、Profile、JBROOT、jbrand（能取到的项）。
2. 列出 TweakInject 目录内 dylib/plist，完成同名配对标注。
3. 解析每个已配对 plist 的 Filter 规则并展示 Bundles/Classes/Executables/版本门槛。
4. 给出每个插件的初步来源与归属包（精确命中 / 启发式 / 未知）。
5. 导出符合数据模型的只读 JSON。

### 6.2 双路线独立验收

- RootHide 与 Rootless **分别测试、分别判定**；RootHide 通过不代表 Rootless 通过。
- 两套环境的路径/规则/校验差异由各自 Adapter 负责，Core/UI 无路线分支判断。

### 6.3 异常隔离（单点失败不拖垮整体）

遇到下列情况必须记录错误/告警并**继续扫描其他插件**，不得整体崩溃：

- plist 损坏 / 格式不正确；
- dylib 缺失 / 文件无法读取；
- 未知 Filter 字段；
- 未知 ElleKit 版本；
- 软链接异常。

### 6.4 状态准确性

- 三层状态独立：`installed`（文件在位）/ `configured`（配置有效）/ `loaded`（独立运行时证据）/ `unknown`。
- **不得把 Configured 当作 Loaded**；本版无运行时取证手段，`loaded` 一律 `unknown`。
- 未取到/未验证项显式 `null` / `unknown`，不留空串冒充已知。

### 6.5 只读合规

- 全程无设备写入：不创建/修改/删除文件，不改 plist，不执行 `dpkg -i/-r`，不触碰软链。
- 未知 Profile 下降级只读保守模式，不出现任何写入入口。

## 7. 明确禁止（本版不做）

- 修改 plist / 修改 Bundles；
- 启用或停用插件；
- 安装或卸载插件；
- 删除或移动文件；
- 修改 DynamicLibraries 软链；
- 执行注入操作；
- 安装常驻 Daemon。

## 8. 开放依赖（真机缺口，影响结论背书，不改变范围）

| 依赖 | 影响 | 现状 |
|---|---|---|
| TweakInject 全量目录与配对实况 | S5/S6 验收 | 待真机全量列表（旧报告枚举不全） |
| plist 原文字段/类型 | E1 解析口径背书 | 待 ≥1 个原文样本 |
| 注入器/引导库文件实测 | 环境识别深化/排障 | 仅 dpkg 清单记录，未磁盘实测 |
| `.version-roothide` 版本文件 | 版本 Profile 精确判定 | 未读取，暂用 dpkg 包版本旁证 |
| 进程内路径解析接入方式 | Adapter 实现 | 弱链接 libroothide vs 自行发现，待只读探测复核 |

## 9. 非目标（后续阶段）

- 插件关联写入、规则编辑与回写（0.5.0 / 0.6.0）。
- 插件导入/安装/卸载、dpkg 冲突处理与回滚（0.7.0 / 0.8.0）。
- 运行时注入取证、跨进程加载状态判定。
- 常驻 Daemon、特权 Helper 持久化通道（后续阶段待真机验证）。
- 修改目标 App Bundle、重签名、自研注入引擎。

## 10. 状态与未知口径

- 文件层、关联层、运行层状态独立呈现；UI 文案不得把"已安装/已配置"表述为"已注入/已生效"。
- 扫描到的条目若类型/架构/签名异常，仅记录告警，不阻断其他条目扫描。
- 结论分级标注：`[RootHide源码确认]` / `[上游源码参照]` / `[真机已验证]` / `[待真机验证]`。
