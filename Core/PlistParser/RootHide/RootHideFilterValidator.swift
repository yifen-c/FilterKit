//
//  RootHideFilterValidator.swift
//  FilterKit Core — PlistParser RootHide（C3-C1）
//
//  RootHide 严格规则核对（契约 §4.1，PC3-11）。任一受约束字段类型错误，
// 整份结果归 `type_mismatch`；可选字段缺失可容忍，与类型错误严格区分。
// 校验只产出证据与归一化中间值，不构造公共 `FilterRule`（映射由 Mapper
// 负责）。
//

import Foundation

/// RootHide 校验结果（Core 中间层）。
public struct RootHideValidation {
    /// 硬失败证据；非空即整份 `type_mismatch`。
    public let errors: [SkippedField]
    /// 不阻断成功的线索（如版本长度不被支持）。
    public let clues: [SkippedField]
    /// 归一化顶层字典；根非字典为 `nil`。
    public let root: [String: Any]?
    /// 归一化 Filter 字典；缺失 / 非字典为 `nil`。
    public let filter: [String: Any]?
    /// 顶层布尔值；缺失 / 空指针按容忍口径留 `nil`，由 Mapper 归一为 `false`。
    public let isTweakManager: Bool?
    /// 已校验字符串数组。
    public let bundles: [String]
    public let classes: [String]
    public let executables: [String]
    /// 长度 1/2 且元素均为数字的版本数组；其余为 `nil`。
    public let coreFoundationVersion: [Any]?

    /// 是否存在硬失败。
    public var isMismatch: Bool { !errors.isEmpty }

    public init(errors: [SkippedField],
                clues: [SkippedField],
                root: [String: Any]?,
                filter: [String: Any]?,
                isTweakManager: Bool?,
                bundles: [String],
                classes: [String],
                executables: [String],
                coreFoundationVersion: [Any]?) {
        self.errors = errors
        self.clues = clues
        self.root = root
        self.filter = filter
        self.isTweakManager = isTweakManager
        self.bundles = bundles
        self.classes = classes
        self.executables = executables
        self.coreFoundationVersion = coreFoundationVersion
    }
}

/// RootHide 路线校验器（纯函数，无状态）。
public enum RootHideFilterValidator {

    /// RootHide 顶层识别键。
    public static let rootRecognizedKeys: Set<String> = ["Filter", "IsTweakManager"]
    /// RootHide Filter 内识别键。
    public static let filterRecognizedKeys: Set<String> = [
        "Bundles", "Classes", "Executables", "CoreFoundationVersion"
    ]

    private static let route = "roothide"

    /// 对解码对象执行 RootHide 严格核对。
    public static func validate(object: Any?) -> RootHideValidation {
        var errors: [SkippedField] = []
        var clues: [SkippedField] = []

        // 1. 根节点必须为字典。
        guard let root = RootHideFilterTypeChecker.dictionary(object) else {
            errors.append(SkippedField(
                key: "(root)",
                reason: "root_type",
                expectedType: "object",
                observedType: RootHideFilterTypeChecker.observedTypeWord(object),
                route: route
            ))
            return RootHideValidation(
                errors: errors, clues: clues,
                root: nil, filter: nil, isTweakManager: nil,
                bundles: [], classes: [], executables: [],
                coreFoundationVersion: nil
            )
        }

        // 2. Filter 必须存在且为字典；缺失与空指针同口径记 filter_missing。
        let rawFilter = root["Filter"]
        if rawFilter == nil || RootHideFilterTypeChecker.isNull(rawFilter) {
            errors.append(SkippedField(
                key: "Filter",
                reason: "filter_missing",
                expectedType: "object",
                observedType: "missing",
                route: route
            ))
            return RootHideValidation(
                errors: errors, clues: clues,
                root: root, filter: nil, isTweakManager: nil,
                bundles: [], classes: [], executables: [],
                coreFoundationVersion: nil
            )
        }
        guard let filter = RootHideFilterTypeChecker.dictionary(rawFilter) else {
            errors.append(SkippedField(
                key: "Filter",
                reason: "filter_type",
                expectedType: "object",
                observedType: RootHideFilterTypeChecker.observedTypeWord(rawFilter),
                route: route
            ))
            return RootHideValidation(
                errors: errors, clues: clues,
                root: root, filter: nil, isTweakManager: nil,
                bundles: [], classes: [], executables: [],
                coreFoundationVersion: nil
            )
        }

        // 3. IsTweakManager：缺失 / 空指针容忍；出现且非布尔 → field_type。
        var isTweakManager: Bool?
        let rawManager = root["IsTweakManager"]
        if let manager = rawManager, !RootHideFilterTypeChecker.isNull(manager) {
            if RootHideFilterTypeChecker.isBoolean(manager) {
                isTweakManager = manager as? Bool
            } else {
                errors.append(SkippedField(
                    key: "IsTweakManager",
                    reason: "field_type",
                    expectedType: "boolean",
                    observedType: RootHideFilterTypeChecker.observedTypeWord(manager),
                    route: route
                ))
            }
        }

        // 4. Bundles / Classes / Executables 字符串数组。
        let bundles = checkStringArray(
            filter["Bundles"], key: "Bundles", allowNullElement: true, errors: &errors)
        let classes = checkStringArray(
            filter["Classes"], key: "Classes", allowNullElement: false, errors: &errors)
        let executables = checkStringArray(
            filter["Executables"], key: "Executables", allowNullElement: false, errors: &errors)

        // 5. CoreFoundationVersion：数字数组，长度 1 或 2。
        let cfv = checkCoreFoundationVersion(
            filter["CoreFoundationVersion"],
            errors: &errors, clues: &clues)

        return RootHideValidation(
            errors: errors,
            clues: clues,
            root: root,
            filter: filter,
            isTweakManager: isTweakManager,
            bundles: bundles ?? [],
            classes: classes ?? [],
            executables: executables ?? [],
            coreFoundationVersion: cfv
        )
    }

