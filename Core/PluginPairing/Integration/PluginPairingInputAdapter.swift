//
//  PluginPairingInputAdapter.swift
//  FilterKit Core — C1 快照 → 配对输入视图（C2-C 集成契约 §1 / §4）
//
//  只做类型过滤与字段原样搬运：不重新扫描、不重新读取、不重算哈希、
//  不补默认三态位、不改写 entryStatus / 路径 / 文件名。
//

import Foundation
import Models

/// 配对输入适配器（纯函数，无状态）。
public enum PluginPairingInputAdapter {

    /// 由 C1 库存快照构造配对输入视图；非候选类型保留在 C1 快照与 unknownItems 中。
    public static func makeInput(from inventory: PluginInventorySnapshot) -> PluginPairingInput {
        let files = inventory.items.filter {
            $0.kind == .dylib || $0.kind == .plist
        }
        return PluginPairingInput(
            route: inventory.route,
            sourceDirectory: inventory.sourceDirectory,
            enumeration: inventory.enumeration,
            files: files,
            unknownItems: inventory.unknownItems,
            warnings: inventory.warnings
        )
    }
}
