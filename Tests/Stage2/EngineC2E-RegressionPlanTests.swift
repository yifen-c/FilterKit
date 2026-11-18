//
//  EngineC2E-RegressionPlanTests.swift
//  FilterKit Stage 2 — Engine-C2-E1/E2 回归矩阵与历史基线组织核对（测试目标专用）
//
//  核对注册表身份唯一性、依赖边有效性、证据状态与待验收纪律；并复核既有
//  C1 22 项基线注册表与 Stage1~Stage2 套件映射。本测试只做组织层静态核对，
//  不解析 Runner 报告、不把注册表条目统计为已通过。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2ERegressionPlanTests: XCTestCase {

    // MARK: - E1 注册表身份与结构

    func testRegressionIDsUnique() {
        let ids = EngineC2ERegistry.all.map { $0.identifier }
        XCTAssertEqual(Set(ids).count, ids.count, "回归编号不得重复")
    }

    func testSuiteIdentityFieldsPresent() {
        for entry in EngineC2ERegistry.all {
            XCTAssertFalse(entry.suiteClass.isEmpty, "\(entry.identifier) 缺套件类名")
            XCTAssertFalse(entry.sourceFile.isEmpty, "\(entry.identifier) 缺源文件")
            XCTAssertTrue(entry.sourceFile.hasSuffix(".swift"),
                          "\(entry.identifier) 源文件基名应为 .swift")
        }
    }

    func testDependencyReferencesExistingCase() {
        let ids = Set(EngineC2ERegistry.all.map { $0.identifier })
        for entry in EngineC2ERegistry.all {
            guard let dep = entry.dependency else { continue }
            XCTAssertTrue(ids.contains(dep),
                          "\(entry.identifier) 前置依赖 \(dep) 不在注册表内")
        }
    }

    func testEvidenceStateMatchesEvidenceRun() {
        for entry in EngineC2ERegistry.all {
            switch entry.evidenceState {
            case .pendingRunner:
                XCTAssertNil(entry.evidenceRun,
                              "待验收项 \(entry.identifier) 不得携带归档 Runner 编号")
            case .priorRunnerEvidence, .runnerVerified:
                XCTAssertNotNil(entry.evidenceRun,
                                 "有证据状态的 \(entry.identifier) 必须记录归档 Runner 编号")
            }
        }
    }

    func testC2DCasesVerifiedAgainstLatestRun() {
        let dIDs = ["C2-D1", "C2-D2", "C2-D3", "C2-D4"]
        for id in dIDs {
            let entry = EngineC2ERegistry.first(byID: id)
            XCTAssertEqual(entry?.evidenceState, .runnerVerified,
                           "\(id) 应以 run 44106064051 归档证据标记 runnerVerified")
            XCTAssertEqual(entry?.evidenceRun, EngineC2ERegistry.latestAcceptanceRun,
                           "\(id) 证据编号须指向最新归档 Runner")
        }
    }

    func testNoCaseAllowsSkipByDefault() {
        for entry in EngineC2ERegistry.all where entry.allowsSkip {
            XCTFail("回归矩阵默认不允许 Skip：\(entry.identifier)")
        }
    }

    /// 注册表套件覆盖与测试目标既有 XCTest 套件一一对应（反向身份核对）。
    func testRegistryCoversAllKnownSuites() {
        let knownSuites: [String] = [
            "EnvironmentDetectionTests",
            "JBRootCandidateCollectionTests",
            "JBRootValidationTests",
            "ElleKitDirectoryTests",
            "PluginEnumerationTests",
            "PluginPairingKeyTests",
            "PluginPairingIndexTests",
            "PluginPairingEngineTests",
            "PluginPairingIntegrationTests",
            "PluginPairingCodableTests",
            "PluginPairingS105FixtureTests",
            "PlistReaderTests",
            "PlistDecoderTests",
            "PlistValueKindTests",
            "B5IntegrationTests",
            "B5FixtureComparisonTests",
            "B5DeterminismTests",
            "ModelsCodableTests",
            "PluginInventoryCodableTests",
            "FilterParseResultTests",
            "RootHideFilterParserTests",
            "FilterParseEngineTests",
            "RootlessFilterParserTests",
            "EngineC1ParserBaselineTests",
            "EngineC1EngineBaselineTests",
            "EngineC2EndToEndTests",
            "EngineC2BatchIsolationTests",
            "EngineC2SnapshotWarningsTests",
            "EngineC2BaselineIntegrationTests",
            "EngineC2RouteSymmetryTests",
            "EngineC2EvidenceTraceTests",
            "EngineC2CombinedScenarioTests"
        ]
        let registered = Set(EngineC2ERegistry.all.map { $0.suiteClass })
        for suite in knownSuites {
            XCTAssertTrue(registered.contains(suite), "注册表缺套件 \(suite)")
        }
        XCTAssertEqual(registered.count, knownSuites.count,
                       "注册表套件与既有 XCTest 套件集合不一致")
    }

    // MARK: - E2 Stage1~Stage2 历史基线组织

    func testStage1MappingEntriesPresent() {
        let stage1IDs = ["S1-01", "S1-02a", "S1-02b", "S1-03", "S1-04",
                         "S1-05a", "S1-05b", "S1-05c", "S1-05d", "S1-05e", "S1-05f",
                         "S1-06a", "S1-06b", "S1-06c"]
        for id in stage1IDs {
            XCTAssertNotNil(EngineC2ERegistry.first(byID: id), "缺 Stage1 映射 \(id)")
        }
    }

    func testC1BaselineRegistryRetainsTwentyTwoItems() {
        XCTAssertEqual(EngineC1BaselineRegistry.all.count, 22,
                       "S1-06 基线覆盖数为 22，不与 XCTest 执行总数相加")
    }

    func testParse015AReleasedFromPendingRunner() throws {
        let baseline = try XCTUnwrap(
            EngineC1BaselineRegistry.first(byID: "PARSE-015-A"),
            "注册表缺 PARSE-015-A")
        XCTAssertFalse(baseline.pendingRunner,
                       "PARSE-015-A 已解除挂起；run 44106064051 复验通过")
    }

    func testParse009BRemainsIndependentReview() throws {
        let baseline = try XCTUnwrap(
            EngineC1BaselineRegistry.first(byID: "PARSE-009-B"),
            "PARSE-009-B 独立挂起项应保留在基线注册表")
        // 仅核对条目在位；观测类型词 / 下标口径差异待独立授权复核，本轮不改 Parser 与期望。
        XCTAssertEqual(baseline.caseID, "PARSE-009-B")
    }
}
