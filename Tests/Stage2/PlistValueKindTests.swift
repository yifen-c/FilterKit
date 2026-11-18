//
//  PlistValueKindTests.swift
//  FilterKit Stage 2 — C3-B 类型识别专项测试（PlistValueClassifier）
//
//  硬门禁：Bool 与 NSNumber 必须实测区分。NSNumber(bool) 不得被归为数字；
//  整数 / 浮点 NSNumber 归为数字；其余 plist 类型与未知对象逐类断言。
//

import Foundation
import XCTest
@testable import Core

final class PlistValueKindTests: XCTestCase {

    // MARK: - Bool / NSNumber 区分（硬门禁）

    func testSwiftBoolClassifiesAsBoolean() {
        XCTAssertEqual(PlistValueClassifier.classify(true), .boolean)
        XCTAssertEqual(PlistValueClassifier.classify(false), .boolean)
    }

    func testNumberBridgedFromBoolClassifiesAsBooleanNotNumber() {
        // 陷阱：NSNumber(value: true) 在 `is NSNumber` 下同样命中，必须排除。
        XCTAssertEqual(PlistValueClassifier.classify(NSNumber(value: true)), .boolean)
        XCTAssertEqual(PlistValueClassifier.classify(NSNumber(value: false)), .boolean)
        XCTAssertFalse(PlistValueClassifier.isNumber(NSNumber(value: true)))
        XCTAssertTrue(PlistValueClassifier.isBoolean(NSNumber(value: true)))
    }

    func testIntegerNSNumberClassifiesAsNumber() {
        XCTAssertEqual(PlistValueClassifier.classify(NSNumber(value: 1)), .number)
        XCTAssertEqual(PlistValueClassifier.classify(NSNumber(value: -42)), .number)
        XCTAssertTrue(PlistValueClassifier.isNumber(NSNumber(value: 7)))
    }

    func testFloatingNSNumberClassifiesAsNumber() {
        XCTAssertEqual(PlistValueClassifier.classify(NSNumber(value: 1.5)), .number)
        XCTAssertEqual(PlistValueClassifier.classify(NSNumber(value: 0.0)), .number)
    }

    // MARK: - 其余 plist 类型

    func testStringClassifiesAsString() {
        XCTAssertEqual(PlistValueClassifier.classify("text"), .string)
    }

    func testArrayClassifiesAsArray() {
        XCTAssertEqual(PlistValueClassifier.classify(["a", "b"]), .array)
    }

    func testDictionaryClassifiesAsDictionary() {
        XCTAssertEqual(PlistValueClassifier.classify(["k": "v"]), .dictionary)
    }

    func testDataClassifiesAsData() {
        XCTAssertEqual(PlistValueClassifier.classify(Data([0x01])), .data)
    }

    func testDateClassifiesAsDate() {
        XCTAssertEqual(PlistValueClassifier.classify(Date()), .date)
    }

    func testNilAndNSNullClassifyAsNull() {
        XCTAssertEqual(PlistValueClassifier.classify(nil), .null)
        XCTAssertEqual(PlistValueClassifier.classify(NSNull()), .null)
    }

    func testUnsupportedObjectClassifiesAsUnknown() {
        XCTAssertEqual(PlistValueClassifier.classify(UUID()), .unknown)
    }
}
