//
//  ModelsCodableTests.swift
//  FilterKit Stage 2 骨架单测（2.2-A 仅测试补齐）
//
// 本文件在本机无 Swift 工具链，未编译验证；用例在 macOS runner 执行。
// 2.2-A 授权边界（见 Spec/Stage-2/Stage-2.2-A-Preflight-Audit.md）：
//   - 只补枚举原始值、全模型往返、nil/null/缺失、空数组编码测试；
//   - 不修改 Models 字段/枚举/原始值/解码行为，不改协议，不改 Stage 1 基线；
//   - 未知枚举原始值的默认解码行为（R6）仅观察记录，不在此锁定或修复。
//

import Foundation
import XCTest
@testable import Models

final class ModelsCodableTests: XCTestCase {

    // MARK: - 2.1 骨架口径

    func testDefaultPluginStateIsUnknownAndUndetermined() {
        let plugin = Plugin(pluginID: "test.base", name: "test")
        XCTAssertEqual(plugin.loaded, .unknown)
        XCTAssertEqual(plugin.permission.decision, .undetermined)
        XCTAssertEqual(plugin.ownership.sourceType, .unknown)
        XCTAssertEqual(plugin.ownership.writablePolicy, .readOnly)
        XCTAssertNil(plugin.installed)
        XCTAssertFalse(plugin.configured)
    }

    func testEnvelopeRoundTrip() throws {
        let env = JailbreakEnvironment(profileId: "unknown-profile")
        let envelope = ReportEnvelope(
            profile: ProfileRef(id: env.profileId, route: "unknown"),
            environment: env
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)
        XCTAssertEqual(decoded.profile.id, env.profileId)
        XCTAssertEqual(decoded.plugins, [])
        XCTAssertEqual(decoded.warnings, [])
    }

    // MARK: - 枚举原始值（R1）

    func testSourceTypeRawValues() {
        XCTAssertEqual(SourceType.dpkgSileo.rawValue, "dpkg_sileo")
        XCTAssertEqual(SourceType.filterkit.rawValue, "filterkit")
        XCTAssertEqual(SourceType.manual.rawValue, "manual")
        XCTAssertEqual(SourceType.unknown.rawValue, "unknown")
    }

    func testWritablePolicyRawValues() {
        XCTAssertEqual(WritablePolicy.readOnly.rawValue, "read_only")
        XCTAssertEqual(WritablePolicy.managed.rawValue, "managed")
        XCTAssertEqual(WritablePolicy.confirmedManaged.rawValue, "confirmed_managed")
        XCTAssertEqual(WritablePolicy.forbidden.rawValue, "forbidden")
    }

    func testJailbreakTypeRawValues() {
        XCTAssertEqual(JailbreakType.roothide.rawValue, "roothide")
        XCTAssertEqual(JailbreakType.rootless.rawValue, "rootless")
        XCTAssertEqual(JailbreakType.unknown.rawValue, "unknown")
    }

    func testOwnershipStatusRawValues() {
        XCTAssertEqual(OwnershipStatus.ownedPackage.rawValue, "owned_package")
        XCTAssertEqual(OwnershipStatus.filterkitManaged.rawValue, "filterkit_managed")
        XCTAssertEqual(OwnershipStatus.manualImport.rawValue, "manual_import")
        XCTAssertEqual(OwnershipStatus.unknown.rawValue, "unknown")
    }

    func testLoadCategoryRawValues() {
        XCTAssertEqual(LoadCategory.manager.rawValue, "manager")
        XCTAssertEqual(LoadCategory.oldabi.rawValue, "oldabi")
        XCTAssertEqual(LoadCategory.tweak.rawValue, "tweak")
        XCTAssertEqual(LoadCategory.unknown.rawValue, "unknown")
    }

    func testLoadedStateRawValues() {
        XCTAssertEqual(LoadedState.unknown.rawValue, "unknown")
        XCTAssertEqual(LoadedState.loaded.rawValue, "loaded")
        XCTAssertEqual(LoadedState.notLoaded.rawValue, "not_loaded")
    }

