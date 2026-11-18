//
//  EngineC2E-RegressionRegistry.swift
//  FilterKit Stage 2 — Engine-C2-E1 全量回归矩阵（测试目标专用）
//
//  唯一回归注册表：记录测试身份（编号 / 阶段 / 套件类 / 源文件）、前置依赖、
//  是否允许 Skip 与证据来源状态。注册表只描述回归计划，**不伪造测试通过状态**：
//  存在于注册表不等于已执行或已通过；未运行、跳过、待验收一律不计通过。
//
//  证据状态口径：
//  - `pendingRunner`：代码落地，尚未在当前 HEAD 取得 Runner 证据，必须保持待验收；
//  - `priorRunnerEvidence`：历史归档 Runner 有证据，但 HEAD 之后套件有变更，最终验收需复验；
//  - `runnerVerified`：以有效归档 Runner 证据为准；仍不等于 C2 最终门禁通过。
//
//  本文件不进入生产 Models / Core / Adapters；不重复实现既有 XCTest 注册与归档能力。
//

import Foundation

/// 回归阶段标签（与既有套件阶段归属对齐）。
public enum EngineC2ERegressionStage: String, Equatable {
    case stage1Fixture = "Stage1"
    case stage2B = "Stage2.2-B"
    case models = "Models"
    case readerDecoder = "C3-B"
    case rootHide = "C3-C1"
    case rootless = "C3-C2"
    case engineB = "Engine-B"
    case engineC1 = "Engine-C1"
    case engineC2 = "Engine-C2"
}

/// 证据来源状态（只记录出处，不替换 Runner 实际执行结论）。
public enum EngineC2EEvidenceState: String, Equatable {
    /// 待 Runner：代码落地，未在当前 HEAD 取得有效证据。
    case pendingRunner = "pending_runner"
    /// 历史 Runner 归档有证据；HEAD 之后套件有变更，最终验收需复验。
    case priorRunnerEvidence = "prior_runner_evidence"
    /// 以有效归档 Runner 证据为准；不代表 C2 最终门禁已关闭。
    case runnerVerified = "runner_verified"
}

/// 单条回归项。
public struct EngineC2ERegressionCase: Equatable {
    /// 回归编号（沿用阶段编号，如 `S1-04`、`C-G2`、`C2-D1`）。
    public let identifier: String
    public let stage: EngineC2ERegressionStage
    /// XCTest 套件类名（与 `Tests/Stage2/` 源文件一一对应）。
    public let suiteClass: String
    /// 源文件基名。
    public let sourceFile: String
    /// 前置门禁编号；无前置为 nil。
    public let dependency: String?
    /// 是否允许合法 Skip；当前回归矩阵默认一律不允许。
    public let allowsSkip: Bool
    public let evidenceState: EngineC2EEvidenceState
    /// 归档 Runner 编号；`pendingRunner` 必须为 nil。
    public let evidenceRun: String?
    /// 预期核对范围（文档口径，不与 XCTest 执行总数相加）。
    public let scope: String

    public init(identifier: String,
                stage: EngineC2ERegressionStage,
                suiteClass: String,
                sourceFile: String,
                dependency: String? = nil,
                allowsSkip: Bool = false,
                evidenceState: EngineC2EEvidenceState,
                evidenceRun: String? = nil,
                scope: String) {
        self.identifier = identifier
        self.stage = stage
        self.suiteClass = suiteClass
        self.sourceFile = sourceFile
        self.dependency = dependency
        self.allowsSkip = allowsSkip
        self.evidenceState = evidenceState
        self.evidenceRun = evidenceRun
        self.scope = scope
    }
}

public enum EngineC2ERegistry {

    /// 第四轮有效归档 Runner（C-G1 / C-G2 首次关闭基线）。
    public static let acceptanceRun = "44021119037"

    /// 第五轮统一验收 Runner（run `44106064051`，C-G1～G7 全过；379 例 0 fail / 0 skip）。
    public static let latestAcceptanceRun = "44106064051"

