//
//  RootlessFilterParser.swift
//  FilterKit Core — PlistParser Rootless（C3-C2）
//
//  Rootless 路线 Codable Filter Parser（契约 §4.2、§7）。输入为 C3-B Decoder
// 已成功解码的 Foundation 对象；本层不访问文件系统、不调用 Reader / Decoder、
// 不接 Engine。RootHide 严格规则独立实现，本 Parser 不引用、不复用其口径；
// 未知 / rootful 路线选边由后续 Engine 负责。
//
// 失败口径（与 RootHide 严格区分）：结构不符 / 字段类型不符 / Codable 解码
// 失败一律 `parse_failed`，不得转换为 RootHide 的 `type_mismatch`；重新序列
// 化失败属于解析链路，不记 `read_failed`（文件已成功读取）。
//

import Foundation
import Models

/// Rootless 路线 Filter Parser。
public final class RootlessFilterParser {

    /// 路线标识（证据 `route` 字段固定值）。
    public static let routeName = "rootless"

    public init() {}

    /// 解析单条已解码对象。
    /// - Parameters:
    ///   - object: Decoder 产出的根对象。
    ///   - pairingKey / dylibPath / plistPath: 上游配对记录透传信号。
    ///   - route: 路线原值透传；证据归属固定为 `rootless`。
    ///   - plistFormat / readStatus: Reader 层内容信号透传。
    public func parse(object: Any?,
                      pairingKey: String? = nil,
                      dylibPath: String? = nil,
                      plistPath: String? = nil,
                      route: String? = RootlessFilterParser.routeName,
                      plistFormat: String = "unknown",
                      readStatus: String = "ok") -> FilterParseResult {
        // 1. 根节点必须为字典。
        guard let root = Self.dictionary(object) else {
            let skipped = SkippedField(
                key: "(root)",
                reason: "root_type",
                expectedType: "object",
                observedType: Self.observedTypeWord(object),
                route: Self.routeName
            )
            return Self.failed(
                pairingKey: pairingKey, dylibPath: dylibPath, plistPath: plistPath,
                route: route, reason: "root_type", skipped: [skipped],
                plistFormat: plistFormat, readStatus: readStatus)
        }

        // 2. Filter 必须存在且为字典；缺失与空指针同口径记 filter_missing。
        let rawFilter = root["Filter"]
        if rawFilter == nil || PlistValueClassifier.classify(rawFilter) == .null {
            let skipped = SkippedField(
                key: "Filter",
                reason: "filter_missing",
                expectedType: "object",
                observedType: "missing",
                route: Self.routeName
            )
            return Self.failed(
                pairingKey: pairingKey, dylibPath: dylibPath, plistPath: plistPath,
                route: route, reason: "filter_missing", skipped: [skipped],
                plistFormat: plistFormat, readStatus: readStatus)
        }
        guard let filter = Self.dictionary(rawFilter) else {
            let skipped = SkippedField(
                key: "Filter",
                reason: "filter_type",
                expectedType: "object",
                observedType: Self.observedTypeWord(rawFilter),
                route: Self.routeName
            )
            return Self.failed(
                pairingKey: pairingKey, dylibPath: dylibPath, plistPath: plistPath,
                route: route, reason: "filter_type", skipped: [skipped],
                plistFormat: plistFormat, readStatus: readStatus)
        }

        // 3. 字段级类型核对（先产出结构化证据，再进入 Codable 边界）。
        var skipped: [SkippedField] = []
        _ = Self.checkStringArray(filter["Bundles"], key: "Bundles", skipped: &skipped)
        _ = Self.checkStringArray(filter["Executables"], key: "Executables", skipped: &skipped)

        // UnloadAfter：缺失 / 空指针容忍；出现且非布尔 → field_type 证据。
        // 解码值保留在 Codable 模型内（G-C3-5 归属待评审），本层不落规则字段。
        let rawUnloadAfter = root["UnloadAfter"]
        if let unloadValue = rawUnloadAfter,
           PlistValueClassifier.classify(unloadValue) != .null,
           !PlistValueClassifier.isBoolean(unloadValue) {
            skipped.append(SkippedField(
                key: "UnloadAfter",
                reason: "field_type",
                expectedType: "boolean",
                observedType: Self.observedTypeWord(unloadValue),
                route: Self.routeName
            ))
        }

        if !skipped.isEmpty {
            return Self.failed(
                pairingKey: pairingKey, dylibPath: dylibPath, plistPath: plistPath,
                route: route, reason: Self.topLevelReason(for: skipped.first) ?? "field_type",
                skipped: skipped,
                plistFormat: plistFormat, readStatus: readStatus)
        }

        // 4. Codable 边界：整份根字典重新序列化为 plist Data，交 PropertyListDecoder。
        //    序列化 / 解码失败属解析链路（parse_failed），不记 read_failed。
        let decoded: RootlessPlistCodable
        do {
            let data = try PropertyListSerialization.data(
                fromPropertyList: root,
                format: .xml,
                options: 0
            )
            decoded = try PropertyListDecoder().decode(RootlessPlistCodable.self, from: data)
        } catch {
            let skippedField = SkippedField(
                key: "Filter",
                reason: "codable_type",
                expectedType: "object",
                observedType: "unknown",
                route: Self.routeName
            )
            return Self.failed(
                pairingKey: pairingKey, dylibPath: dylibPath, plistPath: plistPath,
                route: route, reason: "codable_type", skipped: [skippedField],
                plistFormat: plistFormat, readStatus: readStatus)
        }

        // 5. 映射为公共规则；`unloadAfter` 按 G-C3-5 仅保留在解码模型内，不入规则。
        let mapped = RootlessFilterMapper.map(decoded: decoded, root: root, filter: filter)

        return FilterParseResult(
            pairingKey: pairingKey,
            dylibPath: dylibPath,
            plistPath: plistPath,
            route: route,
            status: .valid,
            reason: nil,
            filter: mapped.rule,
            isTweakManager: nil,
            skippedFields: [],
            otherKeys: mapped.otherKeys,
            warnings: mapped.warnings,
            plistFormat: plistFormat,
            readStatus: readStatus
        )
    }

