//
//  FilterParseStatus.swift
//  FilterKit Core — PlistParser Result（C3-C1）
//
//  解析五态封闭枚举（契约 §5.1，PC3-4）。五态互斥：同一插件条目在任一
//  结果中只落入一个状态；原始值与 S1-06 报告逐字一致。是否提升为公共
//  Models 枚举留 G-C3-1 评审，本类型保持 Core 中间层。
//

import Foundation

/// 单条 Filter 解析状态。
public enum FilterParseStatus: String, Codable, Equatable {
    /// 规则校验通过，`FilterRule` 非空。
    case valid
    /// 字节不构成合法属性列表，或 Rootless Codable 解码失败。
    case parseFailed = "parse_failed"
    /// 根 / Filter / 受约束字段类型不符本路线规则。
    case typeMismatch = "type_mismatch"
    /// 条目访问受限 / 读取失败；读取级失败不降级为解析失败。
    case readFailed = "read_failed"
    /// 上游未配对 / 不确定 / 歧义，未进入解析管线。
    case notParsed = "not_parsed"
}
