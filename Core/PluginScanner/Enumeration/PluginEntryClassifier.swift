//
//  PluginEntryClassifier.swift
//  FilterKit Core — 条目分类器（C1 / S1-04）
//
//  判定顺序对齐 `enumerator.js classify()`（顺序不可调换）：
//  1. 目录 → `directory`；
//  2. 软链 → `symlink`（记录自身，不跟随目标）；
//  3. 扩展名（大小写敏感）→ `dylib` / `plist`；
//  4. 其余 → `other`。
//  扩展名取最后一个 `.` 之后的原始后缀；点开头且无第二段点号视为无扩展名。
//

import Foundation
import Models

/// 条目类型分类器（纯规则，不访问文件系统）。
public struct PluginEntryClassifier {

    public init() {}

    /// 提取文件名扩展名（保留大小写；无扩展名返回 `nil`）。
    public static func fileExtension(of name: String) -> String? {
        guard let dot = name.lastIndex(of: ".") else { return nil }
        guard dot > name.startIndex else { return nil }
        return String(name[name.index(after: dot)...])
    }

    /// 按目录/软链信号与扩展名判定条目类型。
    public func classify(name: String, type: String?, isSymlink: Bool?) -> PluginFileKind {
        if type == "directory" {
            return .directory
        }
        if isSymlink == true {
            return .symlink
        }
        switch Self.fileExtension(of: name) {
        case "dylib": return .dylib
        case "plist": return .plist
        default: return .other
        }
    }
}
