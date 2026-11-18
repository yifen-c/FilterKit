//
//  FilterParseResult.swift
//  FilterKit Core — PlistParser Result（C3-C1）
//
//  单条解析统一结果（契约 §5.5，PC3-5 / PC3-6 / PC3-7）。规则载体复用
//  公共 `FilterRule`，不另造规则模型；`filter` 仅在 `valid` 非空，其余
//  四态恒为 `nil`（§8 证据不可变口径）。
//

import Foundation
import Models

/// 单条 plist Filter 解析结果（Core 中间层，不进入公共 ReportEnvelope）。
public struct FilterParseResult: Codable, Equatable {
    /// 上游配对键透传。
    public let pairingKey: String?
    /// 上游 dylib 路径透传。
    public let dylibPath: String?
    /// 上游 plist 路径透传。
    public let plistPath: String?
    /// 路线原值（`roothide / rootless / unknown`）。
    public let route: String?
    /// 五态互斥状态。
    public let status: FilterParseStatus
    /// 状态细分原因；`valid` 为 `nil`。
    public let reason: String?
    /// 成功规则；仅 `valid` 非空，其余四态恒为 `nil`。
    public let filter: FilterRule?
    /// RootHide 缺失 = `false`；Rootless 恒 `nil`。
    public let isTweakManager: Bool?
    /// 错误 / 线索证据；`valid` 下除长度线索外为空数组。
    public let skippedFields: [SkippedField]
    /// 去重排序的未覆盖键名。
    public let otherKeys: [String]
    /// 条目级告警，`sourceStage = "stage2.2-c3"`。
    public let warnings: [ReportWarning]
    /// 透传 Reader 格式信号（`xml / binary / unknown`）。
    public let plistFormat: String
    /// 透传读取状态（`ok / access_denied / read_failed`）。
    public let readStatus: String

    public init(pairingKey: String? = nil,
                dylibPath: String? = nil,
                plistPath: String? = nil,
                route: String? = nil,
                status: FilterParseStatus,
                reason: String? = nil,
                filter: FilterRule? = nil,
                isTweakManager: Bool? = nil,
                skippedFields: [SkippedField] = [],
                otherKeys: [String] = [],
                warnings: [ReportWarning] = [],
                plistFormat: String = "unknown",
                readStatus: String = "ok") {
        self.pairingKey = pairingKey
        self.dylibPath = dylibPath
        self.plistPath = plistPath
        self.route = route
        self.status = status
        self.reason = reason
        self.filter = filter
        self.isTweakManager = isTweakManager
        self.skippedFields = skippedFields
        self.otherKeys = otherKeys
        self.warnings = warnings
        self.plistFormat = plistFormat
        self.readStatus = readStatus
    }
}
