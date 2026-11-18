# P0 / P1 / P2 前置资料清单

基准（P0）：`roothide/ellekit @ 16e3e7e（1.2-3）`；上游 `opa334/ElleKit @ 4825b07`（P1 参照）；真机文件系统（P2 最终依据）。
结论分级：**[RootHide源码确认]** / **[上游源码参照]** / **[真机已验证]** / **[待真机验证]**。
原则：每个底层操作可追溯到 ElleKit 真实机制；每个 RootHide 假设必须有设备证据或明确"待验证"标记。知识库文档见 `Research/`。

## P0 — 未齐备不开始正式功能开发

| # | 资料项 | 状态 | 证据 / 备注 |
|---|---|---|---|
| P0-1 | RootHide ElleKit 源码 | ✅ 已具备 | `research/roothide-ellekit-src/`，HEAD `16e3e7e`（1.2-3） |
| P0-2 | 上游参照源码 | ✅ 已具备 | `research/ellekit-src/` @ `4825b07`，仅对照用 |
| P0-3 | libroothide 路径库源码 | ✅ 已具备 | `research/libroothide-src/`（A7 依据） |
| P0-4 | R&D 0.2 权威报告 | ✅ 已具备 | `Research/R&D 0.2/RootHide-ElleKit-1.2-3.md`（含引导层 `Dopamine-Roothide-Bootstrap.md`） |
| P0-5 | RootHide 真实版本 | 🟡 部分 | dpkg：`roothide 0.1.0` / manager `1.4.1` / patchloader `0.0.8`；源码指定的 `<JBROOT>/basebin/.version-roothide` 文件仍未读取 |
| P0-6 | iOS 真实版本 | ✅ 已具备 | 17.0.2（真机截图 + 报告） |
| P0-7 | 设备型号 / 架构 | ✅ 已具备 | iPhone16,2（iPhone 14 Pro，arm64e / iphoneos-arm64e） |
| P0-8 | 设备 ElleKit 版本 | ✅ 已具备 | 1.2-3，`dpkg_status` 背书；行为差异待真机样本复核 |
| P0-9 | JBROOT 实际路径 | ✅ 已闭合 | 实测 `/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4`，jbrand `9C414BB7D5DCECC4`，realpath `/private/var/…`；见 Validation 回写文档 |
| P0-10 | TweakInject 实际目录 | 🟡 部分 | 软链目标已确认为 `<JBROOT>/usr/lib/TweakInject/`；全量目录未列（旧扫描仅识别 2 个，少于 45 个 dylib 包） |
| P0-11 | DynamicLibraries 软链 | ✅ 已闭合 | 真机 `is_symlink=true`，realpath → TweakInject；inode 可补采 |
| P0-12 | 注入器 / 引导库文件 | ❌ 未实测 | `TweakLoader.dylib`/`libinjector.dylib`/`roothideinit.dylib` 仅 dpkg 清单记录、`exists=null`，需 `ls -la`+`readlink` 实测 |
| P0-13 | 真实 Sileo 插件样本（dylib+plist） | 🟡 部分 | 2 样本路径/归属/解析字段已有；plist **原文**未采集，需 `plutil` 转 xml 复核字段 |
| P0-14 | dpkg 文件所有权记录 | ✅ 样本闭合 | 状态库 `<JBROOT>/var/lib/dpkg/status`、info 目录确认；两样本 `.list` 精确命中归属包 |

> 回写依据：`Research/Validation/Device-Report-0.1.18-Findings.md`；原始 JSON：`Research/Validation/evidence/0.1.18-device-report.json`。

### 真机采集命令（只读，不改任何文件）

> RootHide 的 JBROOT 是隐藏容器，**不要假定 `/var/jb`**。先发现容器再拼相对路径；完整说明见 `Research/Validation/RootHide-Device-Verification.md`。

```bash
# 环境与版本
sw_vers; uname -a
dpkg -l | grep -iE 'ellekit|roothide|libroothide'

# 发现 JBROOT 容器
ls -ld /var/containers/Bundle/Application/.jbroot-* 2>/dev/null

# 插件目录、软链（$JBROOT 替换为上一步实际路径）
ls -la "$JBROOT/usr/lib/TweakInject/" | head -40
ls -ld "$JBROOT/Library/MobileSubstrate/DynamicLibraries"
readlink -f "$JBROOT/Library/MobileSubstrate/DynamicLibraries"

# 注入器 / 引导库
ls -la "$JBROOT/usr/lib/ellekit/" 2>/dev/null
ls -la "$JBROOT/usr/lib/roothideinit.dylib" 2>/dev/null

# 挑一个 Sileo 插件，打印完整 plist（二进制先转 xml）
plutil -convert xml1 "$JBROOT/usr/lib/TweakInject/<插件>.plist" -o -

# dpkg 归属（只读查询）
dpkg -S "$JBROOT/usr/lib/TweakInject/<插件>.dylib"
dpkg -S "$JBROOT/usr/lib/TweakInject/<插件>.plist"
```