    // MARK: - 私有辅助

    /// 字符串数组核对：缺失 / 空指针容忍为 `[]`；非数组 / 元素非字符串记录
    /// `codable_type` 证据。返回归一数组；失败为 `nil`。
    private static func checkStringArray(_ value: Any?,
                                         key: String,
                                         skipped: inout [SkippedField]) -> [String]? {
        if value == nil || PlistValueClassifier.classify(value) == .null {
            return []
        }
        guard let array = Self.array(value) else {
            skipped.append(SkippedField(
                key: key,
                reason: "codable_type",
                expectedType: "string[]",
                observedType: Self.observedTypeWord(value),
                route: Self.routeName
            ))
            return nil
        }

        var strings: [String] = []
        for (index, element) in array.enumerated() {
            guard PlistValueClassifier.classify(element) == .string else {
                skipped.append(SkippedField(
                    key: key,
                    reason: "codable_type",
                    expectedType: "string",
                    observedType: Self.observedTypeWord(element),
                    route: Self.routeName,
                    index: index
                ))
                return nil
            }
            strings.append(element as? String ?? "")
        }
        return strings
    }

    /// 顶层状态细分原因映射（契约 §7，对齐基线 parser.js）。
    /// 数组级 `codable_type` 与布尔 `field_type` 同属字段级失败，顶层统一
    /// `field_type`；结构级原因词原样透传；解码兜底为 `codable_type`。
    private static func topLevelReason(for error: SkippedField?) -> String? {
        guard let reason = error?.reason else { return nil }
        switch reason {
        case "codable_type":
            return "field_type"
        default:
            return reason
        }
    }

    private static func failed(pairingKey: String?,
                               dylibPath: String?,
                               plistPath: String?,
                               route: String?,
                               reason: String,
                               skipped: [SkippedField],
                               plistFormat: String,
                               readStatus: String) -> FilterParseResult {
        let warning = ReportWarning(
            code: reason,
            message: "Rootless Codable 解码未通过：\(reason)",
            sourceStage: RootlessFilterMapper.warningSourceStage
        )
        return FilterParseResult(
            pairingKey: pairingKey,
            dylibPath: dylibPath,
            plistPath: plistPath,
            route: route,
            status: .parseFailed,
            reason: reason,
            filter: nil,
            isTweakManager: nil,
            skippedFields: skipped,
            otherKeys: [],
            warnings: [warning],
            plistFormat: plistFormat,
            readStatus: readStatus
        )
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        guard let dict = value as? NSDictionary else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            guard let key = key as? String else { continue }
            result[key] = value
        }
        return result
    }

    private static func array(_ value: Any?) -> [Any]? {
        guard let array = value as? NSArray else { return nil }
        return array.map { $0 }
    }

    private static func observedTypeWord(_ value: Any?) -> String {
        switch PlistValueClassifier.classify(value) {
        case .dictionary: return "object"
        case .array: return "array"
        case .string: return "string"
        case .boolean: return "boolean"
        case .number: return "number"
        case .data: return "data"
        case .date: return "date"
        case .null: return "null"
        case .unknown: return "unknown"
        }
    }
}
