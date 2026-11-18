//
//  RootlessFilterParserTests.swift
//  FilterKit Stage 2 — C3-C2 Rootless Codable Parser 专项测试
//
//  分组对齐契约 §4.2 与建议 MD：Codable 三字段（Bundles / Executables /
//  UnloadAfter）；Optional 缺失；类型错误；根节点 / Filter 结构错误；
//  otherKeys；Mapper 规范化；确定性与输入不可变。RootHide 严格规则与 Engine
//  编排不在本批次覆盖（C3-C1 / C3-C3）。
//
//  硬门禁：Rootless Codable 解码失败一律 `parse_failed`，不得套 RootHide
//  `type_mismatch`；`filter` 仅 `valid` 非空；`isTweakManager` 恒 `nil`；
//  Classes / CoreFoundationVersion / IsTweakManager 入 otherKeys 不判失败。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class RootlessFilterParserTests: XCTestCase {

    private let parser = RootlessFilterParser()

    private func parse(_ object: Any?) -> FilterParseResult {
        parser.parse(object: object, pairingKey: "pair-rl", plistFormat: "xml", readStatus: "ok")
    }

    // MARK: - A 正常解码与规范化

    func testBundlesAndExecutablesLowercased() {
        let filter: [String: Any] = [
            "Bundles": ["Com.Example.App"],
            "Executables": ["RLApp"]
        ]
        let result = parse(["Filter": filter])

        XCTAssertEqual(result.status, .valid)
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(result.filter?.executables, ["rlapp"])
        XCTAssertEqual(result.filter?.classes, [])
        XCTAssertNil(result.filter?.coreFoundationVersion)
        XCTAssertNil(result.isTweakManager)
    }

    func testUnloadAfterTrueAccepted() {
        let result = parse(["Filter": [String: Any](), "UnloadAfter": true])
        XCTAssertEqual(result.status, .valid)
        XCTAssertNil(result.reason)
    }

    func testUnloadAfterFalseAccepted() {
        let result = parse(["Filter": [String: Any](), "UnloadAfter": false])
        XCTAssertEqual(result.status, .valid)
    }

    func testAllFieldsMissingValidEmptyRule() {
        let result = parse(["Filter": [String: Any]()])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, [])
        XCTAssertEqual(result.filter?.executables, [])
        XCTAssertEqual(result.filter?.classes, [])
        XCTAssertNil(result.filter?.coreFoundationVersion)
        XCTAssertNil(result.isTweakManager)
    }

    func testEmptyArraysAccepted() {
        let filter: [String: Any] = ["Bundles": [], "Executables": []]
        let result = parse(["Filter": filter])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, [])
        XCTAssertEqual(result.filter?.executables, [])
    }

    func testUnknownRouteFieldsGoToOtherKeysNotJudged() {
        // 对齐基线 PARSE-015：Classes / CoreFoundationVersion / IsTweakManager
        // 不纳入 Rootless 模型，记入 otherKeys，不判解码失败。
        let root: [String: Any] = [
            "UnloadAfter": true,
            "IsTweakManager": true,
            "Classes": ["RLClass"],
            "CoreFoundationVersion": [1600],
            "Filter": [
                "Bundles": ["Com.Example.App"],
                "Executables": ["RLApp"]
            ]
        ]
        let result = parse(root)

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(result.filter?.executables, ["rlapp"])
        XCTAssertEqual(result.otherKeys, ["Classes", "CoreFoundationVersion", "IsTweakManager"])
        XCTAssertEqual(result.filter?.otherKeys, ["Classes", "CoreFoundationVersion", "IsTweakManager"])
        XCTAssertEqual(result.skippedFields, [])
        XCTAssertEqual(result.warnings, [])
    }

    func testOtherKeysSortedAndCaseSensitive() {
        let root: [String: Any] = [
            "ZebraRoot": 1,
            "AlphaRoot": 2,
            "Filter": [
                "ZebraFilter": "x",
                "AlphaFilter": "y",
                "bundles": ["lowercase-key-unknown"]
            ]
        ]
        let result = parse(root)

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.otherKeys, [
            "AlphaFilter", "AlphaRoot", "ZebraFilter", "ZebraRoot", "bundles"
        ])
    }

    func testMissingArraysRaiseFieldMissingWarnings() {
        let result = parse(["Filter": [String: Any]()])
        XCTAssertEqual(result.status, .valid)
        let codes = result.warnings.map { $0.code }
        XCTAssertTrue(codes.contains("field_missing"))
        XCTAssertEqual(result.warnings.filter { $0.code == "field_missing" }.count, 2)
        XCTAssertTrue(codes.contains("empty_filter"))
    }

    func testUnknownKeySharedAcrossRootAndFilterDeduplicated() {
        let root: [String: Any] = [
            "SharedKey": 1,
            "Filter": ["SharedKey": "x", "Bundles": ["com.example.app"]]
        ]
        let result = parse(root)
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.otherKeys, ["SharedKey"])
    }

    // MARK: - B 根节点 / Filter 结构错误（parse_failed）

    func testRootArrayIsParseFailed() {
        let result = parse(["com.example.app"])
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "root_type")
        XCTAssertNil(result.filter)
        XCTAssertNil(result.isTweakManager)
        XCTAssertEqual(result.skippedFields.first?.key, "(root)")
        XCTAssertEqual(result.skippedFields.first?.observedType, "array")
    }

    func testRootStringIsParseFailed() {
        let result = parse("not-a-dictionary")
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "root_type")
        XCTAssertEqual(result.skippedFields.first?.observedType, "string")
    }

    func testFilterMissingIsParseFailed() {
        let result = parse([String: Any]())
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "filter_missing")
        XCTAssertEqual(result.skippedFields.first?.expectedType, "object")
        XCTAssertEqual(result.skippedFields.first?.observedType, "missing")
    }

    func testFilterNullIsParseFailed() {
        let result = parse(["Filter": NSNull()])
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "filter_missing")
    }

    func testFilterNonDictionaryIsParseFailed() {
        let result = parse(["Filter": "not-a-dictionary"])
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "filter_type")
        XCTAssertEqual(result.skippedFields.first?.observedType, "string")
    }

    // MARK: - C 字段类型错误（parse_failed，field_type / codable_type 证据）

    func testBundlesNotArrayIsParseFailed() {
        let result = parse(["Filter": ["Bundles": "com.example.app"]])
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "field_type")
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.key, "Bundles")
        XCTAssertEqual(skipped?.reason, "codable_type")
        XCTAssertEqual(skipped?.expectedType, "string[]")
        XCTAssertEqual(skipped?.observedType, "string")
    }

    func testExecutablesNotArrayIsParseFailed() {
        let result = parse(["Filter": ["Executables": NSNumber(value: 7)]])
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "field_type")
        XCTAssertEqual(result.skippedFields.first?.observedType, "number")
    }

    func testBundlesElementNonStringIsParseFailed() {
        let result = parse(["Filter": ["Bundles": [NSNumber(value: 1)]]])
        XCTAssertEqual(result.status, .parseFailed)
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.reason, "codable_type")
        XCTAssertEqual(skipped?.expectedType, "string")
        XCTAssertEqual(skipped?.observedType, "number")
        XCTAssertEqual(skipped?.index, 0)
    }

    func testUnloadAfterNonBooleanIsParseFailed() {
        let result = parse(["Filter": [String: Any](), "UnloadAfter": NSNumber(value: 1)])
        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertEqual(result.reason, "field_type")
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.key, "UnloadAfter")
        XCTAssertEqual(skipped?.expectedType, "boolean")
        XCTAssertEqual(skipped?.observedType, "number")
    }

    func testFailureCarriesNoFilterRule() {
        let failures: [Any?] = [
            ["Filter": "x"],
            ["Filter": ["Bundles": 1]],
            ["Filter": [String: Any](), "UnloadAfter": NSNumber(value: 0)]
        ]
        for object in failures {
            let result = parse(object)
            XCTAssertEqual(result.status, .parseFailed)
            XCTAssertNil(result.filter)
            XCTAssertNil(result.isTweakManager)
            XCTAssertEqual(result.otherKeys, [])
        }
    }

    // MARK: - D 确定性 / 不可变 / 隔离

    func testRepeatedParseProducesEqualResult() {
        let root: [String: Any] = [
            "UnloadAfter": true,
            "Filter": ["Bundles": ["Com.Example.App"], "Executables": ["RLApp"], "Custom": 1]
        ]
        let first = parse(root)
        let second = parse(root)
        XCTAssertEqual(first, second)
    }

    func testParserDoesNotMutateInputRoot() {
        var root: [String: Any] = [
            "Filter": ["Bundles": ["Com.Example.App"]],
            "UnloadAfter": false
        ]
        let snapshot = root.description
        _ = parse(root)
        XCTAssertEqual(root.description, snapshot)
        root["Added"] = 1
        _ = parse(root)
        XCTAssertEqual(root["Added"] as? Int, 1)
    }

    func testRouteEvidenceIsRootless() {
        let result = parse(["Filter": [String: Any]()])
        XCTAssertEqual(result.route, "rootless")
        XCTAssertTrue(result.skippedFields.allSatisfy { $0.route == "rootless" })
    }
}
