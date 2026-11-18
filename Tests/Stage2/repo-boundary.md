# 2.1-B 源码仓库边界清单（推送前核对）

> 目的：区分“正式源码仓库”与“DevDocs 资料包”。推送 GitHub 私有仓库前逐项核对；
> 本清单为建议口径，最终纳入范围需在推送前确认。

## 1. 建议纳入源码仓库

| 路径 | 说明 |
|---|---|
| `App/` | 界面层骨架（Views/ViewModels/PermissionProbe 占位） |
| `Core/` | 共享核心协议与编排骨架 |
| `Adapters/RootHide/`、`Adapters/Rootless/` | 双路线独立 Adapter 占位 |
| `Models/` | Codable 公共模型与枚举 |
| `Tests/Stage1/`、`Tests/Fixtures/`、`Tests/S1-01~S1-08/` | Stage 1 离线夹具、harness、报告（2.2 回归基线；Node 仅 CI/测试载体） |
| `Tests/Stage2/` | 骨架单测、隔离检查、验收记录 |
| `.github/workflows/` | CI 工作流 |
| `scripts/` | 隔离检查等 CI 辅助脚本 |
| `Package.swift`、`Makefile`、`control`、`.gitignore` | 构建入口与打包描述（草稿） |
| `Spec/` | 冻结规格与计划（建议随源码入库，便于追溯口径） |
| `README.md` | 项目基线与状态 |

## 2. 建议不纳入源码仓库

| 路径 | 原因 |
|---|---|
| `research/`（小写，五个上游克隆） | 第三方源码克隆，体积大且非本工程源码；`.gitignore` 已排除 |
| `reference/0.1.18-src/` | 旧 PoC 历史参考，明确“不作新基线”；是否入库需确认，默认不随源码推送 |
| `Research/Validation/evidence/0.1.18-device-report.json` | 设备私有快照：含 App Bundle UUID、容器路径、文件 md5 等；不进源码仓库 |
| `FilterKit-DevDocs-0.1.zip` | 交付资料包产物，不入库 |
| 编译/打包产物（`*.deb/*.tipa/*.ipa`、`.build/`、`DerivedData/`、`.theos/`） | 构建产物，`.gitignore` 已排除 |
| 签名密钥、证书、entitlement 私钥、设备私有配置 | 凭据与隐私，禁止入库 |

## 3. 历史记录注意事项

- 本地已有两次提交（`74e2738`、`5cb3f38`），按授权要求**保留原始提交历史**，不重新打包成全新快照。
- 但当前历史中已跟踪 `reference/` 与设备报告；若确认不纳入源码仓库，需要在推送前决定：
  - 方案 A：从当前历史中移除对应路径（历史改写），再推送；
  - 方案 B：保留历史，仅在后续提交中排除（旧历史仍含敏感/参考文件，私有仓库内可接受）。
- 该选择影响私有仓库可见内容，须由确认后执行；本阶段不擅自改写历史。

## 4. 推送前核对项

- [ ] 远端仓库为 Private；
- [ ] 无密钥/证书/设备私有快照被跟踪；
- [ ] `research/` 克隆未进入暂存；
- [ ] CI 工作流在默认分支可触发；
- [ ] 提交 SHA 记录进 `Stage-2.1-CI-Acceptance.md`。
