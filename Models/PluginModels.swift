//
//  PluginModels.swift
//  FilterKit Models
//
//  Stage 2.1 骨架（未编译验证）。字段对齐 S1-08 exporter.buildPlugin 与
//  Spec/Plugin-Data-Model.md §2.2~§2.4。三层状态 installed/configured/loaded
//  互不推导；ownershipDetails 保留冲突、混合归属与标记异常，不简化为单一来源。
//

import Foundation

/// 版本约束（CoreFoundationVersion）；缺失 = nil。
public struct CoreFoundationVersion: Codable, Equatable {
    public var mode: CoreFoundationMode
    public var min: Int?
    public var max: Int?

    public init(mode: CoreFoundationMode, min: Int? = nil, max: Int? = nil) {
        self.mode = mode
        self.min = min
        self.max = max
    }
}

/// 解析后的 Filter 规则。
public struct FilterRule: Codable, Equatable {
    public var bundles: [String]
    public var classes: [String]
    public var executables: [String]
    public var coreFoundationVersion: CoreFoundationVersion?
    public var otherKeys: [String]

    public init(bundles: [String] = [],
                classes: [String] = [],
                executables: [String] = [],
                coreFoundationVersion: CoreFoundationVersion? = nil,
                otherKeys: [String] = []) {
        self.bundles = bundles
        self.classes = classes
        self.executables = executables
        self.coreFoundationVersion = coreFoundationVersion
        self.otherKeys = otherKeys
    }
}

/// 文件归属与可写策略。
public struct Ownership: Codable, Equatable {
    public var sourceType: SourceType
    public var packageID: String?
    public var listPath: String?
    public var confidence: Confidence
    public var writablePolicy: WritablePolicy

    public init(sourceType: SourceType = .unknown,
                packageID: String? = nil,
                listPath: String? = nil,
                confidence: Confidence = .unknown,
                writablePolicy: WritablePolicy = .readOnly) {
        self.sourceType = sourceType
        self.packageID = packageID
        self.listPath = listPath
        self.confidence = confidence
        self.writablePolicy = writablePolicy
    }
}

/// 归属细节：保留多包冲突、分文件归属、标记损坏等原始证据。
public struct OwnershipDetails: Codable, Equatable {
    public var fileOwnership: String?
    public var markers: String?
    public var conflicts: [String]
    public var notes: [String]
    public var packageVersion: String?
    public var architecture: String?

    public init(fileOwnership: String? = nil,
                markers: String? = nil,
                conflicts: [String] = [],
                notes: [String] = [],
                packageVersion: String? = nil,
                architecture: String? = nil) {
        self.fileOwnership = fileOwnership
        self.markers = markers
        self.conflicts = conflicts
        self.notes = notes
        self.packageVersion = packageVersion
        self.architecture = architecture
    }
}

/// 解析校验报告。
public struct ValidationReport: Codable, Equatable {
    public var status: String
    public var warnings: [String]
    public var skippedFields: [String]

    public init(status: String = "unknown",
                warnings: [String] = [],
                skippedFields: [String] = []) {
        self.status = status
        self.warnings = warnings
        self.skippedFields = skippedFields
    }
}

/// 管理授权状态；只读阶段 decision 恒 undetermined。
public struct PermissionState: Codable, Equatable {
    public var decision: PermissionDecision
    public var reason: String

    public init(decision: PermissionDecision = .undetermined,
                reason: String = "authorization_gate_not_evaluated") {
        self.decision = decision
        self.reason = reason
    }
}

/// 证据块：记录来源阶段、证据类型与等级。
public struct EvidenceBlock: Codable, Equatable {
    public var sourceStages: [String]
    public var evidenceType: String
    public var evidenceLevel: EvidenceLevel

    public init(sourceStages: [String] = [],
                evidenceType: String = "fixture",
                evidenceLevel: EvidenceLevel = .partial) {
        self.sourceStages = sourceStages
        self.evidenceType = evidenceType
        self.evidenceLevel = evidenceLevel
    }
}

