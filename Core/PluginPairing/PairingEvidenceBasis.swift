//
//  PairingEvidenceBasis.swift
//  FilterKit Core — 配对匹配依据封闭码（G-C3，契约冻结 §4.3 / §12）
//
//  记录内不使用自由字符串证据数组；匹配依据以封闭枚举承载，取值外延
//  冻结在下列五类，不在记录内塞运行层或内容推断结论。
//

import Foundation

/// 配对记录的匹配依据封闭码。
public enum PairingEvidenceBasis: String, Codable, Equatable {
    /// 同名 dylib/plist 精确文件名匹配。
    case exactFilenameMatch = "exact_filename_match"
    /// 对侧无候选（dylib 缺 plist 或 plist 缺 dylib）。
    case noOppositeCandidate = "no_opposite_candidate"
    /// 同键多候选，歧义不选边。
    case ambiguousMultiCandidate = "ambiguous_multi_candidate"
    /// 条目受限/元数据不可得，配对关系不确定。
    case uncertainAccess = "uncertain_access"
    /// 对应候选被留置，待不确定条目解除后再裁决。
    case heldAgainstUncertain = "held_against_uncertain"
}
