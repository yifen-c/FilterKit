//
//  FilterParseCounts.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B，契约 §5.7）
//
//  解析五桶计数。`not_parsed` 不是解析失败：非 paired、未知路线等不具备
//  解析条件的条目归集于此。不变量：
//  `valid + parseFailed + typeMismatch + readFailed == parsed.count`；
//  `notParsed == notParsedItems.count`；五桶和等于输入条目总数。
//

import Foundation

/// 解析五桶计数（Core 中间层；基线原始值键冻结）。
public struct FilterParseCounts: Codable, Equatable {
    public var valid: Int
    public var parseFailed: Int
    public var typeMismatch: Int
    public var readFailed: Int
    public var notParsed: Int

    public init(valid: Int = 0,
                parseFailed: Int = 0,
                typeMismatch: Int = 0,
                readFailed: Int = 0,
                notParsed: Int = 0) {
        self.valid = valid
        self.parseFailed = parseFailed
        self.typeMismatch = typeMismatch
        self.readFailed = readFailed
        self.notParsed = notParsed
    }

    /// 五桶计数之和（互斥条目数）。
    public var total: Int {
        valid + parseFailed + typeMismatch + readFailed + notParsed
    }

    private enum CodingKeys: String, CodingKey {
        case valid
        case parseFailed = "parse_failed"
        case typeMismatch = "type_mismatch"
        case readFailed = "read_failed"
        case notParsed = "not_parsed"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        valid = try c.decodeIfPresent(Int.self, forKey: .valid) ?? 0
        parseFailed = try c.decodeIfPresent(Int.self, forKey: .parseFailed) ?? 0
        typeMismatch = try c.decodeIfPresent(Int.self, forKey: .typeMismatch) ?? 0
        readFailed = try c.decodeIfPresent(Int.self, forKey: .readFailed) ?? 0
        notParsed = try c.decodeIfPresent(Int.self, forKey: .notParsed) ?? 0
    }
}
