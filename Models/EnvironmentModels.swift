//
//  EnvironmentModels.swift
//  FilterKit Models
//
//  Stage 2.1 骨架（未编译验证）。结构对齐 S1-08 exporter.buildEnvironment：
//  未取到显式 nil，不留空串冒充已知；pathEvidence 保留定位证据，不反推补齐。
//

import Foundation

/// 版本读取/解析就绪状态（G-B1，契约冻结 §3.1）。
///
/// 与 `EvidenceLevel` 语义不同：本状态表达版本信息的读取与解析状态，
/// 不表达证据可信度；取值与 S1-01 `ellekitVersionStatus` 实测五态逐字一致。
public enum VersionReadinessStatus: String, Codable, Equatable {
    case parsed
    case notInstalled = "not_installed"
    case unreadable
    case unparsable
    case conflicted
}

/// 版本就绪证据（G-B1，契约冻结 §3.2）。
///
/// - `rawVersion`：版本文件中的原始串；
/// - `parsedVersion`：归一化后版本；当前离线夹具二者一致，归一化算法归 Adapter/解析器；
/// - 多来源不一致时 `status = conflicted`，不得任选其一作为最终版本；
/// - `sources` 首版暂缓（冻结契约 D1），不进本结构。
public struct VersionReadiness: Codable, Equatable {
    public var status: VersionReadinessStatus
    public var rawVersion: String?
    public var parsedVersion: String?
    public var warnings: [ReportWarning]

    public init(status: VersionReadinessStatus,
                rawVersion: String? = nil,
                parsedVersion: String? = nil,
                warnings: [ReportWarning] = []) {
        self.status = status
        self.rawVersion = rawVersion
        self.parsedVersion = parsedVersion
        self.warnings = warnings
    }
}

/// 候选校验位（G-B2 §4.1，契约 D6）。
///
/// 三态：`true`=已验证通过、`false`=已验证失败、`nil`=未验证；未验证不得填 `false`。
/// B2 候选收集阶段只记录夹具/信号已提供的存在、结构、可读、realpath 事实；
/// `nameValid` 命名校验归 B3，B2 一律留 `nil`，不提前裁决。
public struct JBRootValidationBits: Codable, Equatable {
    public var nameValid: Bool?
    public var exists: Bool?
    public var structureMatch: Bool?
    public var readable: Bool?
    public var realpath: String?

    public init(nameValid: Bool? = nil,
                exists: Bool? = nil,
                structureMatch: Bool? = nil,
                readable: Bool? = nil,
                realpath: String? = nil) {
        self.nameValid = nameValid
        self.exists = exists
        self.structureMatch = structureMatch
        self.readable = readable
        self.realpath = realpath
    }
}

/// JBROOT 候选（G-B2 §4.2，契约 D4/D5/D7）。
///
/// - `source`：原始来源串原样保留；已知集 `api/scan/bootstrap/rootless/rootful`，
///   非已知值不映射、不丢弃，另附未知来源告警；
/// - `route`：`roothide/rootless/rootful`；未知路线保守留空，不反推；
/// - `validation`：三态校验位，B2 不做命名/存在等校验裁决；
/// - `status`：六态封闭集由 B3 裁决填充；B2 收集阶段为 `nil`（`pending` 仅内部初始态，不导出）；
/// - `warnings`：统一 `[ReportWarning]`（D3）。
public struct JBRootCandidate: Codable, Equatable {
    public var path: String
    public var source: String
    public var route: String
    public var validation: JBRootValidationBits
    public var status: String?
    public var warnings: [ReportWarning]

    public init(path: String,
                source: String,
                route: String,
                validation: JBRootValidationBits = JBRootValidationBits(),
                status: String? = nil,
                warnings: [ReportWarning] = []) {
        self.path = path
        self.source = source
        self.route = route
        self.validation = validation
        self.status = status
        self.warnings = warnings
    }
}

/// 目录定位证据（JBROOT 候选、TweakInject、DynamicLibraries 等）。
///
/// D8 双字段过渡：`jbrootCandidateDetails` 为唯一权威候选结构；`jbrootCandidates`
/// 为派生投影（由权威结构 `path` 生成），构造点同步。旧信封仅含投影字段时解码为
/// 空权威列表 + 保留投影，不报错、不补候选。
public struct PathEvidence: Codable, Equatable {
    public var tweakInject: String?
    public var dynamicLibraries: String?
    public var jbrootCandidateDetails: [JBRootCandidate]
    public var jbrootCandidates: [String]

