# Stage 2.3 C-F3：五页面 Simulator 交互验收规格（0.1-C-Final，待 Runner 执行）

- 上游：第三轮 Runner `120016036175`（SHA `f50c284d`）app-build 与 Dashboard 首屏已取证；Plugins / Detail / Diagnostics / Settings 尚未在模拟器内交互取证。
- 定位：本规格只冻结交互验收清单、观察口径与证据清单，**不重新开发 GUI**；本机 Linux 无模拟器/Xcode，执行依赖后续 Runner。
- 合成信封基线（与第三轮截图一致）：RootHide / ellekit 1.0.0 / roothide-preview；插件 3 Total / 2 Paired / 1 Missing / 1 Parse Failed；JBROOT `/private/var/jb` Confirmed；TweakInject Accessible；Permission Undetermined（2.4 probe）。
- 边界：交互验收只证明合成信封在模拟器内的 UI 映射与导航正确；不构成真机权限、真实扫描、真实加载或 Rootless 真机兼容证据。

## 1. 证据清单（归档目录 `Tests/Stage2/evidence/<run>-acceptance/app-build/simulator/`）

| 截图 | 页面 | 对应清单 |
|---|---|---|
| `dashboard.png` | Dashboard | 已取证（第三轮），本轮复核不回退 |
| `plugins.png` | Plugin List | §2 |
| `plugin-detail.png` | Plugin Detail | §3 |
| `diagnostics.png` | Diagnostics | §4 |
| `settings.png` | Settings（导出前） | §5 |
| `share-sheet.png` | Share Sheet / 导出后 | §5 |

- 每张截图须带模拟器设备标识、Bundle ID 与时间戳；导出产物另存 JSON 样本到 `app-build/export/`，供重新解析校验。
- 导航实现方式不在本规格冻结：`simctl` 直接点击可靠性有限，可由 Runner 选择 XCUITest、启动参数直达 Tab 或确定性深链；无论哪种方式，观察口径以本清单为准。

## 2. Plugin List（对应 GUI-03 / GUI-04，规格 §7）

| # | 观察项 | 通过口径 |
|---|---|---|
| PL-1 | 列表显示三个合成插件 | 行数 = Total 3；name / dylib 基名 / 三态标签 / 配对标签 / 版本（缺失不展示版本行）齐全 |
| PL-2 | 搜索过滤 | 输入 name 或 pluginID 片段（含大小写混合）命中；空关键词回到全量；无结果时空态文案正确 |
| PL-3 | ALL 段 | 显示全部 3 个 |
| PL-4 | PAIRED 段 | 仅显示 `pairing == .paired` 的 2 个 |
| PL-5 | ISSUES 段 | 显示未配对 / `configured == false` / `validation.status != valid` 的异常项；与 §7 交集口径一致 |
| PL-6 | 进入详情 | 点击列表行推入 Detail；无启用/禁用/删除/修复等写操作入口 |

## 3. Plugin Detail（对应 GUI-05 / GUI-06，规格 §8）

逐分区核对；至少打开一个 Paired、一个 Missing、一个 Parse Failed 样本分别记录差异。

| 分区 | 观察项 | 通过口径 |
|---|---|---|
| Status | Installed / Configured / Loaded 独立展示 | 三态互不推导；`loaded = .unknown` 显示为「未确认」类文案，**不得**显示为 Not Loaded / 已加载；Permission 行恒占位 |
| Files | dylib / plist 路径 | 存在则展示路径；缺失展示 Unknown，不拼默认路径 |
| Pairing | 配对结果与配对键 `pluginID` | 标签与列表口径一致；未配对样本如实显示异常 |
| Filter | Bundles / Classes / Executables / 其他键 | 空数组展示空态；`coreFoundationVersion` 按 mode 展示 min/max；不丢 `otherKeys` |
| Ownership | Source / Package / Confidence / Writable Policy / 明细 | Unknown 来源如实显示，不暗示管理权限；conflicts / notes / markers / packageVersion / architecture 原样保留 |
| Evidence | sourceStages / evidenceType / evidenceLevel；warnings / skippedFields | 原始证据保留，UI 映射不裁剪未知项 |

- 详情页只读；无编辑、删除、修复、跳转写入入口。

## 4. Diagnostics（对应 GUI-07，规格 §9.1）

七组信息逐组核对，合成信封中为空的组展示空态而非省略分组：

| # | 分组 | 观察项 |
|---|---|---|
| DG-1 | Environment | jailbreakType、ElleKit implementation/version、profile、iOS 版本、架构、证据等级 |
| DG-2 | JBROOT | `jbroot`、候选投影 `jbrootCandidates` 及各候选 `source/route/status` |
| DG-3 | DynamicLibraries | `pathEvidence.dynamicLibraries`、`pathEvidence.tweakInject` |
| DG-4 | Enumeration | 插件总数与各配对类别计数，与 Dashboard 计数一致 |
| DG-5 | Parsing | valid / parse_failed / type_mismatch / read_failed / not_parsed 计数 |
| DG-6 | Warnings | `warnings` 的 code / message / sourceStage 完整列出 |
| DG-7 | Unknown Items | `unknownItems` 的 base / path / reason / sourceStage / detail 完整列出，不因 UI 映射丢弃 |

## 5. Settings 与 JSON 导出（对应 GUI-08，规格 §9.2）

| # | 步骤 | 通过口径 |
|---|---|---|
| ST-1 | 进入 Settings | 版本信息展示；有信封时导出入口可用 |
| ST-2 | 点击 Export | 调用既有 `ReportExporting` 接缝；UI 层不构造编码器、不重排键序 |
| ST-3 | 生成 JSON | 产物为合法 JSON；归档样本可重新解析回等义信封（GUI-08 往返口径） |
| ST-4 | 写入位置 | 仅写入 App 自身 `FileManager.default.temporaryDirectory`，文件名 `FilterKit-Report-<generatorVersion>.json`；**不得**写入 JBROOT、TweakInject 或任何越狱目录；不修改原始信封 |
| ST-5 | Share Sheet | 调起系统 Share Sheet；`share-sheet.png` 归档 |
| ST-6 | 失败路径 | 导出失败以明确错误文案展示，不吞错、不返回空文件；无信封时入口禁用并说明原因（空信封样本复核） |

## 6. 不通过判定（任一命中即 C-F3 未闭环）

- 任一页面崩溃、白屏、导航卡死；
- `loaded = .unknown` 被渲染成 Not Loaded / 已加载等确定态；
- 未知项、warnings、skippedFields、otherKeys 在 UI 被裁剪；
- 导出写入沙盒临时目录以外路径，或出现启停/装卸/删除/修复等写操作入口；
- 截图与合成信封基线计数不一致且无证据解释。

## 7. 待 Runner 落地事项（本规格不实现）

1. app-build job 增补导航与截图步骤（或新增 UI 测试目标），覆盖 §2～§5 全部观察项。
2. 导出 JSON 样本归档路径与重新解析校验步骤。
3. 空信封样本的导出禁用态与空态复核。
4. 执行结果回填 `RUN-METADATA.md` 与实现记录；通过数量以真实日志/截图为准，不预先写死。
