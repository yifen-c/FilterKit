# FilterKit 0.0.5 实现说明

## 基线

以用户上传的 FilterKit 0.0.4 完整源码 ZIP 解压工程为唯一代码基线。原有只读扫描流程和 10 项验收 ID 保留，新增 `plugin_association` 第 11 项。

## 关联实现

1. dylib/plist：同一目录、去扩展名、大小写不敏感基名配对，不跨目录。
2. dpkg 归属：逐行解析 `.list` 路径，按标准化绝对路径或 JBROOT 相对路径精确匹配；不使用宽泛子串命中。
3. Plugin：优先使用唯一 dpkg 所属包的 Package/Description/Version；无法唯一归属时以文件基名作为标识，来源为 manual，并把多个候选包写入 `PackageCandidates`。
4. Filter：Bundles 精确关联已安装 Bundle ID；Executables 和 Classes 分开保存，不混入 Bundle ID 关联。
5. 全局：保留 `Bundles` 含 `*` 的候选标记，但 `global_semantics_verified=false`。
6. 未匹配：记录不在本机 App 集合中的 Bundle ID。
7. 完整性：报告 missing_dylib、missing_plist、重复标识/路径和异常 Filter。
8. App 反向索引：每个 App 新增 `plugins` 标识数组。

## 解释限制

配对规则参考 Theos 官方 Packaging 文档和 Cydia Substrate 官方 Darwin Deployment 文档，但只是常见布局启发式。未知 Loader 可能使用其他配对方式。Filter 配置存在不代表 Loader 接受其全部字段，也不代表插件已加载。Enabled 始终 unknown。

## 验证状态

本交付完成源码静态审查、结构校验、版本一致性、plist/XML、Makefile/Workflow 和 ZIP 检查。未在此环境执行 Theos 编译，也未执行设备真机测试。
