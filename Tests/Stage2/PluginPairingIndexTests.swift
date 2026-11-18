//
//  PluginPairingIndexTests.swift
//  FilterKit Stage 2 — C2-B 配对索引专项测试（G-C3 §5.2）
//
//  覆盖：同键多候选全量保留不覆盖、候选按路径字母序、键集合有序、
//  非候选类型不入索引。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginPairingIndexTests: XCTestCase {

    func testDuplicateCandidatesRetainedNotOverwritten() {
        let items = [
            evidence(name: "Case.plist", kind: .plist, path: "/dir/a/Case.plist"),
            evidence(name: "Case.plist", kind: .plist, path: "/dir/b/Case.plist")
        ]
        let index = builder.build(from: inventory(items: items))

        XCTAssertEqual(index.plists["Case"]?.count, 2)
        XCTAssertEqual(index.dylibs["Case"]?.count ?? 0, 0)
    }

    func testCandidatesSortedByPath() {
        let items = [
            evidence(name: "Case.plist", kind: .plist, path: "/dir/z/Case.plist"),
            evidence(name: "Case.plist", kind: .plist, path: "/dir/a/Case.plist"),
            evidence(name: "Case.plist", kind: .plist, path: "/dir/m/Case.plist")
        ]
        let index = builder.build(from: inventory(items: items))

        let paths = index.plists["Case"]?.map { $0.path ?? $0.name }
        XCTAssertEqual(paths, ["/dir/a/Case.plist", "/dir/m/Case.plist", "/dir/z/Case.plist"])
    }

    func testKeysUnionSorted() {
        let items = [
            evidence(name: "Zebra.dylib", kind: .dylib),
            evidence(name: "Apple.plist", kind: .plist),
            evidence(name: "Mango.dylib", kind: .dylib)
        ]
        let index = builder.build(from: inventory(items: items))

        XCTAssertEqual(index.keys, ["Apple", "Mango", "Zebra"])
    }

    func testNonCandidateKindsExcludedFromIndex() {
        let items = [
            evidence(name: "Classes", kind: .directory),
            evidence(name: "Link.dylib", kind: .symlink),
            evidence(name: "Notes.txt", kind: .other)
        ]
        let index = builder.build(from: inventory(items: items))

        XCTAssertTrue(index.dylibs.isEmpty)
        XCTAssertTrue(index.plists.isEmpty)
    }

    func testSameBasenameMultipleFilesNotCollapsed() {
        let items = [
            evidence(name: "Case.dylib", kind: .dylib, path: "/dir/1/Case.dylib"),
            evidence(name: "Case.dylib", kind: .dylib, path: "/dir/2/Case.dylib"),
            evidence(name: "Case.plist", kind: .plist, path: "/dir/1/Case.plist")
        ]
        let index = builder.build(from: inventory(items: items))

        XCTAssertEqual(index.dylibs["Case"]?.count, 2)
        XCTAssertEqual(index.plists["Case"]?.count, 1)
    }

    // MARK: - 辅助

    private let builder = PluginPairingIndexBuilder()

    private func inventory(items: [PluginFileEvidence]) -> PluginInventorySnapshot {
        PluginInventorySnapshot(
            route: "roothide",
            sourceDirectory: "/var/containers/Bundle/Application/.jbroot-X/usr/lib/TweakInject/",
            items: items
        )
    }

    private func evidence(name: String, kind: PluginFileKind, path: String? = nil) -> PluginFileEvidence {
        PluginFileEvidence(
            path: path,
            name: name,
            extension: kind == .dylib ? "dylib" : kind == .plist ? "plist" : nil,
            kind: kind
        )
    }
}
