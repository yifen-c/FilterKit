//
//  B5FixtureComparisonTests.swift
//  FilterKit Stage 2 — B5 Stage 1 夹具深比较（附加回归，不计入 71 项冻结回归）
//
//  在 B1/B2/B3/B4 既有单测之外，按夹具目录批量复核各批次裁决输出与 metadata 基线
//  的关键字段与告警集合一致；只做只读解码与离线裁决，不复制第二份基线，不访问
//  真实文件系统。既有 71 项冻结测试文件与方法保持原样，本文件为独立深比较层。
//
//  对齐：Spec/Stage-2/Stage-2.2-B5-Integration-Regression.md §4 深比较矩阵。
//

import Foundation
import XCTest
@testable import Models
@testable import Adapters
@testable import Core

final class B5FixtureComparisonTests: XCTestCase {

    // MARK: - 元数据解码形态

    private struct JBExpected: Codable, Equatable {
        let jbroot: String?
        let ambiguous: Bool
        let outcome: String
        let candidateCount: Int
    }

    private struct JBMeta: Codable, Equatable {
        let expected: JBExpected
        let expectedWarnings: [String]
    }

    private struct DirExpected: Codable, Equatable {
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

    private struct DirMeta: Codable, Equatable {
        let expected: DirExpected
        let expectedWarnings: [String]
    }

    private struct EnvExpected: Codable, Equatable {
        let jailbreakType: String
        let ellekitVersionStatus: String
    }

    private struct EnvMeta: Codable, Equatable {
        let expected: EnvExpected
        let expectedOutcome: String
    }

    // MARK: - 辅助

    private static func batchURL(batch: String) -> URL {
        let testsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return testsDir.appendingPathComponent("Fixtures/\(batch)")
    }

    private func kinds(of batch: String) -> [String] {
        let dir = Self.batchURL(batch: batch)
        let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        return entries?
            .filter { $0.hasDirectoryPath }
            .map { $0.lastPathComponent }
            .sorted() ?? []
    }

    private func decode<T: Decodable>(_ type: T.Type, batch: String, kind: String, file: String) throws -> T {
        let url = Self.batchURL(batch: batch)
            .appendingPathComponent(kind)
            .appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    private func warningCodes(_ warnings: [ReportWarning]) -> Set<String> {
        Set(warnings.map(\.code))
    }

    // MARK: - S1-02：B2 候选收集深比较（顺序/来源/路线映射/规范化路径）

    func testS102CollectorDeepComparison() throws {
        let collector = JBRootCandidateCollector()
        for kind in kinds(of: "S1-02") {
            let snapshot = try decode(JBRootCandidateSnapshot.self, batch: "S1-02", kind: kind, file: "environment.json")
            let collected = collector.collect(snapshot)
            let signals = snapshot.signals.candidates

            // 顺序与来源保留（非法路径被剔除后，保留候选仍按原序）。
            XCTAssertEqual(collected.candidates.map(\.source),
                           signals.compactMap { $0.source }, "\(kind) source order")
            for candidate in collected.candidates {
                let expectedRoute: String
                switch candidate.source {
                case "rootless": expectedRoute = "rootless"
                case "rootful": expectedRoute = "rootful"
                default:
                    expectedRoute = JBRootCandidateCollector.knownSources.contains(candidate.source) ? "roothide" : ""
                }
                XCTAssertEqual(candidate.route, expectedRoute, "\(kind) route \(candidate.source)")
                XCTAssertFalse(candidate.path.isEmpty, "\(kind) normalized path")
            }
        }
    }

    // MARK: - S1-02：JBROOT 裁决深比较

    func testS102FixturesDeepComparison() throws {
        let resolver = JBRootResolver()
        for kind in kinds(of: "S1-02") {
            let snapshot = try decode(JBRootCandidateSnapshot.self, batch: "S1-02", kind: kind, file: "environment.json")
            let meta = try decode(JBMeta.self, batch: "S1-02", kind: kind, file: "metadata.json")
            let result = resolver.resolve(snapshot)

            XCTAssertEqual(result.outcome, meta.expected.outcome, "\(kind) outcome")
            XCTAssertEqual(result.jbroot, meta.expected.jbroot, "\(kind) jbroot")
            XCTAssertEqual(result.ambiguous, meta.expected.ambiguous, "\(kind) ambiguous")
            XCTAssertEqual(result.candidateCount, meta.expected.candidateCount, "\(kind) candidateCount")
            XCTAssertEqual(warningCodes(result.warnings), Set(meta.expectedWarnings), "\(kind) warnings")
        }
    }

    // MARK: - S1-03：目录/软链定位深比较

    func testS103FixturesDeepComparison() throws {
        let resolver = ElleKitDirectoryResolver()
        for kind in kinds(of: "S1-03") {
            let snapshot = try decode(ElleKitDirectorySnapshot.self, batch: "S1-03", kind: kind, file: "environment.json")
            let meta = try decode(DirMeta.self, batch: "S1-03", kind: kind, file: "metadata.json")
            let result = resolver.resolve(snapshot)
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
            XCTAssertEqual(warningCodes(result.warnings), Set(meta.expectedWarnings), "\(kind) warnings")
        }
    }

    // MARK: - S1-01：环境识别深比较（类型/状态/ outcome 基线）

    func testS101FixturesDeepComparison() throws {
        let detector = EnvironmentDetector(advisors: [RootHideAdapter(), RootlessAdapter()])
        for kind in kinds(of: "S1-01") {
            let snapshot = try decode(EnvironmentSnapshot.self, batch: "S1-01", kind: kind, file: "environment.json")
            let meta = try decode(EnvMeta.self, batch: "S1-01", kind: kind, file: "metadata.json")
            let result = detector.detect(snapshot)

            XCTAssertEqual(result.jailbreakType, meta.expected.jailbreakType, "\(kind) jailbreakType")
            XCTAssertEqual(result.versionReadiness.status.rawValue, meta.expected.ellekitVersionStatus, "\(kind) versionStatus")
            XCTAssertEqual(result.outcome, meta.expectedOutcome, "\(kind) outcome")
        }
    }
}
