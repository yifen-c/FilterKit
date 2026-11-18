//
//  EngineC1-EngineBaselineTests.swift
//  FilterKit Stage 2 — Engine-C1 Engine 管线 S1-06 基线测试
//
//  经 `PluginFilterParseEngine` 串联 Reader / Decoder / 双路线 Parser，对照
//  快照级状态、五桶计数、条目归集、告警与证据；补充短路隔离、计数不变量、
//  上游保留与不可变断言。Engine-B 专项已固化的矩阵不重复实现，本批只在
//  基线映射层做端到端核对。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC1EngineBaselineTests: XCTestCase {

    // MARK: - 夹具管线基线

    func testFixtureEngineBaselines() throws {
        let fixtureCases = EngineC1BaselineRegistry.all.filter {
            if case .fixture = $0.source { return true }
            return false
        }

        for baseline in fixtureCases {
            try XCTSkipIf(baseline.pendingRunner,
                          "\(baseline.caseID) 待 C3-C2 Runner 出证（#151 / C-G2）")
            guard case .fixture(let name) = baseline.source else { continue }
            let fixture = try EngineC1FixtureLoader.load(name: name)
            let coordinator = makeCoordinator(fixture: fixture)
            let engine = makeEngine(coordinator: coordinator)

            let result = engine.parse(snapshot: fixture.snapshot)
            let meta = fixture.metadata.expected

            // 快照级状态与计数。
            XCTAssertEqual(result.status, meta.status, "\(baseline.caseID) 快照状态不符")
            assertCounts(result.counts, meta.counts, caseID: baseline.caseID)
            EngineC1ResultComparator.assertWarningsContain(
                result.warnings, expected: fixture.metadata.expectedWarnings ?? [])

            // 条目级状态 / 规则 / otherKeys / 证据。
            for (base, expectedStatus) in meta.statusByBase {
                let parsed = result.parsed.first { $0.pairingKey == base }
                let status = EngineC1ExpectedStatus(rawValue: expectedStatus)
                XCTAssertNotNil(parsed, "\(baseline.caseID) 缺条目 \(base)")
                guard let parsed else { continue }

                EngineC1ResultComparator.assertStatus(
                    parsed.status, expected: status, base: base)
                if let reason = baseline.expectedReasonByBase[base] {
                    EngineC1ResultComparator.assertReason(
                        parsed.reason, expected: reason, base: base)
                }
                let rule = EngineC1ResultComparator.mergedRule(
                    baseline: baseline, metadata: fixture.metadata, base: base)
                EngineC1ResultComparator.assertRule(
                    parsed.filter, expected: rule,
                    status: parsed.status, base: base)
                if let otherKeys = meta.otherKeysByBase[base] {
                    EngineC1ResultComparator.assertOtherKeys(
                        parsed.otherKeys, expected: otherKeys, base: base)
                }
                let skipped = baseline.expectedSkippedByBase[base] ?? []
                EngineC1ResultComparator.assertSkippedFields(
                    parsed.skippedFields, expected: skipped, base: base)
            }

            // 计数不变量。
            let validation = FilterParseIntegrationValidator().validate(snapshot: result)
            XCTAssertTrue(validation.allPassed,
                          "\(baseline.caseID) 计数不变量未通过：\(validation.checks.description)")
        }
    }

    // MARK: - 短路与隔离基线

    func testRouteGuardUnresolvedCallsNothing() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "route-guard")
        let coordinator = makeCoordinator(fixture: fixture)
        let engine = makeEngine(coordinator: coordinator)

        let result = engine.parse(snapshot: fixture.snapshot)

        XCTAssertEqual(coordinator.readerCallCount, 0)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertTrue(result.notParsed.isEmpty)
        XCTAssertEqual(result.status, "unresolved")
        XCTAssertTrue(result.warnings.contains { $0.code == "inventory_unresolved" })
    }

    func testUnknownRouteIsolationZeroCalls() {
        let coordinator = EngineC1Coordinator(inputs: [])
        let engine = makeEngine(coordinator: coordinator)

        let record = PluginPairingRecord(
            category: .paired,
            pairing: .paired,
            pairingKey: "Example",
            dylib: evidence(path: "/dir/Example.dylib", kind: .dylib),
            plist: evidence(path: "/dir/Example.plist", kind: .plist),
            basis: .exactFilenameMatch
        )
        let snapshot = PluginPairingSnapshot(
            route: "rootful",
            sourceDirectory: "/dir",
            status: .enumerated,
            records: [record],
            unknownItems: [],
            counts: PluginPairingCounts(paired: 1),
            warnings: []
        )

        let result = engine.parse(snapshot: snapshot)

        XCTAssertEqual(coordinator.readerCallCount, 0)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.notParsed.first?.reason, "unknown_route")
    }

    // MARK: - 双记录隔离与计数不变量

    func testPartialCorruptKeepsGoodAndCounts() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-partial-corrupt")
        let coordinator = makeCoordinator(fixture: fixture)
        let engine = makeEngine(coordinator: coordinator)

        let result = engine.parse(snapshot: fixture.snapshot)

        XCTAssertEqual(result.status, "partial")
        XCTAssertEqual(result.counts.valid, 1)
        XCTAssertEqual(result.counts.parseFailed, 1)
        XCTAssertEqual(result.counts.typeMismatch, 0)
        XCTAssertEqual(result.counts.readFailed, 0)
        XCTAssertEqual(result.counts.notParsed, 0)

        let good = result.parsed.first { $0.pairingKey == "Good" }
        let bad = result.parsed.first { $0.pairingKey == "Bad" }
        XCTAssertEqual(good?.status, .valid)
        XCTAssertEqual(good?.filter?.bundles, ["com.good.app"])
        XCTAssertEqual(bad?.status, .parseFailed)
        XCTAssertEqual(bad?.reason, "invalid_plist")
        XCTAssertTrue(result.warnings.contains { $0.code == "partial_parsing" })

        let validation = FilterParseIntegrationValidator().validate(snapshot: result)
        XCTAssertTrue(validation.allPassed, validation.checks.description)
    }

    // MARK: - 上游保留与不可变

    func testUpstreamUnknownItemsPreserved() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-xml-valid")
        let coordinator = makeCoordinator(fixture: fixture)
        let engine = makeEngine(coordinator: coordinator)

        let upstream = UnknownItem(path: "/dir/Orphan.plist", base: "Orphan",
                                   reason: "missing_dylib", sourceStage: "stage2.2-c2")
        var snapshot = fixture.snapshot
        snapshot.unknownItems = [upstream]

        let result = engine.parse(snapshot: snapshot)
        XCTAssertEqual(result.notParsed.last, upstream)
    }

    func testUpstreamSnapshotNotMutated() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-xml-valid")
        let coordinator = makeCoordinator(fixture: fixture)
        let engine = makeEngine(coordinator: coordinator)

        let original = fixture.snapshot
        let baseline = original
        _ = engine.parse(snapshot: original)

        XCTAssertEqual(original, baseline)
        XCTAssertEqual(original.records, baseline.records)
        XCTAssertEqual(original.unknownItems, baseline.unknownItems)
    }

    func testEngineDeterminismDeepEqual() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-determinism")
        let coordinator1 = makeCoordinator(fixture: fixture)
        let engine1 = makeEngine(coordinator: coordinator1)
        let coordinator2 = makeCoordinator(fixture: fixture)
        let engine2 = makeEngine(coordinator: coordinator2)

        let r1 = engine1.parse(snapshot: fixture.snapshot)
        let r2 = engine2.parse(snapshot: fixture.snapshot)
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 辅助

    private func makeCoordinator(fixture: EngineC1LoadedFixture) -> EngineC1Coordinator {
        EngineC1Coordinator(inputs: fixture.inputs)
    }

    private func makeEngine(coordinator: EngineC1Coordinator) -> PluginFilterParseEngine {
        PluginFilterParseEngine(
            reader: EngineC1StubReader(coordinator),
            decoder: EngineC1StubDecoder(coordinator),
            rootHideParser: EngineC1CountingParser(
                coordinator: coordinator, side: .hide, delegate: RootHideFilterParser()),
            rootlessParser: EngineC1CountingParser(
                coordinator: coordinator, side: .less, delegate: RootlessFilterParser())
        )
    }

    private func assertCounts(_ actual: FilterParseCounts,
                              _ expected: [String: Int],
                              caseID: String) {
        XCTAssertEqual(actual.valid, expected["valid"] ?? 0, "\(caseID) valid 计数")
        XCTAssertEqual(actual.parseFailed, expected["parse_failed"] ?? 0, "\(caseID) parse_failed 计数")
        XCTAssertEqual(actual.typeMismatch, expected["type_mismatch"] ?? 0, "\(caseID) type_mismatch 计数")
        XCTAssertEqual(actual.readFailed, expected["read_failed"] ?? 0, "\(caseID) read_failed 计数")
        XCTAssertEqual(actual.notParsed, expected["not_parsed"] ?? 0, "\(caseID) not_parsed 计数")
    }

    private func evidence(path: String?, kind: PluginFileKind) -> PluginFileEvidence? {
        guard let path else { return nil }
        let name = (path as NSString).lastPathComponent
        return PluginFileEvidence(
            path: path,
            name: name,
            extension: name.components(separatedBy: ".").last,
            kind: kind,
            exists: true,
            readable: true
        )
    }
}
