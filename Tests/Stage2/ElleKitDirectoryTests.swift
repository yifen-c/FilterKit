//
//  ElleKitDirectoryTests.swift
//  FilterKit Stage 2 — B4 ElleKit 目录与软链定位回归（S1-03 15 项基线）
//
//  离线只读：测试只读引用 Tests/Fixtures/S1-03 原始夹具，不复制第二份基线；
//  不访问真实文件系统，不枚举 dylib，不创建/删除软链，不装配 Pipeline（归 B5）。
//  用例在 macOS runner 执行（本机无 Swift 工具链）。
//
//  对齐：Spec/Stage-2/Stage-2.2-B-Data-Contract-Freeze.md §5（D9/D10/D11）；
//  Stage 1 基线 Tests/S1-03/resolver.js、run.js、report/S1-03-report.json。
//

import Foundation
import XCTest
@testable import Models
@testable import Adapters
@testable import Core

final class ElleKitDirectoryTests: XCTestCase {

    // MARK: - 夹具元数据（解码形态对齐 metadata.json）

    private struct MetaExpected: Codable, Equatable {
        let route: String
        let tiPath: String?
        let tiExists: Bool?
        let tiReadable: Bool?
        let tiEnumerable: Bool?
        let tiStatus: String
        let dlState: String
        let dlTargetMatch: Bool
        let outcome: String
    }

    private struct FixtureMeta: Codable, Equatable {
        let fixtureId: String
        let expected: MetaExpected
        let expectedWarnings: [String]
        let expectedOutcome: String
    }

    // MARK: - 辅助

    private static func fixtureURL(kind: String, fileName: String) -> URL {
        let testsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return testsDir.appendingPathComponent("Fixtures/S1-03/\(kind)/\(fileName)")
    }

    private func loadSnapshot(kind: String) throws -> ElleKitDirectorySnapshot {
        let url = Self.fixtureURL(kind: kind, fileName: "environment.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ElleKitDirectorySnapshot.self, from: data)
    }

    private func loadMeta(kind: String) throws -> FixtureMeta {
        let url = Self.fixtureURL(kind: kind, fileName: "metadata.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FixtureMeta.self, from: data)
    }

    private let resolver = ElleKitDirectoryResolver()

    private func warningCodes(_ warnings: [ReportWarning]) -> Set<String> {
        Set(warnings.map(\.code))
    }

    /// 逐字段对齐基线 expected；告警按 code 集合比较。
    private func assertResult(_ result: ElleKitDirectoryResolution, matches meta: FixtureMeta, kind: String) {
        let expected = meta.expected
        XCTAssertEqual(result.route, expected.route, "\(kind) route")
        XCTAssertEqual(result.tweakInject?.requestedPath, expected.tiPath, "\(kind) tiPath")
        XCTAssertEqual(result.tweakInject?.exists, expected.tiExists, "\(kind) tiExists")
        XCTAssertEqual(result.tweakInject?.readable, expected.tiReadable, "\(kind) tiReadable")
        XCTAssertEqual(result.tweakInject?.enumerable, expected.tiEnumerable, "\(kind) tiEnumerable")
        XCTAssertEqual(result.tweakInject?.status, expected.tiStatus, "\(kind) tiStatus")
        XCTAssertEqual(result.dynamicLibraries?.symlinkState, expected.dlState, "\(kind) dlState")
        XCTAssertEqual(result.dynamicLibraries?.targetMatch, expected.dlTargetMatch, "\(kind) dlTargetMatch")
        XCTAssertEqual(result.outcome, expected.outcome, "\(kind) outcome")
        XCTAssertEqual(result.outcome, meta.expectedOutcome, "\(kind) expectedOutcome")
        XCTAssertEqual(warningCodes(result.warnings), Set(meta.expectedWarnings), "\(kind) warnings")
    }

    // MARK: - 1. rh-valid（DIR-001/004/005）：目录 confirmed + 软链 resolved 且匹配 → resolved

    func testRhValidResolved() throws {
        let kind = "rh-valid"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertEqual(result.dynamicLibraries?.targetPath, result.tweakInject?.requestedPath)
    }

    // MARK: - 2. rh-missing（DIR-002）：目录不存在 → not_found

    func testRhMissingNotFound() throws {
        let kind = "rh-missing"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
    }

    // MARK: - 3. rh-unreadable（DIR-003）：不可读/不可枚举 → partial；可读与可枚举独立分层

    func testRhUnreadablePartialLayered() throws {
        let kind = "rh-unreadable"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        // 状态分层：readable=false 不得推断 enumerable=true（两者均为 false）。
        XCTAssertEqual(result.tweakInject?.readable, false)
        XCTAssertEqual(result.tweakInject?.enumerable, false)
        XCTAssertEqual(result.dynamicLibraries?.symlinkState, "resolved")
        XCTAssertEqual(result.dynamicLibraries?.targetMatch, true)
    }

    // MARK: - 4. rh-broken-link（DIR-006）：软链 broken → partial

    func testRhBrokenLinkPartial() throws {
        let kind = "rh-broken-link"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.warnings.contains { $0.code == "symlink_broken" })
    }

    // MARK: - 5. rh-loop（DIR-007）：软链循环 → partial

    func testRhLoopPartial() throws {
        let kind = "rh-loop"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.warnings.contains { $0.code == "symlink_loop" })
    }

