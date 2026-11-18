# App 界面层（Stage 2.3 GUI Foundation；编译/渲染结论以阶段末 Runner 为准）

首版四页全部**只读**；界面数据来自 Core/Models 报告信封，ViewModel 不拼路径、不判路线、不读设备文件。UI 框架为 SwiftUI；Deployment Target（草案 iOS 17.0）与 Bundle ID（占位 `com.filterkit.manager`）待链接 + 真机证据冻结。

| 目录/页面 | 只读功能 | 禁止 |
|---|---|---|
| `AppEntry/` | 唯一 `@main` 组合根：装配报告来源与导出接缝 | 不实例化 Core 具体扫描器/解析器/Builder/Validator/Service |
| `Navigation/` | 底部 Tab 四页容器 | 不提供页面外的写入入口 |
| `Presentation/` | 纯 Foundation 映射层：Models → 展示摘要/计数/搜索筛选/状态文案；供 SwiftPM `AppPresentation` 目标与 App target 共同编译 | 不 import SwiftUI/UIKit，不依赖 Core 具体实现 |
| `Features/Dashboard/` | 环境类型、ElleKit 实现/版本、Profile、插件统计与系统状态行 | 不展示“已获权限/可读写” |
| `Features/Plugins/` | 插件列表、搜索、来源/归属标签、三层状态、详情跳转 | 不提供启用/禁用、删除入口 |
| `Features/Plugins/PluginDetailView` | dylib/plist 路径、Filter 规则、归属与冲突/混合细节、证据标签 | 不提供编辑/删除 |
| `Features/Diagnostics/` | 环境/JBROOT/库路径/枚举/解析/Warnings/Unknown Items 分组 | 不触发重新扫描，不回写设备 |
| `Features/Settings/` | 版本信息与经 `ReportExporting` 接缝的只读 JSON 导出（App 临时目录 + Share Sheet） | 导出不重编码、不写越狱目录 |
| `Shared/Components/` | 只读通用行/卡片/状态标签组件 | 不承载业务判断 |
| `PermissionProbe/` | 2.4 GUI 进程内权限探针预留目录与接口轮廓 | 2.3 不实现探针、不下权限结论 |

未知/冲突/失败状态如实展示；`loaded=unknown`、`permission.decision=undetermined` 原样呈现。0.1-C 使用固定合成信封做界面预览，合成报告不代表真实 RootHide 文件权限、真实加载或扫描结果；真机快照接入属 0.1-D 探针阶段。
