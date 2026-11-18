# FilterKit 0.0.3 数据获取链路与关键代码

本文对应 0.0.3 源码实现，说明 10 项验收数据的本机来源、关键代码和当前边界。

## 1. JBROOT 路径定位

**来源：设备本机路径与 RootHide libroothide API。**

- RootHide 构建检查 `<roothide.h>` 是否存在，并通过弱链接与运行时 `dlsym(RTLD_DEFAULT, "jbroot")`、`dlsym(RTLD_DEFAULT, "jbrand")` 确认 API 符号是否已加载。
- API 可用时调用 C API `jbroot("/")` 和 `jbrand()`。
- API 不可用时不强行调用；改由 `NSBundle.mainBundle.bundlePath`、LSApplicationWorkspace App Bundle Path 提取 `.jbroot-<16位十六进制>`。
- 容器目录扫描只作旁证；固定 `/var/jb`、`/var/rootless`、`/private/var/jb` 作为兼容兜底。
- 候选根使用 `lstat/stat/realpath/access/opendir` 验证，分别保存 errno。根目录、Applications、Library、dpkg 和 DynamicLibraries 标志分开记录。

关键实现：`FKGetJBRootFunction`、`FKGetJBrandFunction`、`FKRootFromPath`、`FKPathProbe`。

## 2. DynamicLibraries 目录

**来源：设备本机文件系统。**

优先以已确认 JBROOT 拼接：
- `Library/ElleKit/DynamicLibraries`
- `Library/MobileSubstrate/DynamicLibraries`
- `library/MobileSubstrate/DynamicLibraries`

RootHide API 可用时另用 `jbroot(path)` 翻译对应相对路径。Rootless lane 使用 `/var/jb` 兼容路径。每个目录独立记录是否存在、是否目录、是否可读、是否可枚举及各阶段 errno。

## 3. dylib 枚举

**来源：DynamicLibraries 本机目录。**

使用 `opendir/readdir` 遍历可枚举目录，按 `.dylib` 后缀过滤并去重。`enumeration_completed` 与 `count` 分开记录：空目录代表枚举成功但没有发现 dylib，不再误报为“发现文件”。

## 4. plist 读取

**来源：DynamicLibraries 本机文件。**

通过 `NSData dataWithContentsOfFile:options:error:` 读取，记录路径、读取状态、数据长度、读取错误。读取成功不等于格式有效。

## 5. Filter 配置解析

**来源：本机 plist 内容。**

通过 `NSPropertyListSerialization` 解析 Property List，检查根字典与 `Filter` 字典，并观察 `Bundles`、`Executables` 候选字段。当前报告明确 `protocol_verified=false`：字段名与结构是候选观察，不代表 ElleKit 各版本的匹配语义已经验证。必须继续以目标 ElleKit 源码和真机结果确认。

## 6. dpkg status

**来源：设备本机 dpkg 数据库。**

动态 JBROOT 下读取 `var/lib/dpkg/status`。解析空行分隔的段落、`Key: Value` 字段及以空格/Tab 开头的续行。分别记录文件可读、解析成功和有效 Package 记录数量；文件存在但没有有效包记录不算成功解析。

## 7. dpkg 包文件归属

**来源：设备本机 dpkg info 文件。**

对 status 中合法 Package ID，读取 `var/lib/dpkg/info/<Package>.list`。记录清单长度，并尝试将 dylib 路径与清单内容匹配。`Conffiles` 不作为完整安装文件清单。未读取到 `.list` 时保持 unknown，不推断包归属。

## 8. ElleKit 版本

**来源：本机 dpkg status。**

查找包标识包含 `ellekit` 且 Status 表示已安装的记录，输出 Package、Version、Status 和 status 文件来源。没有本机证据时 Version 为 null、状态为 unknown，不从网络或固定常量伪造版本。

## 9. App 枚举

**来源：iOS 本机私有 API。**

使用 `LSApplicationWorkspace.defaultWorkspace` 与 `allApplications`，通过 proxy 获取 `applicationIdentifier`、`localizedName`、`bundleURL`。枚举先于 JBROOT 扫描，以便自身和已安装越狱 App 的 Bundle Path 参与根路径交叉验证。

## 10. App 元数据、版本与图标

**来源：本机 App Bundle、私有 API。**

- 版本优先从 App Bundle `Info.plist` 读取 `CFBundleShortVersionString`，缺失时回退 `CFBundleVersion`，记录 `version_source`。
- 图标优先从 Bundle 的 `CFBundleIcons/CFBundlePrimaryIcon/CFBundleIconFiles` 和旧式 `CFBundleIconFiles` 读取本机图片文件。
- 本机文件未获取图标时，才尝试 `iconDataForVariant:withOptions:`。调用前检查方法参数数量、返回类型、variant 参数类型和 options 参数类型；记录 NSData 长度、magic、格式、UIImage 解码结果样本。
- 本 PoC 不自动对全部 App 发起 iTunes Lookup 网络请求，避免未经用户选择的批量外联。iTunes Lookup 作为后续可选云端兜底，不影响本机数据扫描。

## errno 固定映射

| errno | 含义 |
|---:|---|
| 0 | 成功 |
| 1 | 操作不允许 |
| 2 | 路径不存在 |
| 5 | I/O 错误 |
| 13 | 权限拒绝 |
| 20 | 路径组件不是目录 |
| 40 | 符号链接循环 |

JSON 保留 errno 数字和固定中文解释。POSIX errno 不使用 `NSError.localizedDescription` 翻译，避免不同系统语言/编码导致诊断乱码。

## RootHide API 运行时限制

RootHide 官方接口说明：<https://github.com/roothide/Developer/blob/main/interface.md>

API 源码：<https://github.com/roothide/libroothide>

`roothide.h` 在 RootHide Theos 中提供；Rootless 使用上游 Theos，若没有该头文件则走固定 `/var/jb` 兼容分支。RootHide lane 对 `libroothide` 使用弱链接并通过运行时符号查找确认 API 是否可用；符号未加载时不会直接调用 API，而是使用 Bundle Path 降级探测。弱链接和符号存在不等于设备上的目录一定可读，仍须真机验证。

## 当前版本边界

0.0.3 仍是纯只读 PoC：不启动 Helper/Daemon，不使用 IPC，不修改 ElleKit 配置，不安装、禁用、启用或删除插件。Filter 字段语义、RootHide 目录可读性、图标私有 API 返回格式，均须在目标设备和对应 ElleKit 版本上实测。
