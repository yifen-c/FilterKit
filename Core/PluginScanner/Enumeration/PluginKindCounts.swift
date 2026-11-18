//
//  PluginKindCounts.swift
//  FilterKit Core — 五类条目计数（G-C2，契约冻结 §4.1）
//
//  计数与 `PluginFileKind` 五值一一对应；不只统计 dylib/plist，
//  目录、软链与其他文件必须保留在计数内。
//

import Foundation
import Models

/// 五类条目计数。
public struct PluginKindCounts: Codable, Equatable {
    public var dylib: Int
    public var plist: Int
    public var directory: Int
    public var symlink: Int
    public var other: Int

    public init(dylib: Int = 0,
                plist: Int = 0,
                directory: Int = 0,
                symlink: Int = 0,
                other: Int = 0) {
        self.dylib = dylib
        self.plist = plist
        self.directory = directory
        self.symlink = symlink
        self.other = other
    }

    /// 按分类累加一条条目。
    public mutating func add(_ kind: PluginFileKind) {
        switch kind {
        case .dylib: dylib += 1
        case .plist: plist += 1
        case .directory: directory += 1
        case .symlink: symlink += 1
        case .other: other += 1
        }
    }
}
