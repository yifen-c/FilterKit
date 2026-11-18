//
//  PluginInventoryBuilder.swift
//  FilterKit Core — 清单汇总构建（C1 / S1-04）
//
//  只汇总已有条目证据：确定性排序 → 五类计数 → 未知条目归集 → 目录级状态与
//  告警；不在本层重新访问文件系统，不做配对或解析。
//

import Foundation
import Models

/// 清单快照汇总构建器。
public struct PluginInventoryBuilder {

    private let sourceStage: String

    public init(sourceStage: String = "S1-04") {
        self.sourceStage = sourceStage
    }

    /// 由条目证据列表组装清单快照。
    public func assemble(route: String?,
                         sourceDirectory: String?,
                         entries: [PluginFileEvidence],
                         status: EnumerationStatus,
                         enumerationWarnings: [String]) -> PluginInventorySnapshot {
        // alphasort：按文件名字母序（大小写敏感），保证清单确定性。
        let items = entries.sorted { $0.name < $1.name }

        var counts = PluginKindCounts()
        for item in items {
            counts.add(item.kind)
        }

        let unknownItems = items
            .filter { $0.kind != .dylib && $0.kind != .plist }
            .map { item in
                UnknownItem(path: item.path,
                            base: item.name,
                            reason: item.kind.rawValue,
                            sourceStage: sourceStage,
                            detail: ["name": item.name])
            }

        let warnings = enumerationWarnings.map { code in
            ReportWarning(code: code, message: code, sourceStage: sourceStage)
        }

        return PluginInventorySnapshot(
            route: route,
            sourceDirectory: sourceDirectory,
            enumeration: EnumerationBlock(recursive: false, status: status, warnings: enumerationWarnings),
            items: items,
            unknownItems: unknownItems,
            counts: counts,
            warnings: warnings
        )
    }
}
