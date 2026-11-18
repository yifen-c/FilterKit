//
//  PluginPairingSnapshotBuilder.swift
//  FilterKit Core — 配对快照组装（G-C3，契约冻结 §4 / §7）
//
//  职责：按五桶记录计数、解析目录级状态、归集 unknownItems 与 warnings、
//  产出 `PluginPairingSnapshot`。计数按记录组数，五桶互斥求和等于 records.count。
//

import Foundation
import Models

/// 配对快照组装器（纯计算）。
public struct PluginPairingSnapshotBuilder {

    public init() {}

    /// 组装最终配对快照。
    public func build(
        inventory: PluginInventorySnapshot,
        records: [PluginPairingRecord],
        unknownItems: [UnknownItem],
        warnings: [ReportWarning]
    ) -> PluginPairingSnapshot {
        let counts = PluginPairingCounts(
            paired: records.filter { $0.category == .paired }.count,
            missingPlist: records.filter { $0.category == .missingPlist }.count,
            orphanPlist: records.filter { $0.category == .orphanPlist }.count,
            ambiguous: records.filter { $0.category == .ambiguous }.count,
            uncertain: records.filter { $0.category == .uncertain }.count
        )

        let status = resolveStatus(inventory: inventory, records: records)
        let mergedWarnings = mergeWarnings(base: warnings, status: status)

        return PluginPairingSnapshot(
            route: inventory.route,
            sourceDirectory: inventory.sourceDirectory,
            status: status,
            records: records,
            unknownItems: unknownItems,
            counts: counts,
            warnings: mergedWarnings
        )
    }

    // MARK: - 目录级状态

    /// 目录状态优先级：身份缺失/枚举未决 → unresolved；枚举失败 →
    /// enumeration_failed；存在不确定条目 → partial；否则 enumerated。
    private func resolveStatus(
        inventory: PluginInventorySnapshot,
        records: [PluginPairingRecord]
    ) -> PairingStatus {
        if inventory.sourceDirectory == nil {
            return .unresolved
        }
        switch inventory.enumeration.status {
        case .unresolved:
            return .unresolved
        case .enumerationFailed:
            return .enumerationFailed
        case .partial:
            return .partial
        case .enumerated:
            break
        }
        if records.contains(where: { $0.category == .uncertain }) {
            return .partial
        }
        return .enumerated
    }

    // MARK: - 告警归集

    private func mergeWarnings(
        base: [ReportWarning],
        status: PairingStatus
    ) -> [ReportWarning] {
        var merged = base
        switch status {
        case .unresolved, .enumerationFailed:
            merged.append(ReportWarning(
                code: "inventory_unresolved",
                message: "目录身份或枚举结果未决，配对不可判定",
                sourceStage: "stage2.2-c2"
            ))
        case .partial:
            merged.append(ReportWarning(
                code: "partial_pairing",
                message: "存在不确定配对条目，结果为部分配对",
                sourceStage: "stage2.2-c2"
            ))
        case .enumerated:
            break
        }
        return merged
    }
}
