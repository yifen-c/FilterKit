//
//  PluginPairingEngine.swift
//  FilterKit Core — 配对引擎（G-C3，契约冻结 §10）
//
//  纯计算组件：消费一个已确定目录身份的 `PluginInventorySnapshot`，
//  产出 `PluginPairingSnapshot`。不重新扫描目录、不跨目录/跨快照合并、
//  不读取 plist 内容、不装配服务或 Adapter。
//

import Foundation
import Models

/// 配对引擎。
public struct PluginPairingEngine {

    private let indexBuilder: PluginPairingIndexBuilder
    private let classifier: PluginPairingClassifier
    private let snapshotBuilder: PluginPairingSnapshotBuilder

    public init(
        indexBuilder: PluginPairingIndexBuilder = PluginPairingIndexBuilder(),
        classifier: PluginPairingClassifier = PluginPairingClassifier(),
        snapshotBuilder: PluginPairingSnapshotBuilder = PluginPairingSnapshotBuilder()
    ) {
        self.indexBuilder = indexBuilder
        self.classifier = classifier
        self.snapshotBuilder = snapshotBuilder
    }

    /// 对单个库存快照执行文件关联。
    public func pair(inventory: PluginInventorySnapshot) -> PluginPairingSnapshot {
        let records: [PluginPairingRecord]
        if isUnresolved(inventory) {
            // 目录身份未明或枚举失败：不猜测身份、不构建配对记录（对齐 S1-05 route-guard）。
            records = []
        } else {
            let index = indexBuilder.build(from: inventory)
            records = index.keys.map { key in
                let dylibs = index.dylibs[key] ?? []
                let plists = index.plists[key] ?? []
                return makeRecord(key: key, dylibs: dylibs, plists: plists)
            }
        }

        let unknownItems = collectUnknownItems(inventory: inventory)
        return snapshotBuilder.build(
            inventory: inventory,
            records: records,
            unknownItems: unknownItems,
            warnings: inventory.warnings
        )
    }

    /// 目录身份缺失、枚举未决或失败时，配对不可判定。
    private func isUnresolved(_ inventory: PluginInventorySnapshot) -> Bool {
        guard inventory.sourceDirectory != nil else { return true }
        switch inventory.enumeration.status {
        case .unresolved, .enumerationFailed:
            return true
        case .enumerated, .partial:
            return false
        }
    }

    // MARK: - 记录构建

    private func makeRecord(
        key: String,
        dylibs: [PluginFileEvidence],
        plists: [PluginFileEvidence]
    ) -> PluginPairingRecord {
        let category = classifier.classify(dylibs: dylibs, plists: plists)
        let candidates = (dylibs + plists).sorted(by: PluginPairingIndexBuilder.candidateOrder)

        switch category {
        case .paired:
            return PluginPairingRecord(
                category: category,
                pairing: .paired,
                pairingKey: key,
                dylib: dylibs.first,
                plist: plists.first,
                basis: .exactFilenameMatch
            )

        case .missingPlist:
            return PluginPairingRecord(
                category: category,
                pairing: .missingPlist,
                pairingKey: key,
                dylib: dylibs.first,
                basis: .noOppositeCandidate
            )

        case .orphanPlist:
            return PluginPairingRecord(
                category: category,
                pairing: .orphanPlist,
                pairingKey: key,
                plist: plists.first,
                reason: "missing_dylib",
                basis: .noOppositeCandidate
            )

        case .ambiguous:
            return PluginPairingRecord(
                category: category,
                pairingKey: key,
                candidates: candidates,
                basis: .ambiguousMultiCandidate
            )

        case .uncertain:
            let restricted = candidates.first { $0.entryStatus != .ok }
            return PluginPairingRecord(
                category: category,
                pairingKey: key,
                dylib: dylibs.first,
                plist: plists.first,
                candidates: candidates,
                reason: restricted?.entryStatus.rawValue,
                basis: .uncertainAccess
            )
        }
    }

    // MARK: - 不可配对条目归集

    /// 透传 C1 未知条目；C2 仅补登记 dylib/plist 中配对键无效（空键）的条目。
    /// 其他类型（目录/软链/other）已由 C1 归集，不重复登记。
    private func collectUnknownItems(inventory: PluginInventorySnapshot) -> [UnknownItem] {
        var items = inventory.unknownItems
        for item in inventory.items {
            guard item.kind == .dylib || item.kind == .plist else { continue }
            guard PluginPairingKeyBuilder.key(for: item) == nil else { continue }
            items.append(UnknownItem(
                path: item.path,
                base: item.name,
                reason: "empty_pairing_key",
                sourceStage: "stage2.2-c2",
                detail: ["kind": item.kind.rawValue]
            ))
        }
        return items
    }
}
