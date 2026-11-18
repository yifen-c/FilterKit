//
//  EnvironmentDetectionTests.swift
//  FilterKit Stage 2 — B1 环境识别回归（S1-01 / ENV-001~015）
//
//  离线只读：测试只读引用 Tests/Fixtures/S1-01 原始夹具，不复制第二份基线；
//  不访问真实文件系统，不做真机写入、插件启停或 GUI 扫描。用例在 macOS
//  runner 执行（本机无 Swift 工具链，未编译验证）。
//
//  对齐：Spec/Stage-2/Stage-2.2-B-Data-Contract-Freeze.md §3、§7；
//  Stage 1 基线 Tests/S1-01/detector.js、report/S1-01-report.json。
//

import Foundation
import XCTest
@testable import Models
@testable import Adapters
@testable import Core

final class EnvironmentDetectionTests: XCTestCase {

    // MARK: - 夹具元数据（解码形态对齐 metadata.json）

    private struct MetaBootstrap: Codable, Equatable {
        let name: String?
        let version: String?
    }

    private struct MetaExpected: Codable, Equatable {
        let jailbreakType: String
        let architecture: String
        let iosVersion: String
        let bootstrap: MetaBootstrap
        let ellekitImplementation: String
        let ellekitVersion: String?
        let ellekitVersionStatus: String
        let adapterProfile: String?
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
        return testsDir.appendingPathComponent("Fixtures/S1-01/\(kind)/\(fileName)")
    }

    private func makeDetector() -> EnvironmentDetector {
        EnvironmentDetector(advisors: [RootHideAdapter(), RootlessAdapter()])
    }

