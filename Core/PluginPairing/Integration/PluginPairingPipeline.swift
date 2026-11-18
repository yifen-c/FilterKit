//
//  PluginPairingPipeline.swift
//  FilterKit Core — C1 → C2 配对编排（C2-C 集成契约 §1）
//
//  纯编排组件：输入适配视图 → C2-B 冻结引擎 → 配对快照。本层不新增配对
//  算法、不重扫目录、不读 plist 内容、不装配服务或 Adapter；原始快照
//  原样传入引擎，执行前后不被改写。
//

import Foundation
import Models

/// C1 枚举清单 → C2 配对快照编排入口（Core 内部组合根；离线快照注入）。
public final class PluginPairingPipeline {

    private let engine: PluginPairingEngine

    public init(engine: PluginPairingEngine = PluginPairingEngine()) {
        self.engine = engine
    }

    /// 执行配对编排。
    /// - Parameter inventory: C1 库存快照（只读，不被改写）。
    /// - Returns: C2 配对快照。
    public func execute(inventory: PluginInventorySnapshot) -> PluginPairingSnapshot {
        // 适配视图仅供集成核对；配对输入仍以原始快照为准，避免过滤视图丢归集。
        _ = PluginPairingInputAdapter.makeInput(from: inventory)
        return engine.pair(inventory: inventory)
    }
}
