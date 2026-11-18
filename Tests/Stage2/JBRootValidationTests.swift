//
//  JBRootValidationTests.swift
//  FilterKit Stage 2 — B3 JBROOT 校验与裁决回归（S1-02 18 项基线）
//
//  离线只读：测试只读引用 Tests/Fixtures/S1-02 原始夹具，不复制第二份基线；
//  不访问真实文件系统，不做目录/软链定位（B4），不检查 TweakInject，不装配 Pipeline（B5）。
//  用例在 macOS runner 执行（本机无 Swift 工具链）。
//
//  对齐：Spec/Stage-2/Stage-2.2-B-Data-Contract-Freeze.md（D4/D5/D6/D7/D8）；
//  Stage 1 基线 Tests/S1-02/resolver.js、run.js、report/S1-02-report.json。
//

import Foundation
import XCTest
@testable import Models
@testable import Adapters
@testable import Core

final class JBRootValidationTests: XCTestCase {

    // MARK: - 夹具元数据（解码形态对齐 metadata.json）

    private struct MetaExpected: Codable, Equatable {
        let jbroot: String?
        let jbrand: String?
        let realpath: String?
        let ambiguous: Bool
        let outcome: String
        let selectedSource: String?
        let candidateCount: Int
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
        return testsDir.appendingPathComponent("Fixtures/S1-02/\(kind)/\(fileName)")
    }

    private func loadSnapshot(kind: String) throws -> JBRootCandidateSnapshot {
        let url = Self.fixtureURL(kind: kind, fileName: "environment.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JBRootCandidateSnapshot.self, from: data)
    }

    private func loadMeta(kind: String) throws -> FixtureMeta {
        let url = Self.fixtureURL(kind: kind, fileName: "metadata.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FixtureMeta.self, from: data)
    }

    private let resolver = JBRootResolver()

    private func resolve(signals: [JBRootCandidateSignal]) -> JBRootResolutionResult {
        resolver.resolve(JBRootCandidateSnapshot(signals: .init(candidates: signals)))
    }

    private func warningCodes(_ warnings: [ReportWarning]) -> Set<String> {
        Set(warnings.map(\.code))
    }

    /// 逐字段对齐基线 expected；告警按 code 集合比较。
    private func assertResult(_ result: JBRootResolutionResult, matches meta: FixtureMeta, kind: String) {
        let expected = meta.expected
        XCTAssertEqual(result.jbroot, expected.jbroot, "\(kind) jbroot")
        XCTAssertEqual(result.jbrand, expected.jbrand, "\(kind) jbrand")
        XCTAssertEqual(result.realpath, expected.realpath, "\(kind) realpath")
        XCTAssertEqual(result.ambiguous, expected.ambiguous, "\(kind) ambiguous")
        XCTAssertEqual(result.outcome, expected.outcome, "\(kind) outcome")
        XCTAssertEqual(result.selectedSource, expected.selectedSource, "\(kind) selectedSource")
        XCTAssertEqual(result.candidateCount, expected.candidateCount, "\(kind) candidateCount")
        XCTAssertEqual(result.outcome, meta.expectedOutcome, "\(kind) expectedOutcome")
        XCTAssertEqual(warningCodes(result.warnings), Set(meta.expectedWarnings), "\(kind) warnings")
    }

    // MARK: - 1. PATH-001/002/003/008/009：rh-valid 唯一有效候选 → resolved

    func testRhValidResolved() throws {
        let kind = "rh-valid"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "confirmed")
        XCTAssertEqual(candidate.validation.nameValid, true)
        XCTAssertEqual(candidate.validation.exists, true)
        XCTAssertEqual(candidate.validation.structureMatch, true)
        XCTAssertEqual(candidate.validation.readable, true)
    }

    // MARK: - 2. PATH-006：rh-multiple 两个 roothide 有效候选 → ambiguous，不选边

    func testRhMultipleAmbiguous() throws {
        let kind = "rh-multiple"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        XCTAssertEqual(result.candidates.count, 2)
        XCTAssertTrue(result.candidates.allSatisfy { $0.status == "confirmed" })
        XCTAssertNil(result.jbroot, "歧义时不虚构选中路径")
        XCTAssertNil(result.selectedSource, "歧义时不静默选边")
    }

    // MARK: - 3. PATH-003：rh-badname 校验位失败 → rejected_invalid / no_candidate

    func testRhBadNameRejectedInvalid() throws {
        let kind = "rh-badname"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "rejected_invalid")
        XCTAssertEqual(candidate.validation.nameValid, false)
        XCTAssertTrue(candidate.warnings.contains { $0.code == "invalid_container_name" })
    }

    // MARK: - 4. PATH-002：rh-name-only 不存在 → rejected_missing / no_candidate