/// 插件记录（公共模型）。
public struct Plugin: Codable, Equatable {
    public var pluginID: String
    public var name: String
    public var version: String?
    public var dylibPath: String?
    public var plistPath: String?
    public var pairing: Pairing
    public var source: SourceType
    public var ownership: Ownership
    public var ownershipDetails: OwnershipDetails?
    public var filter: FilterRule?
    public var isTweakManager: Bool
    public var loadCategory: LoadCategory
    /// 文件层：在位/可读证据；上游缺失或未列入库存 = nil，不反推补齐。
    public var installed: Bool?
    /// 关联层：plist 存在且 Filter 可解析；不由 installed/归属推导。
    public var configured: Bool
    /// 运行层：无独立运行时证据恒 unknown。
    public var loaded: LoadedState
    public var validation: ValidationReport
    public var permission: PermissionState
    public var profileId: String
    public var evidence: EvidenceBlock

    public init(pluginID: String,
                name: String,
                version: String? = nil,
                dylibPath: String? = nil,
                plistPath: String? = nil,
                pairing: Pairing = .paired,
                source: SourceType = .unknown,
                ownership: Ownership = Ownership(),
                ownershipDetails: OwnershipDetails? = nil,
                filter: FilterRule? = nil,
                isTweakManager: Bool = false,
                loadCategory: LoadCategory = .unknown,
                installed: Bool? = nil,
                configured: Bool = false,
                loaded: LoadedState = .unknown,
                validation: ValidationReport = ValidationReport(),
                permission: PermissionState = PermissionState(),
                profileId: String = "unknown-profile",
                evidence: EvidenceBlock = EvidenceBlock()) {
        self.pluginID = pluginID
        self.name = name
        self.version = version
        self.dylibPath = dylibPath
        self.plistPath = plistPath
        self.pairing = pairing
        self.source = source
        self.ownership = ownership
        self.ownershipDetails = ownershipDetails
        self.filter = filter
        self.isTweakManager = isTweakManager
        self.loadCategory = loadCategory
        self.installed = installed
        self.configured = configured
        self.loaded = loaded
        self.validation = validation
        self.permission = permission
        self.profileId = profileId
        self.evidence = evidence
    }

    private enum CodingKeys: String, CodingKey {
        case pluginID, name, version, dylibPath, plistPath, pairing, source,
             ownership, ownershipDetails, filter, isTweakManager, loadCategory,
             installed, configured, loaded, validation, permission, profileId, evidence
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pluginID, forKey: .pluginID)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(version, forKey: .version)
        try c.encodeIfPresent(dylibPath, forKey: .dylibPath)
        try c.encodeIfPresent(plistPath, forKey: .plistPath)
        try c.encode(pairing, forKey: .pairing)
        try c.encode(source, forKey: .source)
        try c.encode(ownership, forKey: .ownership)
        try c.encodeIfPresent(ownershipDetails, forKey: .ownershipDetails)
        try c.encodeIfPresent(filter, forKey: .filter)
        try c.encode(isTweakManager, forKey: .isTweakManager)
        try c.encode(loadCategory, forKey: .loadCategory)
        // D4 §6.2.2：Optional Bool 三态保留；nil 显式编码为 null，不省略键、不缺省为 false。
        try c.encode(installed, forKey: .installed)
        try c.encode(configured, forKey: .configured)
        try c.encode(loaded, forKey: .loaded)
        try c.encode(validation, forKey: .validation)
        try c.encode(permission, forKey: .permission)
        try c.encode(profileId, forKey: .profileId)
        try c.encode(evidence, forKey: .evidence)
    }
}

/// 无法归类/解析的条目（保留路径、原因与来源阶段）。
public struct UnknownItem: Codable, Equatable {
    public var path: String?
    public var base: String?
    public var reason: String
    public var sourceStage: String
    public var detail: [String: String]

    public init(path: String? = nil,
                base: String? = nil,
                reason: String,
                sourceStage: String,
                detail: [String: String] = [:]) {
        self.path = path
        self.base = base
        self.reason = reason
        self.sourceStage = sourceStage
        self.detail = detail
    }
}

/// 全局告警。
public struct ReportWarning: Codable, Equatable {
    public var code: String
    public var message: String
    public var sourceStage: String

    public init(code: String, message: String, sourceStage: String) {
        self.code = code
        self.message = message
        self.sourceStage = sourceStage
    }
}
