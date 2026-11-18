//
//  B5DeterminismTests.swift
//  FilterKit Stage 2 — B5 确定性与 Codable 往返（附加回归，不计入 71 项冻结回归）
//
//  离线只读：同一快照重复裁决结果必须逐字段相等；衔接输入 Codable 往返一致、
//  重复编码字节稳定。不访问真实文件系统，不依赖目录遍历顺序之外的环境状态。
//
//  对齐：Spec/Stage-2/Stage-2.2-B5-Integration-Regression.md §4 确定性检查。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class B5DeterminismTests: XCTestCase {

    private static func fixtureURL(kind: String, fileName: String) -> URL {
        let testsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return testsDir.appendingPathComponent("Fixtures/S1-02/\(kind)/\(fileName)")
    }

    private func loadJBSnapshot(_ kind: String) throws -> JBRootCandidateSnapshot {
        let url = Self.fixtureURL(kind: kind, fileName: "environment.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JBRootCandidateSnapshot.self, from: data)
    }

    // MARK: - B3 裁决重复执行确定

    func testJBResolverDeterminism() throws {
        let snapshot = try loadJBSnapshot("rh-valid")
        let resolver = JBRootResolver()
        XCTAssertEqual(resolver.resolve(snapshot), resolver.resolve(snapshot))
    }

    // MARK: - B4 目录定位重复执行确定

    func testDirectoryResolverDeterminism() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/S1-03/rh-valid/environment.json")
        let snapshot = try JSONDecoder().decode(ElleKitDirectorySnapshot.self, from: Data(contentsOf: url))
        let resolver = ElleKitDirectoryResolver()
        XCTAssertEqual(resolver.resolve(snapshot), resolver.resolve(snapshot))
    }

    // MARK: - 跨批次 Pipeline 重复执行确定

    func testPipelineDeterminism() throws {
        let pipeline = ElleKitDirectoryPipeline()
        let snapshot = try loadJBSnapshot("rh-valid")
        let first = pipeline.resolve(jbrootSnapshot: snapshot, directoryFs: nil)
        let second = pipeline.resolve(jbrootSnapshot: snapshot, directoryFs: nil)
        XCTAssertEqual(first, second)
    }

    // MARK: - 桥接映射重复执行确定（resolved 与 ambiguous 两条路径）

    func testBridgeDeterminism() {
        let resolved = JBRootResolutionResult(
            jbroot: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
            ambiguous: false,
            outcome: "resolved",
            candidates: [JBRootCandidate(path: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
                                         source: "scan", route: "roothide")]
        )
        let ambiguous = JBRootResolutionResult(
            ambiguous: true,
            outcome: "ambiguous",
            candidates: [
                JBRootCandidate(path: "/var/containers/Bundle/Application/.jbroot-A", source: "api", route: "roothide"),
                JBRootCandidate(path: "/var/containers/Bundle/Application/.jbroot-B", source: "scan", route: "roothide")
            ]
        )

        XCTAssertEqual(JBRootToDirectoryBridge.bridge(jbroot: resolved),
                       JBRootToDirectoryBridge.bridge(jbroot: resolved))
        XCTAssertEqual(JBRootToDirectoryBridge.bridge(jbroot: ambiguous),
                       JBRootToDirectoryBridge.bridge(jbroot: ambiguous))
    }

    // MARK: - 衔接输入 Codable 往返与重复编码稳定
    func testPipelineInputCodableRoundTripAndStableEncoding() throws {
        let input = ElleKitDirectoryPipelineInput(
            route: "roothide",
            jbroot: "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4",
            jbrootOutcome: "resolved",
            ambiguous: false,
            warnings: [ReportWarning(code: "directory_not_found", message: "m", sourceStage: "S1-03")]
        )

        let encoder = JSONEncoder()
        // 显式排序字典键，避免编码容器键序在不同调用间不稳定导致同值两次编码字节不一致。
        encoder.outputFormatting = .sortedKeys
        let firstData = try encoder.encode(input)
        let secondData = try encoder.encode(input)
        XCTAssertEqual(firstData, secondData)

        let decoded = try JSONDecoder().decode(ElleKitDirectoryPipelineInput.self, from: firstData)
        XCTAssertEqual(decoded, input)
    }

    // MARK: - B1 结果 → 路线映射：封闭集口径 + 告警保留 + 重复确定

    private func makeEnvironment(jailbreakType: String,
                                 outcome: String,
                                 warnings: [ReportWarning] = []) -> EnvironmentDetectionResult {
        EnvironmentDetectionResult(
            jailbreakType: jailbreakType,
            architecture: "arm64e",
            iosVersion: "17.0.2",
            bootstrapName: nil,
            bootstrapVersion: nil,
            ellekitImplementation: "unknown",
            versionReadiness: VersionReadiness(status: .notInstalled),
            adapterProfile: nil,
            outcome: outcome,
            warnings: warnings
        )
    }

    func testEnvironmentRouteMapperCasesAndDeterminism() {
        let cases: [(type: String, outcome: String, expected: String?)] = [
            ("roothide", "profile_candidate", "roothide"),
            ("rootless", "profile_candidate", "rootless"),
            ("rootful", "unsupported_profile", "rootful"),
            ("unknown", "unknown", nil),
            ("unknown", "conflict_no_profile", nil)
        ]
        for testCase in cases {
            let env = makeEnvironment(jailbreakType: testCase.type, outcome: testCase.outcome)
            let mapping = EnvironmentRouteMapper.route(from: env)
            XCTAssertEqual(mapping.route, testCase.expected, "\(testCase.type)/\(testCase.outcome)")
            // 重复映射确定。
            XCTAssertEqual(mapping, EnvironmentRouteMapper.route(from: env))
        }

        // 冲突告警原样保留，不被映射层吞掉。
        let conflictWarning = ReportWarning(code: "route_signal_conflict", message: "", sourceStage: "S1-01")
        let conflictEnv = makeEnvironment(jailbreakType: "unknown",
                                         outcome: "conflict_no_profile",
                                         warnings: [conflictWarning])
        let mapping = EnvironmentRouteMapper.route(from: conflictEnv)
        XCTAssertNil(mapping.route)
        XCTAssertEqual(mapping.warnings, [conflictWarning])
    }
}
