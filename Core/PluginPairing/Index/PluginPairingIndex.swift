//
//  PluginPairingIndex.swift
//  FilterKit Core — 配对索引（G-C3，契约冻结 §5.2）
//
//  两张按键分组的字典；值为候选数组，同键多候选全量保留、不覆盖。
//  候选数组由构建器按路径字母序排序，保证跨枚举顺序的确定性。
//

import Foundation
import Models

/// 配对索引：同一 `sourceDirectory` 作用域内的 dylib/plist 候选分组。
public struct PluginPairingIndex: Equatable {

    /// 按键分组的 dylib 候选（同键多候选取值为数组）。
    public var dylibs: [String: [PluginFileEvidence]]

    /// 按键分组的 plist 候选（同键多候选取值为数组）。
    public var plists: [String: [PluginFileEvidence]]

    public init(
        dylibs: [String: [PluginFileEvidence]] = [:],
        plists: [String: [PluginFileEvidence]] = [:]
    ) {
        self.dylibs = dylibs
        self.plists = plists
    }

    /// 索引内全部配对键（有序）。
    public var keys: [String] {
        Set(dylibs.keys).union(plists.keys).sorted()
    }
}
