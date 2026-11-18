//
//  PlistReaderTests.swift
//  FilterKit Stage 2 — C3-B Reader 专项测试（PlistDataReader）
//
//  覆盖：正常读取 / 文件不存在 / 权限拒绝 / 其他 I/O 失败 / 空文件。
//  合成临时文件，不触碰真机；不判断 plist 内容合法性（归 Decoder）。
//  权限拒绝在沙盒内以 root 身份不可稳定复现，按错误分类接缝做纯函数断言。
//

import Foundation
import XCTest
@testable import Core

final class PlistReaderTests: XCTestCase {

    private var tempRoot: URL?

    override func tearDown() {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
        super.tearDown()
    }

    // MARK: - 临时文件接缝

    private func makeTempFile(named name: String, data: Data) throws -> String {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("filterkit-c3b-reader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        tempRoot = root
        let url = root.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    // MARK: - Reader-01 正常文件读取

    func testReadExistingFileReturnsSuccessWithData() throws {
        let payload = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict/></plist>
        """.utf8)
        let path = try makeTempFile(named: "normal.plist", data: payload)

        let result = PlistDataReader().read(path: path)

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.data, payload)
        XCTAssertEqual(result.path, path)
        XCTAssertNil(result.errorCode)
        XCTAssertNil(result.errorDescription)
    }

    // MARK: - Reader-02 文件不存在

    func testMissingFileReturnsNotFound() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("filterkit-c3b-missing-\(UUID().uuidString).plist")
            .path

        let result = PlistDataReader().read(path: missing)

        XCTAssertEqual(result.status, PlistReadStatus.notFound)
        XCTAssertNil(result.data)
        XCTAssertEqual(result.path, missing)
        XCTAssertNotNil(result.errorDescription)
    }

    // MARK: - Reader-03 权限拒绝（分类接缝）

    func testPermissionDeniedClassifiesAsAccessDenied() {
        let cocoaDenied = NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileReadNoPermission.rawValue,
            userInfo: nil
        )
        let posixDenied = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.EACCES.rawValue),
            userInfo: nil
        )

        let cocoa = PlistDataReader.classify(error: cocoaDenied)
        let posix = PlistDataReader.classify(error: posixDenied)

        XCTAssertEqual(cocoa.status, .accessDenied)
        XCTAssertEqual(posix.status, .accessDenied)
    }

    // MARK: - Reader-04 其他 I/O 读取异常

    func testOtherIOErrorClassifiesAsReadFailed() {
        let posixIO = NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(POSIXErrorCode.EIO.rawValue),
            userInfo: nil
        )
        let unknown = NSError(domain: "com.filterkit.unknown", code: 999, userInfo: nil)

        XCTAssertEqual(PlistDataReader.classify(error: posixIO).status, .readFailed)
        XCTAssertEqual(PlistDataReader.classify(error: unknown).status, .readFailed)
    }

    // MARK: - Reader-05 空文件

    func testEmptyFileReadsAsSuccessWithEmptyData() throws {
        // Reader 只负责交付字节：空文件是成功读取；空字节能否解码归 Decoder。
        let path = try makeTempFile(named: "empty.plist", data: Data())

        let result = PlistDataReader().read(path: path)

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.data, Data())
    }

    // MARK: - 失败结果不得携带虚假数据

    func testFailureResultNeverCarriesData() {
        let result = PlistDataReader().read(
            path: NSTemporaryDirectory() + "filterkit-c3b-absent-\(UUID().uuidString).plist"
        )

        XCTAssertNotEqual(result.status, .success)
        XCTAssertNil(result.data)
    }
}
