//
//  ReportBuilderTests.swift
//  FilterKit Stage 2 — Reporting D2（ReportBuilder）
//
//  覆盖冻结规格 §4.6 Builder-001 ～ Builder-006。桩快照直接构造，不访问
//  文件系统；只核对归并、状态映射与未知归集口径，不替代 Runner 真机证据。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class ReportBuilderTests: XCTestCase {

    // MARK: - 桩构造器

    private func makeEnvironment(route: String = "roothide") -> JailbreakEnvironment {
        JailbreakEnvironment(
            jailbreakType: .roothide,
            profileId: "RootHideProfile",
            jbroot: "/jbroot",
            evidenceLevel: .partial)
    }

    private func makeProfile(route: String = "roothide") -> ProfileRef {
        ProfileRef(id: "RootHideProfile", route: route)
    }

    private func evidence(name: String,
                           kind: PluginFileKind,
                           path: String?,
                           exists: Bool? = true,
                           readable: Bool? = true) -> PluginFileEvidence {
        PluginFileEvidence(
            path: path,
            name: name,
            extension: name.components(separatedBy: ".").last,
            kind: kind,
            exists: exists,
            readable: readable)
    }

    private func inventory(items: [PluginFileEvidence],
                           unknown: [UnknownItem] = []) -> PluginInventorySnapshot {
        PluginInventorySnapshot(
            route: "roothide",
            sourceDirectory: "/dir",
            items: items,
            unknownItems: unknown)
    }

    private func pairingSnapshot(records: [PluginPairingRecord],
                                 unknown: [UnknownItem] = []) -> PluginPairingSnapshot {
        PluginPairingSnapshot(
            route: "roothide",
            sourceDirectory: "/dir",
            records: records,
            unknownItems: unknown)
    }

    private func parseResult(key: String,
                             status: FilterParseStatus,
                             filter: FilterRule? = nil,
                             route: String? = "roothide",
                             dylibPath: String? = nil,
                             plistPath: String? = nil,
                             isTweakManager: Bool? = nil,
                             reason: String? = nil,
                             skipped: [SkippedField] = []) -> FilterParseResult {
        let dylibPath = dylibPath ?? "/dir/\(key).dylib"
        let plistPath = plistPath ?? "/dir/\(key).plist"
        return FilterParseResult(
            pairingKey: key,
            dylibPath: dylibPath,
            plistPath: plistPath,
            route: route,
            status: status,
            reason: reason,
            filter: filter,
            isTweakManager: isTweakManager,
            skippedFields: skipped)
    }

    private func parseSnapshot(results: [FilterParseResult],
                               unknown: [UnknownItem] = []) -> FilterParseSnapshot {
        FilterParseSnapshot(
            route: "roothide",
            sourceDirectory: "/dir",
            status: "enumerated",
            parsed: results,
            notParsed: unknown,
            counts: FilterParseCounts(),
            warnings: [])
    }

    private func record(category: PairingCategory,
                        pairing: Pairing?,
                        key: String,
                        dylibPath: String? = nil,
                        plistPath: String? = nil,
                        reason: String? = nil) -> PluginPairingRecord {
        let dylibPath = dylibPath ?? (category == .orphanPlist ? nil : "/dir/\(key).dylib")
        let plistPath = plistPath ?? (category == .missingPlist ? nil : "/dir/\(key).plist")
        return PluginPairingRecord(
            category: category,
            pairing: pairing,
            pairingKey: key,
            dylib: dylibPath.map { evidence(name: ($0 as NSString).lastPathComponent, kind: .dylib, path: $0) },
            plist: plistPath.map { evidence(name: ($0 as NSString).lastPathComponent, kind: .plist, path: $0) },
            reason: reason,
            basis: .exactFilenameMatch)
    }

    // MARK: - Builder-001 完整混合快照

    func testBuilder001MixedSnapshotMergesAndKeepsFailures() {
        let inv = inventory(items: [
            evidence(name: "alpha.dylib", kind: .dylib, path: "/dir/alpha.dylib"),
            evidence(name: "alpha.plist", kind: .plist, path: "/dir/alpha.plist"),
            evidence(name: "beta.plist", kind: .plist, path: "/dir/beta.plist")
        ])
        let pair = pairingSnapshot(records: [
            record(category: .paired, pairing: .paired, key: "alpha"),
            record(category: .orphanPlist, pairing: .orphanPlist, key: "beta", dylibPath: nil),
            record(category: .ambiguous, pairing: nil, key: "gamma", reason: "multi_candidate")
        ])
        let parsing = parseSnapshot(results: [
            parseResult(key: "alpha", status: .valid,
                        filter: FilterRule(bundles: ["com.hide"])),
            parseResult(key: "beta", status: .typeMismatch, dylibPath: nil,
                        reason: "filter_type")
        ])

        let input = ReportBuildInput(
            environment: makeEnvironment(),
            inventory: inv,
            pairing: pair,
            parsing: parsing,
            profile: makeProfile())
        let envelope = ReportBuilder().build(input)

        XCTAssertEqual(envelope.plugins.count, 2)
        let alpha = envelope.plugins.first { $0.pluginID == "alpha" }
        let beta = envelope.plugins.first { $0.pluginID == "beta" }
        XCTAssertNotNil(alpha)
        XCTAssertNotNil(beta)
        XCTAssertEqual(alpha?.pairing, .paired)
        XCTAssertEqual(alpha?.configured, true)
        XCTAssertNotNil(alpha?.filter)
        XCTAssertEqual(beta?.pairing, .orphanPlist)
        XCTAssertEqual(beta?.configured, false)
        XCTAssertNil(beta?.filter)

        XCTAssertTrue(envelope.unknownItems.contains { $0.base == "gamma" })
    }

    // MARK: - Builder-002 双路线隔离

    func testBuilder002DualRouteIsolationAndUnknownRouteUnknownItems() {
        let pair = pairingSnapshot(records: [
            record(category: .paired, pairing: .paired, key: "alpha"),
            record(category: .paired, pairing: .paired, key: "beta")
        ])
        let parsing = parseSnapshot(results: [
            parseResult(key: "alpha", status: .valid,
                        filter: FilterRule(bundles: ["com.hide"]), route: "roothide"),
            parseResult(key: "beta", status: .valid,
                        filter: FilterRule(bundles: ["com.less"]), route: "rootless"),
            parseResult(key: "gamma", status: .valid,
                        filter: FilterRule(bundles: ["com.unknown"]), route: "unknown")
        ])

        let input = ReportBuildInput(
            environment: makeEnvironment(),
            inventory: nil,
            pairing: pair,
            parsing: parsing,
            profile: makeProfile())
        let envelope = ReportBuilder().build(input)

        XCTAssertEqual(envelope.plugins.count, 2)
        let alpha = envelope.plugins.first { $0.pluginID == "alpha" }
        let beta = envelope.plugins.first { $0.pluginID == "beta" }
        XCTAssertEqual(alpha?.filter?.bundles, ["com.hide"])
        XCTAssertEqual(beta?.filter?.bundles, ["com.less"])
        XCTAssertTrue(envelope.unknownItems.contains { $0.base == "gamma" })
    }

    // MARK: - Builder-003 解析失败条目保留证据

    func testBuilder003ParseFailureKeepsEvidenceWithoutFilter() {
        let pair = pairingSnapshot(records: [
            record(category: .paired, pairing: .paired, key: "delta")
        ])
        let skipped = SkippedField(
            key: "Bundles", reason: "field_type",
            expectedType: "string[]", observedType: "string",
            route: "roothide")
        let parsing = parseSnapshot(results: [
            parseResult(key: "delta", status: .parseFailed,
                        reason: "invalid plist", skipped: [skipped])
        ])

        let input = ReportBuildInput(
            environment: makeEnvironment(),
            inventory: nil,
            pairing: pair,
            parsing: parsing,
            profile: makeProfile())
        let envelope = ReportBuilder().build(input)

        XCTAssertEqual(envelope.plugins.count, 1)
        let plugin = envelope.plugins.first
        XCTAssertNil(plugin?.filter)
        XCTAssertEqual(plugin?.validation.status, "parse_failed")
        XCTAssertEqual(plugin?.validation.skippedFields, ["Bundles:field_type"])
    }

    // MARK: - Builder-004 归属细节不选边

    func testBuilder004OwnershipDetailsPreservedWithoutMerging() {
        let pair = pairingSnapshot(records: [
            record(category: .paired, pairing: .paired, key: "alpha")
        ])
        let parsing = parseSnapshot(results: [
            parseResult(key: "alpha", status: .valid,
                        filter: FilterRule(bundles: ["com.hide"]))
        ])
        let ownership = Ownership(
            sourceType: .dpkgSileo,
            packageID: "com.alpha",
            listPath: "/var/lib/dpkg/status",
            confidence: .exactRecord,
            writablePolicy: .readOnly)
        let details = OwnershipDetails(
            fileOwnership: "dpkg",
            markers: "com.alpha",
            conflicts: ["conflict-a"],
            notes: ["note-a"],
            packageVersion: "1.0.0",
            architecture: "arm64e")

        let input = ReportBuildInput(
            environment: makeEnvironment(),
            inventory: nil,
            pairing: pair,
            parsing: parsing,
            ownershipByKey: ["alpha": ownership],
            ownershipDetailsByKey: ["alpha": details],
            profile: makeProfile())
        let envelope = ReportBuilder().build(input)

        XCTAssertEqual(envelope.plugins.count, 1)
        let plugin = envelope.plugins.first
        XCTAssertEqual(plugin?.source, .dpkgSileo)
        XCTAssertEqual(plugin?.ownership.packageID, "com.alpha")
        XCTAssertEqual(plugin?.ownershipDetails?.conflicts, ["conflict-a"])
        XCTAssertEqual(plugin?.ownershipDetails?.notes, ["note-a"])
        XCTAssertEqual(plugin?.pluginID, "com.alpha:alpha")
    }

    // MARK: - Builder-005 上游阶段缺失不回退补齐

    func testBuilder005MissingStagesLeaveNilAndWarn() {
        let input = ReportBuildInput(
            environment: makeEnvironment(),
            inventory: nil,
            pairing: nil,
            parsing: nil,
            profile: makeProfile())
        let envelope = ReportBuilder().build(input)

        XCTAssertTrue(envelope.plugins.isEmpty)
        XCTAssertTrue(envelope.unknownItems.isEmpty)
        let codes = envelope.warnings.map(\.code)
        XCTAssertTrue(codes.contains("inventory_unresolved"))
        XCTAssertTrue(codes.contains("pairing_unresolved"))
        XCTAssertTrue(codes.contains("parsing_unresolved"))
    }

    // MARK: - Builder-006 三层状态分离

    func testBuilder006StateSeparation() {
        let inv = inventory(items: [
            evidence(name: "alpha.dylib", kind: .dylib, path: "/dir/alpha.dylib")
        ])
        let pair = pairingSnapshot(records: [
            record(category: .paired, pairing: .paired, key: "alpha")
        ])
        let parsing = parseSnapshot(results: [
            parseResult(key: "alpha", status: .parseFailed, reason: "invalid plist")
        ])

        let input = ReportBuildInput(
            environment: makeEnvironment(),
            inventory: inv,
            pairing: pair,
            parsing: parsing,
            profile: makeProfile())
        let envelope = ReportBuilder().build(input)

        XCTAssertEqual(envelope.plugins.count, 1)
        let plugin = envelope.plugins.first
        XCTAssertEqual(plugin?.installed, true)
        XCTAssertEqual(plugin?.configured, false)
        XCTAssertEqual(plugin?.loaded, .unknown)
        XCTAssertEqual(plugin?.permission.decision, .undetermined)
    }
}
