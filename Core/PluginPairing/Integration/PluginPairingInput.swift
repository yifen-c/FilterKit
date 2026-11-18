//
//  PluginPairingInput.swift
//  FilterKit Core — C1 → C2 配对输入视图（C2-C 集成契约 §1）
//
//  仅为配对所需的 dylib/plist 过滤视图；不复制改写证据字段，不重扫目录。
//  原始 `PluginInventorySnapshot` 保持完整，本结构不冒充完整 C1 Inventory。
//

import Foundation
import Models

/// 配对输入视图（Core 内部集成核对用，不进入公共 Models / ReportEnvelope）。
public struct PluginPairingInput: Equatable {

    /// 路线标识（C1 原值透传，桥接层不改写）。
    public var route: String?

    /// 枚举根目录（C1 原值透传）。
    public var sourceDirectory: String?

    /// C1 目录级枚举元数据（状态传递依据，不与 C2 状态共享枚举类型）。
    public var enumeration: EnumerationBlock

    /// 配对候选证据（仅 dylib/plist；字段原样保留）。
    public var files: [PluginFileEvidence]

    /// C1 归集的未知条目（原样透传）。
    public var unknownItems: [UnknownItem]

    /// C1 清单级告警（原样透传）。
    public var warnings: [ReportWarning]

    public init(route: String?,
                 sourceDirectory: String?,
                 enumeration: EnumerationBlock,
                 files: [PluginFileEvidence],
                 unknownItems: [UnknownItem],
                 warnings: [ReportWarning]) {
        self.route = route
        self.sourceDirectory = sourceDirectory
        self.enumeration = enumeration
        self.files = files
        self.unknownItems = unknownItems
        self.warnings = warnings
    }
}
