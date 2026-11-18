//
//  EngineC1-BaselineModels.swift
//  FilterKit Stage 2 — Engine-C1 S1-06 基线映射测试（测试目标专用）
//
//  测试层基线描述模型：只服务 Stage 2.2-C3-Engine-C1 基线对照，不进入生产
//  Models / Core / Adapters。期望取值来源为 Stage 1 `Tests/Fixtures/S1-06/`
//  原始夹具元数据与 `Tests/S1-06/report/S1-06-report.json`，不为迁就实现
//  修改期望值。
//
//  计数纪律：22 是 S1-06 原始基线执行项数；XCTest 用例数、专项断言数、
//  集成场景数分列统计，不与基线覆盖数相加。
//

import Foundation
import Models

/// 测试层路线标签（不伪装未知路线为任一开放路线）。
public enum EngineC1BaselineRoute: String, Equatable {
    case rootHide = "roothide"
    case rootless = "rootless"
    case unknown
}

/// 测试层五态期望（原始值与基线逐字一致）。
public enum EngineC1ExpectedStatus: String, Equatable {
    case valid
    case parseFailed = "parse_failed"
    case typeMismatch = "type_mismatch"
    case readFailed = "read_failed"
    case notParsed = "not_parsed"
}

/// 测试层期望规则字段。`nil` 表示基线未约束该字段（不参与断言）；
/// 空数组表示基线明确期望为空。
public struct EngineC1ExpectedRule: Equatable {
    public var bundles: [String]?
    public var classes: [String]?
    public var executables: [String]?
    public var cfvMode: CoreFoundationMode?
    public var cfvMin: Int?
    public var cfvMax: Int?
    public var otherKeys: [String]?

    public init(bundles: [String]? = nil,
                classes: [String]? = nil,
                executables: [String]? = nil,
                cfvMode: CoreFoundationMode? = nil,
                cfvMin: Int? = nil,
                cfvMax: Int? = nil,
                otherKeys: [String]? = nil) {
        self.bundles = bundles
        self.classes = classes
        self.executables = executables
        self.cfvMode = cfvMode
        self.cfvMin = cfvMin
        self.cfvMax = cfvMax
        self.otherKeys = otherKeys
    }
}

/// 测试层期望字段级错误证据（对齐 `SkippedField` 冻结字段）。
public struct EngineC1ExpectedSkipped: Equatable {
    public var key: String
    public var reason: String
    public var expectedType: String?
    public var observedType: String?
    public var index: Int?

    public init(key: String,
                reason: String,
                expectedType: String? = nil,
                observedType: String? = nil,
                index: Int? = nil) {
        self.key = key
        self.reason = reason
        self.expectedType = expectedType
        self.observedType = observedType
        self.index = index
    }
}

/// 基线用例来源：磁盘夹具或 `run.js` 同口径合成样本。
public enum EngineC1BaselineSource {
    /// `Tests/Fixtures/S1-06/<name>/` 夹具。
    case fixture(name: String)
    /// 合成样本：`run.js buildSyntheticCases` 同口径根对象与期望。
    case synthetic(name: String, root: Any?)
}

/// 单条 S1-06 基线执行样本（22 项之一；PARSE 编号可一对多展开）。
public struct EngineC1BaselineCase {
    /// 基线编号（PARSE-001 ~ PARSE-017 展开，原样保留）。
    public let baselineID: String
    /// 具体执行样本编号（同编号多样本时后缀 `-A/-B`）。
    public let caseID: String
    public let route: EngineC1BaselineRoute
    public let source: EngineC1BaselineSource
    /// 快照级状态期望：`enumerated / partial / unresolved`；合成隔离样本为 nil。
    public let expectedSnapshotStatus: String?
    /// 条目五态期望（按 base 归集）。
    public let expectedStatusByBase: [String: EngineC1ExpectedStatus]
    /// 条目规则期望（按 base 归集）。
    public let expectedRulesByBase: [String: EngineC1ExpectedRule]
    /// otherKeys 期望（按 base 归集）。
    public let expectedOtherKeysByBase: [String: [String]]
    /// 字段级证据期望（按 base 归集）。
    public let expectedSkippedByBase: [String: [EngineC1ExpectedSkipped]]
    /// 快照级告警 code 期望。
    public let expectedWarnings: [String]
    /// 顶层 reason 期望（按 base 归集）；nil 表示 valid 不约束 reason。
    public let expectedReasonByBase: [String: String]
    /// Runner 依赖挂起标记：PARSE-015 待 C3-C2 Runner（#151）出证。
    public let pendingRunner: Bool

    public init(baselineID: String,
                caseID: String,
                route: EngineC1BaselineRoute,
                source: EngineC1BaselineSource,
                expectedSnapshotStatus: String? = nil,
                expectedStatusByBase: [String: EngineC1ExpectedStatus] = [:],
                expectedRulesByBase: [String: EngineC1ExpectedRule] = [:],
                expectedOtherKeysByBase: [String: [String]] = [:],
                expectedSkippedByBase: [String: [EngineC1ExpectedSkipped]] = [:],
                expectedWarnings: [String] = [],
                expectedReasonByBase: [String: String] = [:],
                pendingRunner: Bool = false) {
        self.baselineID = baselineID
        self.caseID = caseID
        self.route = route
        self.source = source
        self.expectedSnapshotStatus = expectedSnapshotStatus
        self.expectedStatusByBase = expectedStatusByBase
        self.expectedRulesByBase = expectedRulesByBase
        self.expectedOtherKeysByBase = expectedOtherKeysByBase
        self.expectedSkippedByBase = expectedSkippedByBase
        self.expectedWarnings = expectedWarnings
        self.expectedReasonByBase = expectedReasonByBase
        self.pendingRunner = pendingRunner
    }
}
