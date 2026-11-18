//
//  EngineC2CombinedScenarioTests.swift
//  FilterKit Stage 2 — Engine-C2-D4：组合场景与不变量（测试目标专用）
//
//  在同一混合批次内覆盖双 valid、valid 与各失败态并存、告警合并、上游
//  unknownItems 保留、多记录路线隔离、快照完整与计数不变量、重复执行确定性
//  与输入不可变。组合场景为 Engine 编排层自洽核对，不冒充 PARSE-001~022
//  基线验收；桩仅用于受控 Reader / Decoder 回灌，Parser 走真实实现。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2CombinedScenarioTests: XCTestCase {

    private func makeEngine(coordinator: EngineC2Coordinator) -> PluginFilterParseEngine {
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        return engineC2Engine(coordinator: coordinator, hide: hide, less: less)
    }

    // MARK: - 混合批次：五态并存，计数与归属自洽

    func testCombinedMixedStatesSingleBatch() {
        let validRoot = engineC2ValidRoot(bundles: ["com.valid.app"],
                                        classes: ["ValidHook"],
                                        executables: ["ValidProc"])
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/Valid.plist", decodeRoot: validRoot),
            EngineC2PlistStub(plistPath: "/dir/ReadFail.plist", readStatus: .readFailed),
            EngineC2PlistStub(plistPath: "/dir/DecodeFail.plist", decodeFailed: true),
            EngineC2PlistStub(plistPath: "/dir/Mismatch.plist",
                              decodeRoot: ["Filter": ["Bundles": "not-an-array"]])
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let engine = makeEngine(coordinator: coordinator)

        let orphan = PluginPairingRecord(
            category: .orphanPlist,
            pairing: .orphanPlist,
            pairingKey: "Orphan",
            plist: engineC2Evidence(name: "Orphan.plist", kind: .plist, path: "/dir/Orphan.plist"),
            reason: "missing_dylib",
            basis: .noOppositeCandidate
        )
        let records = [
            engineC2Record(key: "Valid", plistPath: "/dir/Valid.plist", dylibPath: "/dir/Valid.dylib"),
            engineC2Record(key: "ReadFail", plistPath: "/dir/ReadFail.plist", dylibPath: "/dir/ReadFail.dylib"),
            engineC2Record(key: "DecodeFail", plistPath: "/dir/DecodeFail.plist", dylibPath: "/dir/DecodeFail.dylib"),
            engineC2Record(key: "Mismatch", plistPath: "/dir/Mismatch.plist", dylibPath: "/dir/Mismatch.dylib"),
            orphan
        ]
        let snapshot = engineC2Snapshot(route: "roothide", records: records)
        let result = engine.parse(snapshot: snapshot)

        XCTAssertEqual(result.counts.valid, 1)
        XCTAssertEqual(result.counts.readFailed, 1)
        XCTAssertEqual(result.counts.parseFailed, 1)
        XCTAssertEqual(result.counts.typeMismatch, 1)
        XCTAssertEqual(result.counts.notParsed, 1)
        XCTAssertEqual(result.counts.total, 5)
        XCTAssertEqual(result.parsed.count, 4)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.route, "roothide")
        XCTAssertEqual(result.sourceDirectory, "/dir")

        // 内部完整性校验通过：计数桶与 parsed/notParsed 一致，规则归属正确。
        let validation = FilterParseIntegrationValidator().validate(snapshot: result)
        XCTAssertTrue(validation.allPassed, validation.checks.compactMap { $0.passed ? nil : $0.code }.joined(separator: ","))
    }

    // MARK: - 双路线隔离：两份快照各自只调对应 Parser

    func testCombinedRouteIsolationAcrossSnapshots() {
        // roothide 快照：一条 valid Hide，一条 Hide 类型失败。
        let hideValid = engineC2ValidRoot(bundles: ["com.hide.app"],
                                         classes: ["HideHook"],
                                         executables: ["HideProc"])
        let hideMismatch: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let hideStubs = [
            EngineC2PlistStub(plistPath: "/dir/HideA.plist", decodeRoot: hideValid),
            EngineC2PlistStub(plistPath: "/dir/HideB.plist", decodeRoot: hideMismatch)
        ]
        let hideCoordinator = EngineC2Coordinator(stubs: hideStubs)
        let hideEngine = makeEngine(coordinator: hideCoordinator)
        let hideRecords = [
            engineC2Record(key: "HideA", plistPath: "/dir/HideA.plist", dylibPath: "/dir/HideA.dylib"),
            engineC2Record(key: "HideB", plistPath: "/dir/HideB.plist", dylibPath: "/dir/HideB.dylib")
        ]
        let hideResult = hideEngine.parse(snapshot: engineC2Snapshot(route: "roothide", records: hideRecords))

        XCTAssertEqual(hideCoordinator.hideCallCount, 2)
        XCTAssertEqual(hideCoordinator.lessCallCount, 0)
        XCTAssertEqual(hideResult.counts.valid, 1)
        XCTAssertEqual(hideResult.counts.typeMismatch, 1)

        // rootless 快照：一条 valid Less，一条 Less Codable 失败。
        let lessValid: [String: Any] = [
            "Filter": ["Bundles": ["Com.Less.App"], "Executables": ["LessProc"]] as [String: Any],
            "UnloadAfter": true
        ]
        let lessFail: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let lessStubs = [
            EngineC2PlistStub(plistPath: "/dir/LessA.plist", decodeRoot: lessValid),
            EngineC2PlistStub(plistPath: "/dir/LessB.plist", decodeRoot: lessFail)
        ]
        let lessCoordinator = EngineC2Coordinator(stubs: lessStubs)
        let lessEngine = makeEngine(coordinator: lessCoordinator)
        let lessRecords = [
            engineC2Record(key: "LessA", plistPath: "/dir/LessA.plist", dylibPath: "/dir/LessA.dylib"),
            engineC2Record(key: "LessB", plistPath: "/dir/LessB.plist", dylibPath: "/dir/LessB.dylib")
        ]
        let lessResult = lessEngine.parse(snapshot: engineC2Snapshot(route: "rootless", records: lessRecords))

        XCTAssertEqual(lessCoordinator.hideCallCount, 0)
        XCTAssertEqual(lessCoordinator.lessCallCount, 2)
        XCTAssertEqual(lessResult.counts.valid, 1)
        XCTAssertEqual(lessResult.counts.parseFailed, 1)
    }

    // MARK: - 混合批次告警合并与上游未知项保留

    func testCombinedWarningsAndUnknownItemsPreserved() {
        let validRoot = engineC2ValidRoot(bundles: ["com.a.app"],
                                        classes: ["AClass"],
                                        executables: ["AProc"])
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: validRoot),
            EngineC2PlistStub(plistPath: "/dir/AppC.plist", decodeRoot: mismatchRoot)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let engine = makeEngine(coordinator: coordinator)

        let upstreamWarnings = [
            ReportWarning(code: "up_a", message: "上游告警 A", sourceStage: "stage2.2-c2"),
            ReportWarning(code: "up_b", message: "上游告警 B", sourceStage: "stage2.2-c2")
        ]
        let upstreamUnknown = UnknownItem(path: "/dir/Orphan.plist", base: "Orphan",
                                        reason: "missing_dylib", sourceStage: "stage2.2-c2")
        let records = [
            engineC2Record(key: "AppA", plistPath: "/dir/AppA.plist", dylibPath: "/dir/AppA.dylib"),
            engineC2Record(key: "AppC", plistPath: "/dir/AppC.plist", dylibPath: "/dir/AppC.dylib")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(
            route: "roothide", records: records,
            unknownItems: [upstreamUnknown], warnings: upstreamWarnings))

        // 上游告警保留；条目级与 Engine 追加告警并入；同 code 去重。
        XCTAssertTrue(result.warnings.contains { $0.code == "up_a" })
        XCTAssertTrue(result.warnings.contains { $0.code == "up_b" })
        XCTAssertTrue(result.warnings.contains { $0.code == "partial_parsing" })
        let codes = result.warnings.map { $0.code }
        XCTAssertEqual(Set(codes).count, codes.count)

        // 上游未知项原样归集在 Engine 派生未知项之后，不被重分类。
        XCTAssertEqual(result.notParsed.last, upstreamUnknown)
        XCTAssertEqual(result.notParsed.last?.reason, "missing_dylib")
    }

    // MARK: - 确定性：相同混合输入重复执行结果深相等

    func testCombinedScenarioDeterministicAcrossRepeatedRuns() {
        let validRoot = engineC2ValidRoot(bundles: ["com.valid.app"],
                                        classes: ["ValidHook"],
                                        executables: ["ValidProc"])
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/Valid.plist", decodeRoot: validRoot),
            EngineC2PlistStub(plistPath: "/dir/Mismatch.plist", decodeRoot: mismatchRoot)
        ]
        let records = [
            engineC2Record(key: "Valid", plistPath: "/dir/Valid.plist", dylibPath: "/dir/Valid.dylib"),
            engineC2Record(key: "Mismatch", plistPath: "/dir/Mismatch.plist", dylibPath: "/dir/Mismatch.dylib")
        ]

        let coordinator1 = EngineC2Coordinator(stubs: stubs)
        let engine1 = makeEngine(coordinator: coordinator1)
        let coordinator2 = EngineC2Coordinator(stubs: stubs)
        let engine2 = makeEngine(coordinator: coordinator2)

        let r1 = engine1.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))
        let r2 = engine2.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))
        XCTAssertEqual(r1, r2)
    }

    // MARK: - 不可变：解析不回写上游快照

    func testCombinedInputSnapshotNotMutated() {
        let validRoot = engineC2ValidRoot(bundles: ["com.valid.app"])
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/Valid.plist", decodeRoot: validRoot),
            EngineC2PlistStub(plistPath: "/dir/ReadFail.plist", readStatus: .notFound)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let engine = makeEngine(coordinator: coordinator)

        let upstreamUnknown = UnknownItem(path: "/dir/Orphan.plist", base: "Orphan",
                                        reason: "missing_dylib", sourceStage: "stage2.2-c2")
        let upstreamWarnings = [
            ReportWarning(code: "up_a", message: "上游告警 A", sourceStage: "stage2.2-c2")
        ]
        let records = [
            engineC2Record(key: "Valid", plistPath: "/dir/Valid.plist", dylibPath: "/dir/Valid.dylib"),
            engineC2Record(key: "ReadFail", plistPath: "/dir/ReadFail.plist", dylibPath: "/dir/ReadFail.dylib")
        ]
        let original = engineC2Snapshot(route: "roothide", records: records,
                                      unknownItems: [upstreamUnknown],
                                      warnings: upstreamWarnings)
        let baseline = original
        _ = engine.parse(snapshot: original)

        XCTAssertEqual(original, baseline)
        XCTAssertEqual(original.records, baseline.records)
        XCTAssertEqual(original.unknownItems, baseline.unknownItems)
        XCTAssertEqual(original.warnings, baseline.warnings)
    }
}
