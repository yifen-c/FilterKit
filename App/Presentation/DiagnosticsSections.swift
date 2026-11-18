//
//  DiagnosticsSections.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  诊断分组模型：环境 / JBROOT / DynamicLibraries / 枚举 / 解析 / Warnings /
//  Unknown Items。分组与计数由 `ReportEnvelope` 只读派生；Warnings 与
//  UnknownItems 完整归集，不裁剪字段。
//

import Foundation
import Models

/// 诊断分区。
public struct DiagnosticsSection: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let rows: [DetailRow]

    public var isEmpty: Bool { rows.isEmpty }

    public init(id: String, title: String, rows: [DetailRow]) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}

public enum DiagnosticsMapper {

    private static let parseOrder: [String] = [
        "valid", "parse_failed", "type_mismatch", "read_failed", "not_parsed"
    ]

    public static func sections(_ envelope: ReportEnvelope?) -> [DiagnosticsSection] {
        guard let envelope else {
            return [
                DiagnosticsSection(id: "environment", title: "Environment", rows: [
                    DetailRow(label: "Environment", value: "Unknown")
                ]),
                DiagnosticsSection(id: "jbroot", title: "JBROOT", rows: []),
                DiagnosticsSection(id: "dynamic-libraries", title: "Dynamic Libraries", rows: []),
                DiagnosticsSection(id: "enumeration", title: "Enumeration", rows: []),
                DiagnosticsSection(id: "parsing", title: "Parsing", rows: []),
                DiagnosticsSection(id: "warnings", title: "Warnings", rows: []),
                DiagnosticsSection(id: "unknown-items", title: "Unknown Items", rows: [])
            ]
        }

        let env = envelope.environment
        let plugins = envelope.plugins

        // Environment
        let environmentRows: [DetailRow] = [
            DetailRow(label: "Jailbreak Type",
                      value: ReportLabels.jailbreakType(env.jailbreakType)),
            DetailRow(label: "ElleKit Implementation",
                      value: env.ellekitImplementation ?? "Unknown"),
            DetailRow(label: "ElleKit Version",
                      value: env.ellekitVersion ?? "Unknown"),
            DetailRow(label: "Profile", value: env.profileId),
            DetailRow(label: "iOS Version", value: env.iosVersion ?? "Unknown"),
            DetailRow(label: "Architecture", value: env.architecture ?? "Unknown"),
            DetailRow(label: "Evidence Level",
                      value: ReportLabels.evidenceLevel(env.evidenceLevel))
        ]

        // JBROOT
        var jbrootRows: [DetailRow] = [
            DetailRow(label: "JBROOT", value: env.jbroot ?? "Unknown")
        ]
        for candidate in env.pathEvidence.jbrootCandidateDetails {
            let detail = [candidate.source, candidate.route, candidate.status ?? "unknown"]
                .joined(separator: " · ")
            jbrootRows.append(DetailRow(label: candidate.path, value: detail))
        }
        if env.pathEvidence.jbrootCandidateDetails.isEmpty,
           let first = env.pathEvidence.jbrootCandidates.first {
            jbrootRows.append(DetailRow(label: "Candidate", value: first))
        }

        // Dynamic Libraries
        let libraryRows: [DetailRow] = [
            DetailRow(label: "Dynamic Libraries",
                      value: env.pathEvidence.dynamicLibraries ?? "Unknown"),
            DetailRow(label: "TweakInject", value: env.pathEvidence.tweakInject ?? "Unknown")
        ]

        // Enumeration
        let paired = plugins.filter { $0.pairing == .paired }.count
        let enumerationRows: [DetailRow] = [
            DetailRow(label: "Plugins Found", value: "\(plugins.count)"),
            DetailRow(label: "Paired", value: "\(paired)"),
            DetailRow(label: "Missing / Orphan", value: "\(plugins.count - paired)")
        ]

        // Parsing
        var statusCounts: [String: Int] = [:]
        for plugin in plugins {
            statusCounts[plugin.validation.status, default: 0] += 1
        }
        var parsingRows: [DetailRow] = parseOrder.compactMap { status in
            guard let count = statusCounts[status], count > 0 else { return nil }
            let label = ReportLabels.parseStatus(status).text
            return DetailRow(label: label, value: "\(count)")
        }
        let extraStatuses = statusCounts.keys.filter { !parseOrder.contains($0) }
        for status in extraStatuses.sorted() {
            parsingRows.append(DetailRow(label: status, value: "\(statusCounts[status] ?? 0)"))
        }
        if parsingRows.isEmpty {
            parsingRows.append(DetailRow(label: "Parsing", value: "—"))
        }

        // Warnings
        let warningRows: [DetailRow] = envelope.warnings.map { warning in
            DetailRow(label: warning.code,
                      value: "\(warning.message) · \(warning.sourceStage)")
        }

        // Unknown Items
        let unknownRows: [DetailRow] = envelope.unknownItems.map { item in
            let identity = item.base ?? item.path ?? "Unknown"
            let detail = item.detail.map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            let value = [item.reason, item.sourceStage, detail]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return DetailRow(label: identity, value: value)
        }

        return [
            DiagnosticsSection(id: "environment", title: "Environment", rows: environmentRows),
            DiagnosticsSection(id: "jbroot", title: "JBROOT", rows: jbrootRows),
            DiagnosticsSection(id: "dynamic-libraries", title: "Dynamic Libraries", rows: libraryRows),
            DiagnosticsSection(id: "enumeration", title: "Enumeration", rows: enumerationRows),
            DiagnosticsSection(id: "parsing", title: "Parsing", rows: parsingRows),
            DiagnosticsSection(id: "warnings", title: "Warnings", rows: warningRows),
            DiagnosticsSection(id: "unknown-items", title: "Unknown Items", rows: unknownRows)
        ]
    }
}
