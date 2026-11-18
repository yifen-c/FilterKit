//
//  DashboardOverview.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  Dashboard 展示模型：环境行、插件统计、系统状态行，全部由 `ReportEnvelope`
//  只读派生。空信封（nil）各计数为 0、环境行 Unknown，不推断已识别路线。
//

import Foundation
import Models

/// Dashboard 单行信息（标题 + 值 + 可选分级）。
public struct DashboardInfoRow: Equatable, Identifiable {
    public let title: String
    public let value: String
    public let status: DisplayStatus?

    public var id: String { title }

    public init(title: String, value: String, status: DisplayStatus? = nil) {
        self.title = title
        self.value = value
        self.status = status
    }
}

/// 插件统计计数。
public struct DashboardCounts: Equatable {
    public let total: Int
    public let paired: Int
    public let missing: Int
    public let parseFailed: Int

    public init(total: Int, paired: Int, missing: Int, parseFailed: Int) {
        self.total = total
        self.paired = paired
        self.missing = missing
        self.parseFailed = parseFailed
    }
}

/// Dashboard 概览（只读派生，不回改信封）。
public struct DashboardOverview: Equatable {
    public let environmentRows: [DashboardInfoRow]
    public let counts: DashboardCounts
    public let systemRows: [DashboardInfoRow]

    /// 计入 Parse Failed 的解析状态；`not_parsed` 不计入。
    private static let parseFailureStatuses: Set<String> = [
        "parse_failed", "type_mismatch", "read_failed"
    ]

    public init(envelope: ReportEnvelope?) {
        guard let envelope else {
            self.environmentRows = DashboardOverview.unknownEnvironmentRows()
            self.counts = DashboardCounts(total: 0, paired: 0, missing: 0, parseFailed: 0)
            self.systemRows = DashboardOverview.unknownSystemRows()
            return
        }

        let env = envelope.environment
        let elleKitComponents = [env.ellekitImplementation, env.ellekitVersion]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        let elleKitValue = elleKitComponents.isEmpty
            ? "Unknown"
            : elleKitComponents.joined(separator: " ")

        self.environmentRows = [
            DashboardInfoRow(
                title: "Jailbreak",
                value: ReportLabels.jailbreakType(env.jailbreakType),
                status: env.jailbreakType == .unknown
                    ? DisplayStatus(kind: .unknown, text: "Unknown")
                    : DisplayStatus(kind: .success, text: ReportLabels.jailbreakType(env.jailbreakType))
            ),
            DashboardInfoRow(title: "ElleKit", value: elleKitValue),
            DashboardInfoRow(title: "Profile", value: env.profileId)
        ]

        let plugins = envelope.plugins
        let paired = plugins.filter { $0.pairing == .paired }.count
        let missing = plugins.count - paired
        let parseFailed = plugins.filter {
            Self.parseFailureStatuses.contains($0.validation.status)
        }.count

        self.counts = DashboardCounts(
            total: plugins.count,
            paired: paired,
            missing: missing,
            parseFailed: parseFailed
        )

        let jbroot = env.jbroot
            ?? env.pathEvidence.jbrootCandidates.first
        let tweakInject = env.pathEvidence.tweakInject

        self.systemRows = [
            DashboardInfoRow(
                title: "JBROOT",
                value: jbroot ?? "Unknown",
                status: jbroot == nil
                    ? DisplayStatus(kind: .unknown, text: "Unknown")
                    : DisplayStatus(kind: .success, text: "Confirmed")
            ),
            DashboardInfoRow(
                title: "TweakInject",
                value: tweakInject ?? "Unknown",
                status: tweakInject == nil
                    ? DisplayStatus(kind: .unknown, text: "Unknown")
                    : DisplayStatus(kind: .success, text: "Accessible")
            ),
            DashboardInfoRow(
                title: "Permission",
                value: "Undetermined",
                status: DisplayStatus(kind: .unknown, text: "2.4 probe")
            )
        ]
    }

    private static func unknownEnvironmentRows() -> [DashboardInfoRow] {
        [
            DashboardInfoRow(title: "Jailbreak", value: "Unknown",
                             status: DisplayStatus(kind: .unknown, text: "Unknown")),
            DashboardInfoRow(title: "ElleKit", value: "Unknown"),
            DashboardInfoRow(title: "Profile", value: "Unknown")
        ]
    }

    private static func unknownSystemRows() -> [DashboardInfoRow] {
        [
            DashboardInfoRow(title: "JBROOT", value: "Unknown",
                             status: DisplayStatus(kind: .unknown, text: "Unknown")),
            DashboardInfoRow(title: "TweakInject", value: "Unknown",
                             status: DisplayStatus(kind: .unknown, text: "Unknown")),
            DashboardInfoRow(title: "Permission", value: "Undetermined",
                             status: DisplayStatus(kind: .unknown, text: "2.4 probe"))
        ]
    }
}
