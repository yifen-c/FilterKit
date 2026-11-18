//
//  RootlessFilterCodable.swift
//  FilterKit Core — PlistParser Rootless（C3-C2）
//
//  Rootless 路线上游 Codable 输入模型（契约 §4.2，Tweak.swift 口径）。
// 仅三个叶子字段：顶层 `UnloadAfter: Bool?`，Filter 内 `Bundles / Executables: [String]?`。
// `Classes / IsTweakManager / CoreFoundationVersion` 不属于 Rootless 模型，
// 出现即记入 `otherKeys`，不判解码失败；本模型是上游输入载体，不等于公共
// 业务模型 `FilterRule`（映射由 `RootlessFilterMapper` 负责）。
//
// 边界：G-C3-5（`UnloadAfter` 在导出层的归属字段）维持待评审；本批只解码
// 保留在模型内，不写入 `FilterRule`，不新增公共 Models 字段。
//

import Foundation

/// Rootless 整份 plist 根节点 Codable 视图（Core 内部类型，不进公共 Models）。
struct RootlessPlistCodable: Decodable, Equatable {

    /// Filter 字典 Codable 视图。
    struct FilterPayload: Decodable, Equatable {
        var bundles: [String]?
        var executables: [String]?

        enum CodingKeys: String, CodingKey {
            case bundles = "Bundles"
            case executables = "Executables"
        }
    }

    var filter: FilterPayload?
    var unloadAfter: Bool?

    enum CodingKeys: String, CodingKey {
        case filter = "Filter"
        case unloadAfter = "UnloadAfter"
    }
}
