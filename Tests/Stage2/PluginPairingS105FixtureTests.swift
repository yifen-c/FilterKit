//
//  PluginPairingS105FixtureTests.swift
//  FilterKit Stage 2 — S1-05 原始配对行为基线映射（C2-D1）
//
//  逐例消费 `Tests/Fixtures/S1-05` 原始 environment/metadata，经当前 C2
//  Pairing Pipeline 执行，与冻结预期深比较；不复制第二套基线，不访问真实
//  文件系统，不读取 plist 内容。13 组夹具 + 2 项合成用例，共 15 例独立测试标识。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginPairingS105FixtureTests: XCTestCase {

    private let pipeline = PluginPairingPipeline()

    // MARK: - PAIR-001 ~ 012：13 组原始夹具深比较

    func testPAIR001PairValid() throws {
        try assertFixture("pair-valid", pairId: "PAIR-001")
    }

    func testPAIR002MissingPlist() throws {
        try assertFixture("pair-missing-plist", pairId: "PAIR-002")
    }

    func testPAIR003OrphanPlist() throws {
        try assertFixture("pair-orphan-plist", pairId: "PAIR-003")
    }

    func testPAIR004Multi() throws {
        try assertFixture("pair-multi", pairId: "PAIR-004")
    }

    func testPAIR005CaseMismatch() throws {
        try assertFixture("pair-case-mismatch", pairId: "PAIR-005")
    }

    func testPAIR006CrossPath() throws {
        try assertFixture("pair-cross-path", pairId: "PAIR-006")
    }

    func testPAIR007Hidden() throws {
        try assertFixture("pair-hidden", pairId: "PAIR-007")
    }

    func testPAIR008Symlink() throws {
        try assertFixture("pair-symlink", pairId: "PAIR-008")
    }

    func testPAIR009OtherExt() throws {
        try assertFixture("pair-other-ext", pairId: "PAIR-009")
    }

    func testPAIR010Duplicate() throws {
        try assertFixture("pair-duplicate", pairId: "PAIR-010")
    }

    func testPAIR011AccessDenied() throws {
        try assertFixture("pair-access-denied", pairId: "PAIR-011")
    }

    func testPAIR012RouteGuard() throws {
        try assertFixture("route-guard", pairId: "PAIR-012")
    }

    func testPAIR013DeterminismFixture() throws {
        try assertFixture("pair-determinism", pairId: "PAIR-013")
    }

    // MARK: - 合成用例：确定性 / 路线隔离

    /// PAIR-013（synthetic:determinism）：相同清单重复配对，快照深比较一致。
    func testPAIR013SyntheticDeterminism() throws {
        let fixture = try S105FixtureLoader.load(name: "pair-determinism")
        let first = pipeline.execute(inventory: fixture.inventory)
        let second = pipeline.execute(inventory: fixture.inventory)
        XCTAssertEqual(first, second)
    }

    /// PAIR-006（synthetic:route-isolation）：未定位目录不回退 `/var/jb`，无跨路线泄漏。
    func testPAIR006SyntheticRouteIsolation() throws {
        let fixture = try S105FixtureLoader.load(name: "route-guard")
        let snapshot = pipeline.execute(inventory: fixture.inventory)

        XCTAssertNil(snapshot.sourceDirectory)
        XCTAssertEqual(snapshot.status, .unresolved)
        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.counts.total, 0)

        let leaked = snapshot.records.flatMap { record in
            [record.dylib?.path, record.plist?.path]
                .compactMap { $0 }
                .filter { $0.hasPrefix("/var/jb") }
        }
        XCTAssertTrue(leaked.isEmpty, "不得出现 /var/jb 回退路径")
    }

    // MARK: - 深比较辅助

    private func assertFixture(_ name: String, pairId: String) throws {
        let fixture = try S105FixtureLoader.load(name: name)
        let snapshot = pipeline.execute(inventory: fixture.inventory)
        let expected = fixture.metadata.expected

        // 身份与目录级状态
        XCTAssertEqual(snapshot.route, expected.route, "\(pairId) route")
        XCTAssertEqual(snapshot.sourceDirectory, expected.sourceDirectory, "\(pairId) sourceDirectory")
        XCTAssertEqual(snapshot.status.rawValue, expected.status, "\(pairId) status")
        if let expectedStatus = fixture.metadata.expectedStatus {
            XCTAssertEqual(snapshot.status.rawValue, expectedStatus, "\(pairId) expectedStatus")
        }

        // 五桶计数（逐桶比较，总数相同也不得桶间错配）
        XCTAssertEqual(snapshot.counts.paired, expected.counts.paired, "\(pairId) counts.paired")
        XCTAssertEqual(snapshot.counts.missingPlist, expected.counts.missingPlist, "\(pairId) counts.missing_plist")
        XCTAssertEqual(snapshot.counts.orphanPlist, expected.counts.orphanPlist, "\(pairId) counts.orphan_plist")
        XCTAssertEqual(snapshot.counts.ambiguous, expected.counts.ambiguous, "\(pairId) counts.ambiguous")
        XCTAssertEqual(snapshot.counts.uncertain, expected.counts.uncertain, "\(pairId) counts.uncertain")
        XCTAssertEqual(snapshot.counts.total, snapshot.records.count, "\(pairId) counts.total")

        // 归类基名/文件名集合
        XCTAssertEqual(pairedBases(snapshot), expected.pairedBases.sorted(), "\(pairId) pairedBases")
        XCTAssertEqual(missingBases(snapshot), expected.missingBases.sorted(), "\(pairId) missingBases")
        XCTAssertEqual(orphanNames(snapshot), expected.orphanNames.sorted(), "\(pairId) orphanNames")
        XCTAssertEqual(ambiguousBases(snapshot), (expected.ambiguousBases ?? []).sorted(), "\(pairId) ambiguousBases")
        XCTAssertEqual(uncertainPaths(snapshot), (expected.uncertainPaths ?? []).sorted(), "\(pairId) uncertainPaths")

        // 告警码集合
        XCTAssertEqual(
            Set(snapshot.warnings.map(\.code)),
            Set(fixture.metadata.expectedWarnings),
            "\(pairId) warnings"
        )

        // 软链身份标记（pair-symlink 基线附加断言）
        if let flags = expected.dylibSymlinkFlags {
            for (base, flag) in flags {
                let record = snapshot.records.first { $0.pairingKey == base }
                XCTAssertEqual(record?.dylib?.isSymlink, Optional(flag), "\(pairId) symlink flag \(base)")
            }
        }
    }

    private func pairedBases(_ snapshot: PluginPairingSnapshot) -> [String] {
        snapshot.records.filter { $0.category == .paired }
            .compactMap(\.pairingKey).sorted()
    }

    private func missingBases(_ snapshot: PluginPairingSnapshot) -> [String] {
        snapshot.records.filter { $0.category == .missingPlist }
            .compactMap(\.pairingKey).sorted()
    }

    private func orphanNames(_ snapshot: PluginPairingSnapshot) -> [String] {
        snapshot.records.filter { $0.category == .orphanPlist }
            .compactMap { $0.plist?.name }.sorted()
    }

    private func ambiguousBases(_ snapshot: PluginPairingSnapshot) -> [String] {
        snapshot.records.filter { $0.category == .ambiguous }
            .compactMap(\.pairingKey).sorted()
    }

    private func uncertainPaths(_ snapshot: PluginPairingSnapshot) -> [String] {
        // 对齐 S1-05 基线 `uncertain[].path`：只登记受限侧（entryStatus != .ok）
        // 条目；被留置的 ok 对侧保留在记录证据中，不作为 uncertain 路径上报。
        snapshot.records.filter { $0.category == .uncertain }
            .flatMap { [$0.dylib, $0.plist].compactMap { $0 } }
            .filter { $0.entryStatus != .ok }
            .map(\.name)
            .sorted()
    }
}