    /// 全量回归矩阵（唯一来源；新增 / 移除套件只改此处）。
    public static let all: [EngineC2ERegressionCase] = [
        // MARK: Stage 1 夹具与既有行为映射
        EngineC2ERegressionCase(
            identifier: "S1-01", stage: .stage1Fixture,
            suiteClass: "EnvironmentDetectionTests", sourceFile: "EnvironmentDetectionTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "环境识别与路线上游透传不改写"),
        EngineC2ERegressionCase(
            identifier: "S1-02a", stage: .stage1Fixture,
            suiteClass: "JBRootCandidateCollectionTests", sourceFile: "JBRootCandidateCollectionTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "JBROOT 候选收集"),
        EngineC2ERegressionCase(
            identifier: "S1-02b", stage: .stage1Fixture,
            suiteClass: "JBRootValidationTests", sourceFile: "JBRootValidationTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "JBROOT 候选五项三态校验与歧义裁决"),
        EngineC2ERegressionCase(
            identifier: "S1-03", stage: .stage1Fixture,
            suiteClass: "ElleKitDirectoryTests", sourceFile: "ElleKitDirectoryTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "目录定位与软链证据口径"),
        EngineC2ERegressionCase(
            identifier: "S1-04", stage: .stage1Fixture,
            suiteClass: "PluginEnumerationTests", sourceFile: "PluginEnumerationTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "条目中性证据与三态事实位"),
        EngineC2ERegressionCase(
            identifier: "S1-05a", stage: .stage1Fixture,
            suiteClass: "PluginPairingKeyTests", sourceFile: "PluginPairingKeyTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "配对键规则"),
        EngineC2ERegressionCase(
            identifier: "S1-05b", stage: .stage1Fixture,
            suiteClass: "PluginPairingIndexTests", sourceFile: "PluginPairingIndexTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "配对索引与同目录作用域"),
        EngineC2ERegressionCase(
            identifier: "S1-05c", stage: .stage1Fixture,
            suiteClass: "PluginPairingEngineTests", sourceFile: "PluginPairingEngineTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "五桶归类与配对引擎"),
        EngineC2ERegressionCase(
            identifier: "S1-05d", stage: .stage1Fixture,
            suiteClass: "PluginPairingIntegrationTests", sourceFile: "PluginPairingIntegrationTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "配对集成桥接与校验"),
        EngineC2ERegressionCase(
            identifier: "S1-05e", stage: .stage1Fixture,
            suiteClass: "PluginPairingCodableTests", sourceFile: "PluginPairingCodableTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "配对模型 Codable 往返"),
        EngineC2ERegressionCase(
            identifier: "S1-05f", stage: .stage1Fixture,
            suiteClass: "PluginPairingS105FixtureTests", sourceFile: "PluginPairingS105FixtureTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "S1-05 15 项夹具映射独立过滤"),
        EngineC2ERegressionCase(
            identifier: "S1-06a", stage: .readerDecoder,
            suiteClass: "PlistReaderTests", sourceFile: "PlistReaderTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "读取四态与路径回显"),
        EngineC2ERegressionCase(
            identifier: "S1-06b", stage: .readerDecoder,
            suiteClass: "PlistDecoderTests", sourceFile: "PlistDecoderTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "解码两态与 XML/Binary"),
        EngineC2ERegressionCase(
            identifier: "S1-06c", stage: .readerDecoder,
            suiteClass: "PlistValueKindTests", sourceFile: "PlistValueKindTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "类型识别口径"),

        // MARK: Stage 2.2-B / Models
        EngineC2ERegressionCase(
            identifier: "B5-a", stage: .stage2B,
            suiteClass: "B5IntegrationTests", sourceFile: "B5IntegrationTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "B5 目录解析集成"),
        EngineC2ERegressionCase(
            identifier: "B5-b", stage: .stage2B,
            suiteClass: "B5FixtureComparisonTests", sourceFile: "B5FixtureComparisonTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "B5 夹具对照"),
        EngineC2ERegressionCase(
            identifier: "B5-c", stage: .stage2B,
            suiteClass: "B5DeterminismTests", sourceFile: "B5DeterminismTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "B5 确定性"),
        EngineC2ERegressionCase(
            identifier: "Models-a", stage: .models,
            suiteClass: "ModelsCodableTests", sourceFile: "ModelsCodableTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "公共模型 Codable 往返与枚举原始值"),
        EngineC2ERegressionCase(
            identifier: "Models-b", stage: .models,
            suiteClass: "PluginInventoryCodableTests", sourceFile: "PluginInventoryCodableTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "清单模型 Codable 往返"),

        // MARK: C3-C1 / C3-C2 / Engine-B 专项门禁
        EngineC2ERegressionCase(
            identifier: "C3-C1a", stage: .rootHide,
            suiteClass: "FilterParseResultTests", sourceFile: "FilterParseResultTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "统一 Result 模型五态与字段口径"),
        EngineC2ERegressionCase(
            identifier: "C3-C1b", stage: .rootHide,
            suiteClass: "RootHideFilterParserTests", sourceFile: "RootHideFilterParserTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "RootHide 严格类型、CFV 模式、otherKeys 与证据保留"),
        EngineC2ERegressionCase(
            identifier: "C-G1", stage: .engineB,
            suiteClass: "FilterParseEngineTests", sourceFile: "FilterParseEngineTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "Engine-B 短路矩阵、双路线隔离、五桶计数与不可变口径"),
        EngineC2ERegressionCase(
            identifier: "C-G2", stage: .rootless,
            suiteClass: "RootlessFilterParserTests", sourceFile: "RootlessFilterParserTests.swift",
            evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "Rootless Codable 字段、小写规范化、otherKeys 与失败语义"),

        // MARK: Engine-C1 基线（D2 解除 Rootless 挂起后需复验）
        EngineC2ERegressionCase(
            identifier: "C1-a", stage: .engineC1,
            suiteClass: "EngineC1ParserBaselineTests", sourceFile: "EngineC1-ParserBaselineTests.swift",
            dependency: "C-G2", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "22 项基线 Parser 层逐条对照；PARSE-015-A 解除挂起后 run 44106064051 复验通过"),
        EngineC2ERegressionCase(
            identifier: "C1-b", stage: .engineC1,
            suiteClass: "EngineC1EngineBaselineTests", sourceFile: "EngineC1-EngineBaselineTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "22 项基线 Engine 链路逐条对照；PARSE-015-A 解除挂起后 run 44106064051 复验通过"),

        // MARK: Engine-C2 A~C（第四轮归档；Rootless 对称用例 D2 解除挂起后需复验）
        EngineC2ERegressionCase(
            identifier: "C2-A", stage: .engineC2,
            suiteClass: "EngineC2EndToEndTests", sourceFile: "EngineC2-EndToEndTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "双路线端到端；Rootless 对称用例解除挂起后 run 44106064051 复验通过"),
        EngineC2ERegressionCase(
            identifier: "C2-B", stage: .engineC2,
            suiteClass: "EngineC2BatchIsolationTests", sourceFile: "EngineC2-BatchIsolationTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "五态传递、混合批次失败隔离与规则载体归属"),
        EngineC2ERegressionCase(
            identifier: "C2-C", stage: .engineC2,
            suiteClass: "EngineC2SnapshotWarningsTests", sourceFile: "EngineC2-SnapshotWarningsTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "三层追溯、上游保留、告警合并顺序、计数一致、确定性与不可变"),

        // MARK: Engine-C2 D（run 44106064051 统一验收 Runner 证据归档）
        EngineC2ERegressionCase(
            identifier: "C2-D1", stage: .engineC2,
            suiteClass: "EngineC2BaselineIntegrationTests", sourceFile: "EngineC2BaselineIntegrationTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "22 项基线完整 Engine 链路矩阵与 Parser/Engine 一致性对照"),
        EngineC2ERegressionCase(
            identifier: "C2-D2", stage: .engineC2,
            suiteClass: "EngineC2RouteSymmetryTests", sourceFile: "EngineC2RouteSymmetryTests.swift",
            dependency: "C-G2", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "路线选边、不跨路线回退、失败语义分路线与公共规则模型"),
        EngineC2ERegressionCase(
            identifier: "C2-D3", stage: .engineC2,
            suiteClass: "EngineC2EvidenceTraceTests", sourceFile: "EngineC2EvidenceTraceTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "错误证据三层追溯、短路零下游与失败态无规则"),
        EngineC2ERegressionCase(
            identifier: "C2-D4", stage: .engineC2,
            suiteClass: "EngineC2CombinedScenarioTests", sourceFile: "EngineC2CombinedScenarioTests.swift",
            dependency: "C-G1", evidenceState: .runnerVerified, evidenceRun: latestAcceptanceRun,
            scope: "混合批次不变量、双路线隔离、告警/未知项保留、确定性与不可变")
    ]

    /// 按编号查找。
    public static func first(byID identifier: String) -> EngineC2ERegressionCase? {
        all.first { $0.identifier == identifier }
    }

    /// 待验收（pendingRunner）回归项。
    public static var pendingRunnerCases: [EngineC2ERegressionCase] {
        all.filter { $0.evidenceState == .pendingRunner }
    }
}
