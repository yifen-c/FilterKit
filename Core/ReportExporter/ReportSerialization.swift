//
//  ReportSerialization.swift
//  FilterKit Core — ReportExporter（Stage 2.2-D，D4）
//
//  导出前确定性排序策略。`JSONEncoder.outputFormatting = .sortedKeys` 只保证
//  对象键序；数组元素顺序由本文件显式排序策略确定。排序键与冻结规格
//  §7 排序表一致；同键保持稳定序（Swift 排序稳定）。
//

import Foundation
import Models

/// 报告数组排序策略（纯函数；不修改元素）。
public enum ReportSerialization {
    /// 插件序：pluginID → name → plistPath（回退 dylibPath）。
    public static func sortedPlugins(_ plugins: [Plugin]) -> [Plugin] {
        plugins.sorted { lhs, rhs in
            compare(lhs.pluginID, rhs.pluginID)
                ?? compare(lhs.name, rhs.name)
                ?? compare(lhs.plistPath ?? lhs.dylibPath,
                           rhs.plistPath ?? rhs.dylibPath)
                ?? false
        }
    }

    /// 未知条目序：path（回退 base）→ reason → sourceStage。
    public static func sortedUnknownItems(_ items: [UnknownItem]) -> [UnknownItem] {
        items.sorted { lhs, rhs in
            compare(lhs.path ?? lhs.base, rhs.path ?? rhs.base)
                ?? compare(lhs.reason, rhs.reason)
                ?? compare(lhs.sourceStage, rhs.sourceStage)
                ?? false
        }
    }

    /// 告警序：code → sourceStage → message。
    public static func sortedWarnings(_ warnings: [ReportWarning]) -> [ReportWarning] {
        warnings.sorted { lhs, rhs in
            compare(lhs.code, rhs.code)
                ?? compare(lhs.sourceStage, rhs.sourceStage)
                ?? compare(lhs.message, rhs.message)
                ?? false
        }
    }

    /// 可选字符串比较：相等返回 `nil` 以落到下一排序键；`nil` 排前。
    private static func compare(_ lhs: String?, _ rhs: String?) -> Bool? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        case (nil, _): return true
        case (_, nil): return false
        case let (a?, b?): return a == b ? nil : a < b
        }
    }
}
