# FilterKit 0.0.7 编译修复说明

## 基线

以用户上传的 `FilterKit-0.0.7-full-source.zip` 解压工程为唯一代码基线。GitHub Actions（roothide, arm64e, Xcode 26.6 / iPhoneOS 26.5 SDK）在编译 `Sources/FKMainViewController.m` 阶段失败，共 9 处错误；`main.m`、`FKAppDelegate.m` 已编译通过。`FKScanner.m` 相对 0.0.6 仅版本号变更，`FKDPKGAnalyzer.m` 与 0.0.6 修复版一致（MD5 局部 pragma 抑制保留）。

## 错误与修复

| # | 位置 | 错误 | 根因 | 修复 |
|---|---|---|---|---|
| 1 | `filterItems:` 搜索谓词 | `property 'lowercaseString' not found on object of type 'const __strong id'` | 循环变量是 `id`，直接点语法取 `lowercaseString`，编译器不做类型收窄 | 先判 `isKindOfClass:NSString.class`，再强转 `(NSString *)` 取 `lowercaseString` |
| 2 | `FKDetailController` 接口 | `duplicate interface definition for class 'FKDetailController'` | 同一类在文件前部和实现前各写了一个 `@interface` 主定义 | 合并为一个主接口，属性与方法声明集中在前部，删除实现前的重复块 |
| 3 | 详情初始化 App 分支 | `assignment to readonly property`（`detailTitle`） | 属性只在第二个重复接口声明，主接口不可见，setter 未生效 | `detailTitle` 并入主接口声明（readwrite） |
| 4 | 详情初始化插件分支 | `assignment to readonly property`（`detailTitle`） | 同上 | 同上 |
| 5 | 详情初始化末尾 | `use of undeclared identifier '_rows'` | `rows` 属性声明位置错乱，自动合成的 `_rows` ivar 不可见 | `rows` 并入主接口，ARC 自动合成 `_rows` |
| 6 | 文件选择器 | `property 'data' not found on object of type 'UTType'` | 该 SDK 无 `UTType.data` 类属性 | 改用类方法 `[UTType typeWithIdentifier:@"public.data"]`，判空后装入数组 |
| 7 | 文件选择器 else 分支 | `'UIDocumentPickerModeOpen' is deprecated`（-Werror） | iOS 13 旧枚举，iOS 14 起废弃 | 部署目标为 iOS 15，该 else 为死分支，直接移除 |
| 8 | 文件选择器 else 分支 | `'initWithDocumentTypes:inMode:' is deprecated`（-Werror） | iOS 13 旧初始化器，iOS 14 起废弃 | 同上，统一使用 `initForOpeningContentTypes:asCopy:` |
| 9 | 设置页统计行 | `unused variable 'dpkg'`（-Werror） | 声明后未使用 | 删除该变量；dpkg 数量改由已有的 `fs`（filesystem）读取，避免 `fs` 再次变为未使用 |

## 未改动项

- `FKScanner.m` 扫描/关联分析逻辑、`FKDPKGAnalyzer.m` dpkg 解析与 MD5 校验、17 项验收 ID、四 Tab 产品结构均未回退或改写。
- 只读边界不变：导入页仅预览文件元数据，不复制、不解压、不安装、不部署、不修改注入配置。

## 验证状态

- 已完成：9 处错误逐一对日志定位修复；`node scripts/validate-project.js` 通过；各 `.m` 括号/花括号配对平衡；plist/XML 合法；版本号 control / Info.plist / Scanner / MainVC / workflow 一致为 0.0.7；全工程扫描无其它 deprecated 旧 API。
- 未在本环境执行：Theos 实编译（本地 Linux 无 clang / iOS SDK）、设备真机测试。
- 待 Actions / 真机确认：编译链接是否通过；文件选择器在真机能否正常拉起 `public.data` 类型选择。

## 待真机确认的文案点（非编译错误）

`FKImportController` 选择结果文案中现有 `\\n` 写法，在 ObjC 字符串里会被解析为字面反斜杠 + `n`。若真机上未换行而显示成 `\n` 字样，再改为 `\n`；本次按"只修编译错误"未改动该文案。