    func testRhNameOnlyRejectedMissing() throws {
        let kind = "rh-name-only"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "rejected_missing")
        XCTAssertEqual(candidate.validation.exists, false)
        XCTAssertTrue(candidate.warnings.contains { $0.code == "candidate_missing" })
    }

    // MARK: - 5. PATH-007：rh-unreadable 存在但不可读 → partial

    func testRhUnreadablePartial() throws {
        let kind = "rh-unreadable"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "partial")
        XCTAssertEqual(candidate.validation.readable, false)
        XCTAssertTrue(candidate.warnings.contains { $0.code == "access_limited" })
    }

    // MARK: - 6. PATH-005/007：rh-broken-link 软链失败 → resolve_failed，realpath 置 nil

    func testRhBrokenLinkResolveFailed() throws {
        let kind = "rh-broken-link"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "resolve_failed")
        XCTAssertNil(candidate.validation.realpath, "软链失败不产出 realpath")
        XCTAssertTrue(candidate.warnings.contains { $0.code == "symlink_resolve_failed" })
    }

    // MARK: - 7. PATH-010：rootless 候选 → cross_route_only，不确认

    func testRootlessCrossRouteOnly() throws {
        let kind = "rootless-varjb"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "cross_route")
        XCTAssertEqual(candidate.route, "rootless")
        XCTAssertNil(candidate.validation.nameValid, "跨路线不做命名校验")
    }

    // MARK: - 8. PATH-010：rootful 候选 → cross_route_only，不确认

    func testRootfulCrossRouteOnly() throws {
        let kind = "rootful-root"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "cross_route")
        XCTAssertEqual(candidate.route, "rootful")
    }

    // MARK: - 9. PATH-007：no-candidate → no_candidate + no_jbroot_candidate

    func testNoCandidate() throws {
        let kind = "no-candidate"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)
        XCTAssertTrue(result.candidates.isEmpty)
    }

    // MARK: - 10. PATH-005：realpath-privatevar → resolved，realpath 保留 /private/var 前缀

    func testRealpathPrivateVarResolved() throws {
        let kind = "realpath-privatevar"
        let result = resolver.resolve(try loadSnapshot(kind: kind))
        assertResult(result, matches: try loadMeta(kind: kind), kind: kind)

        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.status, "confirmed")
        XCTAssertEqual(candidate.validation.realpath, "/private/var/containers/Bundle/Application/.jbroot-D87B48653D7178BA")
    }

    // MARK: - 11. 命名校验规则：前缀/长度/字符集/非零/校验位

    func testNameValidationRules() {
        let valid = "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4"
        XCTAssertTrue(JBRootNameValidator.isJbrootName(valid))
        // 小写十六进制同样通过（字符集大小写均可）。
        XCTAssertTrue(JBRootNameValidator.isJbrootName(
            "/var/containers/Bundle/Application/.jbroot-9c414bb7d5dcecc4"))
        // 校验位不通过（rh-badname 后缀）。
        XCTAssertFalse(JBRootNameValidator.isJbrootName(
            "/var/containers/Bundle/Application/.jbroot-76484591DA3078C2"))
        // 仅前缀、后缀长度不足。
        XCTAssertFalse(JBRootNameValidator.isJbrootName(
            "/var/containers/Bundle/Application/.jbroot-ABC"))
        // 非十六进制字符。
        XCTAssertFalse(JBRootNameValidator.isJbrootName(
            "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECCZ"))
        // 全零后缀数值为零，不通过。
        XCTAssertFalse(JBRootNameValidator.isJbrootName(
            "/var/containers/Bundle/Application/.jbroot-0000000000000000"))
        // 缺少前缀。
        XCTAssertFalse(JBRootNameValidator.isJbrootName("/var/containers/Bundle/Application/9C414BB7D5DCECC4"))
    }

    // MARK: - 12. jbrand 解析：大写后缀；非法命名返回 nil

    func testJbrandParseUppercase() {
        XCTAssertEqual(
            JBRootNameValidator.parseJbrand("/var/containers/Bundle/Application/.jbroot-d87b48653d7178ba"),
            "D87B48653D7178BA")
        XCTAssertNil(JBRootNameValidator.parseJbrand("/var/containers/Bundle/Application/other-dir"))
        XCTAssertNil(JBRootNameValidator.parseJbrand("/var/containers/Bundle/Application/.jbroot-ABC"))
    }

    // MARK: - 13. PATH-004：沿用 B2 词法规范化结果做命名校验，不另起规范化

    func testPATH004NormalizedNameValidation() {
        let messy = "//var/containers/Bundle/./Application/../Application/.jbroot-9C414BB7D5DCECC4/"
        let normalized = JBRootCandidateCollector.normalizeLexical(messy)
        XCTAssertEqual(normalized, "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4")
        XCTAssertTrue(JBRootNameValidator.isJbrootName(normalized ?? ""))
    }

    // MARK: - 14. PATH-011：相同输入重复裁决结果确定（Equatable 全等）

    func testPATH011Determinism() throws {
        let snapshot = try loadSnapshot(kind: "rh-valid")
        let first = resolver.resolve(snapshot)
        let second = resolver.resolve(snapshot)
        XCTAssertEqual(first, second)
    }

    // MARK: - 15. PATH-012：fixtureId 不一致不影响裁决

    func testPATH012IdMismatchDoesNotAffectDecision() throws {
        var snapshot = try loadSnapshot(kind: "rh-valid")
        snapshot.fixtureId = "S1-02-MISMATCH-999"
        let result = resolver.resolve(snapshot)
        XCTAssertEqual(result.outcome, "resolved")
        XCTAssertEqual(result.selectedSource, "scan")
        XCTAssertEqual(result.candidateCount, 1)
    }

    // MARK: - 16. 三态：nil 不转 false；structureMatch/可读/存在事实位原样保留

    func testThreeStateBitsNotCoerced() {
        let signal = JBRootCandidateSignal(
            root: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
            source: "scan",
            exists: nil, structureMatch: nil, readable: nil,
            realpath: nil, symlinkState: "none"
        )
        let result = resolve(signals: [signal])
        let candidate = result.candidates[0]

        // 未验证位保持 nil，不得被填成 false。
        XCTAssertNil(candidate.validation.exists)
        XCTAssertNil(candidate.validation.structureMatch)
        XCTAssertNil(candidate.validation.readable)
        // 存在性事实为 nil 时按不存在参与裁决（基线口径）。
        XCTAssertEqual(candidate.status, "rejected_missing")
        XCTAssertEqual(result.outcome, "no_candidate")
    }

    // MARK: - 17. 多候选裁决：唯一确认 + 拒绝共存；全部拒绝；跨路线证据保留

    func testMultiCandidateDecisionScenarios() {
        let validRoot = "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4"
        let otherRoot = "/var/containers/Bundle/Application/.jbroot-D87B48653D7178BA"

        // 17a. 一个 confirmed + 一个 rejected_invalid → 确认唯一有效候选，不歧义。
        let mixed = resolve(signals: [
            JBRootCandidateSignal(root: validRoot, source: "scan", exists: true,
                                  structureMatch: true, readable: true, realpath: nil, symlinkState: "none"),
            JBRootCandidateSignal(root: "/var/containers/Bundle/Application/.jbroot-76484591DA3078C2",
                                  source: "api", exists: true, structureMatch: true, readable: true,
                                  realpath: nil, symlinkState: "none")
        ])
        XCTAssertEqual(mixed.outcome, "resolved")
        XCTAssertEqual(mixed.selectedSource, "scan")
        XCTAssertEqual(mixed.candidates.count, 2)

        // 17b. 两个 confirmed roothide → ambiguous，不静默选边。
        let multiple = resolve(signals: [
            JBRootCandidateSignal(root: validRoot, source: "api", exists: true,
                                  structureMatch: true, readable: true, realpath: nil, symlinkState: "none"),
            JBRootCandidateSignal(root: otherRoot, source: "scan", exists: true,
                                  structureMatch: true, readable: true, realpath: nil, symlinkState: "none")
        ])
        XCTAssertEqual(multiple.outcome, "ambiguous")
        XCTAssertTrue(multiple.ambiguous)
        XCTAssertNil(multiple.selectedSource)

        // 17c. 全部被拒绝 → no_candidate，失败原因候选证据保留。
        let allRejected = resolve(signals: [
            JBRootCandidateSignal(root: "/var/containers/Bundle/Application/.jbroot-76484591DA3078C2",
                                  source: "scan", exists: true, structureMatch: true, readable: true,
                                  realpath: nil, symlinkState: "none")
        ])
        XCTAssertEqual(allRejected.outcome, "no_candidate")
        XCTAssertEqual(allRejected.candidates.count, 1)

        // 17d. 跨路线候选作为冲突证据保留在候选列表，不被删除。
        let cross = resolve(signals: [
            JBRootCandidateSignal(root: "/var/jb", source: "rootless", exists: true,
                                  structureMatch: true, readable: true, realpath: nil, symlinkState: "none")
        ])
        XCTAssertEqual(cross.outcome, "cross_route_only")
        XCTAssertEqual(cross.candidates[0].status, "cross_route")
    }

    // MARK: - 18. 校验后候选 Codable 往返；D8 旧信封投影兼容保持

    func testValidatedCandidateCodableRoundTrip() throws {
        let candidate = JBRootCandidate(
            path: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
            source: "scan",
            route: "roothide",
            validation: JBRootValidationBits(
                nameValid: true, exists: true, structureMatch: true, readable: true,
                realpath: "/private/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4"
            ),
            status: "confirmed",
            warnings: [ReportWarning(code: "access_limited", message: "", sourceStage: "S1-02")]
        )
        let data = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(JBRootCandidate.self, from: data)
        XCTAssertEqual(decoded, candidate)

        // D8 兼容：旧信封仅含投影字段，解码不报错、权威列表为空。
        let legacyJson = """
        {
          "jbrootCandidates": ["/var/jb"]
        }
        """
        let legacy = try JSONDecoder().decode(PathEvidence.self, from: Data(legacyJson.utf8))
        XCTAssertEqual(legacy.jbrootCandidates, ["/var/jb"])
        XCTAssertEqual(legacy.jbrootCandidateDetails, [])
    }
}
