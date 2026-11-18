//
//  FilterParseRouteResolver.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B）
//
//  路线归一纯函数：只消费 C2 快照已透传的 `route` 可信值，映射为 Engine
//  内部 `FilterParseRoute`。本层不访问文件系统、不读 plist 内容、不实例化
//  Adapter；未知 / rootful / nil / 开放字符串一律归 `.unknown`，不自动降级、
//  不产生第二套路线推断机制。
//

import Foundation

/// 路线归一器（无状态纯计算）。
public struct FilterParseRouteResolver {

    public init() {}

    /// 将上游路线原值归一为内部路线。
    /// - Parameter route: `PluginPairingSnapshot.route` 原样值。
    /// - Returns: 归一结果；非 `roothide / rootless` 均为 `.unknown`。
    public func resolve(route: String?) -> FilterParseRoute {
        switch route?.lowercased() {
        case "roothide":
            return .rootHide
        case "rootless":
            return .rootless
        default:
            return .unknown
        }
    }
}
