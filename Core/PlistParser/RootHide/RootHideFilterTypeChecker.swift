//
//  RootHideFilterTypeChecker.swift
//  FilterKit Core — PlistParser RootHide（C3-C1）
//
//  RootHide 严格类型谓词（契约 §4.1）。Bool / NSNumber 桥接陷阱统一复用
//  C3-B `PlistValueClassifier`，不在本层另写一套布尔/数字判断；字典与
//  数组做 Foundation 桥接归一化，避免 `[String: Any]` 直接 `as?` 失败。
//

import Foundation

/// RootHide 路线类型谓词辅助（纯函数，无状态）。
public enum RootHideFilterTypeChecker {

    /// 把解码值归类为证据层观测类型词（对齐 S1-06 `typeOf`）。
    public static func observedTypeWord(_ value: Any?) -> String {
        switch PlistValueClassifier.classify(value) {
        case .dictionary: return "object"
        case .array: return "array"
        case .string: return "string"
        case .boolean: return "boolean"
        case .number: return "number"
        case .data: return "data"
        case .date: return "date"
        case .null: return "null"
        case .unknown: return "unknown"
        }
    }

    /// 是否为字典（NSNull / 数组 / 字符串均否）。
    public static func isDictionary(_ value: Any?) -> Bool {
        dictionary(value) != nil
    }

    /// 是否为数组。
    public static func isArray(_ value: Any?) -> Bool {
        array(value) != nil
    }

    /// 是否为布尔（已排除 NSNumber 桥接）。
    public static func isBoolean(_ value: Any?) -> Bool {
        PlistValueClassifier.isBoolean(value)
    }

    /// 是否为数字（已排除布尔）。
    public static func isNumber(_ value: Any?) -> Bool {
        PlistValueClassifier.isNumber(value)
    }

    /// 是否为字符串。
    public static func isString(_ value: Any?) -> Bool {
        PlistValueClassifier.classify(value) == .string
    }

    /// 是否为空值（NSNull 或 `nil`）；缺失与空指针在本路线分别记录。
    public static func isNull(_ value: Any?) -> Bool {
        PlistValueClassifier.classify(value) == .null
    }

    /// 字典归一化：`NSDictionary` → `[String: Any]`；非字典返回 `nil`。
    public static func dictionary(_ value: Any?) -> [String: Any]? {
        guard let dict = value as? NSDictionary else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            guard let key = key as? String else { continue }
            result[key] = value
        }
        return result
    }

    /// 数组归一化：`NSArray` → `[Any]`；非数组返回 `nil`。
    public static func array(_ value: Any?) -> [Any]? {
        guard let array = value as? NSArray else { return nil }
        return array.map { $0 }
    }
}
