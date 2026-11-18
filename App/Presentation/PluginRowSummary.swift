//
//  PluginRowSummary.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  列表行摘要 + 关键词搜索 + 分段筛选。映射纯由 `Plugin` 派生；不含扫描、
//  配对引擎或解析器调用。ISSUES 口径：配对未成功、未配置或解析状态非 valid。
//

import Foundation
import Models

/// 列表分段。
public enum PluginListSegment: String, CaseIterable, Identifiable {
    case all
    case paired
    case issues

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "ALL"
        case .paired: "PAIRED"
        case .issues: "ISSUES"
        }
    }
}

/// 列表行展示摘要。
public struct PluginRowSummary: Identifiable, Equatable {
    public let pluginID: String
    public let name: String
    public let dylibName: String?
    public let version: String?
    public let installed: DisplayStatus
    public let configured: DisplayStatus
    public let loaded: DisplayStatus
    public let pairing: String
    public let paired: Bool
    public let issues: Bool

    public var id: String { pluginID }

    public init(pluginID: String,
                name: String,
                dylibName: String?,
                version: String?,
                installed: DisplayStatus,
                configured: DisplayStatus,
                loaded: DisplayStatus,
                pairing: String,
                paired: Bool,
                issues: Bool) {
        self.pluginID = pluginID
        self.name = name
        self.dylibName = dylibName
        self.version = version
        self.installed = installed
        self.configured = configured
        self.loaded = loaded
        self.pairing = pairing
        self.paired = paired
        self.issues = issues
    }
}

public enum PluginListMapper {

    /// 条目是否进入 ISSUES 分段。
    public static func hasIssues(_ plugin: Plugin) -> Bool {
        plugin.pairing != .paired
            || plugin.configured == false
            || plugin.validation.status != "valid"
    }

    public static func summarize(_ plugins: [Plugin]) -> [PluginRowSummary] {
        plugins.map { plugin in
            PluginRowSummary(
                pluginID: plugin.pluginID,
                name: plugin.name,
                dylibName: ReportLabels.baseName(of: plugin.dylibPath),
                version: plugin.version,
                installed: ReportLabels.installed(plugin.installed),
                configured: ReportLabels.configured(plugin.configured),
                loaded: ReportLabels.loaded(plugin.loaded),
                pairing: ReportLabels.pairing(plugin.pairing),
                paired: plugin.pairing == .paired,
                issues: hasIssues(plugin)
            )
        }
    }

    /// 关键词命中 name 或 pluginID（大小写不敏感）；空关键词返回全量。
    public static func search(_ summaries: [PluginRowSummary], keyword: String) -> [PluginRowSummary] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return summaries }
        return summaries.filter { summary in
            summary.name.localizedCaseInsensitiveContains(trimmed)
                || summary.pluginID.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public static func filter(_ summaries: [PluginRowSummary], segment: PluginListSegment) -> [PluginRowSummary] {
        switch segment {
        case .all:
            return summaries
        case .paired:
            return summaries.filter { $0.paired }
        case .issues:
            return summaries.filter { $0.issues }
        }
    }
}
