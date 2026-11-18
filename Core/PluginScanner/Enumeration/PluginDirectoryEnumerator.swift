//
//  PluginDirectoryEnumerator.swift
//  FilterKit Core — 插件目录枚举编排（C1 / S1-04）
//
//  串联：上游定位信号 → 条目过滤（非递归）→ 证据构建 → 清单汇总。
//  单层扫描、不跟随软链、单条目异常不中断整轮；不重新实现 B4 路径定位，
//  不读取 `metadata.json`，不访问真实文件系统。
//
//  目录级状态判定优先级（对齐 `enumerator.js enumerate`，顺序不可调换）：
//  1. 上游目录未定位 → `unresolved`（`directory_unresolved`）；
//  2. 目录不可枚举 → `enumeration_failed`（`enumeration_failed`）；
//  3. 部分条目状态非 `ok` → `partial`（`partial_enumeration`）；
//  4. 完整读取 → `enumerated`。空目录不判定为失败。
//
//  本编排器不产出配对、解析、归属或加载结论；C2 配对 / C3 解析不在本层。
//

import Foundation
import Models

/// 插件目录枚举入口：输入信号快照 → 清单快照。
public final class PluginDirectoryEnumerator {

    private let evidenceBuilder: PluginFileEvidenceBuilder
    private let inventoryBuilder: PluginInventoryBuilder
    private let sourceStage: String

    public init(evidenceBuilder: PluginFileEvidenceBuilder = PluginFileEvidenceBuilder(),
                inventoryBuilder: PluginInventoryBuilder = PluginInventoryBuilder(),
                sourceStage: String = "S1-04") {
        self.evidenceBuilder = evidenceBuilder
        self.inventoryBuilder = inventoryBuilder
        self.sourceStage = sourceStage
    }

    /// 对输入信号快照执行单层枚举。
    public func enumerate(_ signal: PluginInventoryFixtureSignal) -> PluginInventorySnapshot {
        let route = signal.upstream?.route ?? "unknown"
        let sourceDirectory = signal.upstream?.sourceDirectory

        // 1. 上游目录未定位：不猜测路径，不回退扫描其他根。
        if sourceDirectory == nil {
            return inventoryBuilder.assemble(
                route: route,
                sourceDirectory: nil,
                entries: [],
                status: .unresolved,
                enumerationWarnings: ["directory_unresolved"]
            )
        }

        // 2. 目录不可枚举：保留失败状态与告警，不伪造成功清单。
        if signal.fs?.enumerable == false {
            return inventoryBuilder.assemble(
                route: route,
                sourceDirectory: sourceDirectory,
                entries: [],
                status: .enumerationFailed,
                enumerationWarnings: ["enumeration_failed"]
            )
        }

        // 3. 单层非递归：嵌套条目不进入清单。
        let rawEntries = signal.fs?.entries ?? []
        let topLevel = rawEntries.filter { $0.nested != true }
        let entries = topLevel.map {
            evidenceBuilder.build(sourceDirectory: sourceDirectory, entry: $0)
        }

        let partial = entries.contains { $0.entryStatus != .ok }
        let status: EnumerationStatus = partial ? .partial : .enumerated
        let enumerationWarnings: [String] = partial ? ["partial_enumeration"] : []

        return inventoryBuilder.assemble(
            route: route,
            sourceDirectory: sourceDirectory,
            entries: entries,
            status: status,
            enumerationWarnings: enumerationWarnings
        )
    }
}
