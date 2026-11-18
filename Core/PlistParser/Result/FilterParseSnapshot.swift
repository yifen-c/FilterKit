//
//  FilterParseSnapshot.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B，契约 §5.6）
//
//  双路线统一解析快照。`parsed` 只承载进入解析管线的条目（含各失败态）；
//  非 paired、未知路线等不具备解析条件的条目归集到 `notParsed`。快照为
//  只读汇总：不回写上游配对快照、记录或夹具。
//

import Foundation
import Models

/// 解析快照（Core 中间层；不提升为公共 Models 类型）。
public struct FilterParseSnapshot: Codable, Equatable {
    /// 上游路线原值透传（基线词汇，可能为 nil）。
    public var route: String?
    /// 上游目录原值透传。
    public var sourceDirectory: String?
    /// 目录级状态：`enumerated / partial / unresolved`。
    public var status: String
    /// 进入解析管线的条目（按上游记录稳定序）。
    public var parsed: [FilterParseResult]
    /// 未进入解析管线的条目归集（非 paired / 未知路线 / 上游 unknownItems）。
    public var notParsed: [UnknownItem]
    /// 五桶计数。
    public var counts: FilterParseCounts
    /// 目录级告警（上游告警保留，按 code 去重）。
    public var warnings: [ReportWarning]

    public init(route: String?,
                sourceDirectory: String?,
                status: String,
                parsed: [FilterParseResult],
                notParsed: [UnknownItem],
                counts: FilterParseCounts,
                warnings: [ReportWarning]) {
        self.route = route
        self.sourceDirectory = sourceDirectory
        self.status = status
        self.parsed = parsed
        self.notParsed = notParsed
        self.counts = counts
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case route
        case sourceDirectory
        case status
        case parsed
        case notParsed
        case counts
        case warnings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        route = try c.decodeIfPresent(String.self, forKey: .route)
        sourceDirectory = try c.decodeIfPresent(String.self, forKey: .sourceDirectory)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "unresolved"
        parsed = try c.decodeIfPresent([FilterParseResult].self, forKey: .parsed) ?? []
        notParsed = try c.decodeIfPresent([UnknownItem].self, forKey: .notParsed) ?? []
        counts = try c.decodeIfPresent(FilterParseCounts.self, forKey: .counts) ?? FilterParseCounts()
        warnings = try c.decodeIfPresent([ReportWarning].self, forKey: .warnings) ?? []
    }
}
