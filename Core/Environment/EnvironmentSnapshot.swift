//
//  EnvironmentSnapshot.swift
//  FilterKit Core — 环境识别输入快照（B1 / S1-01）
//
//  离线只读输入：对应夹具 environment.json 的 signals 结构。识别器只消费本快照，
//  不读取 metadata，不访问真实文件系统；信号缺失一律按未提供处理，不反推补齐。
//

import Foundation
import Models

/// 单路环境信号（夹具信号值的中性载体，不含路线规则）。
public struct EnvironmentSignalValue: Codable, Equatable {
    public var present: Bool?
    public var value: String?
    public var boolValue: Bool?
    public var readability: String?
    public var raw: String?
    public var name: String?
    public var version: String?

    public init(present: Bool? = nil,
                value: String? = nil,
                boolValue: Bool? = nil,
                readability: String? = nil,
                raw: String? = nil,
                name: String? = nil,
                version: String? = nil) {
        self.present = present
        self.value = value
        self.boolValue = boolValue
        self.readability = readability
        self.raw = raw
        self.name = name
        self.version = version
    }

    /// 信号是否显式提供。
    public var isPresent: Bool { present == true }

    private enum CodingKeys: String, CodingKey {
        case present, value, boolValue, readability, raw, name, version
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        present = try c.decodeIfPresent(Bool.self, forKey: .present)
        readability = try c.decodeIfPresent(String.self, forKey: .readability)
        raw = try c.decodeIfPresent(String.self, forKey: .raw)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        version = try c.decodeIfPresent(String.self, forKey: .version)
        // `value` 宽松解码：字符串入 value；布尔入 boolValue；其余类型忽略，不抛错。
        if let bool = try? c.decodeIfPresent(Bool.self, forKey: .value) {
            boolValue = bool
        } else if let str = try? c.decodeIfPresent(String.self, forKey: .value) {
            value = str
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(present, forKey: .present)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encodeIfPresent(boolValue, forKey: .boolValue)
        try c.encodeIfPresent(readability, forKey: .readability)
        try c.encodeIfPresent(raw, forKey: .raw)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(version, forKey: .version)
    }
}

/// 环境识别输入快照（S1-01 夹具 environment.json 解码形态）。
public struct EnvironmentSnapshot: Codable, Equatable {
    public var fixtureId: String?
    public var fixtureKind: String?
    public var signals: Signals

    public struct Signals: Codable, Equatable {
        public var jailbreakType: EnvironmentSignalValue?
        public var rootlessPathPresent: EnvironmentSignalValue?
        public var architecture: EnvironmentSignalValue?
        public var iosVersion: EnvironmentSignalValue?
        public var bootstrap: EnvironmentSignalValue?
        public var ellekitImplementation: EnvironmentSignalValue?
        public var ellekitVersion: EnvironmentSignalValue?

        public init() {}
    }

    public init(fixtureId: String? = nil,
                fixtureKind: String? = nil,
                signals: Signals = Signals()) {
        self.fixtureId = fixtureId
        self.fixtureKind = fixtureKind
        self.signals = signals
    }
}
