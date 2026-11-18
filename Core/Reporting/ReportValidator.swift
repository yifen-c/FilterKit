//
//  ReportValidator.swift
//  FilterKit Core — Reporting（Stage 2.2-D，D3）
//
//  只读一致性校验：在 Builder 产出的 `ReportEnvelope` 上做结构与证据口径
//  检查，只发现问题并生成 `ReportWarning`，不修复、不回写、不重排上游
//  快照。校验编号 RV-001～RV-010 与冻结规格 §5 一一对应。
//

import Foundation
import Models

/// 校验结果；`isValid` 为 `errors` 是否为空。
public struct ReportValidationResult: Equatable {
    public let isValid: Bool
    public let errors: [ReportWarning]

    public init(isValid: Bool, errors: [ReportWarning]) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// 报告只读校验器（纯数据校验；不访问文件系统）。
public struct ReportValidator {
    /// 解析状态封闭集（与 `FilterParseStatus.rawValue` 对齐，外加兜底 `unknown`）。
    private static let knownStatuses: Set<String> = [
        "valid", "parse_failed", "type_mismatch", "read_failed", "not_parsed", "unknown"
    ]

    public init() {}

    public func validate(_ envelope: ReportEnvelope) -> ReportValidationResult {
        var errors: [ReportWarning] = []

        errors.append(contentsOf: checkEnvelopeCompleteness(envelope))
        errors.append(contentsOf: checkPluginIdentity(envelope))
        errors.append(contentsOf: checkPairingEvidence(envelope))
        errors.append(contentsOf: checkValidationStatus(envelope))
        errors.append(contentsOf: checkFilterConsistency(envelope))
        errors.append(contentsOf: checkLoadedState(envelope))
        errors.append(contentsOf: checkOwnershipConsistency(envelope))
        errors.append(contentsOf: checkWarningDeduplication(envelope))
        errors.append(contentsOf: checkUnknownItemIdentity(envelope))
        errors.append(contentsOf: checkProfileRouteConsistency(envelope))

        return ReportValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// MARK: - 单项校验（RV-001 ～ RV-010）

extension ReportValidator {
    /// RV-001：信封基础字段完整（版本 / Profile 标识与路线非空）。
    private func checkEnvelopeCompleteness(_ envelope: ReportEnvelope) -> [ReportWarning] {
        var issues: [String] = []
        if envelope.schemaVersion.isEmpty { issues.append("schemaVersion 为空") }
        if envelope.generatorVersion.isEmpty { issues.append("generatorVersion 为空") }
        if envelope.profile.id.isEmpty { issues.append("profile.id 为空") }
        if envelope.profile.route.isEmpty { issues.append("profile.route 为空") }
        guard !issues.isEmpty else { return [] }
        return [ReportWarning(
            code: "RV-001",
            message: "信封基础字段不完整：\(issues.joined(separator: "；"))",
            sourceStage: "validator")]
    }

    /// RV-002：插件身份非空且 pluginID 不重复。
    private func checkPluginIdentity(_ envelope: ReportEnvelope) -> [ReportWarning] {
        var errors: [ReportWarning] = []
        var counts: [String: Int] = [:]
        for plugin in envelope.plugins {
            if plugin.pluginID.isEmpty {
                errors.append(ReportWarning(
                    code: "RV-002",
                    message: "插件身份为空：name=\(plugin.name)",
                    sourceStage: "validator"))
            }
            counts[plugin.pluginID, default: 0] += 1
        }
        for (id, count) in counts where count > 1 {
            errors.append(ReportWarning(
                code: "RV-002",
                message: "pluginID 重复 \(count) 次：\(id)",
                sourceStage: "validator"))
        }
        return errors
    }

    /// RV-003：配对状态与两侧路径证据一致。
    private func checkPairingEvidence(_ envelope: ReportEnvelope) -> [ReportWarning] {
        envelope.plugins.compactMap { plugin in
            switch plugin.pairing {
            case .paired:
                guard plugin.dylibPath == nil, plugin.plistPath == nil else { return nil }
                return ReportWarning(
                    code: "RV-003",
                    message: "paired 条目缺少 dylib / plist 路径证据：\(plugin.pluginID)",
                    sourceStage: "validator")
            case .missingPlist:
                guard plugin.plistPath != nil else { return nil }
                return ReportWarning(
                    code: "RV-003",
                    message: "missing_plist 条目携带 plist 路径证据：\(plugin.pluginID)",
                    sourceStage: "validator")
            case .orphanPlist:
                guard plugin.dylibPath != nil else { return nil }
                return ReportWarning(
                    code: "RV-003",
                    message: "orphan_plist 条目携带 dylib 路径证据：\(plugin.pluginID)",
                    sourceStage: "validator")
            case .missingDylib:
                guard plugin.dylibPath != nil else { return nil }
                return ReportWarning(
                    code: "RV-003",
                    message: "missing_dylib 条目携带 dylib 路径证据：\(plugin.pluginID)",
                    sourceStage: "validator")
            }
        }
    }

    /// RV-004：解析状态落在封闭集内。
    private func checkValidationStatus(_ envelope: ReportEnvelope) -> [ReportWarning] {
        envelope.plugins.compactMap { plugin in
            guard !Self.knownStatuses.contains(plugin.validation.status) else { return nil }
            return ReportWarning(
                code: "RV-004",
                message: "解析状态不在封闭集：\(plugin.pluginID) status=\(plugin.validation.status)",
                sourceStage: "validator")
        }
    }

    /// RV-005：filter 与解析状态一致（仅 valid 允许非空 filter）。
    private func checkFilterConsistency(_ envelope: ReportEnvelope) -> [ReportWarning] {
        envelope.plugins.compactMap { plugin in
            if plugin.validation.status == "valid" && plugin.filter == nil {
                return ReportWarning(
                    code: "RV-005",
                    message: "valid 条目缺少 filter：\(plugin.pluginID)",
                    sourceStage: "validator")
            }
            if plugin.validation.status != "valid" && plugin.filter != nil {
                return ReportWarning(
                    code: "RV-005",
                    message: "非 valid 条目携带 filter：\(plugin.pluginID) status=\(plugin.validation.status)",
                    sourceStage: "validator")
            }
            return nil
        }
    }

    /// RV-006：只读阶段无运行时取证，loaded 必须恒为 `.unknown`。
    private func checkLoadedState(_ envelope: ReportEnvelope) -> [ReportWarning] {
        envelope.plugins.compactMap { plugin in
            guard plugin.loaded != .unknown else { return nil }
            return ReportWarning(
                code: "RV-006",
                message: "只读阶段 loaded 必须为 unknown：\(plugin.pluginID) loaded=\(plugin.loaded.rawValue)",
                sourceStage: "validator")
        }
    }

    /// RV-007：来源与归属一致；未知归属不得携带包标识。
    private func checkOwnershipConsistency(_ envelope: ReportEnvelope) -> [ReportWarning] {
        var errors: [ReportWarning] = []
        for plugin in envelope.plugins {
            if plugin.source != plugin.ownership.sourceType {
                errors.append(ReportWarning(
                    code: "RV-007",
                    message: "source 与归属来源不一致：\(plugin.pluginID) source=\(plugin.source.rawValue) ownership=\(plugin.ownership.sourceType.rawValue)",
                    sourceStage: "validator"))
            }
            if plugin.ownership.sourceType == .unknown,
               let packageID = plugin.ownership.packageID,
               !packageID.isEmpty {
                errors.append(ReportWarning(
                    code: "RV-007",
                    message: "未知归属携带包标识：\(plugin.pluginID) packageID=\(packageID)",
                    sourceStage: "validator"))
            }
        }
        return errors
    }

    /// RV-008：告警按 code + message + sourceStage 去重。
    private func checkWarningDeduplication(_ envelope: ReportEnvelope) -> [ReportWarning] {
        var seen = Set<String>()
        return envelope.warnings.compactMap { warning in
            let key = [warning.code, warning.message, warning.sourceStage].joined(separator: "\u{1F}")
            return seen.insert(key).inserted
                ? nil
                : ReportWarning(
                    code: "RV-008",
                    message: "告警重复：\(warning.code) @ \(warning.sourceStage)",
                    sourceStage: "validator")
        }
    }

    /// RV-009：未知归集条目必须保留可追溯身份（path 或 base 至少其一）。
    private func checkUnknownItemIdentity(_ envelope: ReportEnvelope) -> [ReportWarning] {
        envelope.unknownItems.compactMap { item in
            guard item.path == nil, item.base == nil else { return nil }
            return ReportWarning(
                code: "RV-009",
                message: "未知条目缺少 path 与 base：reason=\(item.reason) stage=\(item.sourceStage)",
                sourceStage: "validator")
        }
    }

    /// RV-010：Profile 路线一致；未知路线不得携带路线专属 filter。
    private func checkProfileRouteConsistency(_ envelope: ReportEnvelope) -> [ReportWarning] {
        var errors: [ReportWarning] = []
        for plugin in envelope.plugins {
            if plugin.profileId != envelope.profile.id {
                errors.append(ReportWarning(
                    code: "RV-010",
                    message: "插件 profileId 与信封 Profile 不一致：\(plugin.pluginID)",
                    sourceStage: "validator"))
            }
            if envelope.profile.route == "unknown" && plugin.filter != nil {
                errors.append(ReportWarning(
                    code: "RV-010",
                    message: "未知路线携带路线专属 filter：\(plugin.pluginID)",
                    sourceStage: "validator"))
            }
        }
        return errors
    }
}
