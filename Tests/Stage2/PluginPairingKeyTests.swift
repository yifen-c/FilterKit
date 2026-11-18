//
//  PluginPairingKeyTests.swift
//  FilterKit Stage 2 — C2-B 配对键专项测试（G-C3 §5.1）
//
//  覆盖：精确后缀剥离、大小写敏感、空键、隐藏前缀保留、非候选类型排除。
//  合成夹具，不触碰真机；不读取文件内容。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginPairingKeyTests: XCTestCase {

    // MARK: - 后缀剥离

    func testDylibSuffixStripped() {
        let file = evidence(name: "Example.dylib", kind: .dylib)
        XCTAssertEqual(PluginPairingKeyBuilder.key(for: file), "Example")
    }

    func testPlistSuffixStripped() {
        let file = evidence(name: "Example.plist", kind: .plist)
        XCTAssertEqual(PluginPairingKeyBuilder.key(for: file), "Example")
    }

    func testLibraryPrefixPreserved() {
        let file = evidence(name: "libExample.dylib", kind: .dylib)
        XCTAssertEqual(PluginPairingKeyBuilder.key(for: file), "libExample")
    }

    // MARK: - 大小写敏感

    func testUppercaseSuffixDoesNotMatch() {
        // kind 为 dylib 但文件名后缀为大写 `.DYLIB`：精确后缀不匹配，返回 nil。
        let file = evidence(name: "Example.DYLIB", kind: .dylib)
        XCTAssertNil(PluginPairingKeyBuilder.key(for: file))
    }

    func testCasePreservedNoLowercasing() {
        let upper = evidence(name: "Example.plist", kind: .plist)
        let lower = evidence(name: "example.dylib", kind: .dylib)
        XCTAssertEqual(PluginPairingKeyBuilder.key(for: upper), "Example")
        XCTAssertEqual(PluginPairingKeyBuilder.key(for: lower), "example")
    }

    // MARK: - 空键

    func testEmptyDylibKeyRejected() {
        let file = evidence(name: ".dylib", kind: .dylib)
        XCTAssertNil(PluginPairingKeyBuilder.key(for: file))
    }

    func testEmptyPlistKeyRejected() {
        let file = evidence(name: ".plist", kind: .plist)
        XCTAssertNil(PluginPairingKeyBuilder.key(for: file))
    }

    // MARK: - 隐藏前缀保留

    func testHiddenPrefixPreserved() {
        let file = evidence(name: ".Hidden.dylib", kind: .dylib)
        XCTAssertEqual(PluginPairingKeyBuilder.key(for: file), ".Hidden")
    }

    // MARK: - 非候选类型

    func testDirectoryExcluded() {
        let file = evidence(name: "Classes", kind: .directory)
        XCTAssertNil(PluginPairingKeyBuilder.key(for: file))
    }

    func testSymlinkExcluded() {
        let file = evidence(name: "Link.dylib", kind: .symlink)
        XCTAssertNil(PluginPairingKeyBuilder.key(for: file))
    }

    func testOtherKindExcluded() {
        let file = evidence(name: "Notes.txt", kind: .other)
        XCTAssertNil(PluginPairingKeyBuilder.key(for: file))
    }

    // MARK: - 辅助

    private func evidence(name: String, kind: PluginFileKind) -> PluginFileEvidence {
        PluginFileEvidence(
            name: name,
            extension: kind == .dylib ? "dylib" : kind == .plist ? "plist" : nil,
            kind: kind
        )
    }
}
