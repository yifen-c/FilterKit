//
//  PlistDecoderTests.swift
//  FilterKit Stage 2 — C3-B Decoder 专项测试（PlistDecoder）
//
//  覆盖：XML / Binary 解码、非法字节、空 Data、根字典、根数组、嵌套结构、
//  Data / Date 类型。合成编码数据，不触碰真机；不做业务字段规则核对。
//

import Foundation
import XCTest
@testable import Core

final class PlistDecoderTests: XCTestCase {

    private let decoder = PlistDecoder()

    // MARK: - 编码接缝

    private func encode(_ object: Any,
                       format: PropertyListSerialization.PropertyListFormat) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: object,
            format: format,
            options: 0
        )
    }

    // MARK: - Decoder-01 XML plist

    func testDecodeXMLDictionarySucceeds() throws {
        let data = try encode(["Filter": ["Bundles": ["com.example"]]], format: .xml)

        let result = decoder.decode(data: data)

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.object?.format, .xml)
        XCTAssertEqual(PlistValueClassifier.classify(result.object?.rootObject), .dictionary)
        XCTAssertNil(result.errorDescription)
    }

    // MARK: - Decoder-02 Binary plist

    func testDecodeBinaryDictionarySucceeds() throws {
        let data = try encode(["Filter": ["Executables": ["example"]]], format: .binary)

        let result = decoder.decode(data: data)

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.object?.format, .binary)
        XCTAssertEqual(PlistValueClassifier.classify(result.object?.rootObject), .dictionary)
    }

    // MARK: - Decoder-03 非法 plist

    func testDecodeInvalidBytesFails() {
        let data = Data("this is not a property list".utf8)

        let result = decoder.decode(data: data)

        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertNil(result.object)
        XCTAssertNotNil(result.errorDescription)
    }

    // MARK: - Decoder-04 空 Data

    func testDecodeEmptyDataFails() {
        let result = decoder.decode(data: Data())

        XCTAssertEqual(result.status, .parseFailed)
        XCTAssertNil(result.object)
        XCTAssertEqual(result.errorDescription, "empty_data")
    }

    // MARK: - Decoder-05 根对象 Dictionary

    func testRootDictionaryClassifiesAsDictionary() throws {
        let data = try encode(["key": "value"], format: .xml)

        let result = decoder.decode(data: data)

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(PlistValueClassifier.classify(result.object?.rootObject), .dictionary)
    }

    // MARK: - Decoder-06 根对象 Array

    func testRootArrayClassifiesAsArray() throws {
        let data = try encode(["one", "two", "three"], format: .xml)

        let result = decoder.decode(data: data)

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(PlistValueClassifier.classify(result.object?.rootObject), .array)
    }

    // MARK: - Decoder-08 嵌套 Dictionary / Array

    func testNestedDictionaryAndArrayClassifyCorrectly() throws {
        let nested: [String: Any] = [
            "sub": ["k": "v"],
            "arr": [1, true, "text"]
        ]
        let data = try encode(nested, format: .xml)

        let result = decoder.decode(data: data)
        let root = try XCTUnwrap(result.object?.rootObject as? [String: Any])

        XCTAssertEqual(PlistValueClassifier.classify(root["sub"]), .dictionary)
        let arr = try XCTUnwrap(root["arr"] as? [Any])
        XCTAssertEqual(PlistValueClassifier.classify(arr[0]), .number)
        XCTAssertEqual(PlistValueClassifier.classify(arr[1]), .boolean)
        XCTAssertEqual(PlistValueClassifier.classify(arr[2]), .string)
    }

    // MARK: - Decoder-09 Data / Date 类型

    func testDataAndDateValuesClassifyCorrectly() throws {
        let payload: [String: Any] = [
            "blob": Data([0x01, 0x02, 0x03]),
            "when": Date(timeIntervalSince1970: 1_700_000_000)
        ]
        let data = try encode(payload, format: .xml)

        let result = decoder.decode(data: data)
        let root = try XCTUnwrap(result.object?.rootObject as? [String: Any])

        XCTAssertEqual(PlistValueClassifier.classify(root["blob"]), .data)
        XCTAssertEqual(PlistValueClassifier.classify(root["when"]), .date)
    }

    // MARK: - 失败结果不得携带对象

    func testFailureResultNeverCarriesObject() {
        // 多词非法字节：单 token 会被 OpenStep 兼容解析器接受为字符串标量，
        // 必须用不构成任何合法 plist 的字节序列触发 parseFailed。
        let result = decoder.decode(data: Data("this is not a property list".utf8))

        XCTAssertNotEqual(result.status, .success)
        XCTAssertNil(result.object)
    }
}
