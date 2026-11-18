//
//  PluginDetailModel.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  详情分区模型：状态 / 文件 / 配对 / Filter 规则 / 归属 / 证据，全部由
//  `Plugin` 只读派生。路径缺失展示 Unknown，不拼默认路径；空数组展示空态；
//  归属 Unknown 不暗示管理权限。详情页只读，无编辑入口。
//

import Foundation
import Models

/// 详情单行（标签 + 值 + 可选分级）。
public struct DetailRow: Equatable, Identifiable {
    public let label: String
    public let value: String
    public let status: DisplayStatus?

    public var id: String { label }

    public init(label: String, value: String, status: DisplayStatus? = nil) {
        self.label = label
        self.value = value
        self.status = status
    }
}

public struct PluginDetailModel: Equatable {
    public let pluginID: String
    public let name: String
    public let version: String?
    public let statusRows: [DetailRow]
    public let fileRows: [DetailRow]
    public let pairingRows: [DetailRow]
    public let filterRows: [DetailRow]
    public let ownershipRows: [DetailRow]
    public let evidenceRows: [DetailRow]

    public init(plugin: Plugin) {
        self.pluginID = plugin.pluginID
        self.name = plugin.name
        self.version = plugin.version

        // MARK: PLUGIN STATUS
        let validation = ReportLabels.parseStatus(plugin.validation.status)
        self.statusRows = [
            DetailRow(label: "Installed",
                       value: ReportLabels.installed(plugin.installed).text,
                       status: ReportLabels.installed(plugin.installed)),
            DetailRow(label: "Configured",
                       value: ReportLabels.configured(plugin.configured).text,
                       status: ReportLabels.configured(plugin.configured)),
            DetailRow(label: "Loaded",
                       value: ReportLabels.loaded(plugin.loaded).text,
                       status: ReportLabels.loaded(plugin.loaded)),
            DetailRow(label: "Validation", value: validation.text, status: validation),
            DetailRow(label: "Permission", value: "Undetermined",
                       status: DisplayStatus(kind: .unknown, text: "2.4 probe"))
        ]

        // MARK: FILES
        self.fileRows = [
            DetailRow(label: "Dynamic Library", value: plugin.dylibPath ?? "Unknown"),
            DetailRow(label: "Filter Plist", value: plugin.plistPath ?? "Unknown")
        ]

        // MARK: PAIRING
        self.pairingRows = [
            DetailRow(label: "Pairing", value: ReportLabels.pairing(plugin.pairing)),
            DetailRow(label: "Plugin ID", value: plugin.pluginID)
        ]

        // MARK: FILTER RULES
        let filter = plugin.filter
        var filterRows = [
            DetailRow(label: "Bundles", value: DetailRow.joinedOrDash(filter?.bundles ?? [])),
            DetailRow(label: "Executables", value: DetailRow.joinedOrDash(filter?.executables ?? [])),
            DetailRow(label: "Classes", value: DetailRow.joinedOrDash(filter?.classes ?? [])),
            DetailRow(label: "Other Keys", value: DetailRow.joinedOrDash(filter?.otherKeys ?? []))
        ]
        if let cf = filter?.coreFoundationVersion {
            filterRows.append(DetailRow(label: "CoreFoundation",
                                        value: DetailRow.coreFoundationText(cf)))
        }
        self.filterRows = filterRows

        // MARK: OWNERSHIP
        let ownership = plugin.ownership
        var ownershipRows = [
            DetailRow(label: "Source", value: ReportLabels.source(ownership.sourceType)),
            DetailRow(label: "Package", value: ownership.packageID ?? "Unknown"),
            DetailRow(label: "Confidence", value: ReportLabels.confidence(ownership.confidence)),
            DetailRow(label: "Writable Policy", value: ReportLabels.writablePolicy(ownership.writablePolicy))
        ]
        if let details = plugin.ownershipDetails {
            if let fileOwnership = details.fileOwnership, !fileOwnership.isEmpty {
                ownershipRows.append(DetailRow(label: "File Ownership", value: fileOwnership))
            }
            if let markers = details.markers, !markers.isEmpty {
                ownershipRows.append(DetailRow(label: "Markers", value: markers))
            }
            ownershipRows.append(DetailRow(label: "Conflicts",
                                           value: DetailRow.joinedOrDash(details.conflicts)))
            ownershipRows.append(DetailRow(label: "Notes",
                                           value: DetailRow.joinedOrDash(details.notes)))
            if let packageVersion = details.packageVersion, !packageVersion.isEmpty {
                ownershipRows.append(DetailRow(label: "Package Version", value: packageVersion))
            }
            if let architecture = details.architecture, !architecture.isEmpty {
                ownershipRows.append(DetailRow(label: "Architecture", value: architecture))
            }
        }
        self.ownershipRows = ownershipRows

        // MARK: EVIDENCE
        var evidenceRows = [
            DetailRow(label: "Source Stages",
                      value: DetailRow.joinedOrDash(plugin.evidence.sourceStages)),
            DetailRow(label: "Evidence Type", value: plugin.evidence.evidenceType),
            DetailRow(label: "Evidence Level",
                      value: ReportLabels.evidenceLevel(plugin.evidence.evidenceLevel))
        ]
        if !plugin.validation.warnings.isEmpty {
            evidenceRows.append(DetailRow(label: "Warnings",
                                          value: DetailRow.joinedOrDash(plugin.validation.warnings)))
        }
        if !plugin.validation.skippedFields.isEmpty {
            evidenceRows.append(DetailRow(label: "Skipped Fields",
                                          value: DetailRow.joinedOrDash(plugin.validation.skippedFields)))
        }
        self.evidenceRows = evidenceRows
    }
}

extension DetailRow {
    static func joinedOrDash(_ values: [String]) -> String {
        let joined = values.filter { !$0.isEmpty }.joined(separator: ", ")
        return joined.isEmpty ? "—" : joined
    }

    static func coreFoundationText(_ cf: CoreFoundationVersion) -> String {
        switch cf.mode {
        case .max:
            return cf.max.map { "max \($0)" } ?? "max"
        case .range:
            let min = cf.min.map(String.init) ?? "?"
            let max = cf.max.map(String.init) ?? "?"
            return "range \(min)…\(max)"
        }
    }
}
