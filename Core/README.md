# Core 模块映射（Stage 2.1 骨架；runner 第六轮 SwiftPM 与 xcodebuild 均编译通过）

Core 为共享管理核心，依赖方向 `App → Core → Models → Adapters`；Core 不写路线特有规则。

| 目录 | 职责 | Stage 1 迁移来源（2.2） |
|---|---|---|
| `Environment/` | 环境识别编排 | S1-01 `detector.js` |
| `PathResolver/` | JBROOT / ElleKit 目录 / 路径归一 | S1-02、S1-03 `resolver.js` |
| `PluginScanner/` | 目录枚举、候选生成 | S1-04 `enumerator.js` |
| `PluginPairing/` | dylib ↔ plist 配对与未配对分类 | S1-05 `pairing.js` |
| `PlistParser/` | plist 读取与类型校验编排 | S1-06 `parser.js` |
| `OwnershipResolver/` | 归属、冲突、混合来源、unknown 降级 | S1-07 `resolver.js` |
| `ReportExporter/` | 统一模型映射与 JSON 导出 | S1-08 `exporter.js` |

服务协议见 `CoreServices.swift`。未知 Profile 不执行扫描；三层状态与来源/权限分离口径见 Models 与 Stage 1 规格。
