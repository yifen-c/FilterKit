# acceptance-report.md — Stage 2.2-C2-D2 Runner 验收报告（run 43857670397 / Run ID 118727393219）

- 验收日期：2026-11-16（UTC）；分支 `C2` @ `ce118319ec6940ac688d9fd08895474fe1e34c28`；本地锚点 `64420bb`。
- 验收依据：`Stage-2.2-C2-D-Runner-Acceptance-Checklist.md` §4 硬门槛；证据见同目录 `RUN-METADATA.md` 与 `logs/`、`test-log/`、`app-build/`。

## 1. 硬门槛逐项结论

| # | 验收项目 | 通过要求 | Runner 证据 | 结论 |
|---:|---|---|---|---|
| 1 | Swift 编译 | 0 error | build Job `Build complete! (17.41s)`；Models/Adapters/Core 63 源 + Stage2Tests 86 单元编译，日志 0 error / 0 warning | ✅ 通过 |
| 2 | XCTest | 0 failure；跳过为 0 或逐项说明 | 全量 210 tests，0 failures（0 unexpected）；未见跳过 | ✅ 通过 |
| 3 | Stage 1 回归 | S1-04 / S1-05 原始基线全覆盖且通过 | S1-04 23 例（Enumeration 14 + InventoryCodable 9）0 失败；S1-05 15 例映射 0 失败；独立 `--filter` 复跑 15 例 0 失败 | ✅ 通过 |
| 4 | C1 回归 | 23 项全部通过 | 同 #3 C1 Enumeration 23 例 0 失败 | ✅ 通过 |
| 5 | C2-A | 模型 / Codable 测试全部通过 | PluginPairingCodableTests 12 例 0 失败 | ✅ 通过 |
| 6 | C2-B | 配对行为测试全部通过 | Key 11 + Index 5 + Engine 21 = 37 例 0 失败 | ✅ 通过 |
| 7 | C2-C | 集成桥接测试全部通过 | PluginPairingIntegrationTests 32 例 0 失败 | ✅ 通过 |
| 8 | 路线隔离 | 双路线隔离检查全部通过 | 隔离脚本三向 OK（RootHide↔Rootless 互不引用；Core 未实例化具体 Adapter） | ✅ 通过 |
| 9 | Fixture 完整性 | 无意外修改 | `git diff 5b481e6..HEAD -- Tests/Fixtures/` 为空；Stage 1 fixtures/harness/metadata 未改 | ✅ 通过 |
| 10 | App Build | iOS Simulator 构建成功 | `** BUILD SUCCEEDED **`；App 安装启动，复查存活 PID 3991；截图 `dashboard.png` 归档 | ✅ 通过 |

## 2. 计数汇总

- 全量执行：**210** 例，0 失败。
- 原始基线映射：**38**（S1-04 23 + S1-05 15）。
- C2 新增专项：**81**（A 12 + B 37 + C 32）。
- B 阶段既有回归：91 例，0 失败。
- 独立过滤复跑：`PluginPairingS105FixtureTests` **15** 例，0 失败（`test-log/test-log-s105.txt`）。

## 3. 验收结论

**Stage 2.2-C：Enumeration & Pairing Core Migration — Runner 验收通过（C2-D2 收口）。**

该结论仅限离线 Core 数据处理链路（环境/目录识别、枚举、配对归类、集成校验与 Codable 往返）；不构成真机扫描、GUI 权限、Rootless 兼容或插件启停证据。

## 4. 未决项（移交后续批次，不在本批收口）

- 2.2-A R6 未知枚举原始值默认解码行为未真机实测。
- Deployment Target / iOS 17 兼容、Rootless 无真机、App 存活不证明目录访问权限、Runner SDK 26.5 不作为 Theos 16.5 兼容证据。
- C3（Filter plist 解析）、归属识别、插件启停、真机只读探测须另行授权。