    public init(tweakInject: String? = nil,
                dynamicLibraries: String? = nil,
                jbrootCandidateDetails: [JBRootCandidate] = [],
                jbrootCandidates: [String] = []) {
        self.tweakInject = tweakInject
        self.dynamicLibraries = dynamicLibraries
        self.jbrootCandidateDetails = jbrootCandidateDetails
        if jbrootCandidateDetails.isEmpty {
            self.jbrootCandidates = jbrootCandidates
        } else {
            self.jbrootCandidates = jbrootCandidateDetails.map(\.path)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case tweakInject, dynamicLibraries, jbrootCandidates, jbrootCandidateDetails
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tweakInject = try c.decodeIfPresent(String.self, forKey: .tweakInject)
        dynamicLibraries = try c.decodeIfPresent(String.self, forKey: .dynamicLibraries)
        let details = try c.decodeIfPresent([JBRootCandidate].self, forKey: .jbrootCandidateDetails) ?? []
        let legacyProjection = try c.decodeIfPresent([String].self, forKey: .jbrootCandidates) ?? []
        jbrootCandidateDetails = details
        if details.isEmpty {
            jbrootCandidates = legacyProjection
        } else {
            jbrootCandidates = details.map(\.path)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(tweakInject, forKey: .tweakInject)
        try c.encodeIfPresent(dynamicLibraries, forKey: .dynamicLibraries)
        try c.encode(jbrootCandidateDetails, forKey: .jbrootCandidateDetails)
        try c.encode(jbrootCandidates, forKey: .jbrootCandidates)
    }
}

/// 越狱环境快照（公共模型，不含路线特有分支字段）。
public struct JailbreakEnvironment: Codable, Equatable {
    public var jailbreakType: JailbreakType
    public var ellekitImplementation: String?
    public var ellekitVersion: String?
    public var profileId: String
    public var jbroot: String?
    public var jbrand: String?
    public var iosVersion: String?
    public var architecture: String?
    public var evidenceLevel: EvidenceLevel
    public var pathEvidence: PathEvidence
    /// G-B1 增补：版本就绪证据；旧信封缺省解码为 `nil`，不改变既有字段语义。
    public var versionReadiness: VersionReadiness?

    public init(jailbreakType: JailbreakType = .unknown,
                ellekitImplementation: String? = nil,
                ellekitVersion: String? = nil,
                profileId: String = "unknown-profile",
                jbroot: String? = nil,
                jbrand: String? = nil,
                iosVersion: String? = nil,
                architecture: String? = nil,
                evidenceLevel: EvidenceLevel = .partial,
                pathEvidence: PathEvidence = PathEvidence(),
                versionReadiness: VersionReadiness? = nil) {
        self.jailbreakType = jailbreakType
        self.ellekitImplementation = ellekitImplementation
        self.ellekitVersion = ellekitVersion
        self.profileId = profileId
        self.jbroot = jbroot
        self.jbrand = jbrand
        self.iosVersion = iosVersion
        self.architecture = architecture
        self.evidenceLevel = evidenceLevel
        self.pathEvidence = pathEvidence
        self.versionReadiness = versionReadiness
    }
}

/// 报告内 Profile 引用（id + 路线）。
public struct ProfileRef: Codable, Equatable {
    public var id: String
    public var route: String

    public init(id: String, route: String) {
        self.id = id
        self.route = route
    }
}

// MARK: - G-B3 目录 / 软链证据（契约冻结 §5.1 / §5.2，B4）

/// 目录路径证据（G-B3 §5.1，D9）。
///
/// - `requestedPath`：请求/推导路径；无法推导时为 `nil`（不填空串冒充已知）；
/// - `resolvedPath`：对应基线 realpath；
/// - `exists / readable / enumerable / structureMatch`：三态事实位，`nil`=未验证，不填 `false`；
/// - `status`：目录裁决状态（D9），独立于证据等级，不用 `EvidenceLevel` 替代；
/// - `warnings`：统一 `[ReportWarning]`（D3）。
public struct PathLocationEvidence: Codable, Equatable {
    public var requestedPath: String?
    public var resolvedPath: String?
    public var exists: Bool?
    public var readable: Bool?
    public var enumerable: Bool?
    public var structureMatch: Bool?
    public var status: String?
    public var warnings: [ReportWarning]

    public init(requestedPath: String? = nil,
                resolvedPath: String? = nil,
                exists: Bool? = nil,
                readable: Bool? = nil,
                enumerable: Bool? = nil,
                structureMatch: Bool? = nil,
                status: String? = nil,
                warnings: [ReportWarning] = []) {
        self.requestedPath = requestedPath
        self.resolvedPath = resolvedPath
        self.exists = exists
        self.readable = readable
        self.enumerable = enumerable
        self.structureMatch = structureMatch
        self.status = status
        self.warnings = warnings
    }
}

/// 软链证据（G-B3 §5.2，D10）。
///
/// - `isSymlink` 三态：`false`=已检查确认非软链，`nil`=未检查，二者不得混同；
/// - `targetPath`：对应基线 symlinkTarget；`realpath`：实际解析路径；
/// - `symlinkState` 五态封闭集：`resolved / broken / loop / denied / not_symlink`；
/// - `targetMatch`：软链目标是否符合预期；独立于五态，不并入状态位；
/// - 首版不纳入 `targetExists / targetReadable / resolutionSucceeded / structureValid` 等基线外布尔位。
public struct SymlinkEvidence: Codable, Equatable {
    public var isSymlink: Bool?
    public var targetPath: String?
    public var realpath: String?
    public var symlinkState: String?
    public var targetMatch: Bool?
    public var warnings: [ReportWarning]

    public init(isSymlink: Bool? = nil,
                targetPath: String? = nil,
                realpath: String? = nil,
                symlinkState: String? = nil,
                targetMatch: Bool? = nil,
                warnings: [ReportWarning] = []) {
        self.isSymlink = isSymlink
        self.targetPath = targetPath
        self.realpath = realpath
        self.symlinkState = symlinkState
        self.targetMatch = targetMatch
        self.warnings = warnings
    }
}
