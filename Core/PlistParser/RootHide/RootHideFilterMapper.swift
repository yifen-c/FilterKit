//
//  RootHideFilterMapper.swift
//  FilterKit Core — PlistParser RootHide（C3-C1）
//
//  校验通过后的规则映射（契约 §4.1 版本映射、§4.3 空配置口径、PC3-7
//  otherKeys）。规则载体复用公共 `FilterRule`；缺失字段归一为 `[]` /
//  `nil`，空串元素保留不静默剔除；告警统一 `ReportWarning`。
//

import Foundation
import Models

/// RootHide 路线规则映射器（纯函数，无状态）。
public enum RootHideFilterMapper {

    /// 告警来源阶段（契约 §5.5）。
    public static let warningSourceStage = "stage2.2-c3"

    /// 映射校验结果为成功规则、未覆盖键与条目告警。
    public static func map(validation: RootHideValidation)
        -> (rule: FilterRule, otherKeys: [String], warnings: [ReportWarning]) {
        guard let filter = validation.filter else {
            // 防御性分支：硬失败路径不会进入本映射；空规则兜底。
            let empty = FilterRule()
            return (empty, [], [])
        }

        var warnings: [ReportWarning] = []

        // 数组字段：缺失 / 空数组 / 空串元素分别记录告警。
        let bundles = validatedArray(
            filter: filter, key: "Bundles", values: validation.bundles, warnings: &warnings)
        let classes = validatedArray(
            filter: filter, key: "Classes", values: validation.classes, warnings: &warnings)
        let executables = validatedArray(
            filter: filter, key: "Executables", values: validation.executables, warnings: &warnings)

        let coreFoundationVersion = mapCoreFoundationVersion(validation.coreFoundationVersion)

        // 空 Filter：三数组皆空且无版本约束。
        if bundles.isEmpty && classes.isEmpty && executables.isEmpty && coreFoundationVersion == nil {
            warnings.append(warning(code: "empty_filter", message: "Filter 字典未包含任何有效规则条目"))
        }

        // 版本长度线索对应的兼容告警（不阻断成功）。
        if validation.clues.contains(where: { $0.reason == "unsupported_length" }) {
            warnings.append(warning(
                code: "versions_length_unhandled",
                message: "CoreFoundationVersion 长度不在 1~2 范围内，未构造版本约束"))
        }

        let otherKeys = collectOtherKeys(root: validation.root, filter: filter)

        let rule = FilterRule(
            bundles: bundles,
            classes: classes,
            executables: executables,
            coreFoundationVersion: coreFoundationVersion,
            otherKeys: otherKeys
        )
        return (rule, otherKeys, warnings)
    }

    // MARK: - 私有辅助

    private static func validatedArray(filter: [String: Any],
                                       key: String,
                                       values: [String],
                                       warnings: inout [ReportWarning]) -> [String] {
        let raw = filter[key]
        let missing = raw == nil || RootHideFilterTypeChecker.isNull(raw)

        if missing {
            warnings.append(warning(code: "field_missing", message: "Filter.\(key) 缺失，按空数组处理"))
        } else if values.isEmpty {
            warnings.append(warning(code: "empty_array", message: "Filter.\(key) 为空数组"))
        }

        for (index, item) in values.enumerated() where item.isEmpty {
            warnings.append(warning(
                code: "empty_element",
                message: "Filter.\(key) 第 \(index) 个元素为空串，保留不剔除"))
        }
        return values
    }

    private static func mapCoreFoundationVersion(_ array: [Any]?) -> CoreFoundationVersion? {
        guard let array, !array.isEmpty else { return nil }
        let integers = array.compactMap { ($0 as? NSNumber)?.intValue }
        guard integers.count == array.count else { return nil }

        if integers.count == 1 {
            return CoreFoundationVersion(mode: .max, min: nil, max: integers[0])
        }
        if integers.count == 2 {
            return CoreFoundationVersion(mode: .range, min: integers[0], max: integers[1])
        }
        return nil
    }

    private static func collectOtherKeys(root: [String: Any]?, filter: [String: Any]) -> [String] {
        var collected: Set<String> = []
        if let root {
            for key in root.keys where !RootHideFilterValidator.rootRecognizedKeys.contains(key) {
                collected.insert(key)
            }
        }
        for key in filter.keys where !RootHideFilterValidator.filterRecognizedKeys.contains(key) {
            collected.insert(key)
        }
        return collected.sorted()
    }

    private static func warning(code: String, message: String) -> ReportWarning {
        ReportWarning(code: code, message: message, sourceStage: warningSourceStage)
    }
}
