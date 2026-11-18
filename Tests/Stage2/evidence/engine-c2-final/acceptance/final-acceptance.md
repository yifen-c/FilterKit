# Engine-C2 最终验收结论（run `44106064051`）

> 本结论以本轮有效归档 Runner 证据为准；历史汇报、静态检查或注册表条目不解除门禁。
> 证据归档：`Tests/Stage2/evidence/run-44106064051-acceptance/`。

## 验收基线

- 本地 HEAD：`1298edcad86e5ddd84572f302ab01c9f454def73`（2.2-D 规格冻结；代码面最近提交 `0d4315f`）
- Runner 编号：`44106064051`（branch `D5`，检出 SHA `f4629f268e680bc0e25e911997d03959457263ec`）
- 归档时间（UTC）：2026-11-17 15:04:16Z
- 环境：macOS 26.7.2（25G332）/ Xcode 26.6（17F113）/ Swift 6.3.3 / iOS Simulator SDK 26.5 / arm64-apple-macosx26.0
- 基线差异说明：Runner 检出 SHA 与本地 HEAD 不同名；本地无远端，未做逐行源码 diff。metadata 五文件（Package.swift / Makefile / control / project.yml / workflow）与本地一致；本地静态 `func test` 计数 379 与 Runner 执行 379 逐套件对齐。

## 门禁表（C-G1～G7）

| 门禁 | 定义 | 证据位置 | 状态 |
| --- | --- | --- | --- |
| C-G1 | Engine-B Runner 全过：Core Build 0 error/0 warning、E-B1～E-B6、既有回归、S1-05、App Build 与隔离 | `tests/engine-b.log` / `core-build/` / `app-build/` / `isolation/` | ✅ passed（19 例 0 fail / 0 skip） |
| C-G2 | C3-C2 Rootless Parser Runner 全过（22 例专项 + 既有回归无损伤） | `tests/full-regression.log`（`RootlessFilterParserTests`） | ✅ passed（22 例 0 fail / 0 skip，无 Skip 隐藏） |
| C-G3 | S1-06 22 项全部映射到 Swift XCTest 并逐项对照基线 | `tests/engine-c1.log` | ✅ passed（注册表 22 项自校验通过；Parser 8 + Engine 7 例 0 fail） |
| C-G4 | 双路线隔离：失败不跨路线重试，未知路线零调用 | `tests/engine-b.log` / `tests/engine-c2.log` / `isolation/` | ✅ passed（路线选边/不回退 6 例、批次隔离 4 例；脚本 1a/1b/2a/2b OK） |
| C-G5 | 五态与 Counts 不变量：四桶和 == parsed.count；notParsed == 条目数；五桶和 == 总数 | `tests/engine-c2.log` | ✅ passed（SnapshotWarnings 6 + CombinedScenario 5 + 集成校验器不变量） |
| C-G6 | 既有回归全部通过（Models / Environment / JBROOT / Directory / Enumeration / Pairing / Reader-Decoder / 双 Parser / Engine） | `tests/full-regression.log` | ✅ passed（既有 275 例 0 fail / 0 skip） |
| C-G7 | App Build 成功，架构隔离通过（无 GUI 私有解析、无服务装配泄漏、七方法协议未演进） | `app-build/app-xcodebuild.log` / `isolation/` | ✅ passed（BUILD SUCCEEDED，PID 3508 存活；脚本第 4 项 OK；七方法签名未演进） |

## 测试计数（Runner 实际执行；未执行保持 null）

| 分组 | passed | failed | skipped | 备注 |
| --- | --- | --- | --- | --- |
| Stage1 / 既有回归 | 275 | 0 | 0 | S1-05 15 项 / S1-06 22 项为基线覆盖数，不与 XCTest 总数相加 |
| Engine-B | 19 | 0 | 0 | C-G1 |
| Engine-C1 | 15 | 0 | 0 | 22 项基线（Parser 8 + Engine 7） |
| Engine-C2 A～D | 37 | 0 | 0 | A～C 16 + D1～D4 21 |
| C-G2 Rootless 专项 | 22 | 0 | 0 | 计入全量，单列 |
| E 组织自校验 | 11 | 0 | 0 | 注册表身份/结构核对，计入全量，单列 |
| 全量回归 | 379 | 0 | 0 | `swift test` 全量；S1-05 独立过滤 15 例 0 failure |

## 独立挂起项

| Issue | Status | Production parser modification | Expected behavior modification |
| --- | --- | --- | --- |
| PARSE-009-B | pending_independent_review | Not authorized | Not authorized |

## 边界记录

- 本轮未扫真机、未修改越狱文件、未进行插件启停 / 装卸 / 注入 / dpkg / 软链改动或其他写操作。
- 未运行 / 跳过 / 待验收测试不计通过；本轮全量 0 skipped，第四轮 3 例挂起对应用例本轮已实际执行并通过。
- 统一报告 / JSON 导出属 Stage 2.2-D，本阶段不实现；归属识别分类器未迁移。
- Runner SDK 26.5 不作 Theos 16.5 / 真机兼容证据；模拟器存活取证不等同于稳定性或真机权限验证。
- 观察项（不阻塞本轮门禁）：NSNumber/NSNull 桥接、Rootless Codable 桩输入行为、字典键唯一性、三数组齐备时 mapper 零条目告警口径。

## 最终结论

**Runner 证据口径：C-G1～G7 全部 `passed`，Stage 2.2-C3 Engine 完整集成在 CI / iOS Simulator 证据下收口；等待最终人工确认。**

- 本结论仅覆盖本轮 Runner 检出 `f4629f2` 的编译、测试、静态隔离与模拟器存活证据；不构成真机权限、真实加载或 Rootless 真机兼容证据。
- PARSE-009-B 保持独立挂起，独立授权前不改 Parser 实现与基线期望。
- 下一阶段（Stage 2.2-D 统一报告 / JSON 导出）须另行授权，不因本轮 Engine 集成通过自动开始。
