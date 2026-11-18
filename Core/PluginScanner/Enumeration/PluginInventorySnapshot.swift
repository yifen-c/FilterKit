//
//  PluginInventorySnapshot.swift
//  FilterKit Core — 枚举清单快照（G-C2，契约冻结 §4.2）
//
//  一次完整目录枚举的中间结果，是 C2 配对的输入边界；首版不进入
//  `ReportEnvelope`，不产出最终 `Plugin`。快照只汇总已有证据，
//  不在本层重新访问文件系统。
//

import Foundation
import Models

/// 目录级枚举元数据。
public struct EnumerationBlock: Codable, Equatable {
    /// 扫描深度：C1 恒为 `false`（单层非递归）。
    public var recursive: Bool
    /// 目录级四态。
    public var status: EnumerationStatus
    /// 目录级告警码（`partial_enumeration` / `enumeration_failed` / `directory_unresolved`）。
    public var warnings: [String]

    public init(recursive: Bool = false,
                status: EnumerationStatus = .enumerated,
                warnings: [String] = []) {
        self.recursive = recursive
        self.status = status
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey { case recursive, status, warnings }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recursive = try c.decodeIfPresent(Bool.self, forKey: .recursive) ?? false
        status = try c.decodeIfPresent(EnumerationStatus.self, forKey: .status) ?? .enumerated
        warnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

/// 插件目录枚举清单快照（Core 中间层）。
public struct PluginInventorySnapshot: Codable, Equatable {
    /// 路线标识（开放字符串原样保留；未知不套用任一开放路线规则）。
    public var route: String?
    /// 枚举根目录；未定位为 `nil`。
    public var sourceDirectory: String?
    /// 目录级枚举元数据。
    public var enumeration: EnumerationBlock
    /// 全部顶层条目（含受限、隐藏、软链、其他类），按文件名字母序确定性排序。
    public var items: [PluginFileEvidence]
    /// 目录/软链/其他类条目归集；不并入 dylib/plist 清单。
    public var unknownItems: [UnknownItem]
    /// 五类计数，与 `items[].kind` 一一对应。
    public var counts: PluginKindCounts
    /// 清单级统一告警载体。
    public var warnings: [ReportWarning]

    public init(route: String? = nil,
                sourceDirectory: String? = nil,
                enumeration: EnumerationBlock = EnumerationBlock(),
                items: [PluginFileEvidence] = [],
                unknownItems: [UnknownItem] = [],
                counts: PluginKindCounts = PluginKindCounts(),
                warnings: [ReportWarning] = []) {
        self.route = route
        self.sourceDirectory = sourceDirectory
        self.enumeration = enumeration
        self.items = items
        self.unknownItems = unknownItems
        self.counts = counts
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case route, sourceDirectory, enumeration, items, unknownItems, counts, warnings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        route = try c.decodeIfPresent(String.self, forKey: .route)
        sourceDirectory = try c.decodeIfPresent(String.self, forKey: .sourceDirectory)
        enumeration = try c.decodeIfPresent(EnumerationBlock.self, forKey: .enumeration) ?? EnumerationBlock()
        items = try c.decodeIfPresent([PluginFileEvidence].self, forKey: .items) ?? []
        unknownItems = try c.decodeIfPresent([UnknownItem].self, forKey: .unknownItems) ?? []
        counts = try c.decodeIfPresent(PluginKindCounts.self, forKey: .counts) ?? PluginKindCounts()
        warnings = try c.decodeIfPresent([ReportWarning].self, forKey: .warnings) ?? []
    }
}
