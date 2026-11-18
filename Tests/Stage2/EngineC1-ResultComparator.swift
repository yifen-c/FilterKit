//
//  EngineC1-ResultComparator.swift
//  FilterKit Stage 2 — Engine-C1 全维度基线比较器（测试目标专用）
//
//  对齐 `run.js compareResult`：不只比较状态，逐条核对五态、顶层 reason、
//  FilterRule 三数组与 CFV、otherKeys、字段级错误证据（key/reason/expected/
//  observed/index）。比较器只读取测试层期望与既有 Core 类型，不修改生产
//  模型；期望值不为迁就当前实现而改动。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

public enum EngineC1ResultComparator {

    // MARK: - 状态 / reason

    /// 核对条目五态；期望为 nil 时不断言状态。
    public static func assertStatus(_ actual: FilterParseStatus,
                                    expected: EngineC1ExpectedStatus?,
                                    base: String?,
                                    file: StaticString = #filePath,
                                    line: UInt = #line) {
        guard let expected else { return }
        XCTAssertEqual(actual.rawValue, expected.rawValue,
                       "条目 \(base ?? "-") 五态不符", file: file, line: line)
    }

    /// 核对顶层 reason；`expected == nil` 表示期望 valid（reason 为 nil）。
    public static func assertReason(_ actual: String?,
                                    expected: String?,
                                    base: String?,
                                    file: StaticString = #filePath,
                                    line: UInt = #line) {
        XCTAssertEqual(actual, expected,
                       "条目 \(base ?? "-") 顶层 reason 不符", file: file, line: line)
    }

    // MARK: - 规则期望装配（注册表覆盖 metadata 未承载的 CFV / otherKeys）

    public static func mergedRule(baseline: EngineC1BaselineCase,
                                  metadata: EngineC1Metadata?,
                                  base: String) -> EngineC1ExpectedRule? {
        let meta = metadata?.expected.filterByBase[base]
        let reg = baseline.expectedRulesByBase[base]
        guard meta != nil || reg != nil else { return nil }
        return EngineC1ExpectedRule(
            bundles: reg?.bundles ?? meta?.bundles,
            classes: reg?.classes ?? meta?.classes,
            executables: reg?.executables ?? meta?.executables,
            cfvMode: reg?.cfvMode,
            cfvMin: reg?.cfvMin,
            cfvMax: reg?.cfvMax,
            otherKeys: reg?.otherKeys ?? metadata?.expected.otherKeysByBase[base]
        )
    }

    // MARK: - 规则

    /// 核对成功规则；期望规则为 nil 时跳过规则字段断言。
    public static func assertRule(_ actual: FilterRule?,
                                  expected: EngineC1ExpectedRule?,
                                  status: FilterParseStatus,
                                  base: String?,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) {
        // 非 valid 恒无规则（冻结红线）。
        guard status == .valid else {
            XCTAssertNil(actual, "条目 \(base ?? "-") 非 valid 不得带规则",
                         file: file, line: line)
            return
        }
        guard let expected else { return }
        guard let actual else {
            XCTFail("条目 \(base ?? "-") valid 规则缺失", file: file, line: line)
            return
        }

        if let wanted = expected.bundles {
            XCTAssertEqual(actual.bundles, wanted, "条目 \(base ?? "-") Bundles 不符",
                           file: file, line: line)
        }
        if let wanted = expected.classes {
            XCTAssertEqual(actual.classes, wanted, "条目 \(base ?? "-") Classes 不符",
                           file: file, line: line)
        }
        if let wanted = expected.executables {
            XCTAssertEqual(actual.executables, wanted, "条目 \(base ?? "-") Executables 不符",
                           file: file, line: line)
        }
        if let wantedKeys = expected.otherKeys {
            XCTAssertEqual(actual.otherKeys, wantedKeys, "条目 \(base ?? "-") 规则 otherKeys 不符",
                           file: file, line: line)
        }

        if let mode = expected.cfvMode {
            let cfv = actual.coreFoundationVersion
            XCTAssertEqual(cfv?.mode, mode, "条目 \(base ?? "-") CFV 模式不符",
                           file: file, line: line)
            if let min = expected.cfvMin {
                XCTAssertEqual(cfv?.min, min, "条目 \(base ?? "-") CFV min 不符",
                               file: file, line: line)
            }
            if let max = expected.cfvMax {
                XCTAssertEqual(cfv?.max, max, "条目 \(base ?? "-") CFV max 不符",
                               file: file, line: line)
            }
        } else if expected.cfvMin == nil && expected.cfvMax == nil {
            XCTAssertNil(actual.coreFoundationVersion, "条目 \(base ?? "-") CFV 应为 nil",
                         file: file, line: line)
        }
    }

    // MARK: - otherKeys

    public static func assertOtherKeys(_ actual: [String],
                                       expected: [String]?,
                                       base: String?,
                                       file: StaticString = #filePath,
                                       line: UInt = #line) {
        guard let expected else { return }
        XCTAssertEqual(actual, expected, "条目 \(base ?? "-") otherKeys 不符",
                       file: file, line: line)
    }

    // MARK: - 字段级错误证据

    /// 核对字段级证据：期望条目按 key 在位，reason/expected/observed/index
    /// 逐项匹配；不要求 actual 不含额外线索证据。
    public static func assertSkippedFields(_ actual: [SkippedField],
                                            expected: [EngineC1ExpectedSkipped],
                                            base: String?,
                                            file: StaticString = #filePath,
                                            line: UInt = #line) {
        for wanted in expected {
            let match = actual.first { $0.key == wanted.key }
            guard let match else {
                XCTFail("条目 \(base ?? "-") 缺证据字段 \(wanted.key)",
                        file: file, line: line)
                continue
            }
            XCTAssertEqual(match.reason, wanted.reason,
                           "条目 \(base ?? "-") \(wanted.key) reason 不符",
                           file: file, line: line)
            if let expectedType = wanted.expectedType {
                XCTAssertEqual(match.expectedType, expectedType,
                               "条目 \(base ?? "-") \(wanted.key) 期望类型不符",
                               file: file, line: line)
            }
            if let observedType = wanted.observedType {
                XCTAssertEqual(match.observedType, observedType,
                               "条目 \(base ?? "-") \(wanted.key) 观测类型不符",
                               file: file, line: line)
            }
            if let index = wanted.index {
                XCTAssertEqual(match.index, index,
                               "条目 \(base ?? "-") \(wanted.key) 元素下标不符",
                               file: file, line: line)
            }
            // 未在基线中冻结的下标（如 PARSE-009-B 元素级口径待复核）不强制断言 nil，
            // 与 observedType 的可选断言口径一致；差异留待 Runner 对照后独立复核。
        }
    }

    // MARK: - 告警

    /// 提取告警 code 集合（去重排序），便于子集核对。
    public static func warningCodes(_ warnings: [ReportWarning]) -> [String] {
        Array(Set(warnings.map(\.code))).sorted()
    }

    /// 核对期望告警 code 全部在位（快照级补充告警如 `partial_parsing` 不排除）。
    public static func assertWarningsContain(_ warnings: [ReportWarning],
                                             expected: [String],
                                             file: StaticString = #filePath,
                                             line: UInt = #line) {
        let codes = Set(warnings.map(\.code))
        for wanted in expected {
            XCTAssertTrue(codes.contains(wanted), "缺告警 \(wanted)",
                          file: file, line: line)
        }
    }
}
