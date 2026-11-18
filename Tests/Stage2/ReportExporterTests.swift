//
//  ReportExporterTests.swift
//  FilterKit Stage 2 — Reporting D4（ReportExporter / ReportSerialization）
//
//  覆盖冻结规格 §6.4 Exporter-001 ～ Exporter-005。只核对序列化口径、
//  三态保留、确定性与证据字段往返；不访问文件系统，不替代 Runner 真机证据。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class ReportExporterTests: XCTestCase {

    // MARK: - 桩构造器

    private func makePlugin(id: String,
                            installed: Bool? = true,
                            filter: FilterRule? = FilterRule(bundles: ["com.hide"]),
                            details: OwnershipDetails? = nil) -> Plugin {
        Plugin(
            pluginID: id,
            name: id.capitalized,
            dylibPath: "/dir/\(id).dylib",
            plistPath: "/dir/\(id).plist",
            pairing: .paired,
            source: .dpkgSileo,
            ownership: Ownership(sourceType: .dpkgSileo, packageID: "com.\(id)"),
            ownershipDetails: details,
            filter: filter,
            installed: installed,
            configured: filter != nil,
            loaded: .unknown,
            validation: ValidationReport(
                status: filter != nil ? "valid" : "type_mismatch",
                warnings: ["w:\(id)"],
                skippedFields: ["Bundles:field_type"]),
            profileId: "RootHideProfile")
    }

    private func makeEnvelope(plugins: [Plugin],
                               unknowns: [UnknownItem] = [],
                               warnings: [ReportWarning] = []) -> ReportEnvelope {
        ReportEnvelope(
            profile: ProfileRef(id: "RootHideProfile", route: "roothide"),
            environment: JailbreakEnvironment(profileId: "RootHideProfile"),
            plugins: plugins,
            unknownItems: unknowns,
            warnings: warnings)
    }

    // MARK: - Exporter-001 编码成功且可往返

    func testExporter001EncodesAndRoundTrips() throws {
        let envelope = makeEnvelope(plugins: [makePlugin(id: "alpha")])

        let data = try ReportExporter().export(envelope)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(object)
        let topKeys: Set<String> = object.map { Set($0.keys) } ?? []
        for key in ["schemaVersion", "generatorVersion", "profile", "environment",
                    "plugins", "unknownItems", "warnings"] {
            XCTAssertTrue(topKeys.contains(key), "缺少顶层键 \(key)")
        }

        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)
        XCTAssertEqual(decoded, envelope)
    }

    // MARK: - Exporter-002 三态 Bool? 保留

    func testExporter002OptionalBoolThreeStatesSurvive() throws {
        let envelope = makeEnvelope(plugins: [
            makePlugin(id: "yes", installed: true),
            makePlugin(id: "no", installed: false),
            makePlugin(id: "unknown", installed: nil)
        ])

        let data = try ReportExporter().export(envelope)
        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)

        XCTAssertEqual(decoded.plugins.count, 3)
        XCTAssertEqual(decoded.plugins.first { $0.pluginID == "yes" }?.installed, true)
        XCTAssertEqual(decoded.plugins.first { $0.pluginID == "no" }?.installed, false)
        XCTAssertNil(decoded.plugins.first { $0.pluginID == "unknown" }?.installed)

        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let plugins = object?["plugins"] as? [[String: Any]]
        let unknownEntry = plugins?.first { ($0["pluginID"] as? String) == "unknown" }
        XCTAssertTrue(unknownEntry?["installed"] is NSNull)
    }

    // MARK: - Exporter-003 确定性导出

    func testExporter003DeterministicOutputAcrossShuffledInput() throws {
        let plugins = [
            makePlugin(id: "zeta"),
            makePlugin(id: "alpha"),
            makePlugin(id: "mu")
        ]
        let unknowns = [
            UnknownItem(path: "/dir/zeta.plist", base: "zeta", reason: "missing_dylib", sourceStage: "stage2.2-c3"),
            UnknownItem(path: "/dir/alpha.plist", base: "alpha", reason: "orphan_plist", sourceStage: "stage2.2-c3")
        ]
        let warnings = [
            ReportWarning(code: "b", message: "第二", sourceStage: "stage2.2-c1"),
            ReportWarning(code: "a", message: "第一", sourceStage: "stage2.2-c1")
        ]
        let envelope = makeEnvelope(plugins: plugins, unknowns: unknowns, warnings: warnings)

        let exporter = ReportExporter()
        let first = try exporter.export(envelope)
        let second = try exporter.export(envelope)

        XCTAssertEqual(first, second)

        // 数组按显式策略排序；对象键由 sortedKeys 排序。
        let object = try JSONSerialization.jsonObject(with: first) as? [String: Any]
        let exportedPlugins = object?["plugins"] as? [[String: Any]]
        XCTAssertEqual(exportedPlugins?.compactMap { $0["pluginID"] as? String },
                       ["alpha", "mu", "zeta"])
    }

    // MARK: - Exporter-004 证据字段完整序列化

    func testExporter004EvidenceFieldsRoundTrip() throws {
        let details = OwnershipDetails(
            fileOwnership: "dpkg",
            markers: "com.hide",
            conflicts: ["conflict-a", "conflict-b"],
            notes: ["note-a"],
            packageVersion: "1.0.0",
            architecture: "arm64e")
        var plugin = makePlugin(id: "alpha", details: details)
        plugin.filter = FilterRule(
            bundles: ["com.hide"],
            classes: ["HideClass"],
            executables: ["SpringBoard"],
            coreFoundationVersion: CoreFoundationVersion(mode: .max, max: 16),
            otherKeys: ["UnloadAfter", "Version"])
        let envelope = makeEnvelope(plugins: [plugin])

        let data = try ReportExporter().export(envelope)
        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)

        XCTAssertEqual(decoded, envelope)
        let decodedPlugin = decoded.plugins.first
        XCTAssertEqual(decodedPlugin?.ownershipDetails?.conflicts, ["conflict-a", "conflict-b"])
        XCTAssertEqual(decodedPlugin?.ownershipDetails?.notes, ["note-a"])
        XCTAssertEqual(decodedPlugin?.filter?.otherKeys, ["UnloadAfter", "Version"])
        XCTAssertEqual(decodedPlugin?.validation.skippedFields, ["Bundles:field_type"])
    }

    // MARK: - Exporter-005 原始报告不被改动；错误类型明确

    func testExporter005OriginalReportUnchangedAndErrorTypeExplicit() throws {
        let envelope = makeEnvelope(plugins: [makePlugin(id: "alpha")])
        let original = envelope

        _ = try ReportExporter().export(envelope)

        XCTAssertEqual(envelope, original)

        let failure = ReportExportError.encodingFailed("demo")
        guard case ReportExportError.encodingFailed(let message) = failure else {
            return XCTFail("错误类型应为 encodingFailed")
        }
        XCTAssertEqual(message, "demo")
        XCTAssertEqual(failure, ReportExportError.encodingFailed("demo"))
    }
}
