//
//  PairingStatus.swift
//  FilterKit Core — 目录级配对状态（G-C3，契约冻结 §4.2）
//
//  表达整轮配对任务的执行情况，不是单个条目的配对分类；原始值与
//  S1-05 `pairing.js` 状态词汇表逐字一致，不另造同义状态枚举。
//  判定优先级：`unresolved`（目录未定位）→ `enumeration_failed`
//  （清单不可枚举）→ `partial`（存在 uncertain 记录）→ `enumerated`。
//

import Foundation

/// 目录级配对状态（四态封闭集）。
public enum PairingStatus: String, Codable, Equatable {
    case enumerated
    case partial
    case enumerationFailed = "enumeration_failed"
    case unresolved
}
