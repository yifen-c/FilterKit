//
//  ElleKitDirectorySnapshot.swift
//  FilterKit Core — ElleKit 目录定位输入快照（B4 / S1-03）
//
//  离线只读输入：对应 S1-03 夹具 environment.json 的 `upstream` 与 `fs` 结构。
//  解析器只消费本快照，不读取 metadata，不访问真实文件系统；信号缺失按未提供
//  处理，不反推补齐。目录/软链证据结构见 Models `PathLocationEvidence` /
//  `SymlinkEvidence`；本层只承载中性信号。
//

import Foundation
import Models

/// 上游 JBROOT 定位结果信号（路线 + 已确认 jbroot）。
public struct DirectoryUpstreamSignal: Codable, Equatable {
    public var route: String?
    public var jbroot: String?

    public init(route: String? = nil, jbroot: String? = nil) {
        self.route = route
        self.jbroot = jbroot
    }

    private enum CodingKeys: String, CodingKey { case route, jbroot }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        route = try c.decodeIfPresent(String.self, forKey: .route)
        jbroot = try c.decodeIfPresent(String.self, forKey: .jbroot)
    }
}

/// TweakInject 目录信号（存在/可读/可枚举/结构/realpath 事实位）。
public struct DirectoryTiSignal: Codable, Equatable {
    public var exists: Bool?
    public var readable: Bool?
    public var enumerable: Bool?
    public var realpath: String?
    public var structureMatch: Bool?

    public init(exists: Bool? = nil,
                readable: Bool? = nil,
                enumerable: Bool? = nil,
                realpath: String? = nil,
                structureMatch: Bool? = nil) {
        self.exists = exists
        self.readable = readable
        self.enumerable = enumerable
        self.realpath = realpath
        self.structureMatch = structureMatch
    }

    private enum CodingKeys: String, CodingKey {
        case exists, readable, enumerable, realpath, structureMatch
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exists = try c.decodeIfPresent(Bool.self, forKey: .exists)
        readable = try c.decodeIfPresent(Bool.self, forKey: .readable)
        enumerable = try c.decodeIfPresent(Bool.self, forKey: .enumerable)
        realpath = try c.decodeIfPresent(String.self, forKey: .realpath)
        structureMatch = try c.decodeIfPresent(Bool.self, forKey: .structureMatch)
    }
}

/// DynamicLibraries 软链信号。
public struct DirectoryDlSignal: Codable, Equatable {
    public var exists: Bool?
    public var isSymlink: Bool?
    public var symlinkTarget: String?
    public var realpath: String?
    public var symlinkState: String?

    public init(exists: Bool? = nil,
                isSymlink: Bool? = nil,
                symlinkTarget: String? = nil,
                realpath: String? = nil,
                symlinkState: String? = nil) {
        self.exists = exists
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.realpath = realpath
        self.symlinkState = symlinkState
    }

    private enum CodingKeys: String, CodingKey {
        case exists, isSymlink, symlinkTarget, realpath, symlinkState
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exists = try c.decodeIfPresent(Bool.self, forKey: .exists)
        isSymlink = try c.decodeIfPresent(Bool.self, forKey: .isSymlink)
        symlinkTarget = try c.decodeIfPresent(String.self, forKey: .symlinkTarget)
        realpath = try c.decodeIfPresent(String.self, forKey: .realpath)
        symlinkState = try c.decodeIfPresent(String.self, forKey: .symlinkState)
    }
}

/// 目录定位文件系统信号（离线注入；不代表真实设备文件状态）。
public struct DirectoryFsSignal: Codable, Equatable {
    public var tweakInject: DirectoryTiSignal?
    public var dynamicLibraries: DirectoryDlSignal?

    public init(tweakInject: DirectoryTiSignal? = nil,
                dynamicLibraries: DirectoryDlSignal? = nil) {
        self.tweakInject = tweakInject
        self.dynamicLibraries = dynamicLibraries
    }

    private enum CodingKeys: String, CodingKey { case tweakInject, dynamicLibraries }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tweakInject = try c.decodeIfPresent(DirectoryTiSignal.self, forKey: .tweakInject)
        dynamicLibraries = try c.decodeIfPresent(DirectoryDlSignal.self, forKey: .dynamicLibraries)
    }
}

/// ElleKit 目录定位输入快照（S1-03 `environment.json` 解码形态）。
public struct ElleKitDirectorySnapshot: Codable, Equatable {
    public var fixtureId: String?
    public var fixtureKind: String?
    public var upstream: DirectoryUpstreamSignal?
    public var fs: DirectoryFsSignal?

    public init(fixtureId: String? = nil,
                fixtureKind: String? = nil,
                upstream: DirectoryUpstreamSignal? = nil,
                fs: DirectoryFsSignal? = nil) {
        self.fixtureId = fixtureId
        self.fixtureKind = fixtureKind
        self.upstream = upstream
        self.fs = fs
    }

    private enum CodingKeys: String, CodingKey { case fixtureId, fixtureKind, upstream, fs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fixtureId = try c.decodeIfPresent(String.self, forKey: .fixtureId)
        fixtureKind = try c.decodeIfPresent(String.self, forKey: .fixtureKind)
        upstream = try c.decodeIfPresent(DirectoryUpstreamSignal.self, forKey: .upstream)
        fs = try c.decodeIfPresent(DirectoryFsSignal.self, forKey: .fs)
    }
}
