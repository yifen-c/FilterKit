# FilterKit 0.0.9 实现说明

1. 基于 0.0.8 源码及用户提供的 0.0.8 真机 JSON 报告开发。
2. MD5 算法仍为 dpkg md5sums 要求的 MD5；保留全部原始 expected/actual 值。
3. 非 Conffiles plist 差异从硬失败调整为 configuration_review，并计入 not_confirmed，避免将运行时配置变化直接定性为文件损坏或恶意修改。
4. 其他 text、非 plist configuration、resource 不匹配仍计入硬失败；Mach-O 仅警告。
5. 新增 roothelper_preflight 第 18 项，仅探测候选二进制及 LaunchDaemon plist，不启动、不安装、不通信。
6. 版本、导出名、DEB control、Info.plist、GitHub Actions artifact 和静态校验脚本同步为 0.0.9。

边界：静态检查不能代替 Theos 编译；RootHelper 真实启动验证未在此版本执行。

## 0.0.9 诊断准确性修复（版本号仍为 0.0.9）

依据 0.0.9 真机报告（16 通过 / 0 失败 / 2 未确认：`dpkg_checksum`、`roothelper_preflight`），本轮只提升诊断准确性，不改变只读架构，不新增 Daemon / Helper / IPC / 写入。

### 一、RootHelper 双向关联探测

原实现只检查 5 个固定路径，并按文件名过滤 LaunchDaemon plist，证据不足。改为双向关联：

- **反向（LaunchDaemon → Helper）**：全量遍历 `Library/LaunchDaemons/` 下所有 plist，不再按文件名过滤；解析 `Label`、`Program`、`ProgramArguments`、`RunAtLoad`、`MachServices`、`UserName`、`GroupName`。从 `Program` / `ProgramArguments` 提取程序路径，逐项检查存在性、普通文件、可执行位与大小。
- **正向（文件系统 → 候选）**：除保留固定候选路径作为存在性证据外，仅在受限可执行目录（`usr/libexec`、`usr/bin`、`usr/sbin`、`Library/PrivilegedHelperTools`）按文件名关键词（helper/root/daemon/agent/service/privileged）枚举，不扫描全盘。
- **dpkg 归属关联**：候选与解析出的程序路径按逻辑路径在 `file_ownership` 中反查所属软件包，输出 `package_ids`，避免把其他程序误识别为 RootHelper。
- **证据分级**：payload 新增 `evidence_status`：
  - `complete`：可执行候选与可解析且指向存在可执行程序的服务声明齐全 → Passed；
  - `partial_binary_only`：仅有可执行候选，缺少服务声明 → Unknown；
  - `partial_registration_only`：仅有服务声明，未定位到可执行程序 → Unknown；
  - `inaccessible`：LaunchDaemons 目录不可访问 → Unknown；
  - `not_found`：目录可访问但无候选无声明 → Unknown。
- 没有发现 RootHelper 不等于其不可用；本版本不调用 `launchctl`、不启动 Helper、不发送 IPC、不安装或修改 helper。

### 二、MD5 文件类型三级识别与归因

原实现仅识别 Mach-O magic，其余按扩展名归类，Unknown 占比偏高。改为三级识别，文件头优先于内容、内容优先于扩展名：

- **第一级 magic**：Mach-O 32/64、FAT/FAT64 Mach-O、ELF、PNG、JPEG、ZIP、GZIP、SQLite、PDF、bplist00。
- **第二级内容**：magic 未命中时采样前若干字节，按 UTF-8 可读与不可打印字符比例判断是否为文本，不仅凭 UTF-8 解码成功认定文本。
- **第三级扩展名**：作为辅助证据，不覆盖已识别出的真实格式。
- 每条不匹配记录新增 `format`（细分格式）、`detection_method`（magic/content/extension/unknown）、`confidence`（high/medium/low）、`reason`（差异归因说明）。
- **Conffiles 规范化**：补全相对路径前缀、标准化路径后再与 md5sums 逻辑路径匹配；未在 Conffiles 声明的 plist 不豁免。
- **包级统计**：每个包输出 `checksum_stats`（checked / matched / mach_o_mismatch / configuration_mismatch / text_mismatch / resource_mismatch / unknown_mismatch / hard_failure）。
- **覆盖率**：`checksum_analysis` 增加 `records`（MD5 记录总数）、`coverage`（已校验 / 记录总数）、`unknown_type_total`（无法识别类型总数）。缺少 MD5 记录不直接视为文件损坏。

### 三、判定口径（沿用 0.0.8，未放宽）

