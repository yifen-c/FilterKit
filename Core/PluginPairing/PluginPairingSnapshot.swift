//
//  PluginPairingSnapshot.swift
//  FilterKit Core — 配对清单快照（G-C3，契约冻结 §4.5）
//
//  一次完整配对任务的中间结果，是 C3 解析的输入边界之一；首版不进入
//  `ReportEnvelope`，不组装最终 `Plugin`。快照只汇总配对记录与既有
//  归集条目，不在本层重新访问文件系统或读取 plist 内容。
//

import Foundation
import Models

/// 插件目录配对快照（Core 中间层）。
public struct PluginPairingSnapshot: Codable, Equatable {
    /// 路线标识（开放字符串原样保留；未知不套用任一开放路线规则）。
    public var route: String?
    /// 配对根目录；未定位为 `nil`。
    public var sourceDirectory: String?
    /// 目录级配对状态。
    public var status: PairingStatus
    /// 全部配对记录（按配对键/路径字母序确定性排序）。
    public var records: [PluginPairingRecord]
    /// 非候选、空键与 C1 透传归集条目；歧义/不确定明细以 `records` 为准。
    public var unknownItems: [UnknownItem]
    /// 五桶计数，与 `records[].category` 一一对应。
    public var counts: PluginPairingCounts
    /// 快照级统一告警载体。
    public var warnings: [ReportWarning]

    public init(route: String? = nil,
                sourceDirectory: String? = nil,
                status: PairingStatus = .enumerated,
                records: [PluginPairingRecord] = [],
                unknownItems: [UnknownItem] = [],
                counts: PluginPairingCounts = PluginPairingCounts(),
                warnings: [ReportWarning] = []) {
        self.route = route
        self.sourceDirectory = sourceDirectory
        self.status = status
        self.records = records
        self.unknownItems = unknownItems
        self.counts = counts
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case route, sourceDirectory, status, records, unknownItems, counts, warnings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        route = try c.decodeIfPresent(String.self, forKey: .route)
        sourceDirectory = try c.decodeIfPresent(String.self, forKey: .sourceDirectory)
        status = try c.decodeIfPresent(PairingStatus.self, forKey: .status) ?? .enumerated
        records = try c.decodeIfPresent([PluginPairingRecord].self, forKey: .records) ?? []
        unknownItems = try c.decodeIfPresent([UnknownItem].self, forKey: .unknownItems) ?? []
        counts = try c.decodeIfPresent(PluginPairingCounts.self, forKey: .counts) ?? PluginPairingCounts()
        warnings = try c.decodeIfPresent([ReportWarning].self, forKey: .warnings) ?? []
    }
}
