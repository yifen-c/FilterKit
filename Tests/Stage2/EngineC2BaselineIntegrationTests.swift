//
//  EngineC2BaselineIntegrationTests.swift
//  FilterKit Stage 2 — Engine-C2-D1：22 项基线接入完整 Engine 链路（测试目标专用）
//
//  复用 Engine-C1 既有资产：`EngineC1BaselineRegistry` 22 项注册表、
//  `EngineC1ResultComparator` 全维度比较器、`EngineC1FixtureLoader` 夹具加载器、
//  `EngineC1Coordinator` / `EngineC1StubReader` / `EngineC1StubDecoder` /
//  `EngineC1CountingParser` 桩协调器范式；C2 不另建第二套 BaselineRegistry 或简化比较器。
//
//  三层追溯口径（Implementation-Spec §3.4）：
//  1. Parser 单独结果：直接调真实 Parser（C1 Parser 层既有落点，本文件做链路一致性对照）；
//  2. 完整链路：桩 Reader 成功 → 桩 Decoder 回灌根对象 → 真实 Parser；
//  3. Engine Snapshot：经 `PluginFilterParseEngine.parse(snapshot:)` 汇总后的条目结果。
//  当前架构中第 2、3 层由 Engine 内部编排完成；一致性对照只读取测试层期望与既有
//  Core 类型，不修改生产模型，不为迁就实现改动期望值。
//
//  挂起：PARSE-015（Rootless RL）`pendingRunner`，C-G2 已出 Parser 专项证据，
//  完整 Rootless 链路用例归 D2 解除挂起；本批保持 `XCTSkipIf`，不计通过。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2BaselineIntegrationTests: XCTestCase {

    // MARK: - 22 项基线完整 Engine 链路矩阵

    func testBaselinesRunThroughFullEngineChain() throws {
        for baseline in EngineC1BaselineRegistry.all {
            try XCTSkipIf(baseline.pendingRunner,
                          "\(baseline.caseID) 完整 Rootless 链路待 D2 出证，本测试不记通过")

            switch baseline.source {
            case .fixture(let name):
                try evaluateFixtureChain(baseline: baseline, fixtureName: name)
            case .synthetic(_, let root):
                try evaluateSyntheticChain(baseline: baseline, root: root)
            }
        }
    }

    // MARK: - Parser 直连结果与 Engine 链路结果一致性（RootHide 可达 Parser 项）

    func testEngineChainMatchesDirectParserForRootHide() throws {
        let hide = RootHideFilterParser()

        for baseline in EngineC1BaselineRegistry.all {
            try XCTSkipIf(baseline.pendingRunner,
                          "\(baseline.caseID) 完整 Rootless 链路待 D2 出证")
            guard baseline.route == .rootHide else { continue }

            switch baseline.source {
            case .fixture(let name):
                let fixture = try EngineC1FixtureLoader.load(name: name)
                for input in fixture.inputs {
                    // Decoder 失败项 Parser 未被调用，不做直连对照。
                    guard !input.payloadInvalid else { continue }
                    let direct = hide.parse(
                        object: input.root,
                        pairingKey: input.base,
                        plistPath: input.plistPath,
                        route: "roothide",
                        plistFormat: input.format,
                        readStatus: input.readStatus
                    )
                    guard let entry = engineEntry(baseline: baseline, fixture: fixture,
                                                  base: input.base) else {
                        XCTFail("\(baseline.caseID) Engine 缺条目 \(input.base)")
                        continue
                    }
                    assertConsistent(direct: direct, engine: entry, base: input.base,
                                     caseID: baseline.caseID)
                }

            case .synthetic(_, let root):
                guard let base = syntheticBase(baseline: baseline) else { continue }
                let plistPath = "/dir/\(base).plist"
                let direct = hide.parse(
                    object: root,
                    pairingKey: base,
                    plistPath: plistPath,
                    route: "roothide",
                    plistFormat: "xml",
                    readStatus: "ok"
                )
                guard let entry = syntheticEngineEntry(baseline: baseline, root: root, base: base) else {
                    XCTFail("\(baseline.caseID) Engine 缺条目 \(base)")
                    continue
                }
                assertConsistent(direct: direct, engine: entry, base: base,
                                 caseID: baseline.caseID)
            }
        }
    }

    // MARK: - 夹具项完整链路

    private func evaluateFixtureChain(baseline: EngineC1BaselineCase, fixtureName: String) throws {
        let fixture = try EngineC1FixtureLoader.load(name: fixtureName)
        let coordinator = EngineC1Coordinator(inputs: fixture.inputs)
        let engine = makeEngine(coordinator: coordinator)

        let result = engine.parse(snapshot: fixture.snapshot)
        let meta = fixture.metadata.expected
        let caseID = baseline.caseID

        // 快照级状态与计数。
        XCTAssertEqual(result.status, meta.status, "\(caseID) 快照状态不符")
        assertCounts(result.counts, meta.counts, caseID: caseID)
        EngineC1ResultComparator.assertWarningsContain(
            result.warnings, expected: fixture.metadata.expectedWarnings ?? [])

        // 条目级状态 / 规则 / otherKeys / 字段证据。
        for (base, expectedStatus) in meta.statusByBase {
            guard let parsed = result.parsed.first(where: { $0.pairingKey == base }) else {
                XCTFail("\(caseID) 缺条目 \(base)")
                continue
            }
            let status = EngineC1ExpectedStatus(rawValue: expectedStatus)
            EngineC1ResultComparator.assertStatus(parsed.status, expected: status, base: base)

            if let reason = baseline.expectedReasonByBase[base] {
                EngineC1ResultComparator.assertReason(parsed.reason, expected: reason, base: base)
            }
            let rule = EngineC1ResultComparator.mergedRule(
                baseline: baseline, metadata: fixture.metadata, base: base)
            EngineC1ResultComparator.assertRule(parsed.filter, expected: rule,
                                                status: parsed.status, base: base)
            if let otherKeys = meta.otherKeysByBase[base] {
                EngineC1ResultComparator.assertOtherKeys(parsed.otherKeys,
                                                         expected: otherKeys, base: base)
            }
            let skipped = baseline.expectedSkippedByBase[base] ?? []
            EngineC1ResultComparator.assertSkippedFields(
                parsed.skippedFields, expected: skipped, base: base)
        }

        let validation = FilterParseIntegrationValidator().validate(snapshot: result)
        XCTAssertTrue(validation.allPassed,
                     "\(caseID) 计数不变量未通过：\(validation.checks.description)")
    }

    // MARK: - 合成项完整链路

    private func evaluateSyntheticChain(baseline: EngineC1BaselineCase, root: Any?) throws {
        let base = syntheticBase(baseline: baseline) ?? baseline.caseID
        let plistPath = "/dir/\(base).plist"
        let dylibPath = "/dir/\(base).dylib"

        // 未知路线隔离项：不进入 Reader / Decoder / Parser，归集 notParsed。
        if baseline.route == .unknown {
            let coordinator = EngineC1Coordinator(inputs: [])
            let engine = makeEngine(coordinator: coordinator)
            let record = engineC2Record(key: base, plistPath: plistPath, dylibPath: dylibPath)
            let snapshot = engineC2Snapshot(route: "rootful", records: [record])
            let result = engine.parse(snapshot: snapshot)

            XCTAssertEqual(coordinator.readerCallCount, 0, "\(baseline.caseID) 未知路线不得进 Reader")
            XCTAssertEqual(coordinator.decoderCallCount, 0, "\(baseline.caseID) 未知路线不得进 Decoder")
            XCTAssertEqual(coordinator.hideCallCount, 0, "\(baseline.caseID) 未知路线不得进 Parser")
            XCTAssertEqual(coordinator.lessCallCount, 0)
            XCTAssertTrue(result.parsed.isEmpty, "\(baseline.caseID) 未知路线不得有 parsed 条目")
            XCTAssertEqual(result.notParsed.count, 1)
            XCTAssertEqual(result.notParsed.first?.reason, "unknown_route")
            return
        }

        let input = EngineC1PlistInput(
            base: base,
            dylibPath: dylibPath,
            plistPath: plistPath,
            format: "xml",
            readStatus: "ok",
            payloadInvalid: false,
            root: root
        )
        let coordinator = EngineC1Coordinator(inputs: [input])
        let engine = makeEngine(coordinator: coordinator)
        let record = engineC2Record(key: base, plistPath: plistPath, dylibPath: dylibPath)
        let snapshot = engineC2Snapshot(route: baseline.route.rawValue, records: [record])

        let result = engine.parse(snapshot: snapshot)
        let caseID = baseline.caseID
        guard let parsed = result.parsed.first(where: { $0.pairingKey == base }) else {
            XCTFail("\(caseID) 缺条目 \(base)")
            return
        }

        if let expectedStatus = baseline.expectedStatusByBase[base] {
            EngineC1ResultComparator.assertStatus(parsed.status, expected: expectedStatus, base: base)
        }
        if let reason = baseline.expectedReasonByBase[base] {
            EngineC1ResultComparator.assertReason(parsed.reason, expected: reason, base: base)
        }
        let rule = baseline.expectedRulesByBase[base]
        EngineC1ResultComparator.assertRule(parsed.filter, expected: rule,
                                            status: parsed.status, base: base)
        let skipped = baseline.expectedSkippedByBase[base] ?? []
        EngineC1ResultComparator.assertSkippedFields(
            parsed.skippedFields, expected: skipped, base: base)

        let validation = FilterParseIntegrationValidator().validate(snapshot: result)
        XCTAssertTrue(validation.allPassed,
                     "\(caseID) 计数不变量未通过：\(validation.checks.description)")
    }

    // MARK: - 一致性对照辅助

    private func engineEntry(baseline: EngineC1BaselineCase,
                            fixture: EngineC1LoadedFixture,
                            base: String) -> FilterParseResult? {
        let coordinator = EngineC1Coordinator(inputs: fixture.inputs)
        let engine = makeEngine(coordinator: coordinator)
        let result = engine.parse(snapshot: fixture.snapshot)
        return result.parsed.first { $0.pairingKey == base }
    }

    private func syntheticEngineEntry(baseline: EngineC1BaselineCase,
                                      root: Any?,
                                      base: String) -> FilterParseResult? {
        let plistPath = "/dir/\(base).plist"
        let dylibPath = "/dir/\(base).dylib"
        let input = EngineC1PlistInput(
            base: base, dylibPath: dylibPath, plistPath: plistPath,
            format: "xml", readStatus: "ok", payloadInvalid: false, root: root)
        let coordinator = EngineC1Coordinator(inputs: [input])
        let engine = makeEngine(coordinator: coordinator)
        let record = engineC2Record(key: base, plistPath: plistPath, dylibPath: dylibPath)
        let snapshot = engineC2Snapshot(route: baseline.route.rawValue, records: [record])
        let result = engine.parse(snapshot: snapshot)
        return result.parsed.first { $0.pairingKey == base }
    }

    /// 直连 Parser 与 Engine 链路条目一致性：五态、reason、规则三数组、otherKeys、
    /// 证据 key 集合对齐；未冻结的观测类型词 / 下标口径不强制比对（PARSE-009-B 待复核）。
    private func assertConsistent(direct: FilterParseResult,
                                  engine: FilterParseResult,
                                  base: String,
                                  caseID: String) {
        XCTAssertEqual(engine.status, direct.status, "\(caseID) \(base) 五态不一致")
        XCTAssertEqual(engine.reason, direct.reason, "\(caseID) \(base) reason 不一致")
        XCTAssertEqual(engine.filter?.bundles, direct.filter?.bundles,
                       "\(caseID) \(base) Bundles 不一致")
        XCTAssertEqual(engine.filter?.classes, direct.filter?.classes,
                       "\(caseID) \(base) Classes 不一致")
        XCTAssertEqual(engine.filter?.executables, direct.filter?.executables,
                       "\(caseID) \(base) Executables 不一致")
        XCTAssertEqual(engine.otherKeys, direct.otherKeys, "\(caseID) \(base) otherKeys 不一致")
        XCTAssertEqual(engine.skippedFields.map(\.key).sorted(),
                       direct.skippedFields.map(\.key).sorted(),
                       "\(caseID) \(base) 证据字段 key 集合不一致")
    }

    // MARK: - 通用辅助

    private func syntheticBase(baseline: EngineC1BaselineCase) -> String? {
        baseline.expectedStatusByBase.keys.first
            ?? baseline.expectedRulesByBase.keys.first
            ?? baseline.expectedReasonByBase.keys.first
    }

    private func makeEngine(coordinator: EngineC1Coordinator) -> PluginFilterParseEngine {
        PluginFilterParseEngine(
            reader: EngineC1StubReader(coordinator),
            decoder: EngineC1StubDecoder(coordinator),
            rootHideParser: EngineC1CountingParser(
                coordinator: coordinator, side: .hide, delegate: RootHideFilterParser()),
            rootlessParser: EngineC1CountingParser(
                coordinator: coordinator, side: .less, delegate: RootlessFilterParser())
        )
    }

    private func assertCounts(_ actual: FilterParseCounts,
                              _ expected: [String: Int],
                              caseID: String) {
        XCTAssertEqual(actual.valid, expected["valid"] ?? 0, "\(caseID) valid 计数")
        XCTAssertEqual(actual.parseFailed, expected["parse_failed"] ?? 0, "\(caseID) parse_failed 计数")
        XCTAssertEqual(actual.typeMismatch, expected["type_mismatch"] ?? 0, "\(caseID) type_mismatch 计数")
        XCTAssertEqual(actual.readFailed, expected["read_failed"] ?? 0, "\(caseID) read_failed 计数")
        XCTAssertEqual(actual.notParsed, expected["not_parsed"] ?? 0, "\(caseID) not_parsed 计数")
    }
}