### 采集必要性分级（按里程碑，非全部前置）

| 待采集项 | 分级 | 理由 / 替代 |
|---|---|---|
| TweakInject 全量目录 + dylib/plist 配对实况 | **0.1.0 门禁必需** | 0.1.0 完整只读链包含扫描与配对；必须确认真实目录可枚举、同名配对实况，旧报告只识别 2 个不能当全量 |
| 真实 plist 原文（≥1 个） | **0.2.0 前补齐** | 0.1.0 只枚举配对、不解析规则；0.2.0 做 plist 解析/类型校验前才需要原文核对字段 |
| 注入器/引导库文件实测（libinjector / roothideinit / TweakLoader） | **可延后** | 只读扫描 TweakInject 不依赖其存在性；ElleKit 版本已由 dpkg_status 背书 1.2-3。留到环境识别深化或排障时补 |
| `.version-roothide` 版本文件 | **可延后，有旁证** | 版本 Profile 判定可先用 dpkg `roothide`/`ellekit` 包版本旁证；专用版本文件仅在需要精确 RootHide 版本时再读 |
| pkgmirror 路径性质 | **可延后，先标未知** | 边界澄清项；扫描未从该路径读取即可先标记未知，不阻塞主线 |

> 原则：未采集项对应的结论一律保留 **[待真机验证]**，不得当已确认；采集是为源码结论背书，不是开工前提。研究/骨架阶段仍按版本规则推进。

## P1 — 开发过程中必须完成

| # | 项目 | 现状 |
|---|---|---|
| P1-1 | Safe Mode（`_MSSafeMode`/`_SafeMode`/`.eksafemode`） | [RootHide源码确认] 环境变量全局跳过；`.eksafemode` 仅 UI 进程判定；真机触发路径待验 |
| P1-2 | 插件加载顺序（逆字母序；Managers → OldABI → 普通 Tweak） | [RootHide源码确认]，真机待验 |
| P1-3 | IsTweakManager 精确语义与产品用途边界 | [RootHide源码确认] 先收集先加载；用途边界待验 |
| P1-4 | plist 异常处理（损坏/非字典/类型不符/空数组） | [RootHide源码确认] 严格类型校验不符即跳过；边界待真机样本核对 |
| P1-5 | dylib 异常处理（损坏/错架构/缺失依赖） | [RootHide源码确认] 单个失败不中断后续；报错表现待验 |
| P1-6 | 软链接与目录扫描行为 | [RootHide源码确认] 完整性自检要求软链；scandir 对软链条目行为待验 |
| P1-7 | 插件升级冲突（同名覆盖、版本兼容） | 未确认 |
| P1-8 | 规则变更须杀进程冷启动生效 | [RootHide源码确认] 进程内无缓存；真机待验 |
| P1-9 | Bundles 大小写 / 可执行已加载 / 后台前缀过滤 | [RootHide源码确认] 无小写回退、要求 `CFBundleIsExecutableLoaded`、非 UI 跳过 UIKit 系；真机待验 |
| P1-10 | FilterKit 进程内 JBROOT 解析方式（链接 libroothide 或自行发现） | 🟡 旁证：报告显示进程内 `jbroot(/)` 可取到容器、runtime API 可用；符号链接/沙盒可读性仍待新工程只读探测复核 |

## P2 — 后续完善

- 不同 ElleKit / RootHide 版本兼容性
- 插件依赖关系与冲突检测
- 运行时加载状态检测（跨进程取证）
- 故障恢复机制
- OldABI.dylib 兼容范围与缺失后果

## 来源与权限策略（草案，待 P0-13/14 样本背书）

| 来源 | 查看 | 关联管理 | 删除文件 |
|---|---|---|---|
| Sileo / dpkg 管理 | ✓ | 视 ElleKit 能力而定 | 默认禁止 |
| FilterKit 自管 | ✓ | ✓ | 无关联引用后允许 |
| 用户手动导入 | ✓ | 确认后管理 | 谨慎 |
| 来源不明 | ✓ | 只读并提示风险 | 默认禁止 |

原则：**不能因为能改某个文件，就默认拥有该文件的管理权。** FilterKit 不接管 dpkg 软件包生命周期。
