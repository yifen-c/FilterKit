//
//  PluginInventoryCodableTests.swift
//  FilterKit Stage 2 — C1 新模型 Codable 往返与兼容口径
//
//  对齐：`Stage-2.2-C-Enumeration-Models-Contract.md` §6 Codable 兼容口径。
//  覆盖：枚举原始值锁定、证据/快照往返、三态 nil 保留、缺失可选字段缺省、
//  未知键忽略。不修改既有 Models 字段/枚举/原始值/解码行为。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginInventoryCodableTests: XCTestCase {

    // MARK: - 枚举原始值冻结

    func testPluginFileKindRawValues() {
        XCTAssertEqual(PluginFileKind.dylib.rawValue, "dylib")
        XCTAssertEqual(PluginFileKind.plist.rawValue, "plist")
        XCTAssertEqual(PluginFileKind.directory.rawValue, "directory")
        XCTAssertEqual(PluginFileKind.symlink.rawValue, "symlink")
        XCTAssertEqual(PluginFileKind.other.rawValue, "other")
    }

    func testPluginEntryStatusRawValues() {
        XCTAssertEqual(PluginEntryStatus.ok.rawValue, "ok")
        XCTAssertEqual(PluginEntryStatus.accessDenied.rawValue, "access_denied")
        XCTAssertEqual(PluginEntryStatus.metadataUnavailable.rawValue, "metadata_unavailable")
        XCTAssertEqual(PluginEntryStatus.readFailed.rawValue, "read_failed")
        XCTAssertEqual(PluginEntryStatus.notFound.rawValue, "not_found")
    }

    func testEnumerationStatusRawValues() {
        XCTAssertEqual(EnumerationStatus.enumerated.rawValue, "enumerated")
        XCTAssertEqual(EnumerationStatus.partial.rawValue, "partial")
        XCTAssertEqual(EnumerationStatus.enumerationFailed.rawValue, "enumeration_failed")
        XCTAssertEqual(EnumerationStatus.unresolved.rawValue, "unresolved")
    }

    // MARK: - 证据往返：三态 nil 保留，不转 false

    func testEvidenceRoundTripPreservesOptionals() throws {
        let evidence = PluginFileEvidence(
            path: "/tweak/X.dylib",
            name: "X.dylib",
            extension: "dylib",
            kind: .dylib,
            exists: true,
            readable: nil,
            isSymlink: false,
            symlinkTarget: nil,
            symlinkState: nil,
            realpath: nil,
            size: nil,
            hash: nil,
            hidden: false,
            entryStatus: .ok
        )

        let data = try JSONEncoder().encode(evidence)
        let decoded = try JSONDecoder().decode(PluginFileEvidence.self, from: data)

        XCTAssertEqual(decoded, evidence)
        XCTAssertNil(decoded.readable)
        XCTAssertNil(decoded.realpath)
        XCTAssertNil(decoded.hash)
        XCTAssertEqual(decoded.exists, true)
        XCTAssertEqual(decoded.isSymlink, false)
    }

    // MARK: - 缺失可选字段：按契约缺省，不反推补齐

    func testEvidenceMissingOptionalsDecodeWithDefaults() throws {
        let json = """
        {
            "name": "Plain.dylib",
            "kind": "dylib"
        }
        """
        let evidence = try JSONDecoder().decode(
            PluginFileEvidence.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(evidence.name, "Plain.dylib")
        XCTAssertEqual(evidence.kind, .dylib)
        XCTAssertNil(evidence.path)
        XCTAssertNil(evidence.`extension`)
        XCTAssertNil(evidence.exists)
        XCTAssertNil(evidence.readable)
        XCTAssertNil(evidence.isSymlink)
        XCTAssertFalse(evidence.hidden)
        XCTAssertEqual(evidence.entryStatus, .ok)
    }

    // MARK: - 快照往返：计数/数组/状态一致

    func testSnapshotRoundTrip() throws {
        let evidence = PluginFileEvidence(
            name: "Y.plist",
            extension: "plist",
            kind: .plist,
            hidden: true,
            entryStatus: .ok
        )
        let snapshot = PluginInventorySnapshot(
            route: "rootless",
            sourceDirectory: "/var/jb/usr/lib/TweakInject/",
            enumeration: EnumerationBlock(status: .enumerated),
            items: [evidence],
            unknownItems: [],
            counts: PluginKindCounts(plist: 1),
            warnings: []
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PluginInventorySnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }

    // MARK: - 快照最小 JSON：缺省计数/数组/递归位成立

    func testSnapshotMinimalJSONDecodesWithDefaults() throws {
        let json = """
        {
            "route": "roothide",
            "enumeration": { "status": "partial" }
        }
        """
        let snapshot = try JSONDecoder().decode(
            PluginInventorySnapshot.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(snapshot.route, "roothide")
        XCTAssertNil(snapshot.sourceDirectory)
        XCTAssertFalse(snapshot.enumeration.recursive)
        XCTAssertEqual(snapshot.enumeration.status, .partial)
        XCTAssertEqual(snapshot.items, [])
        XCTAssertEqual(snapshot.unknownItems, [])
        XCTAssertEqual(snapshot.counts, PluginKindCounts())
        XCTAssertEqual(snapshot.warnings, [])
    }

    // MARK: - 未知键忽略，不抛解码错误

    func testUnknownKeysAreIgnored() throws {
        let json = """
        {
            "name": "Z.dylib",
            "kind": "dylib",
            "futureInternalField": "ignored",
            "nested": { "x": 1 }
        }
        """
        let evidence = try JSONDecoder().decode(
            PluginFileEvidence.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(evidence.name, "Z.dylib")
        XCTAssertEqual(evidence.kind, .dylib)
    }

    // MARK: - 计数与五分类一一对应

    func testCountsAccumulateByKind() {
        var counts = PluginKindCounts()
        for kind in [PluginFileKind.dylib, .plist, .directory, .symlink, .other] {
            counts.add(kind)
        }
        XCTAssertEqual(counts.dylib, 1)
        XCTAssertEqual(counts.plist, 1)
        XCTAssertEqual(counts.directory, 1)
        XCTAssertEqual(counts.symlink, 1)
        XCTAssertEqual(counts.other, 1)
    }
}
