# FilterKit 0.0.8

FilterKit 0.0.8 是基于用户提供的 `FilterKit-0.0.7-fixed-source.zip` 的只读诊断升级版。保留 0.0.7 四 Tab UI、RootHide/Rootless 路径与环境探测、App 枚举、插件关联、dpkg 深度分析和原有 17 项验收 ID。本版本重点修正 dpkg MD5 验收策略：不改变 MD5 算法或原始比对证据，而是按实际文件类型分流判定。

## 0.0.8 更新

### 1. MD5 完整性分类与分级判定

- 保留 `info/*.md5sums` 的原始 MD5 计算和逐文件 `expected_md5` / `actual_md5`。
- 读取文件头识别 Mach-O 32/64-bit、大小端和 FAT/FAT64 Mach-O，不仅依赖扩展名。
- 其余文件按已知扩展名分为 configuration、text、resource；不能可靠归类的归为 unknown。
- Mach-O 不匹配标记 `warning`，不计入硬失败；不会声称一定是重签名或补丁导致。
- dpkg `Conffiles` 字段明确声明的配置文件不匹配标记 `mutable_config` 警告。未声明为 Conffiles 的配置文件差异仍计入硬失败。
- text、configuration（非 Conffiles）、resource 不匹配计入硬失败；unknown 标记未确认，不伪装成通过。
- 原始不匹配记录全部保留，并增加 `file_type`、`disposition`、`path_category`、`extension`、`conffile_declared`。
- 增加按包、路径类别、扩展名、文件类型的分布，以及硬失败、警告、未确认计数。另计算已校验 Mach-O 总数与二进制差异比例，仅作信息指标，不作为阈值判定。
- 不采用二进制比例阈值作为通过/失败依据；可从明细计算比例，避免小包单个二进制差异被百分比放大。

### 2. 综合诊断与原有数据

保留并继续输出原有环境、App、插件关联、Filter、dpkg 状态、文件清单、缺失文件、多包归属冲突和插件来源证据。原有 17 项验收项 ID 不变；`dpkg_checksum` 现在按硬失败数判 Failed，有未知类型差异时判 Unknown，只有 Mach-O/已声明 Conffiles 等警告时不再错误地判硬失败。

### 3. UI 与 JSON

- 保留 App、插件、导入、设置四个 Tab。
- 设置页扫描统计增加 MD5 完整性摘要：校验数、Mach-O 警告数、硬失败数、未确认数。
- JSON 导出文件名更新为 `FilterKit-0.0.8-report.json`。
- JSON 详细分布位于 `filesystem.dpkg_analysis.integrity.checksum_analysis`；逐条证据位于 `filesystem.dpkg_analysis.integrity.checksum_mismatches`。

## MD5 判定口径

| 类型 | 不匹配处置 | 验收影响 |
|---|---|---|
| Mach-O | `warning` | 不计硬失败 |
| Conffiles 声明的配置文件 | `mutable_config` | 不计硬失败，保留警告 |
| 普通文本 | `hard_failure` | 失败 |
| 非 Conffiles 配置文件 | `hard_failure` | 失败 |
| 资源文件 | `hard_failure` | 失败 |
| 未知类型 | `not_confirmed` | 未确认，不直接判失败 |

重要边界：MD5 不匹配只证明当前文件内容与本机 dpkg md5sums 记录不同。Mach-O 差异可能来自重签名、补丁、重定位或其他变更，但本工具不做代码签名段级比对，因此不判断具体成因、不推断恶意篡改。三个 LaunchDaemons plist 是否由 postinst/守护进程合法改写，也必须有 Conffiles 或其他独立证据；仅凭路径名称不豁免。

## 官方资料与接口边界

- RootHide Developer API：<https://github.com/roothide/Developer/blob/main/interface.md>
- RootHide 路径约定：<https://github.com/RootHide/Developer/blob/main/roothide.md>
- Theos packaging / Filter：<https://theos.dev/docs/packaging>
- Apple UIKit：<https://developer.apple.com/documentation/uikit>

本版本没有重写 0.0.7 已验收的数据采集链路。`LSApplicationWorkspace` 等原有 App 枚举接口属于 Apple 私有 API，仍以设备实测为准。

## 安全边界

纯只读：不修改越狱文件、目标 App、DynamicLibraries、Filter plist 或注入配置；不安装、启停、卸载、部署插件；不引入 RootHelper、Daemon 或 IPC。

## 构建与验证

执行 `node scripts/validate-project.js` 做工程静态检查；再通过 GitHub Actions 手动选择 RootHide 或 Rootless 构建。静态检查不代表 Theos 编译成功，编译产物仍需在目标设备真机验收。
