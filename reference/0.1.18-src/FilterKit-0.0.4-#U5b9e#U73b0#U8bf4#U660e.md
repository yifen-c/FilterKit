# FilterKit 0.0.4 实现说明

## Filter 字段
Theos 官方格式包含 `Bundles`、`Executables`、`Classes` 三个数组。本版本逐项校验数组和字符串元素，忽略空字符串并记录 warnings。未知字段同时保留 `other_keys` 和 `other_values`。`Bundles` 的 `*` 被记录为 `global=true` 候选，但 `global_semantics_verified=false`，不能据此推定当前 ElleKit loader 的通配语义。

## 注入器识别证据层

1. **dpkg status**：识别包别名，并按 Status 最后一个状态词严格判断 `installed`。Version 仅在包确认为 installed 后作为版本证据。
2. **文件指纹**：检查注入器 dylib/framework。framework 可读取 Info.plist 版本；裸 dylib 不推断版本。
3. **注入目录**：单独报告目录存在、可读、可枚举，不把目录存在当成注入器二进制存在。
4. **当前进程 dyld 镜像**：仅代表 FilterKit 进程当前加载的镜像，不代表其他 App。
5. **suspect_packages**：输出关键词命中但未匹配已知注入器别名的 dpkg 包。

`environment.injector` 汇总多类注入器；`environment.ellekit` 仅在 ElleKit 专属包、文件或当前进程镜像证据出现时报告 detected。未发现证据时仍为 unknown/false，不得得出“设备没有注入器”的结论。

## 版本可信度

`dpkg_status` > `framework_info_plist` > 无版本。运行时镜像和裸 dylib 只用于存在性旁证，不产生版本号。

## 安全与验证边界

0.0.4 继续保持纯只读：没有 Helper、Daemon、IPC、注入配置写入、插件启停或删除。`protocol_verified` 保持 false，直到针对目标 ElleKit 版本核对 loader 源码并进行真机行为验证。