    func testEvidenceLevelRawValues() {
        XCTAssertEqual(EvidenceLevel.verified.rawValue, "verified")
        XCTAssertEqual(EvidenceLevel.partial.rawValue, "partial")
        XCTAssertEqual(EvidenceLevel.unverified.rawValue, "unverified")
    }

    func testConfidenceRawValues() {
        XCTAssertEqual(Confidence.exactRecord.rawValue, "exact_record")
        XCTAssertEqual(Confidence.heuristic.rawValue, "heuristic")
        XCTAssertEqual(Confidence.unknown.rawValue, "unknown")
    }

    func testPairingRawValues() {
        XCTAssertEqual(Pairing.paired.rawValue, "paired")
        XCTAssertEqual(Pairing.missingPlist.rawValue, "missing_plist")
        XCTAssertEqual(Pairing.orphanPlist.rawValue, "orphan_plist")
        XCTAssertEqual(Pairing.missingDylib.rawValue, "missing_dylib")
    }

    func testPermissionDecisionRawValue() {
        XCTAssertEqual(PermissionDecision.undetermined.rawValue, "undetermined")
    }

    func testCoreFoundationModeRawValues() {
        XCTAssertEqual(CoreFoundationMode.max.rawValue, "max")
        XCTAssertEqual(CoreFoundationMode.range.rawValue, "range")
    }

    // MARK: - 全模型 Codable 往返（R2）

    private func makeSamplePlugin() -> Plugin {
        let filter = FilterRule(
            bundles: ["com.example.app"],
            classes: ["ExampleClass"],
            executables: ["example-exec"],
            coreFoundationVersion: CoreFoundationVersion(mode: .range, min: 12, max: 16),
            otherKeys: ["UnloadAfter"]
        )
        let ownership = Ownership(
            sourceType: .dpkgSileo,
            packageID: "z.pkg",
            listPath: "/var/lib/dpkg/info/z.pkg.list",
            confidence: .exactRecord,
            writablePolicy: .readOnly
        )
        let details = OwnershipDetails(
            fileOwnership: "file",
            markers: "marker",
            conflicts: ["conflict-1"],
            notes: ["note-1"],
            packageVersion: "1.0.0",
            architecture: "arm64e"
        )
        return Plugin(
            pluginID: "z.pkg:base",
            name: "Example",
            version: "1.0.0",
            dylibPath: "/usr/lib/TweakInject/base.dylib",
            plistPath: "/usr/lib/TweakInject/base.plist",
            pairing: .paired,
            source: .dpkgSileo,
            ownership: ownership,
            ownershipDetails: details,
            filter: filter,
            isTweakManager: false,
            loadCategory: .tweak,
            installed: true,
            configured: true,
            loaded: .unknown,
            validation: ValidationReport(status: "valid", warnings: [], skippedFields: []),
            permission: PermissionState(),
            profileId: "RootHideProfile_1_2_3",
            evidence: EvidenceBlock(sourceStages: ["S1-04"], evidenceType: "fixture", evidenceLevel: .partial)
        )
    }

