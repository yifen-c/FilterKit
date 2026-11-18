# ElleKit-Compatibility.md — 双路线兼容规范（Spec 0.1 草案）

- 状态：规格草案；RootHide 侧基于 **[RootHide源码确认]**，Rootless 侧基于 **[上游源码参照]**，真机背书见 `Research/Validation/`。
- 基准：RootHide `roothide/ellekit @ 16e3e7e（1.2-3）`；Rootless `opa334/ElleKit @ 4825b07`（上游，待真机确认）。

## 1. 双源码基准

| 路线 | 源码 | 基准 | 架构/打包档 | 证据等级 |
|---|---|---|---|---|
| RootHide | `roothide/ellekit` | `16e3e7e` / 1.2-3 | arm64e，`INSTALL_PREFIX` 空，走 `jbroot()` 翻译 | [RootHide源码确认]；真机路径/样本待补 |
| Rootless | `opa334/ElleKit` | `4825b07` | arm64，`/var/jb` 前缀 | [上游源码参照]；未在真机确认 |

> Rootless 暂以已有上游研究为基准；不同 rootless 越狱可能装不同 ElleKit 分支/版本，须经 Profile 层识别，不默认等同上游。

## 2. 八维度兼容对照

| 维度 | RootHide 1.2-3 | Rootless（上游 4825b07） | 差异要点 / 证据 |
|---|---|---|---|
| 注入机制 | 引导层 `systemhook` hook `posix_spawn` → dlopen `TweakLoader.dylib`→libinjector；进程内 scandir 扫描 | 上游 `loader`/pspawn 挂钩拉起注入器；进程内扫描 | D7；启动挂钩由 bootstrap/libroothide 接管 |
| 插件目录 | `jbroot("/usr/lib/TweakInject/")` 翻译到 JBROOT 容器 | 硬编码 `/var/jb/usr/lib/TweakInject/` | D1；RootHide 不硬编码 `/var/jb` |
| 路径解析 | libroothide `jbroot()/rootfs()` 翻译；容器 `.jbroot-<jbrand>` | `/var/jb` 前缀直拼 | Path-Resolution.md；接入方式待真机复核 |
| plist 格式 | 顶层 `Filter` 字典 + 可选 `IsTweakManager` 布尔；逐字段严格类型校验，不符即跳过 | 同字段集；基础 CF 解析，类型容错 | D5；Filter-Rules.md §2 |
| Filter 匹配 | Bundles 要求 `CFBundleIsExecutableLoaded`；无小写回退；非 UI 进程跳过 UIKit/TextInput/TextEntry 前缀；OR 语义 | 含小写回退；仅查已注册 bundle；无显式后台前缀过滤 | D2；Filter-Rules.md §3 |
| 加载顺序 | 扫描完收集 managers/tweaks 数组 → Managers → OldABI → 普通 Tweak；Manager 上限 20、普通 1000，溢出静默丢弃 | 边 scandir 边 dlopen；Manager 先于普通 Tweak | D3/D12；Plugin-Loading-Order.md |
| Safe Mode | `_MSSafeMode`/`_SafeMode` 全局跳过；`.eksafemode` 仅 UI 进程（`.app`/`.appex`）判定 | 环境变量 + `.eksafemode` 对注入进程统一判定 | D4/D10；injector.c:446-454,493-495 |
| 异常处理 | 单个 dylib 失败不中断后续；完整性损坏走 `ABORT_WITH`；类型不符静默跳过 | 失败后 `dlerror()` 清空；无独立致命通道 | D13/D14；D6 软链自检为 RootHide 特有 |

## 3. 两条路线保持一致的口径

- 配对：`X.dylib` ↔ `X.plist` 同名；缺 plist 不注入；孤儿 plist 不被枚举。
- Filter 字段：`Bundles / Classes / Executables / CoreFoundationVersion`；顶层 `IsTweakManager`。
- 匹配 OR；无黑名单/排除 Bundle 语义；无默认全注入；Bundles 可列多个 ID（单插件多 App）。
- 排序：`alphasort2 = -strcoll`，逆字母序（Z→A）。
- 进程内无缓存：每个新 spawn 重新 scandir + 重读 plist；规则变更须杀目标 App 冷启动生效。
- 配置即磁盘文件，重越狱自动重读，无常驻 daemon 依赖。

## 4. 路径与软链事实（RootHide 真机旁证）

- JBROOT：`/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4`（jbrand `9C414BB7D5DCECC4`）；realpath `/private/var/…`。
- `Library/MobileSubstrate/DynamicLibraries` 为软链 → `<JBROOT>/usr/lib/TweakInject`。
- dpkg：状态库 `<JBROOT>/var/lib/dpkg/status`，info 目录 `<JBROOT>/var/lib/dpkg/info`。
- 来源：`Research/Validation/Device-Report-0.1.18-Findings.md`（旧 App 二手内省，扫描枚举不全）。

## 5. 待真机验证项（不阻塞规格，阻塞对应结论背书）

| 项 | 说明 | 对应清单 |
|---|---|---|
| TweakInject 全量目录与配对实况 | 旧报告仅识别 2 个，少于 45 个 dylib 包 | V1 / P0-10 |
| plist 原文字段与类型 | 抓 ≥1 个 Sileo 插件原文核对 | V6 / P0-13 |
| 注入器/引导库文件实测 | libinjector / roothideinit / TweakLoader 存在性与软链 | P0-12 |
| `.version-roothide` 版本文件 | RootHide 专用版本号 | P0-5 |
| Bundles 可执行已加载 / 后台前缀过滤 | 真机行为复核 | V10 / V11 |
| 规则变更冷启动生效 | 热启动 vs 冷启动对比 | V4 |
| 重越狱规则自动恢复 | 重启/重越狱后重读 | V7 |

## 6. 兼容实现约束

1. 两条路线的解析器/校验器各自独立；公共层不持有路线特有分支。
2. 规则预览必须区分"Bundle ID 已注册"与"可执行已加载"两个层次。
3. 类型不符的 plist 必须标注"规则可能被 ElleKit 跳过"，不得当作合法配置。
4. 不删除/替换 `DynamicLibraries` 软链——它是完整性自检对象，破坏会导致 `.app` 进程 ABORT（D6）。
5. 未知 ElleKit 版本/分支 → 只读保守模式，规则语义标未确认。
