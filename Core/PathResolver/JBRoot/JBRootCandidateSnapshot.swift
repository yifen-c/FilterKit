//
//  JBRootCandidateSnapshot.swift
//  FilterKit Core — JBROOT 候选输入快照（B2 / S1-02）
//
//  离线只读输入：对应 S1-02 夹具 environment.json 的 signals.candidates 结构。
//  收集器只消费本快照，不读取 metadata，不访问真实文件系统；信号缺失按未提供
//  处理，不反推补齐。候选校验位裁决、六态状态与最终 JBROOT 选择归 B3，不在本层。
//

import Foundation
import Models

/// 单条候选信号（夹具候选对象的中性载体，不含路线规则与校验裁决）。
public struct JBRootCandidateSignal: Codable, Equatable {
    public var root: String?
    public var source: String?
    public var exists: Bool?
    public var structureMatch: Bool?
    public var readable: Bool?
    public var realpath: String?
    public var symlinkState: String?

    public init(root: String? = nil,
                source: String? = nil,
                exists: Bool? = nil,
                structureMatch: Bool? = nil,
                readable: Bool? = nil,
                realpath: String? = nil,
                symlinkState: String? = nil) {
        self.root = root
        self.source = source
        self.exists = exists
        self.structureMatch = structureMatch
        self.readable = readable
        self.realpath = realpath
        self.symlinkState = symlinkState
    }

    private enum CodingKeys: String, CodingKey {
        case root, source, exists, structureMatch, readable, realpath, symlinkState
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        root = try c.decodeIfPresent(String.self, forKey: .root)
        source = try c.decodeIfPresent(String.self, forKey: .source)
        exists = try c.decodeIfPresent(Bool.self, forKey: .exists)
        structureMatch = try c.decodeIfPresent(Bool.self, forKey: .structureMatch)
        readable = try c.decodeIfPresent(Bool.self, forKey: .readable)
        realpath = try c.decodeIfPresent(String.self, forKey: .realpath)
        symlinkState = try c.decodeIfPresent(String.self, forKey: .symlinkState)
    }
}

/// JBROOT 候选收集输入快照（S1-02 夹具 environment.json 解码形态）。
public struct JBRootCandidateSnapshot: Codable, Equatable {
    public var fixtureId: String?
    public var fixtureKind: String?
    public var signals: Signals

    public struct Signals: Codable, Equatable {
        public var candidates: [JBRootCandidateSignal]

        public init(candidates: [JBRootCandidateSignal] = []) {
            self.candidates = candidates
        }
    }

    public init(fixtureId: String? = nil,
                fixtureKind: String? = nil,
                signals: Signals = Signals()) {
        self.fixtureId = fixtureId
        self.fixtureKind = fixtureKind
        self.signals = signals
    }
}
