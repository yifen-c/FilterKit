//
//  EnvironmentDetector.swift
//  FilterKit Core — 环境识别编排（B1 / S1-01）
//
//  规则对齐 Stage 1 detector.js（离线只读）：多信号组合判定；版本五态；
//  两类冲突不强行选边、不自动降级 Profile。Core 只做中性编排，路线匹配
//  口径由各 Adapter 的 EnvironmentProfileAdvisor 提供，Core 不写路线规则。
//

import Foundation
import Models

/// S1-01 环境识别结果（与 Stage 1 报告字段对齐；不反推补齐缺失信息）。
public struct EnvironmentDetectionResult: Equatable {
    public var jailbreakType: String
    public var architecture: String
    public var iosVersion: String
    public var bootstrapName: String?
    public var bootstrapVersion: String?
    public var ellekitImplementation: String
    public var versionReadiness: VersionReadiness
    public var adapterProfile: String?
    public var outcome: String
    public var warnings: [ReportWarning]
}

public final class EnvironmentDetector {
    private let parser: VersionParser
    private let advisors: [EnvironmentProfileAdvisor]
    private let sourceStage: String

    public init(parser: VersionParser = VersionParser(),
                advisors: [EnvironmentProfileAdvisor] = [],
                sourceStage: String = "S1-01") {
        self.parser = parser
        self.advisors = advisors
        self.sourceStage = sourceStage
    }

    public func detect(_ snapshot: EnvironmentSnapshot) -> EnvironmentDetectionResult {
        let s = snapshot.signals

        var jailbreakType = Self.presentValue(s.jailbreakType)?.lowercased() ?? "unknown"
        let architecture = Self.presentValue(s.architecture) ?? "unknown"
        let iosVersion = Self.presentValue(s.iosVersion) ?? "unknown"

        var bootstrapName: String?
        var bootstrapVersion: String?
        if s.bootstrap?.present == true {
            bootstrapName = s.bootstrap?.name ?? s.bootstrap?.value
            bootstrapVersion = s.bootstrap?.version
        }

        var implementation = Self.presentValue(s.ellekitImplementation)?.lowercased() ?? "unknown"

        var warnings: [ReportWarning] = []
        let recognizedJb = jailbreakType == "roothide" || jailbreakType == "rootless"
        if s.bootstrap?.present != true && recognizedJb {
            addWarning(&warnings, "bootstrap_missing")
        }
        if s.ellekitImplementation?.present != true && recognizedJb {
            addWarning(&warnings, "implementation_missing")
        }

        var readiness = parser.classify(signal: s.ellekitVersion)

        // 冲突检测：① 路线信号冲突；② 实现-版本冲突。
        let routeConflict = jailbreakType == "roothide" && Self.boolValue(s.rootlessPathPresent) == true
        let implVersionConflict = implementation == "upstream"
            && readiness.status == .parsed
            && (readiness.rawVersion ?? "").contains("1.2-3")

        let outcome: String
        var adapterProfile: String?

        if routeConflict || implVersionConflict {
            if routeConflict { addWarning(&warnings, "route_signal_conflict") }
            if implVersionConflict { addWarning(&warnings, "impl_version_conflict") }
            // 冲突不选边：类型/实现/版本归零，状态置 conflicted。
            jailbreakType = "unknown"
            implementation = "unknown"
            readiness = VersionReadiness(status: .conflicted)
            outcome = "conflict_no_profile"
        } else if jailbreakType == "rootful" {
            addWarning(&warnings, "unsupported_rootful")
            outcome = "unsupported_profile"
        } else if let profile = advisors.compactMap({
            $0.proposedProfile(jailbreakType: jailbreakType,
                               implementation: implementation,
                               versionStatus: readiness.status)
        }).first {
            adapterProfile = profile
            outcome = "profile_candidate"
        } else if jailbreakType == "unknown" && implementation == "unknown" && readiness.status == .notInstalled {
            addWarning(&warnings, "no_jailbreak_signals")
            outcome = "unknown"
        } else {
            outcome = "partial"
        }

        // 合并版本就绪层告警（access_limited / version_unparsable 等），按 code 去重。
        for warning in readiness.warnings {
            guard !warnings.contains(where: { $0.code == warning.code }) else { continue }
            warnings.append(warning)
        }

        return EnvironmentDetectionResult(
            jailbreakType: jailbreakType,
            architecture: architecture,
            iosVersion: iosVersion,
            bootstrapName: bootstrapName,
            bootstrapVersion: bootstrapVersion,
            ellekitImplementation: implementation,
            versionReadiness: readiness,
            adapterProfile: adapterProfile,
            outcome: outcome,
            warnings: warnings
        )
    }

    // MARK: - 信号取值辅助

    private static func presentValue(_ sig: EnvironmentSignalValue?) -> String? {
        guard let sig, sig.isPresent, let value = sig.value, !value.isEmpty else { return nil }
        return value
    }

    private static func boolValue(_ sig: EnvironmentSignalValue?) -> Bool? {
        guard let sig, sig.isPresent else { return nil }
        if let boolValue = sig.boolValue { return boolValue }
        return sig.value == "true"
    }

    private func addWarning(_ warnings: inout [ReportWarning], _ code: String) {
        guard !warnings.contains(where: { $0.code == code }) else { return }
        warnings.append(ReportWarning(code: code, message: "", sourceStage: sourceStage))
    }
}
