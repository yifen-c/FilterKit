//
//  EnumerationStatus.swift
//  FilterKit Core — 目录级枚举状态（G-C2，契约冻结 §4.1）
//
//  四态封闭集，与 S1-04 §6 目录级分类逐字一致；状态判定优先级：
//  上游目录未定位 → `unresolved`；目录不可枚举 → `enumeration_failed`；
//  部分条目访问失败 → `partial`；完整读取 → `enumerated`。
//  空目录不判定为失败。
//

import Foundation

/// 目录级枚举状态。
public enum EnumerationStatus: String, Codable, Equatable {
    case enumerated
    case partial
    case enumerationFailed = "enumeration_failed"
    case unresolved
}