    func testFilterRuleRoundTrip() throws {
        let rule = FilterRule(
            bundles: ["com.example.app"],
            classes: ["ExampleClass"],
            executables: ["example-exec"],
            coreFoundationVersion: CoreFoundationVersion(mode: .max, max: 16),
            otherKeys: ["UnloadAfter"]
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(FilterRule.self, from: data)
        XCTAssertEqual(decoded, rule)
    }

    func testOwnershipRoundTrip() throws {
        let ownership = Ownership(
            sourceType: .filterkit,
            packageID: nil,
            listPath: nil,
            confidence: .heuristic,
            writablePolicy: .managed
        )
        let data = try JSONEncoder().encode(ownership)
        let decoded = try JSONDecoder().decode(Ownership.self, from: data)
        XCTAssertEqual(decoded, ownership)
    }

    func testPluginRoundTrip() throws {
        let plugin = makeSamplePlugin()
        let data = try JSONEncoder().encode(plugin)
        let decoded = try JSONDecoder().decode(Plugin.self, from: data)
        XCTAssertEqual(decoded, plugin)
    }

    func testEnvelopeRoundTripWithPlugin() throws {
        let env = JailbreakEnvironment(
            jailbreakType: .roothide,
            profileId: "RootHideProfile_1_2_3",
            evidenceLevel: .partial
        )
        let envelope = ReportEnvelope(
            profile: ProfileRef(id: env.profileId, route: "roothide"),
            environment: env,
            plugins: [makeSamplePlugin()],
            unknownItems: [UnknownItem(path: "/orphan.plist", base: "orphan", reason: "missing_dylib", sourceStage: "S1-05")],
            warnings: [ReportWarning(code: "profile_unknown", message: "未知", sourceStage: "S1-01")]
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)
        XCTAssertEqual(decoded, envelope)
    }

    // MARK: - nil / null / 字段缺失（R3、R4，仅记录现有行为）

    func testNilOptionalsSurviveRoundTrip() throws {
        let plugin = Plugin(pluginID: "bare.base", name: "bare")
        let data = try JSONEncoder().encode(plugin)
        let decoded = try JSONDecoder().decode(Plugin.self, from: data)
        XCTAssertEqual(decoded, plugin)
        XCTAssertNil(decoded.version)
        XCTAssertNil(decoded.dylibPath)
        XCTAssertNil(decoded.plistPath)
        XCTAssertNil(decoded.ownershipDetails)
        XCTAssertNil(decoded.filter)
        XCTAssertNil(decoded.installed)
    }

    func testMissingOptionalFieldsDecodeToNil() throws {
        // 最小 JSON：只填非可选字段；缺失的 Optional 字段解码应为 nil，不得补成 false / 空串 / 空数组。
        let json = """
        {
          "pluginID": "bare.base",
          "name": "bare",
          "pairing": "paired",
          "source": "unknown",
          "ownership": {
            "sourceType": "unknown",
            "packageID": null,
            "listPath": null,
            "confidence": "unknown",
            "writablePolicy": "read_only"
          },
          "isTweakManager": false,
          "loadCategory": "unknown",
          "configured": false,
          "loaded": "unknown",
          "validation": { "status": "unknown", "warnings": [], "skippedFields": [] },
          "permission": { "decision": "undetermined", "reason": "authorization_gate_not_evaluated" },
          "profileId": "unknown-profile",
          "evidence": { "sourceStages": [], "evidenceType": "fixture", "evidenceLevel": "partial" }
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(Plugin.self, from: data)
        XCTAssertNil(decoded.version)
        XCTAssertNil(decoded.dylibPath)
        XCTAssertNil(decoded.plistPath)
        XCTAssertNil(decoded.ownershipDetails)
        XCTAssertNil(decoded.filter)
        XCTAssertNil(decoded.installed)
        // R4：Optional Bool 缺失为 nil，不是 false。
        XCTAssertNil(decoded.installed)
    }

    // MARK: - 空数组编码（R5，仅记录现有行为）

    func testEmptyArraysEncodeAsArrayNotNil() throws {
        let rule = FilterRule()
        let data = try JSONEncoder().encode(rule)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(dict)
        for key in ["bundles", "classes", "executables", "otherKeys"] {
            XCTAssertTrue(dict?[key] is [Any], "\(key) 应编码为数组")
            XCTAssertFalse(dict?[key] is NSNull, "\(key) 不应编码为 null")
        }
    }

    func testEvidenceBlockEmptySourceStagesRoundTrip() throws {
        let evidence = EvidenceBlock()
        let data = try JSONEncoder().encode(evidence)
        let decoded = try JSONDecoder().decode(EvidenceBlock.self, from: data)
        XCTAssertEqual(decoded.sourceStages, [])
        XCTAssertEqual(decoded, evidence)
    }
}
