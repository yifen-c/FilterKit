//
//  B5IntegrationTests.swift
//  FilterKit Stage 2 — B5 跨批次集成回归（INT-001~010，附加用例，不计入 71 项冻结回归）
//
//  离线只读：经 `ElleKitDirectoryPipeline` 组合 B2/B3 裁决与 B4 目录定位，核对
//  输入输出类型匹配、证据传递、未确认状态保留、告警不丢失、路线不错误切换。
//  不访问真实文件系统，不实例化 Adapter 到 Core 编排，不枚举 dylib，不装配插件 Pipeline。
//  用例在 macOS runner 执行（本机无 Swift 工具链，未编译验证）。
//
//  对齐：Spec/Stage-2/Stage-2.2-B5-Integration-Regression.md §3.2；
//  Stage 1 基线 Tests/S1-02、Tests/S1-03 夹具与报告。
//

import Foundation
import XCTest
@testable import Models
@testable import Adapters
@testable import Core

final class B5IntegrationTests: XCTestCase {

    private let pipeline = ElleKitDirectoryPipeline()

    // MARK: - 夹具读取（只读引用，不复制基线）

    private static func fixtureURL(batch: String, kind: String, fileName: String) -> URL {
        let testsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return testsDir.appendingPathComponent("Fixtures/\(batch)/\(kind)/\(fileName)")
    }

