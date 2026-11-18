//
//  RootlessFilterMapper.swift
//  FilterKit Core — PlistParser Rootless（C3-C2）
//
//  Codable 模型 → 公共 `FilterRule` 映射（契约 §4.2、§4.3、PC3-7 otherKeys）。
// 取值规范化：`Bundles / Executables` 统一 `lowercased()`；`classes` 恒空、
// `coreFoundationVersion` 恒 `nil`（Rootless 模型不覆盖这两项）；未覆盖键
// 两层合并、去重、字典序排序。告警统一 `ReportWarning`，`sourceStage` 与
// C3-C1 同阶段口径。
//
// 边界：`UnloadAfter` 已在 Codable 模型解码，但按 G-C3-5 待评审归属，本批
// 不写入 `FilterRule`，也不新增公共 Models 字段。
//

import Foundation
import Models

/// Rootless 路线规则映射器（纯函数，无状态）。
public enum RootlessFilterMapper {

    /// 告警来源阶段（契约 §5.5）。
    public static let warningSourceStage = "stage2.2-c3"

    /// Rootless 顶层识别键（契约 §4.2）。
    public static let rootRecognizedKeys: Set<String> = ["Filter", "UnloadAfter"]
    /// Rootless Filter 内识别键（契约 §4.2）。
    public static let filterRecognizedKeys: Set<String> = ["Bundles", "Executables"]

    /// 映射解码模型为成功规则、未覆盖键与条目告警。
    static func map(decoded: RootlessPlistCodable,
                     root: [String: Any],
                     filter: [String: Any])
        -> (rule: FilterRule, otherKeys: [String], warnings: [ReportWarning]) {
        var warnings: [ReportWarning] = []

        let bundles = normalizedArray(
            filter: filter, key: "Bundles",
            values: decoded.filter?.bundles ?? [], warnings: &warnings)
        let executables = normalizedArray(
            filter: filter, key: "Executables",
            values: decoded.filter?.executables ?? [], warnings: &warnings)

        // 空 Filter：两数组皆空（Rootless 模型无版本约束字段）。
        if bundles.isEmpty && executables.isEmpty {
            warnings.append(warning(code: "empty_filter", message: "Filter 字典未包含任何有效规则条目"))
        }

        let otherKeys = collectOtherKeys(root: root, filter: filter)

        let rule = FilterRule(
            bundles: bundles,
            classes: [],
            executables: executables,
            coreFoundationVersion: nil,
            otherKeys: otherKeys
        )
        return (rule, otherKeys, warnings)
    }

    // MARK: - 私有辅助

    /// 数组取值规范化：统一小写；缺失 / 空数组 / 空串元素分别记录告警，
    /// 空串保留不静默剔除（契约 §4.3）。
    private static func normalizedArray(filter: [String: Any],
                                        key: String,
                                        values: [String],
                                        warnings: inout [ReportWarning]) -> [String] {
        let raw = filter[key]
        let missing = raw == nil || PlistValueClassifier.classify(raw) == .null

        if missing {
            warnings.append(warning(code: "field_missing", message: "Filter.\(key) 缺失，按空数组处理"))
        } else if values.isEmpty {
            warnings.append(warning(code: "empty_array", message: "Filter.\(key) 为空数组"))
        }

        let lowercased = values.map { $0.lowercased() }
        for (index, item) in lowercased.enumerated() where item.isEmpty {
            warnings.append(warning(
                code: "empty_element",
                message: "Filter.\(key) 第 \(index) 个元素为空串，保留不剔除"))
        }
        return lowercased
    }

    private static func collectOtherKeys(root: [String: Any], filter: [String: Any]) -> [String] {
        var collected: Set<String> = []
        for key in root.keys where !Self.rootRecognizedKeys.contains(key) {
            collected.insert(key)
        }
        for key in filter.keys where !Self.filterRecognizedKeys.contains(key) {
            collected.insert(key)
        }
        return collected.sorted()
    }

    private static func warning(code: String, message: String) -> ReportWarning {
        ReportWarning(code: code, message: message, sourceStage: warningSourceStage)
    }
}