    // MARK: - 字段级核对

    private static func checkStringArray(_ value: Any?,
                                         key: String,
                                         allowNullElement: Bool,
                                         errors: inout [SkippedField]) -> [String]? {
        // 缺失 / 空指针容忍为 `[]`，不判失败。
        if value == nil || RootHideFilterTypeChecker.isNull(value) {
            return []
        }
        guard let array = RootHideFilterTypeChecker.array(value) else {
            errors.append(SkippedField(
                key: key,
                reason: "not_array",
                expectedType: "string[]",
                observedType: RootHideFilterTypeChecker.observedTypeWord(value),
                route: route
            ))
            return nil
        }

        var strings: [String] = []
        for (index, element) in array.enumerated() {
            if RootHideFilterTypeChecker.isNull(element) {
                if !allowNullElement {
                    errors.append(SkippedField(
                        key: key,
                        reason: "null_element",
                        expectedType: "string",
                        observedType: "null",
                        route: route,
                        index: index
                    ))
                    return nil
                }
                // Bundles 空指针元素容忍，跳过不纳入结果数组。
                continue
            }
            guard RootHideFilterTypeChecker.isString(element) else {
                errors.append(SkippedField(
                    key: key,
                    reason: "element_type",
                    expectedType: "string",
                    observedType: RootHideFilterTypeChecker.observedTypeWord(element),
                    route: route,
                    index: index
                ))
                return nil
            }
            strings.append(element as? String ?? "")
        }
        return strings
    }

    private static func checkCoreFoundationVersion(_ value: Any?,
                                                   errors: inout [SkippedField],
                                                   clues: inout [SkippedField]) -> [Any]? {
        // 缺失 / 空指针容忍为 `nil`。
        if value == nil || RootHideFilterTypeChecker.isNull(value) {
            return nil
        }
        guard let array = RootHideFilterTypeChecker.array(value) else {
            errors.append(SkippedField(
                key: "CoreFoundationVersion",
                reason: "versions_type",
                expectedType: "number[]",
                observedType: RootHideFilterTypeChecker.observedTypeWord(value),
                route: route
            ))
            return nil
        }
        // 元素必须全部为数字（布尔不计为数字）。
        for (index, element) in array.enumerated() {
            guard RootHideFilterTypeChecker.isNumber(element) else {
                errors.append(SkippedField(
                    key: "CoreFoundationVersion",
                    reason: "versions_type",
                    expectedType: "number[]",
                    observedType: RootHideFilterTypeChecker.observedTypeWord(element),
                    route: route,
                    index: index
                ))
                return nil
            }
        }
        guard array.count == 1 || array.count == 2 else {
            clues.append(SkippedField(
                key: "CoreFoundationVersion",
                reason: "unsupported_length",
                expectedType: "number[1|2]",
                observedType: "number[\(array.count)]",
                route: route
            ))
            return nil
        }
        return array
    }
}
