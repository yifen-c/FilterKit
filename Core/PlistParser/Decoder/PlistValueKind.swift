//
//  PlistValueKind.swift
//  FilterKit Core — PlistParser Decoder（C3-B）
//
//  plist 值类型谓词。专门处理 Foundation 桥接陷阱：Bool 与 NSNumber 在
//  Swift `is` 判断下会同时命中，必须先按 Core Foundation 类型 ID 区分
//  CFBoolean，再把其余 NSNumber 归为数字，避免后续版本字段校验把布尔
//  当作数字。整数 / 浮点的进一步细化属于 C3-C 路线 Parser 的规则职责。
//

import Foundation

/// plist 值类型封闭集（Decoder 内部类型识别，不进入公共 Models）。
public enum PlistValueKind: String, Codable, Equatable {
    case dictionary
    case array
    case string
    case boolean
    case number
    case data
    case date
    case null
    case unknown
}

/// plist 值分类器（纯函数，无状态）。
public enum PlistValueClassifier {

    /// 把解码后的 Foundation 值归类为 `PlistValueKind`。
    public static func classify(_ value: Any?) -> PlistValueKind {
        guard let value else { return .null }

        // Bool 桥接为 CFBoolean：必须先于 NSNumber 判断。
        if CFBooleanGetTypeID() == CFGetTypeID(value as CFTypeRef) {
            return .boolean
        }

        switch value {
        case is NSDictionary:
            return .dictionary
        case is NSArray:
            return .array
        case is String:
            return .string
        case is Data:
            return .data
        case is Date:
            return .date
        case is NSNull:
            return .null
        case is NSNumber:
            return .number
        default:
            return .unknown
        }
    }

    /// 是否为布尔（供路线 Parser 显式断言，避免重复桥接判断）。
    public static func isBoolean(_ value: Any?) -> Bool {
        classify(value) == .boolean
    }

    /// 是否为数字（已排除布尔）。
    public static func isNumber(_ value: Any?) -> Bool {
        classify(value) == .number
    }
}
