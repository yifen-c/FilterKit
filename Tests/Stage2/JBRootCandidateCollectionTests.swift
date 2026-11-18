//
//  JBRootCandidateCollectionTests.swift
//  FilterKit Stage 2 — B2 JBROOT 候选收集回归（S1-02 收集层）
//
//  离线只读：测试只读引用 Tests/Fixtures/S1-02 原始夹具，不复制第二份基线；
//  不访问真实文件系统，不做命名/存在/结构/可读/realpath 校验裁决，不选择
//  最终 JBROOT（归 B3）。用例在 macOS runner 执行（本机无 Swift 工具链）。
//
//  对齐：Spec/Stage-2/Stage-2.2-B-Data-Contract-Freeze.md §4、§7；
//  Stage 1 基线 Tests/S1-02/resolver.js、run.js、report/S1-02-report.json。
//

import Foundation
import XCTest
@testable import Models
@testable import Adapters
@testable import Core

final class JBRootCandidateCollectionTests: XCTestCase {

    // MARK: - 夹具元数据（解码形态对齐 metadata.json；只取收集层可用字段）

    private struct MetaExpected: Codable, Equatable {
        let candidateCount: Int
    }

    private struct FixtureMeta: Codable, Equatable {
        let fixtureId: String
        let expected: MetaExpected
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

    /// 基线 routeOfSource 收集层映射（仅已知来源；未知路线不反推）。
    private static func expectedRoute(source: String) -> String {
        switch source {
        case "rootless": return "rootless"
        case "rootful": return "rootful"
        case "api", "scan", "bootstrap": return "roothide"
        default: return ""
        }
    }

    private let collector = JBRootCandidateCollector()

    // MARK: - 夹具用例：候选数量 / 顺序 / 来源 / 路线 / 校验位记录 / 投影一致

    private static let fixtureKinds: [String] = [
        "rh-valid", "rh-multiple", "rh-badname", "rh-name-only", "rh-unreadable",
        "rh-broken-link", "rootless-varjb", "rootful-root", "no-candidate",
        "realpath-privatevar"
    ]

    func testFixtureCandidateCollection() throws {
        for kind in Self.fixtureKinds {
            let snapshot = try loadSnapshot(kind: kind)
            let meta = try loadMeta(kind: kind)
            let result = collector.collect(snapshot)

            // 数量：收集层不丢候选；与基线 candidateCount 一致。
            XCTAssertEqual(result.candidateCount, snapshot.signals.candidates.count, "\(kind) 候选数量")
            XCTAssertEqual(result.candidateCount, meta.expected.candidateCount, "\(kind) 基线 candidateCount")

            for (index, signal) in snapshot.signals.candidates.enumerated() {
                let candidate = result.candidates[index]
                let source = signal.source ?? ""
                let expectedPath = JBRootCandidateCollector.normalizeLexical(signal.root) ?? ""

                // 顺序保留：候选按夹具输入顺序归集。
                XCTAssertEqual(candidate.path, expectedPath, "\(kind)[\(index)] path")
                XCTAssertEqual(candidate.source, source, "\(kind)[\(index)] source 原样保留")
                XCTAssertEqual(candidate.route, Self.expectedRoute(source: source), "\(kind)[\(index)] route")

                // 三态校验位：记录信号已提供事实；nameValid 未验证留 nil；status 未裁决留 nil。
                XCTAssertNil(candidate.validation.nameValid, "\(kind)[\(index)] nameValid 未验证")
                XCTAssertEqual(candidate.validation.exists, signal.exists, "\(kind)[\(index)] exists")
                XCTAssertEqual(candidate.validation.structureMatch, signal.structureMatch, "\(kind)[\(index)] structureMatch")
                XCTAssertEqual(candidate.validation.readable, signal.readable, "\(kind)[\(index)] readable")
                XCTAssertEqual(candidate.validation.realpath, signal.realpath, "\(kind)[\(index)] realpath")
                XCTAssertNil(candidate.status, "\(kind)[\(index)] status 未裁决")
            }

            // D8 投影一致性：旧 [String] 投影 == 权威结构路径列表。
            let evidence = PathEvidence(jbrootCandidateDetails: result.candidates)
            XCTAssertEqual(evidence.jbrootCandidates, result.candidates.map(\.path), "\(kind) 投影一致")
        }
    }

    // MARK: - 五种已知来源在夹具中全覆盖

    func testFiveKnownSourcesCovered() throws {
        var covered = Set<String>()
        for kind in Self.fixtureKinds {
            let snapshot = try loadSnapshot(kind: kind)
            for signal in snapshot.signals.candidates {
                if let source = signal.source { covered.insert(source) }
            }
        }
        XCTAssertEqual(covered, Set(JBRootCandidateCollector.knownSources), "五种候选来源全覆盖")
    }

    // MARK: - PATH-004：词法规范化（. / .. / 重复分隔符 / 尾斜杠）

