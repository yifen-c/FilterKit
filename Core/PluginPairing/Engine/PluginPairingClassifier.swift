//
//  PluginPairingClassifier.swift
//  FilterKit Core — 配对归类决策（G-C3，契约冻结 §6）
//
//  决策优先级（契约 PC7 / PC8）：
//  1. 任一侧条目 `entryStatus != .ok` → uncertain：受限关系不能裁决为
//     paired / missing_plist / orphan_plist，候选留置。
//  2. 两侧均可用，但同键存在多 dylib 或多 plist → ambiguous：全候选保留、不取边。
//  3. 两侧均可用且唯一：1+1 paired；1+0 missing_plist；0+1 orphan_plist。
//
//  口径边界：`entryStatus` 与 `readable` 三态位是不同证据；分类只依据
//  `entryStatus`，`readable == nil` 不单独触发 uncertain。`not_found` 属
//  非 ok 受限状态，按 uncertain 留置，不按不存在处理。
//

import Foundation
import Models

/// 单键归类器（纯计算，无状态）。
public struct PluginPairingClassifier {

    public init() {}

    /// 对同一配对键的两侧候选归类。
    public func classify(
        dylibs: [PluginFileEvidence],
        plists: [PluginFileEvidence]
    ) -> PairingCategory {
        if hasRestrictedEntry(dylibs) || hasRestrictedEntry(plists) {
            return .uncertain
        }
        if dylibs.count > 1 || plists.count > 1 {
            return .ambiguous
        }
        if dylibs.count == 1 && plists.count == 1 {
            return .paired
        }
        if dylibs.count == 1 && plists.isEmpty {
            return .missingPlist
        }
        if dylibs.isEmpty && plists.count == 1 {
            return .orphanPlist
        }
        // 两侧均空不应进入索引；兜底为 uncertain，避免落入未定义分组。
        return .uncertain
    }

    /// 条目是否受限（entryStatus 非 ok）。
    private func hasRestrictedEntry(_ files: [PluginFileEvidence]) -> Bool {
        files.contains { $0.entryStatus != .ok }
    }
}
