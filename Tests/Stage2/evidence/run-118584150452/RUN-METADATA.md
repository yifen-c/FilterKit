# RUN-METADATA.md — 第十二轮（2.2-B2 JBROOT 候选收集 runner 验收通过）

- Run ID：**118584150452**；仓库 `yi-fen/007` / `main`；artifact `filterkit-build-metadata`（ID 14197418118，6673 字节）、`filterkit-test-log`（ID 14196922850，1731 字节）。
- Runner SHA：`1fb25e295a79195114f82d376b770ba058dd0511`（fetch-depth 1；与本地提交 `035db7f`/`a3a8c7a` 的差异为同步时变基/压缩，内容对应 B2 本地落地 + 判重微调后状态；runner 侧 `Package.swift`/`control`/`project.yml`/`Makefile` 快照与本地一致）。
- 时间：2026-11-16 04:19:14Z ~ 04:24:26Z。
- Runner：macOS 26.7.2（25G332），镜像 `macos-26-arm64` 20261102.0473.1；runner 2.338.2；westus / MacCloud；git 2.56.0。
- 工具链：Xcode 26.6（Build 17F113）；Apple Swift 6.3.3（swiftlang-6.3.3.1.3 clang-2100.1.1.101）；SDK iOS 26.5 / Simulator iOS 26.5 / macOS 26.5；Testing Library 1902；测试平台 arm64e-apple-macos14.0；XcodeGen 2.46.0。

## 1. Job 结果总览

| Job | 结论 | 证据 |
|---|---|---|
| environment | ✅ success | 工具链版本落盘，无 error |
| build（Models / Adapters / Core） | ✅ success | `Build complete! (6.33s)`；`JBRootCandidateCollector.swift`、`JBRootCandidateSnapshot.swift` 均编译，Models / Adapters / Core 模块均 emit |
| test（Stage2Tests） | ✅ success | **Executed 38 tests, with 0 failures (0 unexpected)** |
| isolation | ✅ success（静态文本层面） | 三向 OK：RootHide 未引用 Rootless；Rootless 未引用 RootHide；Core 未直接实例化具体 Adapter |
| app-build | ✅ success | `xcodegen generate`；`** BUILD SUCCEEDED **`；模拟器 install/launch；存活复查；截图归档 |
| artifact | ✅ success | build-metadata、test-log 上传成功 |

## 2. 测试明细（38 例，0 失败）

### 2.1 B2 候选收集：JBRootCandidateCollectionTests 10 方法，0 失败

`Test Suite 'JBRootCandidateCollectionTests' ... Executed 10 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds`

| 测试方法 | 覆盖口径 | 结果 |
|---|---|---|
| `testFixtureCandidateCollection` | 十组 S1-02 夹具：候选数量对齐基线 `candidateCount`、输入顺序、`source` 原样保留、`route` 映射、规范化路径、校验位事实镜像、`nameValid/status` 留空、D8 投影一致 | ✅ |
| `testFiveKnownSourcesCovered` | 五来源 `api/scan/bootstrap/rootless/rootful` 并集覆盖 | ✅ |
| `testPATH004LexicalNormalization` | `.`/`..`/重复分隔符/尾斜杠/纯根/越界边界 | ✅ |
| `testPATH011Determinism` | 相同输入重复收集 Equatable 全等 | ✅ |
| `testPATH012IdMismatchDoesNotAffectCollection` | metadata/environment ID 不一致不影响收集 | ✅ |
| `testUnknownSourcePreservedAndWarned` | D7：原始来源保留、路线不反推、`unknown_candidate_source` 告警 | ✅ |
| `testMultiSourceSamePathRetainedAndExactDuplicateDropped` | 同路径不同来源保留；同路径同来源精确重复去重 + 告警 | ✅ |
| `testInvalidPathWarnedAndSkipped` | 空/非法路径告警且不入库 | ✅ |
| `testCandidateCodableRoundTrip` | 候选结构 Codable 往返全等 | ✅ |
| `testLegacyPathEvidenceDecodesProjectionOnly` | D8 旧信封仅投影字段解码不报错、权威列表为空 | ✅ |

### 2.2 既有回归保持：21 Codable + 7 环境识别，0 失败

- `ModelsCodableTests`：**Executed 21 tests, with 0 failures**（2.2-A 冻结面未破坏）；
- `EnvironmentDetectionTests`：**Executed 7 tests, with 0 failures**（B1 环境识别回归未破坏）。

## 3. App Target 复验（沿用 2.1/B1 闭环口径）

- 模拟器：`iPhone 17 Pro`，UDID `5AB3DACF-C352-49D1-BF9A-3C0104FA4ED3`，Booted；
- 安装 `FilterKit.app`（Debug-iphonesimulator，bundle `com.filterkit.manager`）；`xcrun simctl launch` → PID **9011**；
- 存活复查：`9011 0 UIKitApplication:com.filterkit.manager[ff96][rb-legacy]`，存活 PID 9011 == 启动 PID 9011；
- 截图 `dashboard.png` 1206×2622 RGBA：标题 `FilterKit`、环境「尚未检测」、权限「尚未验证（2.4 探针）」、脚注「本阶段为只读骨架；不含扫描、启停或写入功能。」，中文渲染正常；界面无扫描/启停/写入入口。

## 4. 边界核对（B2 授权范围内）

- 只做候选归集：规范化、来源/路线映射、顺序保留、多来源保留、精确重复去重、未知来源告警；
- 未做命名/存在/结构/可读/realpath 校验裁决，未填六态 `status`，未选择最终 JBROOT/jbrand/selectedSource/outcome（归 B3）；
- `ElleKitAdapter` 七方法协议未改；`CoreServices.swift` 服务协议未新增；
- Stage 1 Fixtures / harness / 报告未改；测试只读引用 `Tests/Fixtures/S1-02/`；
- 无真机写入、插件启停、GUI 文件扫描、权限探针；隔离脚本三向通过。

## 5. 遗留与非目标（不构成本轮失败项）

- B2 结论仅为候选集合；候选路径与 `.jbroot-` 前缀命中均不构成 JBROOT 有效性证据。
- `nameValid` 与六态裁决、多候选歧义/跨路线/无候选判定归 B3；B4 目录/软链定位只使用 B3 确认路径。
- App 仍为只读骨架：模拟器存活只证明未立即退出，不代表越狱文件访问权限；GUI 真实权限 / entitlement / `jbroot()` 进程内调用归 2.4 探针。
- Rootless/Rootful 候选仅作路线对照，无真机结论；B3/B4/B5、2.2-C、进入 2.3 均未授权。

## 6. 归档清单

- `logs/`：environment / build / test / isolation / app-build / artifact 各 job 分步日志与 system 日志；
- `test-log/test-log.txt`：`swift test` 完整输出；
- `app-build/`：`app-xcodebuild.log`、`sim-launch.log`、`dashboard.png`（不含 DerivedData `.app` 二进制）；
- `metadata/`：runner 侧 `Package.swift`、`control`、`project.yml`、`Makefile`、`filterkit-build.yml` 快照。
