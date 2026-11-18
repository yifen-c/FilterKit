//
//  PluginEntryStatus.swift
//  FilterKit Models — 枚举条目级状态（G-C1，契约冻结 §3.1）
//
//  封闭集五值，与 S1-04 §6 条目级分类逐字一致；异常分层保留，
//  不允许合并为单一 `failed`。访问拒绝 ≠ 不存在；元数据不可获取
//  ≠ 读取失败。夹具实见 `ok / access_denied / metadata_unavailable`，
//  `read_failed / not_found` 为规格封闭集预留。
//

import Foundation

/// 枚举条目级状态。
public enum PluginEntryStatus: String, Codable, Equatable {
    case ok
    case accessDenied = "access_denied"
    case metadataUnavailable = "metadata_unavailable"
    case readFailed = "read_failed"
    case notFound = "not_found"
}
