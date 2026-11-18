//
//  SkippedField.swift
//  FilterKit Core — PlistParser Result（C3-C1）
//
//  结构化错误证据（契约 §5.2，PC3-6）。SkippedField 是错误证据，不是
//  「跳过错误字段后仍然有效」：RootHide 受约束字段类型错误时整份 plist
//  必须为 `type_mismatch`，不得解读为部分 valid。
//

import Foundation

/// 单字段 / 单元素级跳过证据。
public struct SkippedField: Codable, Equatable {
    /// 字段名；根节点级固定为 `(root)`。
    public let key: String
    /// 封闭原因词：`root_type / filter_missing / filter_type / field_type /
    /// not_array / null_element / element_type / codable_type /
    /// versions_type / unsupported_length`。
    public let reason: String
    /// 期望类型词：`object / string[] / string / boolean / number[] / number[1|2]` 等。
    public let expectedType: String
    /// 观测类型词：`object / array / string / number / boolean / null / missing / number[N]`。
    public let observedType: String
    /// 归属路线：`roothide / rootless / unknown`。
    public let route: String
    /// 数组元素级证据位置；非元素级为 `nil`。
    public let index: Int?

    public init(key: String,
                reason: String,
                expectedType: String,
                observedType: String,
                route: String,
                index: Int? = nil) {
        self.key = key
        self.reason = reason
        self.expectedType = expectedType
        self.observedType = observedType
        self.route = route
        self.index = index
    }
}
