//
//  PluginFileKind.swift
//  FilterKit Models — 枚举条目文件类型（G-C1，契约冻结 §3.1）
//
//  封闭集五值，原始值与 S1-04 `enumerator.js classify()` 输出逐字一致；
//  扩展名匹配大小写敏感：仅全小写 `.dylib` / `.plist` 归入对应类型，
//  `.DYLIB` / `.Dylib` / `.PLIST` 归 `other`。目录与软链独立识别，
//  不以文件名后缀替代类型判定。
//

import Foundation

/// 枚举条目文件类型（C1 / S1-04）。
public enum PluginFileKind: String, Codable, Equatable {
    case dylib
    case plist
    case directory
    case symlink
    case other
}
