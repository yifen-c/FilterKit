//
//  PlistDecodeStatus.swift
//  FilterKit Core — PlistParser Decoder（C3-B）
//
//  Decoder 内部解码状态：只区分「字节能否构成属性列表」与「不能」。
//  业务字段类型规则属于 C3-C 路线 Parser；本层不产出 type_mismatch。
//

import Foundation

/// plist 解码状态（Decoder 内部封闭集）。
public enum PlistDecodeStatus: String, Codable, Equatable {
    /// 字节构成合法属性列表，根对象已交付。
    case success
    /// 字节无法构成合法属性列表（破损 XML / Binary / 空数据 / 异常对象）。
    case parseFailed = "parse_failed"
}