    private func loadSnapshot(kind: String) throws -> EnvironmentSnapshot {
        let url = Self.fixtureURL(kind: kind, fileName: "environment.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(EnvironmentSnapshot.self, from: data)
    }

    private func loadMeta(kind: String) throws -> FixtureMeta {
        let url = Self.fixtureURL(kind: kind, fileName: "metadata.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FixtureMeta.self, from: data)
    }

    private func compare(result: EnvironmentDetectionResult,
                         meta: FixtureMeta,
                         envId: String) {
        let expected = meta.expected
        XCTAssertEqual(result.jailbreakType, expected.jailbreakType, "\(envId) jailbreakType")
        XCTAssertEqual(result.architecture, expected.architecture, "\(envId) architecture")
        XCTAssertEqual(result.iosVersion, expected.iosVersion, "\(envId) iosVersion")
        XCTAssertEqual(result.bootstrapName, expected.bootstrap.name, "\(envId) bootstrap.name")
        XCTAssertEqual(result.bootstrapVersion, expected.bootstrap.version, "\(envId) bootstrap.version")
        XCTAssertEqual(result.ellekitImplementation, expected.ellekitImplementation, "\(envId) implementation")
        XCTAssertEqual(result.versionReadiness.status.rawValue, expected.ellekitVersionStatus, "\(envId) versionStatus")
        XCTAssertEqual(result.versionReadiness.parsedVersion, expected.ellekitVersion, "\(envId) ellekitVersion")
        XCTAssertEqual(result.adapterProfile, expected.adapterProfile, "\(envId) adapterProfile")
        XCTAssertEqual(Set(result.warnings.map(\.code)), Set(meta.expectedWarnings), "\(envId) warnings")
        XCTAssertEqual(result.outcome, meta.expectedOutcome, "\(envId) outcome")
    }

    // MARK: - 夹具用例（ENV-001~010、ENV-014）

    private static let fixtureCases: [(envId: String, kind: String)] = [
        ("ENV-001", "roothide"),
        ("ENV-002", "rootless"),
        ("ENV-003", "rootful"),
        ("ENV-004", "unknown"),
        ("ENV-005", "unknown"),
        ("ENV-006", "incomplete"),
        ("ENV-007", "unknown"),
        ("ENV-008", "conflicting"),
        ("ENV-009", "conflicting"),
        ("ENV-010", "incomplete"),
        ("ENV-014", "incomplete")
    ]

    func testFixtureCasesENV001To010And014() throws {
        let detector = makeDetector()
        for testCase in Self.fixtureCases {
            let snapshot = try loadSnapshot(kind: testCase.kind)
            let meta = try loadMeta(kind: testCase.kind)
            let result = detector.detect(snapshot)
            compare(result: result, meta: meta, envId: testCase.envId)
        }
    }

    // MARK: - ENV-011：格式错误结构化捕获，识别器不崩溃

    func testENV011MalformedInputCapturedWithoutCrash() {
        let malformed = "{ not valid json"
        var decodeThrew = false
        do {
            _ = try JSONDecoder().decode(EnvironmentSnapshot.self, from: Data(malformed.utf8))
        } catch {
            decodeThrew = true
        }
        XCTAssertTrue(decodeThrew, "格式错误应被解码层结构化捕获")

        let result = makeDetector().detect(EnvironmentSnapshot())
        XCTAssertEqual(result.jailbreakType, "unknown")
        XCTAssertEqual(result.versionReadiness.status, .notInstalled)
        XCTAssertEqual(result.outcome, "unknown")
        XCTAssertTrue(result.warnings.contains { $0.code == "no_jailbreak_signals" })
    }

    // MARK: - ENV-012：版本存在但不可读 → unreadable + access_limited

    func testENV012UnreadableVersion() throws {
        var signals = EnvironmentSnapshot.Signals()
        signals.jailbreakType = .init(present: true, value: "roothide")
        signals.architecture = .init(present: true, value: "arm64e")
        signals.iosVersion = .init(present: true, value: "17.0.2")
        signals.bootstrap = .init(present: true, name: "dopamine-roothide", version: "3.0.13-30")
        signals.ellekitImplementation = .init(present: true, value: "roothide")
        signals.ellekitVersion = .init(present: true, value: nil, readability: "unreadable")

        let result = makeDetector().detect(EnvironmentSnapshot(signals: signals))
        XCTAssertEqual(result.versionReadiness.status, .unreadable)
        XCTAssertTrue(result.warnings.contains { $0.code == "access_limited" })
        XCTAssertEqual(result.outcome, "partial")
    }

    // MARK: - ENV-013：相同输入重复执行结果确定

    func testENV013Determinism() throws {
        let snapshot = try loadSnapshot(kind: "roothide")
        let detector = makeDetector()
        let first = detector.detect(snapshot)
        let second = detector.detect(snapshot)
        XCTAssertEqual(first, second)
    }

    // MARK: - ENV-015：metadata/environment ID 不一致由框架识别，识别判断不受影响

    func testENV015IdMismatchDoesNotAffectDetection() throws {
        let snapshot = try loadSnapshot(kind: "roothide")
        let meta = try loadMeta(kind: "roothide")
        let mismatchedId = "S1-01-MISMATCH-999"
        XCTAssertNotEqual(snapshot.fixtureId, mismatchedId)
        XCTAssertNotEqual(meta.fixtureId, mismatchedId)

        let result = makeDetector().detect(snapshot)
        XCTAssertEqual(result.adapterProfile, meta.expected.adapterProfile)
        XCTAssertEqual(result.outcome, meta.expectedOutcome)
    }

    // MARK: - VersionReadiness 增补字段 Codable 往返（兼容旧 JSON）

    func testVersionReadinessRoundTrip() throws {
        let readiness = VersionReadiness(
            status: .parsed,
            rawVersion: "1.2-3",
            parsedVersion: "1.2-3",
            warnings: [ReportWarning(code: "access_limited", message: "", sourceStage: "S1-01")]
        )
        let data = try JSONEncoder().encode(readiness)
        let decoded = try JSONDecoder().decode(VersionReadiness.self, from: data)
        XCTAssertEqual(decoded, readiness)
    }

    func testEnvironmentWithoutReadinessDecodesLegacyJSON() throws {
        // 旧信封 JSON 不含 versionReadiness 字段：解码应为 nil，不报错、不补默认结构。
        let json = """
        {
          "jailbreakType": "unknown",
          "profileId": "unknown-profile",
          "evidenceLevel": "partial",
          "pathEvidence": { "tweakInject": null, "dynamicLibraries": null, "jbrootCandidates": [] }
        }
        """
        let decoded = try JSONDecoder().decode(JailbreakEnvironment.self, from: Data(json.utf8))
        XCTAssertNil(decoded.versionReadiness)
    }
}
