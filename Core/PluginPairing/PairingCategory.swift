//
//  PairingCategory.swift
//  FilterKit Core — 配对五桶分类（G-C3，契约冻结 §4.1）
//
//  与既有 `Pairing` 四值职责不同：本类型表达 C2 配对结果的五桶互斥归类，
//  不向 `Pairing` 枚举新增取值。`ambiguous` / `uncertain` 记录的
//  `pairing` 为 `nil`，歧义/不确定由本分类与既有证据结构承载。
//

import Foundation

/// 配对结果五桶分类（封闭集，原始值与 S1-05 基线逐字一致）。
public enum PairingCategory: String, Codable, Equatable {
    case paired
    case missingPlist = "missing_plist"
    case orphanPlist = "orphan_plist"
    case ambiguous
    case uncertain
}
