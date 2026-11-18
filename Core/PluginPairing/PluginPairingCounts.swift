//
//  PluginPairingCounts.swift
//  FilterKit Core — 配对五桶计数（G-C3，契约冻结 §4.4）
//
//  计数按记录组数统计，不按文件数量；五桶与 `records` 一一对应，
//  互斥不重不漏：`paired + missingPlist + orphanPlist + ambiguous +
//  uncertain == records.count`。`unresolved` 是目录级状态，不单列条目桶。
//

import Foundation

/// 配对五桶计数。
public struct PluginPairingCounts: Codable, Equatable {
    public var paired: Int
    public var missingPlist: Int
    public var orphanPlist: Int
    public var ambiguous: Int
    public var uncertain: Int

    public init(paired: Int = 0,
                missingPlist: Int = 0,
                orphanPlist: Int = 0,
                ambiguous: Int = 0,
                uncertain: Int = 0) {
        self.paired = paired
        self.missingPlist = missingPlist
        self.orphanPlist = orphanPlist
        self.ambiguous = ambiguous
        self.uncertain = uncertain
    }

    /// 五桶计数之和（互斥记录组数）。
    public var total: Int {
        paired + missingPlist + orphanPlist + ambiguous + uncertain
    }

    private enum CodingKeys: String, CodingKey {
        case paired
        case missingPlist = "missing_plist"
        case orphanPlist = "orphan_plist"
        case ambiguous
        case uncertain
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paired = try c.decodeIfPresent(Int.self, forKey: .paired) ?? 0
        missingPlist = try c.decodeIfPresent(Int.self, forKey: .missingPlist) ?? 0
        orphanPlist = try c.decodeIfPresent(Int.self, forKey: .orphanPlist) ?? 0
        ambiguous = try c.decodeIfPresent(Int.self, forKey: .ambiguous) ?? 0
        uncertain = try c.decodeIfPresent(Int.self, forKey: .uncertain) ?? 0
    }
}
