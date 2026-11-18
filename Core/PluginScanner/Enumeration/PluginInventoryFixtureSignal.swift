//
//  PluginInventoryFixtureSignal.swift
//  FilterKit Core — 枚举输入信号快照（G-C2，契约冻结 §4.3）
//
//  离线只读输入：对应 S1-04 夹具 `environment.json` 的 `upstream` / `fs` 结构。
//  收集器只消费本快照，不读取 `metadata.json`，不访问真实文件系统；信号缺失
//  按未提供处理，不反推补齐。`nested` 为 harness 非递归过滤标记，仅输入侧使用，
//  不进入输出证据。
//

import Foundation
import Models

/// 枚举夹具输入信号快照。
public struct PluginInventoryFixtureSignal: Codable, Equatable {
    public var fixtureId: String?
    public var fixtureKind: String?
    public var upstream: UpstreamSignal?
    public var fs: FsSignal?

    public init(fixtureId: String? = nil,
                fixtureKind: String? = nil,
                upstream: UpstreamSignal? = nil,
                fs: FsSignal? = nil) {
        self.fixtureId = fixtureId
        self.fixtureKind = fixtureKind
        self.upstream = upstream
        self.fs = fs
    }

    private enum CodingKeys: String, CodingKey {
        case fixtureId, fixtureKind, upstream, fs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fixtureId = try c.decodeIfPresent(String.self, forKey: .fixtureId)
        fixtureKind = try c.decodeIfPresent(String.self, forKey: .fixtureKind)
        upstream = try c.decodeIfPresent(UpstreamSignal.self, forKey: .upstream)
        fs = try c.decodeIfPresent(FsSignal.self, forKey: .fs)
    }

    /// 上游定位信号（路线 + 已确认目录）。
    public struct UpstreamSignal: Codable, Equatable {
        public var route: String?
        public var sourceDirectory: String?

        public init(route: String? = nil, sourceDirectory: String? = nil) {
            self.route = route
            self.sourceDirectory = sourceDirectory
        }

        private enum CodingKeys: String, CodingKey { case route, sourceDirectory }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            route = try c.decodeIfPresent(String.self, forKey: .route)
            sourceDirectory = try c.decodeIfPresent(String.self, forKey: .sourceDirectory)
        }
    }

    /// 文件系统枚举信号（离线注入；不代表真实设备文件状态）。
    public struct FsSignal: Codable, Equatable {
        public var enumerable: Bool?
        public var enumerationError: String?
        public var entries: [EntrySignal]?

        public init(enumerable: Bool? = nil,
                    enumerationError: String? = nil,
                    entries: [EntrySignal]? = nil) {
            self.enumerable = enumerable
            self.enumerationError = enumerationError
            self.entries = entries
        }

        private enum CodingKeys: String, CodingKey {
            case enumerable, enumerationError, entries
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enumerable = try c.decodeIfPresent(Bool.self, forKey: .enumerable)
            enumerationError = try c.decodeIfPresent(String.self, forKey: .enumerationError)
            entries = try c.decodeIfPresent([EntrySignal].self, forKey: .entries)
        }
    }

    /// 单条目中性信号（夹具原始类型/事实位；分类与状态裁决在 Core 完成）。
    public struct EntrySignal: Codable, Equatable {
        public var name: String?
        public var type: String?
        public var exists: Bool?
        public var readable: Bool?
        public var isSymlink: Bool?
        public var symlinkTarget: String?
        public var symlinkState: String?
        public var realpath: String?
        public var size: Int?
        public var hash: String?
        public var hidden: Bool?
        public var entryStatus: String?
        public var nested: Bool?

        public init(name: String? = nil,
                    type: String? = nil,
                    exists: Bool? = nil,
                    readable: Bool? = nil,
                    isSymlink: Bool? = nil,
                    symlinkTarget: String? = nil,
                    symlinkState: String? = nil,
                    realpath: String? = nil,
                    size: Int? = nil,
                    hash: String? = nil,
                    hidden: Bool? = nil,
                    entryStatus: String? = nil,
                    nested: Bool? = nil) {
            self.name = name
            self.type = type
            self.exists = exists
            self.readable = readable
            self.isSymlink = isSymlink
            self.symlinkTarget = symlinkTarget
            self.symlinkState = symlinkState
            self.realpath = realpath
            self.size = size
            self.hash = hash
            self.hidden = hidden
            self.entryStatus = entryStatus
            self.nested = nested
        }

        private enum CodingKeys: String, CodingKey {
            case name, type, exists, readable, isSymlink, symlinkTarget, symlinkState
            case realpath, size, hash, hidden, entryStatus, nested
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            type = try c.decodeIfPresent(String.self, forKey: .type)
            exists = try c.decodeIfPresent(Bool.self, forKey: .exists)
            readable = try c.decodeIfPresent(Bool.self, forKey: .readable)
            isSymlink = try c.decodeIfPresent(Bool.self, forKey: .isSymlink)
            symlinkTarget = try c.decodeIfPresent(String.self, forKey: .symlinkTarget)
            symlinkState = try c.decodeIfPresent(String.self, forKey: .symlinkState)
            realpath = try c.decodeIfPresent(String.self, forKey: .realpath)
            size = try c.decodeIfPresent(Int.self, forKey: .size)
            hash = try c.decodeIfPresent(String.self, forKey: .hash)
            hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden)
            entryStatus = try c.decodeIfPresent(String.self, forKey: .entryStatus)
            nested = try c.decodeIfPresent(Bool.self, forKey: .nested)
        }
    }
}
