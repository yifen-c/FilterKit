//
//  PluginPairingKeyBuilder.swift
//  FilterKit Core — 配对键生成（G-C3，契约冻结 §5.1）
//
//  仅剥离精确 `.dylib` / `.plist` 后缀；比较大小写敏感，不 lowercase、
//  不模糊包含、不规范化 Unicode、不读取文件内容；隐藏前缀保留；
//  空键（文件名恰为后缀）不参与配对。
//

import Foundation
import Models

/// 配对键生成器（纯函数，无状态）。
public enum PluginPairingKeyBuilder {

    /// 由条目证据派生配对键；非 dylib/plist、后缀不精确匹配或空键返回 `nil`。
    public static func key(for file: PluginFileEvidence) -> String? {
        let suffix: String
        switch file.kind {
        case .dylib: suffix = ".dylib"
        case .plist: suffix = ".plist"
        case .directory, .symlink, .other: return nil
        }

        guard file.name.hasSuffix(suffix) else { return nil }
        let key = String(file.name.dropLast(suffix.count))
        guard !key.isEmpty else { return nil }
        return key
    }
}
