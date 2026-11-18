//
//  ReportServiceTests.swift
//  FilterKit Stage 2 — Reporting D5（ReportService）
//
//  覆盖冻结规格 §7.3 Service-001 ～ Service-003。服务只做三段编排；
//  校验不通过不抛异常阻断，是否导出由调用方决定；不访问文件系统。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class ReportServiceTests: XCTestCase {

    // MARK: - Service-001 完整快照：构建 → 校验 → 导出

    func testService001BuildValidateExportRoundTrip() throws {
        let record = PluginPairingRecord(
            category: .paired,
            pairing: .paired,
            pairingKey: "alpha",
            dylib: PluginFileEvidence(path: "/dir/alpha.dylib", name: "alpha.dylib",
                                       extension: "dylib", kind: .dylib,
                                       exists: true, readable: true),
            plist: PluginFileEvidence(path: "/dir/alpha.plist", name: "alpha.plist",
                                       extension: "plist", kind: .plist),
            basis: .exactFilenameMatch)
        let pairing = PluginPairingSnapshot(
            route: "roothide", sourceDirectory: "/dir",
            records: [record])
        let parsing = FilterParseSnapshot(
            route: "roothide", sourceDirectory: "/dir", status: "enumerated",
            parsed: [FilterParseResult(
                pairingKey: "alpha",
                dylibPath: "/dir/alpha.dylib",
                plistPath: "/dir/alpha.plist",
                route: "roothide",
                status: .valid,
                filter: FilterRule(bundles: ["com.hide"]))],
            notParsed: [], counts: FilterParseCounts(), warnings: [])

        let input = ReportBuildInput(
            environment: JailbreakEnvironment(profileId: "RootHideProfile"),
            inventory: nil,
            pairing: pairing,
            parsing: parsing,
            profile: ProfileRef(id: "RootHideProfile", route: "roothide"))

        let service = ReportService()
        let envelope = service.buildReport(input: input)
        let validation = service.validate(envelope)
        XCTAssertTrue(validation.isValid)

        let data = try service.exportJSON(envelope)
        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)
        XCTAssertEqual(decoded, envelope)
    }

    // MARK: - Service-002 校验不通过：不抛异常，导出由调用方决定

    func testService002InvalidReportDoesNotThrowAndExportIsCallerDecision() throws {
        let invalid = Plugin(
            pluginID: "bad",
            name: "Bad",
            dylibPath: "/dir/bad.dylib",
            plistPath: "/dir/bad.plist",
            pairing: .paired,
            source: .unknown,
            ownership: Ownership(sourceType: .unknown),
            filter: FilterRule(bundles: ["com.bad"]),
            configured: false,
            loaded: .unknown,
            validation: ValidationReport(status: "parse_failed"),
            profileId: "RootHideProfile")
        let envelope = ReportEnvelope(
            profile: ProfileRef(id: "RootHideProfile", route: "roothide"),
            environment: JailbreakEnvironment(profileId: "RootHideProfile"),
            plugins: [invalid])

        let service = ReportService()
        let validation = service.validate(envelope)
        XCTAssertFalse(validation.isValid)
        XCTAssertFalse(validation.errors.isEmpty)

        // 服务不阻断导出；编码仍可完成，是否使用该报告由调用方决定。
        let data = try service.exportJSON(envelope)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Service-003 协议接缝可替换为桩

    func testService003CollaboratorsInjectableThroughSeams() throws {
        let stubBuilder = StubBuilder()
        let stubValidator = StubValidator()
        let stubExporter = StubExporter()
        let service = ReportService(
            builder: stubBuilder,
            validator: stubValidator,
            exporter: stubExporter)

        let input = ReportBuildInput(
            environment: JailbreakEnvironment(profileId: "RootHideProfile"),
            profile: ProfileRef(id: "RootHideProfile", route: "roothide"))

        let envelope = service.buildReport(input: input)
        XCTAssertNotNil(stubBuilder.lastInput)

        let validation = service.validate(envelope)
        XCTAssertTrue(validation.isValid)
        XCTAssertEqual(stubValidator.lastReport, envelope)

        let data = try service.exportJSON(envelope)
        XCTAssertEqual(data, Data("{}".utf8))
        XCTAssertEqual(stubExporter.lastReport, envelope)
    }
}

// MARK: - 测试桩（不进生产目标）

private final class StubBuilder: ReportBuilding {
    var lastInput: ReportBuildInput?
    func build(_ input: ReportBuildInput) -> ReportEnvelope {
        lastInput = input
        return ReportEnvelope(
            profile: ProfileRef(id: "RootHideProfile", route: "roothide"),
            environment: JailbreakEnvironment(profileId: "RootHideProfile"))
    }
}

private final class StubValidator: ReportValidating {
    var lastReport: ReportEnvelope?
    func validate(_ report: ReportEnvelope) -> ReportValidationResult {
        lastReport = report
        return ReportValidationResult(isValid: true, errors: [])
    }
}

private final class StubExporter: ReportExporting {
    var lastReport: ReportEnvelope?
    func export(_ report: ReportEnvelope) throws -> Data {
        lastReport = report
        return Data("{}".utf8)
    }
}
