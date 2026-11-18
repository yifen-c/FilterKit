//
//  ReportValidatorTests.swift
//  FilterKit Stage 2 — Reporting D3（ReportValidator）
//
//  覆盖冻结规格 §5.3 Validator-001 ～ Validator-004。校验器只读：测试同时
//  核对原始报告不被改写；不访问文件系统，不替代 Runner 真机证据。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class ReportValidatorTests: XCTestCase {

    // MARK: - 桩构造器

    private func makePlugin(id: String,
                            name: String,
                            pairing: Pairing = .paired,
                            source: SourceType = .dpkgSileo,
                            ownership: Ownership? = nil,
                            filter: FilterRule? = FilterRule(bundles: ["com.hide"]),
                            status: String = "valid",
                            loaded: LoadedState = .unknown,
                            installed: Bool? = true,
                            dylibPath: String? = nil,
                            plistPath: String? = nil,
                            profileId: String = "RootHideProfile") -> Plugin {
        Plugin(
            pluginID: id,
            name: name,
            dylibPath: dylibPath ?? (pairing == .orphanPlist ? nil : "/dir/\(id).dylib"),
            plistPath: plistPath ?? (pairing == .missingPlist ? nil : "/dir/\(id).plist"),
            pairing: pairing,
            source: source,
            ownership: ownership ?? Ownership(sourceType: source, packageID: "com.\(id)"),
            filter: filter,
            installed: installed,
            configured: status == "valid",
            loaded: loaded,
            validation: ValidationReport(status: status),
            profileId: profileId)
    }

    private func makeEnvelope(plugins: [Plugin],
                               unknowns: [UnknownItem] = [],
                               warnings: [ReportWarning] = [],
                               route: String = "roothide") -> ReportEnvelope {
        ReportEnvelope(
            profile: ProfileRef(id: "RootHideProfile", route: route),
            environment: JailbreakEnvironment(profileId: "RootHideProfile"),
            plugins: plugins,
            unknownItems: unknowns,
            warnings: warnings)
    }

    // MARK: - Validator-001 合法完整报告

    func testValidator001ValidReportPasses() {
        let plugin = makePlugin(id: "alpha", name: "Alpha")
        let envelope = makeEnvelope(plugins: [plugin])

        let result = ReportValidator().validate(envelope)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Validator-002 注入各类不一致

    func testValidator002InjectsInconsistenciesAndKeepsOriginal() {
        let plugins: [Plugin] = [
            // RV-002：重复 + 空标识
            makePlugin(id: "dup", name: "Dup"),
            makePlugin(id: "dup", name: "Dup2"),
            makePlugin(id: "", name: "Empty"),
            // RV-003：paired 两侧路径缺失（不经桩默认回填，显式保留 nil 路径证据）
            Plugin(pluginID: "nopair",
                   name: "NoPair",
                   pairing: .paired,
                   source: .dpkgSileo,
                   ownership: Ownership(sourceType: .dpkgSileo, packageID: "com.nopair"),
                   filter: FilterRule(bundles: ["com.hide"]),
                   installed: true,
                   configured: true,
                   loaded: .unknown,
                   validation: ValidationReport(status: "valid"),
                   profileId: "RootHideProfile"),
            // RV-004：状态不在封闭集
            makePlugin(id: "badstatus", name: "BadStatus", status: "weird"),
            // RV-005：非 valid 携带 filter
            makePlugin(id: "badfilter", name: "BadFilter",
                       filter: FilterRule(bundles: ["com.bad"]),
                       status: "parse_failed"),
            // RV-006：只读阶段 loaded 被置有证据取值
            makePlugin(id: "loaded", name: "Loaded", loaded: .loaded),
            // RV-007：source 与归属矛盾；未知归属携带包标识
            makePlugin(id: "mismatch", name: "Mismatch",
                       source: .manual,
                       ownership: Ownership(sourceType: .dpkgSileo, packageID: "com.mismatch")),
            makePlugin(id: "unknownpkg", name: "UnknownPkg",
                       source: .unknown,
                       ownership: Ownership(sourceType: .unknown, packageID: "com.unknown")),
            // RV-010：profileId 与信封不一致
            makePlugin(id: "wrongprofile", name: "WrongProfile",
                       profileId: "OtherProfile")
        ]
        let unknowns = [
            // RV-009：身份双缺
            UnknownItem(reason: "dropped", sourceStage: "stage2.2-c3")
        ]
        let envelope = makeEnvelope(plugins: plugins, unknowns: unknowns)

        let originalPlugins = envelope.plugins
        let originalUnknowns = envelope.unknownItems
        let result = ReportValidator().validate(envelope)

        XCTAssertFalse(result.isValid)
        let codes = Set(result.errors.map(\.code))
        XCTAssertTrue(codes.contains("RV-002"))
        XCTAssertTrue(codes.contains("RV-003"))
        XCTAssertTrue(codes.contains("RV-004"))
        XCTAssertTrue(codes.contains("RV-005"))
        XCTAssertTrue(codes.contains("RV-006"))
        XCTAssertTrue(codes.contains("RV-007"))
        XCTAssertTrue(codes.contains("RV-009"))
        XCTAssertTrue(codes.contains("RV-010"))

        // 原始报告未被改写。
        XCTAssertEqual(envelope.plugins, originalPlugins)
        XCTAssertEqual(envelope.unknownItems, originalUnknowns)
    }

    // MARK: - Validator-003 失败/未知条目闭合核对

    func testValidator003FailureAndUnknownItemsRetainIdentity() {
        let failed = makePlugin(id: "beta", name: "Beta",
                                filter: nil, status: "type_mismatch")
        let unknown = UnknownItem(
            path: "/dir/gamma.plist", base: "gamma",
            reason: "missing_dylib", sourceStage: "stage2.2-c3")
        let envelope = makeEnvelope(plugins: [failed], unknowns: [unknown])

        let result = ReportValidator().validate(envelope)

        XCTAssertFalse(result.errors.contains { $0.code == "RV-009" })
    }

    // MARK: - Validator-004 重复告警检出且不改写原报告

    func testValidator004DuplicateWarningsDetectedWithoutDeduping() {
        let warning = ReportWarning(
            code: "partial_enumeration",
            message: "目录部分受限",
            sourceStage: "stage2.2-c1")
        let envelope = makeEnvelope(plugins: [], unknowns: [], warnings: [warning, warning])

        let originalWarnings = envelope.warnings
        let result = ReportValidator().validate(envelope)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "RV-008" })
        XCTAssertEqual(envelope.warnings, originalWarnings)
        XCTAssertEqual(envelope.warnings.count, 2)
    }
}
