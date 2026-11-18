//
//  FilterParseRoute.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B）
//
//  Engine 内部路线归一类型。唯一事实来源是 `PluginPairingSnapshot.route`
// （B1 环境识别经 B5 桥接原样透传）；本类型不重新探测越狱环境，不从路径、
// 文件名、插件来源或 plist 内容推断路线。证据 `FilterParseResult.route`
// 仍保持 `String?` 基线词汇，不把本枚举泄漏进单条结果或公共 Models。
//

import Foundation

/// 解析路线（Core 中间层封闭集；无 rootful / auto / fallback 取值）。
public enum FilterParseRoute: String, Codable, Equatable {
    /// RootHide 严格类型路线。
    case rootHide = "roothide"
    /// Rootless Codable 路线。
    case rootless
    /// 未确认 Profile / rootful / 开放未知值；不选边。
    case unknown
}
