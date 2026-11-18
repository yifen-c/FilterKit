//
//  RootHideFilterParserTests.swift
//  FilterKit Stage 2 — C3-C1 RootHide 严格类型 Parser 专项测试
//
//  分组对齐契约 §6：A 根节点 / Filter 字典；B IsTweakManager 类型；
//  C Bundles / Classes / Executables；D CoreFoundationVersion；
//  F otherKeys / 证据；H 确定性与输入不可变。Rootless 口径与 Engine
//  编排不在本批次覆盖（C3-C2 / C3-C3）。
//
//  硬门禁：任一受约束字段类型错误整份 `type_mismatch`；Bool 不得被当作
//  数字；可选字段缺失容忍为 `[]` / `false` / `nil`，与类型错误区分。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class RootHideFilterParserTests: XCTestCase {

    private let parser = RootHideFilterParser()

    private func parse(_ object: Any?) -> FilterParseResult {
        parser.parse(object: object, pairingKey: "pair-test", plistFormat: "xml", readStatus: "ok")
    }

    // MARK: - A 根节点 / Filter 字典

    func testEmptyFilterIsValidWithEmptyRule() {
        let result = parse(["Filter": [String: Any]()])
        XCTAssertEqual(result.status, .valid)
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.filter?.bundles, [])
        XCTAssertEqual(result.filter?.classes, [])
        XCTAssertEqual(result.filter?.executables, [])
        XCTAssertNil(result.filter?.coreFoundationVersion)
        XCTAssertEqual(result.isTweakManager, false)
    }

    func testRootArrayIsTypeMismatch() {
        let result = parse([1, 2])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "root_type")
        XCTAssertNil(result.filter)
        let skipped = try? XCTUnwrap(result.skippedFields.first)
        XCTAssertEqual(skipped?.key, "(root)")
        XCTAssertEqual(skipped?.expectedType, "object")
        XCTAssertEqual(skipped?.observedType, "array")
        XCTAssertEqual(skipped?.route, "roothide")
    }

    func testRootStringIsTypeMismatch() {
        let result = parse("not-a-dictionary")
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "root_type")
        XCTAssertEqual(result.skippedFields.first?.observedType, "string")
    }

    func testFilterMissingIsTypeMismatch() {
        let result = parse([String: Any]())
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "filter_missing")
        XCTAssertEqual(result.skippedFields.first?.observedType, "missing")
    }

    func testFilterNullIsTreatedAsMissing() {
        let result = parse(["Filter": NSNull()])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "filter_missing")
    }

    func testFilterNonDictionaryIsTypeMismatch() {
        let result = parse(["Filter": "bundles-as-string"])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "filter_type")
        XCTAssertEqual(result.skippedFields.first?.observedType, "string")
    }

    // MARK: - B IsTweakManager 类型

    func testIsTweakManagerMissingDefaultsFalse() {
        let result = parse(["Filter": [String: Any]()])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.isTweakManager, false)
    }

    func testIsTweakManagerTrueAccepted() {
        let result = parse(["Filter": [String: Any](), "IsTweakManager": true])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.isTweakManager, true)
    }

    func testIsTweakManagerFalseAccepted() {
        let result = parse(["Filter": [String: Any](), "IsTweakManager": false])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.isTweakManager, false)
    }

    func testIsTweakManagerNumberIsTypeMismatch() {
        let result = parse(["Filter": [String: Any](), "IsTweakManager": NSNumber(value: 1)])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "field_type")
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.key, "IsTweakManager")
        XCTAssertEqual(skipped?.expectedType, "boolean")
        XCTAssertEqual(skipped?.observedType, "number")
    }

    func testIsTweakManagerStringIsTypeMismatch() {
        let result = parse(["Filter": [String: Any](), "IsTweakManager": "yes"])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "field_type")
    }

    // MARK: - C Bundles / Classes / Executables

    func testStringArrayAccepted() {
        let filter: [String: Any] = [
            "Bundles": ["com.example.app"],
            "Classes": ["ExampleHook"],
            "Executables": ["example-daemon"]
        ]
        let result = parse(["Filter": filter])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(result.filter?.classes, ["ExampleHook"])
        XCTAssertEqual(result.filter?.executables, ["example-daemon"])
    }

    func testBundlesNotArrayIsTypeMismatch() {
        let result = parse(["Filter": ["Bundles": "com.example.app"]])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "field_type")
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.key, "Bundles")
        XCTAssertEqual(skipped?.reason, "not_array")
        XCTAssertEqual(skipped?.expectedType, "string[]")
        XCTAssertEqual(skipped?.observedType, "string")
    }

    func testClassesNullElementIsTypeMismatch() {
        let result = parse(["Filter": ["Classes": [NSNull()]]])
        XCTAssertEqual(result.status, .typeMismatch)
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.reason, "null_element")
        XCTAssertEqual(skipped?.index, 0)
    }

    func testExecutableNumberElementIsTypeMismatch() {
        let result = parse(["Filter": ["Executables": [NSNumber(value: 1)]]])
        XCTAssertEqual(result.status, .typeMismatch)
        let skipped = result.skippedFields.first
        XCTAssertEqual(skipped?.reason, "element_type")
        XCTAssertEqual(skipped?.expectedType, "string")
        XCTAssertEqual(skipped?.observedType, "number")
        XCTAssertEqual(skipped?.index, 0)
    }

    func testBundlesNullElementIsTolerated() {
        let result = parse(["Filter": ["Bundles": [NSNull(), "com.example.app"]]])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
    }

    func testClassesNotArrayIsTypeMismatch() {
        let result = parse(["Filter": ["Classes": NSNumber(value: 7)]])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.skippedFields.first?.reason, "not_array")
    }

    func testEmptyStringElementRetainedWithWarning() {
        let result = parse(["Filter": ["Bundles": ["", "com.example.app"]]])
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["", "com.example.app"])
        XCTAssertTrue(result.warnings.contains { $0.code == "empty_element" })
    }

    // MARK: - D CoreFoundationVersion

    func testCFVLengthOneMapsToMaxMode() {
        let result = parse(["Filter": ["CoreFoundationVersion": [NSNumber(value: 1600)]]])
        XCTAssertEqual(result.status, .valid)
        let cfv = result.filter?.coreFoundationVersion
        XCTAssertEqual(cfv?.mode, .max)
        XCTAssertNil(cfv?.min)
        XCTAssertEqual(cfv?.max, 1600)
    }

    func testCFVLengthTwoMapsToRangeMode() {
        let result = parse(["Filter": ["CoreFoundationVersion": [NSNumber(value: 1500), NSNumber(value: 1700)]]])
        XCTAssertEqual(result.status, .valid)
        let cfv = result.filter?.coreFoundationVersion
        XCTAssertEqual(cfv?.mode, .range)
        XCTAssertEqual(cfv?.min, 1500)
        XCTAssertEqual(cfv?.max, 1700)
    }

    func testCFVLengthThreeIsValidWithLengthClue() {
        let result = parse(["Filter": ["CoreFoundationVersion": [1500, 1600, 1700]]])
        XCTAssertEqual(result.status, .valid)
        XCTAssertNil(result.filter?.coreFoundationVersion)
        let clue = result.skippedFields.first
        XCTAssertEqual(clue?.reason, "unsupported_length")
        XCTAssertEqual(clue?.expectedType, "number[1|2]")
        XCTAssertEqual(clue?.observedType, "number[3]")
        XCTAssertTrue(result.warnings.contains { $0.code == "versions_length_unhandled" })
    }

    func testCFVLengthZeroIsValidWithLengthClue() {
        let result = parse(["Filter": ["CoreFoundationVersion": []]])
        XCTAssertEqual(result.status, .valid)
        XCTAssertNil(result.filter?.coreFoundationVersion)
        XCTAssertEqual(result.skippedFields.first?.observedType, "number[0]")
    }

    func testCFVStringElementIsTypeMismatch() {
        let result = parse(["Filter": ["CoreFoundationVersion": ["1600"]]])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "versions_type")
    }

    func testCFVBoolElementIsNotNumber() {
        let result = parse(["Filter": ["CoreFoundationVersion": [NSNumber(value: true)]]])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.skippedFields.first?.observedType, "boolean")
    }

    func testCFVNonArrayIsTypeMismatch() {
        let result = parse(["Filter": ["CoreFoundationVersion": "1600"]])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.reason, "versions_type")
    }

    func testCFVMissingIsNil() {
        let result = parse(["Filter": ["Bundles": ["com.example.app"]]])
        XCTAssertEqual(result.status, .valid)
        XCTAssertNil(result.filter?.coreFoundationVersion)
    }

    // MARK: - F otherKeys / 证据归集

    func testOtherKeysCollectedDeduplicatedAndSorted() {
        let filter: [String: Any] = [
            "Bundles": ["com.example.app"],
            "FilterCustom": "x",
            "Another": 2
        ]
        let root: [String: Any] = ["Filter": filter, "RootCustom": NSNumber(value: 1)]
        let result = parse(root)
        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.otherKeys, ["Another", "FilterCustom", "RootCustom"])
        XCTAssertEqual(result.filter?.otherKeys, ["Another", "FilterCustom", "RootCustom"])
    }

    func testMismatchResultCarriesNoOtherKeys() {
        let result = parse(["Filter": "bad", "UnknownRootKey": 1])
        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertEqual(result.otherKeys, [])
    }

    func testSkippedFieldsRouteIsRootHide() {
        let result = parse(["Filter": 42])
        XCTAssertEqual(result.skippedFields.allSatisfy { $0.route == "roothide" }, true)
    }

    func testMissingArrayFieldsRaiseFieldMissingWarnings() {
        let result = parse(["Filter": [String: Any]()])
        let codes = result.warnings.map { $0.code }
        XCTAssertTrue(codes.contains("field_missing"))
        XCTAssertEqual(codes.filter { $0 == "field_missing" }.count, 3)
    }

    // MARK: - H 确定性 / 不可变

    func testRepeatedParseProducesEqualResult() {
        let filter: [String: Any] = [
            "Bundles": ["com.example.app", "com.example.two"],
            "Classes": ["Hook"],
            "CoreFoundationVersion": [1600]
        ]
        let first = parse(["Filter": filter, "IsTweakManager": true, "Note": "keep"])
        let second = parse(["Filter": filter, "IsTweakManager": true, "Note": "keep"])
        XCTAssertEqual(first, second)
    }

    func testParserDoesNotMutateInputRoot() {
        let filter: [String: Any] = ["Bundles": ["com.example.app"]]
        let root: [String: Any] = ["Filter": filter, "Marker": "original"]
        _ = parse(root)
        XCTAssertEqual(root["Marker"] as? String, "original")
        XCTAssertEqual((root["Filter"] as? [String: Any])?["Bundles"] as? [String], ["com.example.app"])
    }
}
