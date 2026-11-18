//
//  FilterParseResultTests.swift
//  FilterKit Stage 2 — C3-C1 统一 Result 模型专项测试
//
//  硬门禁：五态互斥；`filter` 仅 `valid` 非空；状态原始值与 S1-06 报告
//  逐字一致；SkippedField 证据字段口径对齐契约 §5.2。本文件不覆盖 RootHide
//  业务规则（见 RootHideFilterParserTests.swift）。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class FilterParseResultTests: XCTestCase {

    // MARK: - 五态原始值（PC3-4）

    func testStatusRawValuesMatchBaseline() {
        XCTAssertEqual(FilterParseStatus.valid.rawValue, "valid")
        XCTAssertEqual(FilterParseStatus.parseFailed.rawValue, "parse_failed")
        XCTAssertEqual(FilterParseStatus.typeMismatch.rawValue, "type_mismatch")
        XCTAssertEqual(FilterParseStatus.readFailed.rawValue, "read_failed")
        XCTAssertEqual(FilterParseStatus.notParsed.rawValue, "not_parsed")
    }

    // MARK: - 状态与规则互斥（PC3-5 / §8）

    func testValidResultCarriesFilterRule() {
        let rule = FilterRule(bundles: ["com.example.app"])
        let result = FilterParseResult(
            pairingKey: "pair-1",
            route: "roothide",
            status: .valid,
            filter: rule,
            isTweakManager: false,
            plistFormat: "xml",
            readStatus: "ok"
        )
        XCTAssertEqual(result.status, .valid)
        XCTAssertNotNil(result.filter)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
        XCTAssertNil(result.reason)
    }

    func testNonValidStatesCarryNoFilterRule() {
        let states: [FilterParseStatus] = [.parseFailed, .typeMismatch, .readFailed, .notParsed]
        for state in states {
            let result = FilterParseResult(
                pairingKey: "pair-1",
                status: state,
                reason: "probe-reason"
            )
            XCTAssertNil(result.filter, "\(state.rawValue) 不得携带 FilterRule")
            XCTAssertNotNil(result.reason)
        }
    }

    // MARK: - SkippedField 证据口径（§5.2）

    func testSkippedFieldIndexDefaultsToNil() {
        let field = SkippedField(
            key: "Filter",
            reason: "filter_type",
            expectedType: "object",
            observedType: "string",
            route: "roothide"
        )
        XCTAssertNil(field.index)
        XCTAssertEqual(field.route, "roothide")
    }

    func testSkippedFieldElementIndexPreserved() {
        let field = SkippedField(
            key: "Bundles",
            reason: "element_type",
            expectedType: "string",
            observedType: "number",
            route: "roothide",
            index: 2
        )
        XCTAssertEqual(field.index, 2)
    }

    // MARK: - 透传信号与 Codable 往返

    func testPassthroughFieldsRetained() {
        let result = FilterParseResult(
            pairingKey: "pair-9",
            dylibPath: "/usr/lib/TweakInject/lib.dylib",
            plistPath: "/usr/lib/TweakInject/lib.plist",
            route: "roothide",
            status: .readFailed,
            reason: "access_denied",
            plistFormat: "unknown",
            readStatus: "access_denied"
        )
        XCTAssertEqual(result.pairingKey, "pair-9")
        XCTAssertEqual(result.dylibPath, "/usr/lib/TweakInject/lib.dylib")
        XCTAssertEqual(result.plistPath, "/usr/lib/TweakInject/lib.plist")
        XCTAssertEqual(result.route, "roothide")
        XCTAssertEqual(result.readStatus, "access_denied")
    }

    func testResultCodableRoundTrip() throws {
        let warning = ReportWarning(
            code: "field_missing",
            message: "Filter.Bundles 缺失，按空数组处理",
            sourceStage: "stage2.2-c3"
        )
        let skipped = SkippedField(
            key: "(root)",
            reason: "root_type",
            expectedType: "object",
            observedType: "array",
            route: "roothide"
        )
        let result = FilterParseResult(
            pairingKey: "pair-rt",
            status: .typeMismatch,
            reason: "root_type",
            skippedFields: [skipped],
            otherKeys: ["CustomKey"],
            warnings: [warning],
            plistFormat: "xml",
            readStatus: "ok"
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(FilterParseResult.self, from: data)

        XCTAssertEqual(decoded, result)
        XCTAssertEqual(decoded.status, .typeMismatch)
        XCTAssertEqual(decoded.skippedFields.count, 1)
        XCTAssertEqual(decoded.otherKeys, ["CustomKey"])
        XCTAssertEqual(decoded.warnings.first?.sourceStage, "stage2.2-c3")
    }
}
