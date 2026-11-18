//
//  PluginPairingIndexBuilder.swift
//  FilterKit Core — 配对索引构建（G-C3，契约冻结 §5.2）
//
//  仅消费 C1 快照内已有条目；不重新扫描目录、不跨目录/跨快照合并。
//  键无效条目不进入索引（由 Engine 归集到 unknownItems / uncertain）。
//

import Foundation
import Models

/// 由 `PluginInventorySnapshot` 构建配对索引。
public struct PluginPairingIndexBuilder {

    public init() {}

    /// 构建同目录作用域内的 dylib/plist 候选索引。
    public func build(from inventory: PluginInventorySnapshot) -> PluginPairingIndex {
        var dylibs: [String: [PluginFileEvidence]] = [:]
        var plists: [String: [PluginFileEvidence]] = [:]

        for item in inventory.items {
            guard let key = PluginPairingKeyBuilder.key(for: item) else { continue }
            switch item.kind {
            case .dylib:
                dylibs[key, default: []].append(item)
            case .plist:
                plists[key, default: []].append(item)
            case .directory, .symlink, .other:
                continue
            }
        }

        for key in dylibs.keys {
            dylibs[key]?.sort(by: Self.candidateOrder)
        }
        for key in plists.keys {
            plists[key]?.sort(by: Self.candidateOrder)
        }

        return PluginPairingIndex(dylibs: dylibs, plists: plists)
    }

    /// 候选确定性顺序：路径字母序；路径缺失时回退文件名。
    static func candidateOrder(_ lhs: PluginFileEvidence, _ rhs: PluginFileEvidence) -> Bool {
        let l = lhs.path ?? lhs.name
        let r = rhs.path ?? rhs.name
        return l < r
    }
}