    private func loadJBSnapshot(_ kind: String) throws -> JBRootCandidateSnapshot {
        let url = Self.fixtureURL(batch: "S1-02", kind: kind, fileName: "environment.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(JBRootCandidateSnapshot.self, from: data)
    }

    private func loadDirectoryFs(_ kind: String) throws -> DirectoryFsSignal? {
        let url = Self.fixtureURL(batch: "S1-03", kind: kind, fileName: "environment.json")
        let data = try Data(contentsOf: url)
        let snapshot = try JSONDecoder().decode(ElleKitDirectorySnapshot.self, from: data)
        return snapshot.fs
    }

    private func resolve(jbKind: String,
                         directoryKind: String,
                         environmentRoute: String? = nil) throws -> IntegratedDirectoryResolution {
        let fs = try loadDirectoryFs(directoryKind)
        return pipeline.resolve(jbrootSnapshot: try loadJBSnapshot(jbKind),
                                directoryFs: fs,
                                environmentRoute: environmentRoute)
    }

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

    // MARK: - INT-001：有效 RootHide 候选 → 确认 JBROOT → 推导 TweakInject

    func testINT001ValidRootHideResolved() throws {
        let result = try resolve(jbKind: "rh-valid", directoryKind: "rh-valid")

        XCTAssertEqual(result.jbroot.outcome, "resolved")
        XCTAssertEqual(result.pipelineInput.jbroot,
                       "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4")
        XCTAssertEqual(result.pipelineInput.route, "roothide")
        XCTAssertEqual(result.directory.outcome, "resolved")
        XCTAssertEqual(result.directory.tweakInject?.requestedPath,
                       "/var/containers/Bundle/Application/.jbroot-9C414BB7D5DCECC4/usr/lib/TweakInject/")
        XCTAssertEqual(result.directory.dynamicLibraries?.targetMatch, true)
    }

    // MARK: - INT-002：多个有效 RootHide 候选 → ambiguous，不选边、不注入确认路径

    func testINT002AmbiguousDoesNotSelectCandidate() throws {
        let result = try resolve(jbKind: "rh-multiple", directoryKind: "rh-valid")

        XCTAssertTrue(result.jbroot.ambiguous)
        XCTAssertEqual(result.jbroot.outcome, "ambiguous")
        // 歧义不进入确认路径解析：jbroot 与路线均不得从候选回填。
        XCTAssertNil(result.pipelineInput.jbroot)
        XCTAssertNil(result.pipelineInput.route)
        XCTAssertEqual(result.directory.outcome, "unresolved")
        XCTAssertNil(result.directory.tweakInject?.requestedPath)
    }

    // MARK: - INT-003：RootHide 无有效 JBROOT → 不回退 /var/jb 或 /

    func testINT003NoValidJBRootNoFallback() throws {
        let result = try resolve(jbKind: "rh-badname", directoryKind: "rh-valid",
                                 environmentRoute: "roothide")

        XCTAssertEqual(result.jbroot.outcome, "no_candidate")
        XCTAssertNil(result.pipelineInput.jbroot)
        XCTAssertEqual(result.pipelineInput.route, "roothide")
        XCTAssertEqual(result.directory.outcome, "unresolved")
        XCTAssertNil(result.directory.tweakInject?.requestedPath)
        XCTAssertNotEqual(result.directory.tweakInject?.requestedPath?.hasPrefix("/var/jb"), true)
        XCTAssertNotEqual(result.directory.tweakInject?.requestedPath, "/")
    }

    // MARK: - INT-004：Rootless → 使用独立 /var/jb 路径，不混入 RootHide 规则

    func testINT004RootlessIndependentPath() throws {
        let env = makeEnvironment(jailbreakType: "rootless", outcome: "profile_candidate")
        let result = pipeline.resolve(jbrootSnapshot: try loadJBSnapshot("rootless-varjb"),
                                      directoryFs: try loadDirectoryFs("rootless-valid"),
                                      environment: env)

        XCTAssertEqual(result.jbroot.outcome, "cross_route_only")
        XCTAssertNil(result.pipelineInput.jbroot)
        XCTAssertEqual(result.pipelineInput.route, "rootless")
        XCTAssertEqual(result.directory.outcome, "resolved")
        XCTAssertEqual(result.directory.tweakInject?.requestedPath, "/var/jb/usr/lib/TweakInject/")
    }

    // MARK: - INT-005：Rootful → 仅诊断参照，不获得管理 Profile 资格

    func testINT005RootfulDiagnosticOnly() throws {
        let env = makeEnvironment(jailbreakType: "rootful", outcome: "unsupported_profile")
        let result = pipeline.resolve(jbrootSnapshot: try loadJBSnapshot("rootful-root"),
                                      directoryFs: try loadDirectoryFs("rootful-valid"),
                                      environment: env)

        XCTAssertEqual(result.jbroot.outcome, "cross_route_only")
        XCTAssertEqual(result.directory.outcome, "rootful_diagnostic")
        XCTAssertTrue(result.directory.warnings.contains { $0.code == "rootful_route_not_profile" })
    }

    // MARK: - INT-006：JBROOT 校验失败 → 不生成已确认 TweakInject 路径

    func testINT006ValidationFailureNoConfirmedPath() throws {
        let result = try resolve(jbKind: "rh-badname", directoryKind: "rh-valid",
                                environmentRoute: "roothide")

        XCTAssertEqual(result.jbroot.outcome, "no_candidate")
        XCTAssertNil(result.pipelineInput.jbroot)
        XCTAssertNil(result.directory.tweakInject?.requestedPath)
        XCTAssertEqual(result.directory.outcome, "unresolved")
    }

    // MARK: - INT-007：TweakInject 不存在 → 保留 not_found

    func testINT007TweakInjectNotFoundPreserved() throws {
        let result = try resolve(jbKind: "rh-valid", directoryKind: "rh-missing")

        XCTAssertEqual(result.directory.outcome, "not_found")
        XCTAssertEqual(result.directory.tweakInject?.status, "not_found")
        XCTAssertTrue(result.directory.warnings.contains { $0.code == "directory_not_found" })
    }

    // MARK: - INT-008：DynamicLibraries 损坏软链 → 保留 broken

    func testINT008BrokenSymlinkPreserved() throws {
        let result = try resolve(jbKind: "rh-valid", directoryKind: "rh-broken-link")

        XCTAssertEqual(result.directory.dynamicLibraries?.symlinkState, "broken")
        XCTAssertEqual(result.directory.dynamicLibraries?.targetMatch, false)
        XCTAssertTrue(result.directory.warnings.contains { $0.code == "symlink_broken" })
        XCTAssertEqual(result.directory.outcome, "partial")
    }

    // MARK: - INT-009：软链权限拒绝 → 保留 denied

    func testINT009DeniedSymlinkPreserved() throws {
        let result = try resolve(jbKind: "rh-valid", directoryKind: "rh-target-denied")

        XCTAssertEqual(result.directory.dynamicLibraries?.symlinkState, "denied")
        XCTAssertEqual(result.directory.dynamicLibraries?.targetMatch, false)
        XCTAssertTrue(result.directory.warnings.contains { $0.code == "symlink_target_denied" })
        XCTAssertEqual(result.directory.outcome, "partial")
    }

    // MARK: - INT-010：未验证字段保持 nil，不得变成 false

    func testINT010UnverifiedFieldsRemainNil() throws {
        let fs = DirectoryFsSignal(
            tweakInject: DirectoryTiSignal(exists: true, readable: nil, enumerable: nil,
                                           realpath: nil, structureMatch: nil),
            dynamicLibraries: DirectoryDlSignal()
        )
        let result = pipeline.resolve(jbrootSnapshot: try loadJBSnapshot("rh-valid"),
                                       directoryFs: fs)

        XCTAssertEqual(result.directory.tweakInject?.exists, true)
        XCTAssertNil(result.directory.tweakInject?.readable)
        XCTAssertNil(result.directory.tweakInject?.enumerable)
        XCTAssertNil(result.directory.tweakInject?.structureMatch)
        // 可读/可枚举未验证按未通过参与分层，但证据位本身保留 nil。
        XCTAssertEqual(result.directory.tweakInject?.status, "partial")
    }
}