    func testPATH004LexicalNormalization() {
        let messy = "//var/containers/Bundle/./Application/../Application/.jbroot-9C414BB7D5DCECC4/"
        let normalized = JBRootCandidateCollector.normalizeLexical(messy)
        XCTAssertEqual(normalized, "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4")

        // 空串/非字符串形态 → nil；纯根 → "/"；不越界到根之上。
        XCTAssertNil(JBRootCandidateCollector.normalizeLexical(""))
        XCTAssertEqual(JBRootCandidateCollector.normalizeLexical("//"), "/")
        XCTAssertEqual(JBRootCandidateCollector.normalizeLexical("/../../a"), "/a")
    }

    // MARK: - PATH-011：相同候选重复解析，结果确定

    func testPATH011Determinism() throws {
        let snapshot = try loadSnapshot(kind: "rh-valid")
        let first = collector.collect(snapshot)
        let second = collector.collect(snapshot)
        XCTAssertEqual(first, second)
    }

    // MARK: - PATH-012：metadata 与 environment fixtureId 不一致，收集不受影响

    func testPATH012IdMismatchDoesNotAffectCollection() throws {
        let snapshot = try loadSnapshot(kind: "rh-valid")
        let mismatchedId = "S1-02-MISMATCH-999"
        XCTAssertNotEqual(snapshot.fixtureId, mismatchedId)

        let result = collector.collect(snapshot)
        XCTAssertEqual(result.candidateCount, 1)
        XCTAssertEqual(result.candidates.first?.source, "scan")
    }

    // MARK: - D7：未知来源原样保留 + 告警，不反推路线

    func testUnknownSourcePreservedAndWarned() throws {
        let signal = JBRootCandidateSignal(
            root: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
            source: "jbroot_container",
            exists: true, structureMatch: true, readable: true,
            realpath: nil, symlinkState: "none"
        )
        let snapshot = JBRootCandidateSnapshot(signals: .init(candidates: [signal]))
        let result = collector.collect(snapshot)

        XCTAssertEqual(result.candidateCount, 1)
        let candidate = try XCTUnwrap(result.candidates.first)
        XCTAssertEqual(candidate.source, "jbroot_container")
        XCTAssertEqual(candidate.route, "", "未知来源不反推路线")
        XCTAssertTrue(candidate.warnings.contains {
            $0.code == "unknown_candidate_source" && $0.message == "jbroot_container"
        })
        XCTAssertTrue(result.warnings.contains { $0.code == "unknown_candidate_source" })
    }

    // MARK: - 同路径多来源保留；同路径同来源精确重复去重

    func testMultiSourceSamePathRetainedAndExactDuplicateDropped() {
        let root = "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4"
        let signals = [
            JBRootCandidateSignal(root: root, source: "api"),
            JBRootCandidateSignal(root: root, source: "scan"),
            JBRootCandidateSignal(root: root, source: "api") // 与第一条精确重复
        ]
        let snapshot = JBRootCandidateSnapshot(signals: .init(candidates: signals))
        let result = collector.collect(snapshot)

        XCTAssertEqual(result.candidateCount, 2, "同路径不同来源均保留；精确重复仅去重")
        XCTAssertEqual(result.candidates.map(\.source), ["api", "scan"])
        XCTAssertTrue(result.warnings.contains { $0.code == "duplicate_candidate_removed" })
    }

    // MARK: - 非法路径告警且不入库

    func testInvalidPathWarnedAndSkipped() {
        let signals = [
            JBRootCandidateSignal(root: "", source: "scan"),
            JBRootCandidateSignal(root: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4", source: "scan")
        ]
        let snapshot = JBRootCandidateSnapshot(signals: .init(candidates: signals))
        let result = collector.collect(snapshot)

        XCTAssertEqual(result.candidateCount, 1)
        XCTAssertTrue(result.warnings.contains { $0.code == "candidate_path_invalid" })
    }

    // MARK: - 候选结构 Codable 往返

    func testCandidateCodableRoundTrip() throws {
        let candidate = JBRootCandidate(
            path: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
            source: "scan",
            route: "roothide",
            validation: JBRootValidationBits(
                nameValid: nil, exists: true, structureMatch: true, readable: true,
                realpath: "/private/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4"
            ),
            status: nil,
            warnings: [ReportWarning(code: "unknown_candidate_source", message: "", sourceStage: "S1-02")]
        )
        let data = try JSONEncoder().encode(candidate)
        let decoded = try JSONDecoder().decode(JBRootCandidate.self, from: data)
        XCTAssertEqual(decoded, candidate)
    }

    // MARK: - D8 兼容：旧信封仅含 jbrootCandidates 投影，解码不报错、权威列表为空

    func testLegacyPathEvidenceDecodesProjectionOnly() throws {
        let json = """
        {
          "tweakInject": null,
          "dynamicLibraries": null,
          "jbrootCandidates": ["/var/jb", "/"]
        }
        """
        let decoded = try JSONDecoder().decode(PathEvidence.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.jbrootCandidates, ["/var/jb", "/"])
        XCTAssertEqual(decoded.jbrootCandidateDetails, [])
    }
}
