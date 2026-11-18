//
//  RootHideFilterParser.swift
//  FilterKit Core — PlistParser RootHide（C3-C1）
//
//  RootHide 严格类型 Filter Parser（契约 §4.1，PC3-5 / PC3-6）。输入为
//  C3-B Decoder 已成功解码的对象；本层不访问文件系统、不调用 Reader /
//  Decoder、不接 Engine。Rootless 规则独立实现，本 Parser 不引用、不复用
//  其口径；未知 / rootful 路线的选边由后续 Engine 负责。
//

import Foundation
import Models

/// RootHide 路线 Filter Parser。
public final class RootHideFilterParser {

    /// 路线标识（证据 `route` 字段固定值）。
    public static let routeName = "roothide"

    public init() {}

    /// 解析单条已解码对象。
    /// - Parameters:
    ///   - object: Decoder 产出的根对象。
    ///   - pairingKey / dylibPath / plistPath: 上游配对记录透传信号。
    ///   - route: 路线原值透传；证据归属固定为 `roothide`。
    ///   - plistFormat / readStatus: Reader 层内容信号透传。
    public func parse(object: Any?,
                      pairingKey: String? = nil,
                      dylibPath: String? = nil,
                      plistPath: String? = nil,
                      route: String? = RootHideFilterParser.routeName,
                      plistFormat: String = "unknown",
                      readStatus: String = "ok") -> FilterParseResult {
        let validation = RootHideFilterValidator.validate(object: object)

        if validation.isMismatch {
            let reason = Self.topLevelReason(for: validation.errors.first)
            let warning = ReportWarning(
                code: reason ?? "type_mismatch",
                message: "RootHide 严格类型核对未通过：\(reason ?? "type_mismatch")",
                sourceStage: RootHideFilterMapper.warningSourceStage
            )
            return FilterParseResult(
                pairingKey: pairingKey,
                dylibPath: dylibPath,
                plistPath: plistPath,
                route: route,
                status: .typeMismatch,
                reason: reason,
                filter: nil,
                isTweakManager: nil,
                skippedFields: validation.errors,
                otherKeys: [],
                warnings: [warning],
                plistFormat: plistFormat,
                readStatus: readStatus
            )
        }

        let mapped = RootHideFilterMapper.map(validation: validation)
        return FilterParseResult(
            pairingKey: pairingKey,
            dylibPath: dylibPath,
            plistPath: plistPath,
            route: route,
            status: .valid,
            reason: nil,
            filter: mapped.rule,
            isTweakManager: validation.isTweakManager ?? false,
            skippedFields: validation.clues,
            otherKeys: mapped.otherKeys,
            warnings: mapped.warnings,
            plistFormat: plistFormat,
            readStatus: readStatus
        )
    }

    /// 顶层状态细分原因映射（契约 §7，对齐基线 parser.js）。
    /// 数组级细粒度原因（`not_array / null_element / element_type`）只保留在
    /// `SkippedField`；顶层字段级失败统一归 `field_type`。
    private static func topLevelReason(for error: SkippedField?) -> String? {
        guard let reason = error?.reason else { return nil }
        switch reason {
        case "not_array", "null_element", "element_type":
            return "field_type"
        default:
            return reason
        }
    }
}
