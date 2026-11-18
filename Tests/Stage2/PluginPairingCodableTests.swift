//
//  PluginPairingCodableTests.swift
//  FilterKit Stage 2 — C2-A 配对模型 Codable 往返与兼容口径
//
//  对齐：`Stage-2.2-C2-Pairing-Contract.md` §4 模型定稿 / §8 Codable 口径。
//  覆盖：五桶分类与四态原始值、既有 `Pairing` 四值兼容、五桶计数互斥求和、
//  歧义/不确定候选完整保留、三态 nil 保留、快照往返、缺省解码、未知键忽略、
//  重建确定性。本批不含 Key/Index/Engine 行为测试（归 C2-B）。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginPairingCodableTests: XCTestCase {

    // MARK: - 枚举原始值冻结

    func testPairingCategoryRawValues() {
        XCTAssertEqual(PairingCategory.paired.rawValue, "paired")
        XCTAssertEqual(PairingCategory.missingPlist.rawValue, "missing_plist")
        XCTAssertEqual(PairingCategory.orphanPlist.rawValue, "orphan_plist")
        XCTAssertEqual(PairingCategory.ambiguous.rawValue, "ambiguous")
        XCTAssertEqual(PairingCategory.uncertain.rawValue, "uncertain")
    }

    func testPairingStatusRawValues() {
        XCTAssertEqual(PairingStatus.enumerated.rawValue, "enumerated")
        XCTAssertEqual(PairingStatus.partial.rawValue, "partial")
        XCTAssertEqual(PairingStatus.enumerationFailed.rawValue, "enumeration_failed")
        XCTAssertEqual(PairingStatus.unresolved.rawValue, "unresolved")
    }

    func testPairingEvidenceBasisRawValues() {
        XCTAssertEqual(PairingEvidenceBasis.exactFilenameMatch.rawValue, "exact_filename_match")
        XCTAssertEqual(PairingEvidenceBasis.noOppositeCandidate.rawValue, "no_opposite_candidate")
        XCTAssertEqual(PairingEvidenceBasis.ambiguousMultiCandidate.rawValue, "ambiguous_multi_candidate")
        XCTAssertEqual(PairingEvidenceBasis.uncertainAccess.rawValue, "uncertain_access")
        XCTAssertEqual(PairingEvidenceBasis.heldAgainstUncertain.rawValue, "held_against_uncertain")
    }

    // MARK: - 既有 Pairing 四值兼容（不扩枚举）

    func testPairingFourValuesRemainUnchanged() {
        XCTAssertEqual(Pairing.paired.rawValue, "paired")
        XCTAssertEqual(Pairing.missingPlist.rawValue, "missing_plist")
        XCTAssertEqual(Pairing.orphanPlist.rawValue, "orphan_plist")
        XCTAssertEqual(Pairing.missingDylib.rawValue, "missing_dylib")
    }

    func testRecordCategoryToPairingMapping() {
        let paired = PluginPairingRecord(category: .paired, pairing: .paired, basis: .exactFilenameMatch)
        let missing = PluginPairingRecord(category: .missingPlist, pairing: .missingPlist, basis: .noOppositeCandidate)
        let orphan = PluginPairingRecord(category: .orphanPlist, pairing: .orphanPlist, reason: "missing_dylib", basis: .noOppositeCandidate)
        let ambiguous = PluginPairingRecord(category: .ambiguous, basis: .ambiguousMultiCandidate)
        let uncertain = PluginPairingRecord(category: .uncertain, basis: .uncertainAccess)

        XCTAssertEqual(paired.pairing, .paired)
        XCTAssertEqual(missing.pairing, .missingPlist)
        XCTAssertEqual(orphan.pairing, .orphanPlist)
        // 歧义/不确定不写入 Pairing 四值。
        XCTAssertNil(ambiguous.pairing)
        XCTAssertNil(uncertain.pairing)
    }

    // MARK: - 计数互斥：五桶之和等于记录组数

    func testCountsTotalEqualsFiveBuckets() {
        let counts = PluginPairingCounts(paired: 2, missingPlist: 1, orphanPlist: 1, ambiguous: 1, uncertain: 1)
        XCTAssertEqual(counts.total, 6)
        XCTAssertEqual(counts.paired + counts.missingPlist + counts.orphanPlist + counts.ambiguous + counts.uncertain, 6)
    }

    // MARK: - 歧义/不确定候选完整保留，不取 first

    func testAmbiguousCandidatesPreservedFull() throws {
        let first = evidence(name: "Case.plist", kind: .plist)
        let second = evidence(name: "Case.plist", kind: .plist)
        let record = PluginPairingRecord(
            category: .ambiguous,
            pairingKey: "Case",
            candidates: [first, second],
            basis: .ambiguousMultiCandidate
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(PluginPairingRecord.self, from: data)

        XCTAssertEqual(decoded.candidates.count, 2)
        XCTAssertEqual(decoded.candidates, [first, second])
        XCTAssertNil(decoded.pairing)
    }

    // MARK: - 记录往返：三态可选 nil 保留，不转 false

    func testRecordRoundTripPreservesNilOptionals() throws {
        let record = PluginPairingRecord(
            category: .uncertain,
            pairingKey: "Locked",
            dylib: evidence(name: "Locked.dylib", kind: .dylib, status: .accessDenied),
            reason: "access_denied",
            basis: .uncertainAccess
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(PluginPairingRecord.self, from: data)

        XCTAssertEqual(decoded, record)
        XCTAssertNil(decoded.plist)
        XCTAssertNil(decoded.pairing)
        XCTAssertNil(decoded.evidence)
        XCTAssertEqual(decoded.candidates, [])
        XCTAssertEqual(decoded.warnings, [])
    }

    // MARK: - 快照往返：状态/记录/归集/计数/告警一致

    func testSnapshotRoundTrip() throws {
        let paired = PluginPairingRecord(
            category: .paired,
            pairing: .paired,
            pairingKey: "Example",
            dylib: evidence(name: "Example.dylib", kind: .dylib),
            plist: evidence(name: "Example.plist", kind: .plist),
            basis: .exactFilenameMatch
        )
        let uncertain = PluginPairingRecord(
            category: .uncertain,
            pairingKey: "Locked",
            reason: "read_failed",
            basis: .uncertainAccess
        )
        let snapshot = PluginPairingSnapshot(
            route: "roothide",
            sourceDirectory: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/",
            status: .partial,
            records: [paired, uncertain],
            unknownItems: [UnknownItem(path: nil, base: "Notes.txt", reason: "other_ext", sourceStage: "stage2.2-c2", detail: [:])],
            counts: PluginPairingCounts(paired: 1, uncertain: 1),
            warnings: [ReportWarning(code: "partial_pairing", message: "存在不确定条目", sourceStage: "stage2.2-c2")]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PluginPairingSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.records.count, 2)
        XCTAssertEqual(decoded.counts.total, 2)
    }

    // MARK: - 快照最小 JSON：缺省计数/数组/状态成立

    func testSnapshotMinimalJSONDecodesWithDefaults() throws {
        let json = """
        {
            "route": "rootless",
            "status": "enumerated"
        }
        """
        let snapshot = try JSONDecoder().decode(
            PluginPairingSnapshot.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(snapshot.route, "rootless")
        XCTAssertNil(snapshot.sourceDirectory)
        XCTAssertEqual(snapshot.status, .enumerated)
        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.unknownItems, [])
        XCTAssertEqual(snapshot.counts, PluginPairingCounts())
        XCTAssertEqual(snapshot.warnings, [])
    }

    // MARK: - 未知键忽略，不抛解码错误

    func testUnknownKeysAreIgnored() throws {
        let json = """
        {
            "category": "paired",
            "basis": "exact_filename_match",
            "futureInternalField": "ignored",
            "nested": { "x": 1 }
        }
        """
        let record = try JSONDecoder().decode(
            PluginPairingRecord.self,
            from: Data(json.utf8)
        )
        XCTAssertEqual(record.category, .paired)
        XCTAssertEqual(record.basis, .exactFilenameMatch)
    }

    // MARK: - 确定性：相同输入重建快照深比较一致

    func testDeterministicReconstructionEqual() {
        let record = PluginPairingRecord(
            category: .orphanPlist,
            pairing: .orphanPlist,
            pairingKey: "Orphan",
            plist: evidence(name: "Orphan.plist", kind: .plist),
            reason: "missing_dylib",
            basis: .noOppositeCandidate
        )
        let first = PluginPairingSnapshot(route: "roothide", status: .enumerated, records: [record])
        let second = PluginPairingSnapshot(route: "roothide", status: .enumerated, records: [record])

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.records, second.records)
    }

    // MARK: - 辅助

    private func evidence(name: String,
                          kind: PluginFileKind,
                          status: PluginEntryStatus = .ok) -> PluginFileEvidence {
        PluginFileEvidence(
            name: name,
            extension: kind == .dylib ? "dylib" : "plist",
            kind: kind,
            entryStatus: status
        )
    }
}
