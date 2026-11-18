//
//  PluginPairingEngineTests.swift
//  FilterKit Stage 2 — C2-B 配对引擎专项测试（G-C3 §6 / §7 / §10）
//
//  覆盖五桶归类、受限留置、歧义全候选、同目录作用域、空目录、确定性、
//  计数互斥、未知条目归集、目录级状态与告警、输入不被改写。
//  全部合成夹具，不读取 plist 内容，不实例化 Adapter。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginPairingEngineTests: XCTestCase {

    private let engine = PluginPairingEngine()

    // MARK: - 五桶归类

    func testPaired() {
        let items = [
            evidence(name: "Example.dylib", kind: .dylib),
            evidence(name: "Example.plist", kind: .plist)
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        XCTAssertEqual(snapshot.records.count, 1)
        let record = record(byKey: "Example", in: snapshot)
        XCTAssertEqual(record.category, .paired)
        XCTAssertEqual(record.pairing, .paired)
        XCTAssertEqual(record.basis, .exactFilenameMatch)
        XCTAssertNotNil(record.dylib)
        XCTAssertNotNil(record.plist)
        XCTAssertEqual(snapshot.status, .enumerated)
        XCTAssertEqual(snapshot.counts.paired, 1)
    }

    func testMissingPlist() {
        let items = [evidence(name: "Another.dylib", kind: .dylib)]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Another", in: snapshot)
        XCTAssertEqual(record.category, .missingPlist)
        XCTAssertEqual(record.pairing, .missingPlist)
        XCTAssertNil(record.plist)
        XCTAssertEqual(snapshot.counts.missingPlist, 1)
    }

    func testOrphanPlist() {
        let items = [evidence(name: "Unused.plist", kind: .plist)]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Unused", in: snapshot)
        XCTAssertEqual(record.category, .orphanPlist)
        XCTAssertEqual(record.pairing, .orphanPlist)
        XCTAssertEqual(record.reason, "missing_dylib")
        XCTAssertNil(record.dylib)
        XCTAssertEqual(snapshot.counts.orphanPlist, 1)
    }

    func testAmbiguousMultiplePlists() {
        let items = [
            evidence(name: "Case.dylib", kind: .dylib),
            evidence(name: "Case.plist", kind: .plist, path: "/dir/a/Case.plist"),
            evidence(name: "Case.plist", kind: .plist, path: "/dir/b/Case.plist")
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Case", in: snapshot)
        XCTAssertEqual(record.category, .ambiguous)
        XCTAssertNil(record.pairing)
        XCTAssertEqual(record.candidates.count, 3)
        XCTAssertEqual(record.basis, .ambiguousMultiCandidate)
        XCTAssertEqual(snapshot.counts.ambiguous, 1)
    }

    func testAmbiguousMultipleDylibs() {
        let items = [
            evidence(name: "Case.dylib", kind: .dylib, path: "/dir/a/Case.dylib"),
            evidence(name: "Case.dylib", kind: .dylib, path: "/dir/b/Case.dylib"),
            evidence(name: "Case.plist", kind: .plist)
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Case", in: snapshot)
        XCTAssertEqual(record.category, .ambiguous)
        XCTAssertEqual(record.candidates.count, 3)
    }

    // MARK: - 不确定条目

    func testUncertainAccessDeniedHoldsBothSides() {
        let items = [
            evidence(name: "Locked.dylib", kind: .dylib, status: .accessDenied),
            evidence(name: "Locked.plist", kind: .plist)
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Locked", in: snapshot)
        XCTAssertEqual(record.category, .uncertain)
        XCTAssertNil(record.pairing)
        XCTAssertEqual(record.reason, "access_denied")
        XCTAssertNotNil(record.dylib)
        XCTAssertNotNil(record.plist)
        XCTAssertEqual(record.candidates.count, 2)
        XCTAssertEqual(snapshot.counts.uncertain, 1)
    }

    func testUncertainReadFailedPlistOnly() {
        let items = [evidence(name: "Broken.plist", kind: .plist, status: .readFailed)]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Broken", in: snapshot)
        XCTAssertEqual(record.category, .uncertain)
        XCTAssertEqual(record.reason, "read_failed")
        XCTAssertNil(record.pairing)
    }

    func testNotFoundClassifiedUncertain() {
        let items = [evidence(name: "Ghost.dylib", kind: .dylib, status: .notFound)]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let record = record(byKey: "Ghost", in: snapshot)
        XCTAssertEqual(record.category, .uncertain)
        XCTAssertEqual(record.reason, "not_found")
    }

    func testReadableNilWithOkStatusIsPaired() {
        // entryStatus == .ok；readable 三态位为 nil 不单独触发 uncertain。
        let dylib = PluginFileEvidence(
            name: "Example.dylib", extension: "dylib", kind: .dylib,
            readable: nil, entryStatus: .ok
        )
        let plist = PluginFileEvidence(
            name: "Example.plist", extension: "plist", kind: .plist,
            readable: true, entryStatus: .ok
        )
        let snapshot = engine.pair(inventory: inventory(items: [dylib, plist]))

        let record = record(byKey: "Example", in: snapshot)
        XCTAssertEqual(record.category, .paired)
    }

    // MARK: - 作用域：不跨快照合并

    func testDoesNotMergeAcrossSnapshots() {
        let left = inventory(items: [evidence(name: "Example.dylib", kind: .dylib)])
        let right = inventory(items: [evidence(name: "Example.plist", kind: .plist)])

        let leftSnapshot = engine.pair(inventory: left)
        let rightSnapshot = engine.pair(inventory: right)

        XCTAssertEqual(leftSnapshot.counts.missingPlist, 1)
        XCTAssertEqual(rightSnapshot.counts.orphanPlist, 1)
        XCTAssertEqual(leftSnapshot.records.first?.category, .missingPlist)
        XCTAssertEqual(rightSnapshot.records.first?.category, .orphanPlist)
    }

    // MARK: - 空目录

    func testEmptyDirectoryEnumeratedZero() {
        let snapshot = engine.pair(inventory: inventory(items: []))

        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.counts.total, 0)
        XCTAssertEqual(snapshot.status, .enumerated)
    }

    // MARK: - 确定性

    func testShuffledInputProducesSameRecords() {
        let items = [
            evidence(name: "Alpha.dylib", kind: .dylib),
            evidence(name: "Alpha.plist", kind: .plist),
            evidence(name: "Beta.dylib", kind: .dylib),
            evidence(name: "Gamma.plist", kind: .plist),
            evidence(name: "Beta.plist", kind: .plist)
        ]
        let forward = engine.pair(inventory: inventory(items: items))
        let reversed = engine.pair(inventory: inventory(items: items.reversed()))

        XCTAssertEqual(forward.records, reversed.records)
        XCTAssertEqual(forward.counts, reversed.counts)
    }

    func testRepeatedRunsAreDeterministic() {
        let items = [
            evidence(name: "Case.dylib", kind: .dylib),
            evidence(name: "Case.plist", kind: .plist),
            evidence(name: "Case.plist", kind: .plist, path: "/b/Case.plist")
        ]
        let baseline = engine.pair(inventory: inventory(items: items))
        for _ in 0..<100 {
            let snapshot = engine.pair(inventory: inventory(items: items))
            XCTAssertEqual(snapshot.records, baseline.records)
        }
    }

    // MARK: - 计数互斥

    func testCountsTotalEqualsRecordCount() {
        let items = [
            evidence(name: "Alpha.dylib", kind: .dylib),
            evidence(name: "Alpha.plist", kind: .plist),
            evidence(name: "Only.dylib", kind: .dylib),
            evidence(name: "Lone.plist", kind: .plist),
            evidence(name: "Case.dylib", kind: .dylib),
            evidence(name: "Case.plist", kind: .plist),
            evidence(name: "Case.plist", kind: .plist, path: "/b/Case.plist")
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        XCTAssertEqual(snapshot.counts.total, snapshot.records.count)
        let sum = snapshot.counts.paired + snapshot.counts.missingPlist
            + snapshot.counts.orphanPlist + snapshot.counts.ambiguous
            + snapshot.counts.uncertain
        XCTAssertEqual(sum, snapshot.records.count)
    }

    // MARK: - 未知条目归集

    func testUnknownItemsPassthroughAndEmptyKeyCollected() {
        let existing = UnknownItem(
            path: nil, base: "Notes.txt", reason: "other_ext",
            sourceStage: "stage2.2-c1", detail: [:]
        )
        let items = [evidence(name: ".dylib", kind: .dylib)]
        let snapshot = engine.pair(inventory: inventory(items: items, unknown: [existing]))

        XCTAssertTrue(snapshot.records.isEmpty)
        XCTAssertEqual(snapshot.unknownItems.count, 2)
        XCTAssertEqual(snapshot.unknownItems.first, existing)
        let emptyKey = snapshot.unknownItems.last
        XCTAssertEqual(emptyKey?.reason, "empty_pairing_key")
        XCTAssertEqual(emptyKey?.sourceStage, "stage2.2-c2")
    }

    // MARK: - 目录级状态与告警

    func testUnresolvedWhenSourceDirectoryMissing() {
        let items = [evidence(name: "Example.dylib", kind: .dylib)]
        let snapshot = engine.pair(inventory: inventory(items: items, dir: nil))

        XCTAssertEqual(snapshot.status, .unresolved)
        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.counts.total, 0)
        XCTAssertTrue(snapshot.warnings.contains { $0.code == "inventory_unresolved" })
    }

    func testEnumerationFailedStatus() {
        let snapshot = engine.pair(inventory: inventory(
            items: [evidence(name: "Example.dylib", kind: .dylib)],
            status: .enumerationFailed
        ))

        XCTAssertEqual(snapshot.status, .enumerationFailed)
        XCTAssertEqual(snapshot.records, [])
        XCTAssertTrue(snapshot.warnings.contains { $0.code == "inventory_unresolved" })
    }

    func testPartialWhenUncertainPresent() {
        let items = [evidence(name: "Locked.dylib", kind: .dylib, status: .accessDenied)]
        let snapshot = engine.pair(inventory: inventory(items: items))

        XCTAssertEqual(snapshot.status, .partial)
        XCTAssertTrue(snapshot.warnings.contains { $0.code == "partial_pairing" })
    }

    // MARK: - 输入不被改写

    func testInputSnapshotNotMutated() {
        let items = [
            evidence(name: "Example.dylib", kind: .dylib),
            evidence(name: "Example.plist", kind: .plist)
        ]
        let original = inventory(items: items)
        let baseline = original

        _ = engine.pair(inventory: original)

        XCTAssertEqual(original, baseline)
        XCTAssertEqual(original.items, baseline.items)
    }

    // MARK: - Pairing 四值兼容

    func testPairingFourValueMappingAndNilForUnresolvedBuckets() {
        let items = [
            evidence(name: "Paired.dylib", kind: .dylib),
            evidence(name: "Paired.plist", kind: .plist),
            evidence(name: "Missing.dylib", kind: .dylib),
            evidence(name: "Orphan.plist", kind: .plist),
            evidence(name: "Multi.dylib", kind: .dylib),
            evidence(name: "Multi.plist", kind: .plist),
            evidence(name: "Multi.plist", kind: .plist, path: "/b/Multi.plist")
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        let paired = record(byKey: "Paired", in: snapshot)
        let missing = record(byKey: "Missing", in: snapshot)
        let orphan = record(byKey: "Orphan", in: snapshot)
        let ambiguous = record(byKey: "Multi", in: snapshot)

        XCTAssertEqual(paired.pairing, .paired)
        XCTAssertEqual(missing.pairing, .missingPlist)
        XCTAssertEqual(orphan.pairing, .orphanPlist)
        XCTAssertNil(ambiguous.pairing)
        // 既有第四值 missing_dylib 不在分类桶中重复造值。
        XCTAssertNotEqual(orphan.pairing, .missingDylib)
    }

    func testOtherExtensionsNotRecorded() {
        let items = [
            evidence(name: "Notes.txt", kind: .other),
            evidence(name: "Tweak.deb", kind: .other)
        ]
        let snapshot = engine.pair(inventory: inventory(items: items))

        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.counts.total, 0)
    }

    // MARK: - 辅助

    private func record(byKey key: String, in snapshot: PluginPairingSnapshot) -> PluginPairingRecord {
        guard let record = snapshot.records.first(where: { $0.pairingKey == key }) else {
            XCTFail("缺少配对键 \(key) 的记录")
            return PluginPairingRecord(category: .uncertain, basis: .uncertainAccess)
        }
        return record
    }

    private func inventory(
        items: [PluginFileEvidence],
        dir: String? = "/var/containers/Bundle/Application/.jbroot-X/usr/lib/TweakInject/",
        status: EnumerationStatus = .enumerated,
        unknown: [UnknownItem] = []
    ) -> PluginInventorySnapshot {
        PluginInventorySnapshot(
            route: "roothide",
            sourceDirectory: dir,
            enumeration: EnumerationBlock(status: status),
            items: items,
            unknownItems: unknown
        )
    }

    private func evidence(
        name: String,
        kind: PluginFileKind,
        status: PluginEntryStatus = .ok,
        path: String? = nil
    ) -> PluginFileEvidence {
        PluginFileEvidence(
            path: path,
            name: name,
            extension: kind == .dylib ? "dylib" : kind == .plist ? "plist" : nil,
            kind: kind,
            entryStatus: status
        )
    }
}
