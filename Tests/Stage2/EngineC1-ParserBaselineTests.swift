//
//  EngineC1-ParserBaselineTests.swift
//  FilterKit Stage 2 — Engine-C1 Parser 层 S1-06 基线映射测试
//
//  将 RootHide / Rootless 已解码对象直接交对应路线 Parser，对照注册表与
//  夹具 metadata 全维度断言。Decoder 失败（parse_failed / invalid_plist）
//  与快照级归集归 C1-C Engine 测试；本文件不实例化 Adapter、不读真实文件。
//
//  挂起：PARSE-015 Rootless 组合样本保留 pending（#151 / C-G2），Runner
//  出证前以 skip 处理，不记为通过。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC1ParserBaselineTests: XCTestCase {

    private let rootHide = RootHideFilterParser()
    private let rootless = RootlessFilterParser()

    // MARK: - 注册表自校验

    func testRegistryHasTwentyTwoUniqueCases() {
        XCTAssertTrue(EngineC1BaselineRegistry.validate(),
                      "注册表应为 22 项且 caseID 唯一")
    }

    // MARK: - RootHide 夹具基线

    func testRootHideFixtureBaselines() throws {
        let cases = EngineC1BaselineRegistry.all.filter {
            if case .fixture(let name) = $0.source { return $0.route == .rootHide && !name.isEmpty }
            return false
        }

        for baseline in cases {
            guard case .fixture(let name) = baseline.source else { continue }
            // Decoder 失败态由 C1-C Engine 管线测试覆盖。
            let fixture = try EngineC1FixtureLoader.load(name: name)
            for input in fixture.inputs {
                let metaStatus = fixture.metadata.expected.statusByBase[input.base]
                if metaStatus == FilterParseStatus.parseFailed.rawValue { continue }

                let result = rootHide.parse(
                    object: input.root,
                    pairingKey: input.base,
                    plistPath: input.plistPath,
                    route: "roothide",
                    plistFormat: input.format,
                    readStatus: input.readStatus
                )
                Self.assert(baseline: baseline,
                            metadata: fixture.metadata,
                            base: input.base,
                            result: result,
                            parser: .rootHide)
            }
        }
    }

    // MARK: - RootHide 合成基线

    func testRootHideSyntheticBaselines() {
        let cases = EngineC1BaselineRegistry.all.filter {
            guard $0.route == .rootHide else { return false }
            if case .synthetic = $0.source { return true }
            return false
        }

        for baseline in cases {
            guard case .synthetic(_, let root) = baseline.source else { continue }
            let base = baseline.expectedStatusByBase.keys.first
                ?? baseline.expectedRulesByBase.keys.first ?? "Synthetic"
            let result = rootHide.parse(
                object: root,
                pairingKey: base,
                route: "roothide",
                plistFormat: "xml",
                readStatus: "ok"
            )
            Self.assert(baseline: baseline, metadata: nil, base: base,
                        result: result, parser: .rootHide)
        }
    }

    // MARK: - PARSE-010 混合类型错误证据（本轮重点补缺）

    func testParse010MixedTypeEvidence() {
        let root: [String: Any] = [
            "Filter": ["Bundles": "not-array", "Classes": [123]]
        ]
        let result = rootHide.parse(object: root, pairingKey: "Mixed",
                                    route: "roothide", plistFormat: "xml", readStatus: "ok")

        XCTAssertEqual(result.status, .typeMismatch)
        XCTAssertNil(result.filter)
        XCTAssertEqual(result.reason, "field_type")

        let keys = result.skippedFields.map(\.key).sorted()
        XCTAssertEqual(keys, ["Bundles", "Classes"])

        let bundles = result.skippedFields.first { $0.key == "Bundles" }
        XCTAssertEqual(bundles?.reason, "not_array")
        XCTAssertEqual(bundles?.expectedType, "string[]")
        XCTAssertEqual(bundles?.observedType, "string")
        XCTAssertNil(bundles?.index)

        let classes = result.skippedFields.first { $0.key == "Classes" }
        XCTAssertEqual(classes?.reason, "element_type")
        XCTAssertEqual(classes?.expectedType, "string")
        XCTAssertEqual(classes?.observedType, "number")
        XCTAssertEqual(classes?.index, 0)
    }

    // MARK: - RootHide 组合规则

    func testRootHideMultiRuleCombined() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-multi-rule")
        let input = try XCTUnwrap(fixture.inputs.first)
        let result = rootHide.parse(object: input.root, pairingKey: input.base,
                                   route: "roothide", plistFormat: input.format)

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["com.a.app", "com.b.app", "com.c.app"])
        XCTAssertEqual(result.filter?.classes, ["ClassX", "ClassY"])
        XCTAssertEqual(result.filter?.executables, ["ProcP", "ProcQ"])
        XCTAssertEqual(result.otherKeys, [])
    }

    func testRootHideXmlValidFullRule() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-xml-valid")
        let input = try XCTUnwrap(fixture.inputs.first)
        let result = rootHide.parse(object: input.root, pairingKey: input.base,
                                   route: "roothide", plistFormat: input.format)

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(result.filter?.classes, ["ExampleClass"])
        XCTAssertEqual(result.filter?.executables, ["ExampleApp"])
        XCTAssertEqual(result.filter?.coreFoundationVersion?.mode, .max)
        XCTAssertEqual(result.filter?.coreFoundationVersion?.max, 1600)
        XCTAssertEqual(result.isTweakManager, false)
    }

    // MARK: - 确定性：重复解析深比较一致

    func testRootHideDeterminismDeepEqual() throws {
        let fixture = try EngineC1FixtureLoader.load(name: "parse-determinism")
        let input = try XCTUnwrap(fixture.inputs.first)
        let r1 = rootHide.parse(object: input.root, pairingKey: input.base, route: "roothide")
        let r2 = rootHide.parse(object: input.root, pairingKey: input.base, route: "roothide")
        XCTAssertEqual(r1, r2)
    }

    // MARK: - Rootless 组合样本（C-G2 关闭后解除挂起）

    func testRootlessBaselineThroughParser() throws {
        guard let baseline = EngineC1BaselineRegistry.first(byID: "PARSE-015-A") else {
            return XCTFail("注册表缺 PARSE-015-A")
        }
        XCTAssertFalse(baseline.pendingRunner, "PARSE-015-A 应已解除 Runner 挂起")

        let fixture = try EngineC1FixtureLoader.load(name: "parse-rootless-model")
        let input = try XCTUnwrap(fixture.inputs.first)
        let result = rootless.parse(object: input.root, pairingKey: input.base,
                                    route: "rootless", plistFormat: input.format)

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(result.filter?.executables, ["rlapp"])
        XCTAssertEqual(result.filter?.classes, [])
        XCTAssertNil(result.filter?.coreFoundationVersion)
        XCTAssertNil(result.isTweakManager)
        XCTAssertEqual(result.otherKeys, ["Classes", "CoreFoundationVersion", "IsTweakManager"])
    }

    // MARK: - 共享断言装配

    private enum ParserKind {
        case rootHide, rootless
    }

    private static func assert(baseline: EngineC1BaselineCase,
                               metadata: EngineC1Metadata?,
                               base: String,
                               result: FilterParseResult,
                               parser: ParserKind) {
        let expectedStatus = baseline.expectedStatusByBase[base]
            ?? metadata.flatMap { $0.expected.statusByBase[base] }
            .flatMap { EngineC1ExpectedStatus(rawValue: $0) }

        EngineC1ResultComparator.assertStatus(
            result.status, expected: expectedStatus, base: base)

        let expectedReason = baseline.expectedReasonByBase[base]
        EngineC1ResultComparator.assertReason(
            result.reason, expected: expectedReason, base: base)

        let expectedRule = mergeRule(baseline: baseline, metadata: metadata, base: base)
        EngineC1ResultComparator.assertRule(
            result.filter, expected: expectedRule,
            status: result.status, base: base)

        let expectedOtherKeys = baseline.expectedOtherKeysByBase[base]
            ?? metadata?.expected.otherKeysByBase[base]
        EngineC1ResultComparator.assertOtherKeys(
            result.otherKeys, expected: expectedOtherKeys, base: base)

        let expectedSkipped = baseline.expectedSkippedByBase[base] ?? []
        EngineC1ResultComparator.assertSkippedFields(
            result.skippedFields, expected: expectedSkipped, base: base)

        if parser == .rootHide {
            XCTAssertEqual(result.route, "roothide")
        } else {
            XCTAssertEqual(result.route, "rootless")
        }
    }

    private static func mergeRule(baseline: EngineC1BaselineCase,
                                  metadata: EngineC1Metadata?,
                                  base: String) -> EngineC1ExpectedRule? {
        let meta = metadata?.expected.filterByBase[base]
        let reg = baseline.expectedRulesByBase[base]
        guard meta != nil || reg != nil else { return nil }
        return EngineC1ExpectedRule(
            bundles: reg?.bundles ?? meta?.bundles,
            classes: reg?.classes ?? meta?.classes,
            executables: reg?.executables ?? meta?.executables,
            cfvMode: reg?.cfvMode,
            cfvMin: reg?.cfvMin,
            cfvMax: reg?.cfvMax,
            otherKeys: reg?.otherKeys ?? metadata?.expected.otherKeysByBase[base]
        )
    }
}