    // MARK: - 6. rh-target-denied（DIR-008）：权限拒绝 → partial

    func testRhTargetDeniedPartial() throws {
        let kind = "rh-target-denied"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.warnings.contains { $0.code == "symlink_target_denied" })
    }

    // MARK: - 7. rh-not-symlink（DIR-009）：目标非软链 → partial

    func testRhNotSymlinkPartial() throws {
        let kind = "rh-not-symlink"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.warnings.contains { $0.code == "not_a_symlink" })
    }

    // MARK: - 8. rootless-valid（DIR-001）：独立 /var/jb 路径 → resolved

    func testRootlessValidResolved() throws {
        let kind = "rootless-valid"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertEqual(result.tweakInject?.requestedPath, "/var/jb/usr/lib/TweakInject/")
    }

    // MARK: - 9. rootful-valid（DIR-001）：仅诊断参照 → rootful_diagnostic

    func testRootfulDiagnostic() throws {
        let kind = "rootful-valid"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.warnings.contains { $0.code == "rootful_route_not_profile" })
    }

    // MARK: - 10. route-fallback-guard（DIR-010）：roothide 缺 jbroot 禁止回退 /var/jb 或 /

    func testRouteFallbackGuardNoLeak() throws {
        let kind = "route-fallback-guard"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        XCTAssertNil(result.tweakInject?.requestedPath, "未定位 jbroot 不得推导 RootHide 目录")
        XCTAssertNotEqual(result.tweakInject?.requestedPath?.hasPrefix("/var/jb"), true)
        XCTAssertNotEqual(result.tweakInject?.requestedPath, "/")
        XCTAssertEqual(result.outcome, "unresolved")
    }

    // MARK: - 11. structure-conflict（DIR-011）：软链 resolved 但目标不符 → structure_conflict

    func testStructureConflict() throws {
        let kind = "structure-conflict"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.warnings.contains { $0.code == "structure_conflict" })
    }

    // MARK: - 12. DIR-012：相同目录信号重复解析，结果确定（Equatable 全等）

    func testDeterminismDIR012() throws {
        let snapshot = try loadSnapshot(kind: "rh-valid")
        let first = resolver.resolve(snapshot)
        let second = resolver.resolve(snapshot)
        XCTAssertEqual(first, second)
    }

    // MARK: - 13. DIR-013：fixtureId 不一致不影响解析

    func testIdMismatchDIR013() throws {
        var snapshot = try loadSnapshot(kind: "rh-valid")
        snapshot.fixtureId = "S1-03-MISMATCH-999"
        let result = resolver.resolve(snapshot)
        XCTAssertEqual(result.outcome, "resolved")
        XCTAssertEqual(result.tweakInject?.requestedPath,
                       "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/")
    }

    // MARK: - 14. 目录/软链证据 Codable 往返

    func testEvidenceCodableRoundTrip() throws {
        let ti = PathLocationEvidence(
            requestedPath: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/",
            resolvedPath: "/private/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/",
            exists: true, readable: true, enumerable: true, structureMatch: true,
            status: "confirmed",
            warnings: [ReportWarning(code: "access_limited", message: "", sourceStage: "S1-03")]
        )
        let dl = SymlinkEvidence(
            isSymlink: true,
            targetPath: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/",
            realpath: "/private/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/",
            symlinkState: "resolved",
            targetMatch: true,
            warnings: []
        )

        let tiDecoded = try JSONDecoder().decode(PathLocationEvidence.self, from: JSONEncoder().encode(ti))
        let dlDecoded = try JSONDecoder().decode(SymlinkEvidence.self, from: JSONEncoder().encode(dl))
        XCTAssertEqual(tiDecoded, ti)
        XCTAssertEqual(dlDecoded, dl)
    }

    // MARK: - 15. 三态保留 + 三路线覆盖核对

    func testThreeStatePreservedAndRouteCoverage() throws {
        // 未验证事实位保持 nil，不被填成 false。
        let signal = DirectoryFsSignal(
            tweakInject: DirectoryTiSignal(exists: nil, readable: nil, enumerable: nil,
                                          realpath: nil, structureMatch: nil),
            dynamicLibraries: DirectoryDlSignal()
        )
        let snapshot = ElleKitDirectorySnapshot(
            upstream: DirectoryUpstreamSignal(route: "roothide", jbroot: nil),
            fs: signal
        )
        let result = resolver.resolve(snapshot)
        XCTAssertNil(result.tweakInject?.exists)
        XCTAssertNil(result.tweakInject?.readable)
        XCTAssertNil(result.tweakInject?.enumerable)
        XCTAssertNil(result.tweakInject?.structureMatch)
        XCTAssertEqual(result.outcome, "unresolved")

        // 夹具并集覆盖 roothide / rootless / rootful 三路线。
        var covered = Set<String>()
        for kind in ["rh-valid", "rootless-valid", "rootful-valid"] {
            let loaded = try loadSnapshot(kind: kind)
            if let route = loaded.upstream?.route { covered.insert(route) }
        }
        XCTAssertEqual(covered, Set(["roothide", "rootless", "rootful"]))
    }
}