| 类型 | 处置 | 是否硬失败 |
|---|---|---|
| Mach-O / ELF 等二进制 | `warning` | 否，警告 |
| Conffiles 声明的配置文件 | `mutable_config` | 否，警告 |
| 非 Conffiles plist / 配置 | `configuration_review` | 否，未确认待复核 |
| 普通文本、非 plist 配置、资源 | `hard_failure` | 是 |
| 未知类型 | `not_confirmed` | 未确认，不伪装通过 |

重要边界：MD5 只能证明当前内容与 md5sums 记录不同；二进制差异可能来自重签名、补丁、重定位或其他变更，本工具不做签名段级比对，不判断成因、不推断恶意篡改。

### 四、保留与边界

- 原有 18 项验收 ID 不变；四 Tab UI、App/插件/导入/设置、只读预览边界不变。
- 版本号仍为 0.0.9；JSON 导出文件名仍为 `FilterKit-0.0.9-report.json`。
- CI 编译修复：三级识别改造后，旧的 `FKDChecksumFileType` 包装函数不再被校验循环调用，触发 `-Werror,-Wunused-function`。已对该函数局部标注 `__attribute__((unused))` 保留符号名（供静态校验与后续复用），未全局关闭 `-Werror`。
- 静态检查（`node scripts/validate-project.js`）不代表 Theos 编译成功；RootHelper 真实启动与二进制段级成因仍需真机与后续版本验证。

## 0.0.9 第二轮真机复核与官方/成熟方案对齐（版本号仍为 0.0.9）

依据第二份真机报告（17 通过 / 0 失败 / 1 未确认，唯一未确认项为 `dpkg_checksum` 内 3 个非 Conffiles plist 的 `configuration_review`），逐文件逐段复核源码，并对照 Theos 官方 packaging 文档、Debian dpkg 标准与主流越狱工具实现。本轮仍为纯只读 PoC，不引入 Helper / Daemon / IPC / 写入。

### 一、确定的代码缺陷修复

- **导入预览换行转义错误**：`FKMainViewController.m` 导入预览详情误用双反斜杠 `\\n`（ObjC 解析为字面反斜杠 + n，换行失效），改为 `\n`。
- **未初始化局部变量**：`FKDPKGAnalyzer.m` 的 `FKDMD5` 中 `NSInteger count;` 未初始化（流打开失败路径可能读到未初始化值），改为 `NSInteger count = 0;`；文件清单核对处 `struct stat st;` 清零为 `= {0}`。

### 二、官方 / 成熟方案对齐

- **App 枚举方法**：主流越狱 prefs/工具优先 `LSApplicationWorkspace -allInstalledApplications`；原实现仅用 `allApplications`。新增统一 helper，先取 `allInstalledApplications`，非数组再兜底 `allApplications`，两处枚举（已安装 App、图标兜底）共用。
- **Executables 规则参与关联**：Filter 官方三键为 `Bundles` / `Executables` / `Classes`（Theos 官方 packaging 文档一致）。原关联仅按 Bundles 精确匹配，Executables 只保留为规则不参与关联。现采集 App 的 `CFBundleExecutable`，建立可执行名 → Bundle ID 映射，Executables 规则反查已安装 App 并计入匹配；记录 `matched_executables` / `unmatched_executables`，关联分类相应纳入可执行名未命中项。
- **Conffiles 第二渠道**：除 status stanza 的 `Conffiles` 字段外，标准 dpkg 另在 `var/lib/dpkg/info/<package>.conffiles` 记录配置文件清单。补齐该文件读取并与 status 字段合并，避免单一渠道遗漏；已声明为 Conffile 的配置差异归 `mutable_config`，未声明的 plist 仍归 `configuration_review`。

### 三、未确认 3 项的复核结论（口径未放宽）

- 三条 `configuration_review` 记录分别归属 `com.tigisoftware.filza64bit`、`shshd`、`system-cmds`，均为单包归属、无归属冲突。
- 其 status stanza 的 `Conffiles` 字段确为空（如实记录 `conffile_declared=false`）。补齐 `info/<pkg>.conffiles` 读取后，真机重扫时若包在该清单声明，会自动收敛为 `mutable_config`；仍未声明则继续待复核。
- MD5 只证明当前内容与记录不同，不判定成因、不推断篡改。要区分“合法运行时改写 / 维护脚本改写”与“未授权差异”，需读取 postinst / extrainst_ 等维护脚本或运行时生成证据，属第二阶段增强，本轮不扩大范围、不把未确认项直接判为通过。

### 四、已知限制（本轮未处理）

- 图标 `CFBundleIconName`（Assets.car 资产名）解析未做；跨 bundle 读取 `.car` 受沙盒 / entitlement 限制，主路径仍为 bundle 内裸 PNG 与私有图标 API 画像。
- 所有改动仅经本地静态检查与 `validate-project.js`；本机无 Theos / iOS SDK，未实编译，需 GitHub Actions 编译与真机验收确认。
