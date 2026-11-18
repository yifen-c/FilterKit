//
//  EngineC2-SnapshotWarningsTests.swift
//  FilterKit Stage 2 — Engine-C2-C：Snapshot / Counts / Warnings / 确定性 / 不可变
//
//  三层追溯：Parser 单独结果 ↔ Engine 条目结果 ↔ Snapshot 归集；上游
//  warnings / unknownItems 原样保留不覆盖；告警按冻结顺序合并；计数与输入
//  条目一致；相同输入重复执行结果稳定；调用方原始快照不被改写。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2SnapshotWarningsTests: XCTestCase {

    // MARK: - 三层追溯

    func testParserResultTracesBackToRecordAndSnapshot() {
        let root = engineC2ValidRoot(bundles: ["com.example.app"],
                                     classes: ["ExampleClass"],
                                     executables: ["ExampleApp"])
        let stub = EngineC2PlistStub(plistPath: "/dir/Example.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "Example",
                                    plistPath: "/dir/Example.plist",
                                    dylibPath: "/dir/Example.dylib")

        // Parser 单独结果（直调真实 Parser）。
        let direct = RootHideFilterParser().parse(
            object: root,
            pairingKey: "Example",
            dylibPath: "/dir/Example.dylib",
            plistPath: "/dir/Example.plist",
            route: "roothide",
            plistFormat: "xml",
            readStatus: "ok")

        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        let entry = result.parsed.first { $0.pairingKey == "Example" }
        XCTAssertNotNil(entry)

        // Engine 条目与 Parser 单独结果逐维对齐。
        XCTAssertEqual(entry?.status, direct.status)
        XCTAssertEqual(entry?.reason, direct.reason)
        XCTAssertEqual(entry?.filter?.bundles, direct.filter?.bundles)
        XCTAssertEqual(entry?.filter?.classes, direct.filter?.classes)
        XCTAssertEqual(entry?.filter?.executables, direct.filter?.executables)
        XCTAssertEqual(entry?.otherKeys, direct.otherKeys)
        XCTAssertEqual(entry?.isTweakManager, direct.isTweakManager)
        XCTAssertEqual(entry?.skippedFields, direct.skippedFields)

        // Snapshot 条目可回溯到配对记录身份与路径。
        XCTAssertEqual(entry?.dylibPath, "/dir/Example.dylib")
        XCTAssertEqual(entry?.plistPath, "/dir/Example.plist")
        XCTAssertEqual(entry?.route, "roothide")
    }

    // MARK: - 上游保留

    func testUpstreamWarningsAndUnknownItemsPreserved() {
        let root = engineC2ValidRoot(bundles: ["com.example.app"],
                                     classes: ["ExampleClass"],
                                     executables: ["ExampleApp"])
        let stub = EngineC2PlistStub(plistPath: "/dir/Example.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let upstreamWarnings = [
            ReportWarning(code: "up_a", message: "上游告警 A", sourceStage: "stage2.2-c2"),
            ReportWarning(code: "up_b", message: "上游告警 B", sourceStage: "stage2.2-c2")
        ]
        let upstreamUnknown = UnknownItem(path: "/dir/Orphan.plist", base: "Orphan",
                                          reason: "missing_dylib", sourceStage: "stage2.2-c2")
        let record = engineC2Record(key: "Example")

        let result = engine.parse(snapshot: engineC2Snapshot(
            route: "roothide",
            records: [record],
            unknownItems: [upstreamUnknown],
            warnings: upstreamWarnings))

        // 上游告警原样保留，不被 Engine 追加告警覆盖。
        XCTAssertTrue(result.warnings.contains { $0.code == "up_a" })
        XCTAssertTrue(result.warnings.contains { $0.code == "up_b" })
        XCTAssertEqual(result.notParsed.last, upstreamUnknown)
    }

    // MARK: - 告警合并顺序（专项）

    func testWarningMergeOrderDedicated() {
        let validRoot = engineC2ValidRoot(bundles: ["com.a.app"],
                                          classes: ["AClass"],
                                          executables: ["AProc"])
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: validRoot),
            EngineC2PlistStub(plistPath: "/dir/AppC.plist", decodeRoot: mismatchRoot)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let upstreamWarnings = [
            ReportWarning(code: "up_a", message: "上游告警 A", sourceStage: "stage2.2-c2"),
            ReportWarning(code: "up_b", message: "上游告警 B", sourceStage: "stage2.2-c2")
        ]
        let records = [
            engineC2Record(key: "AppA", plistPath: "/dir/AppA.plist", dylibPath: "/dir/AppA.dylib"),
            engineC2Record(key: "AppC", plistPath: "/dir/AppC.plist", dylibPath: "/dir/AppC.dylib")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(
            route: "roothide", records: records, warnings: upstreamWarnings))

        // 顺序：上游在前 → 条目级告警 → Engine 追加（partial_parsing）；同 code 去重。
        XCTAssertEqual(result.warnings.map { $0.code },
                       ["up_a", "up_b", "field_type", "partial_parsing"])
        let codes = result.warnings.map { $0.code }
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    // MARK: - 计数与输入一致

    func testCountsMatchInputRecords() {
        let roots = ["AppA", "AppB", "AppC"].map {
            engineC2ValidRoot(bundles: ["com.\($0.lowercased()).app"])
        }
        let stubs = zip(["AppA", "AppB", "AppC"], roots).map { name, root in
            EngineC2PlistStub(plistPath: "/dir/\(name).plist", decodeRoot: root)
        }
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records = ["AppA", "AppB", "AppC"].map {
            engineC2Record(key: $0, plistPath: "/dir/\($0).plist", dylibPath: "/dir/\($0).dylib")
        }
        let upstreamUnknown = UnknownItem(path: "/dir/Orphan.plist", base: "Orphan",
                                          reason: "missing_dylib", sourceStage: "stage2.2-c2")
        let result = engine.parse(snapshot: engineC2Snapshot(
            route: "roothide", records: records, unknownItems: [upstreamUnknown]))

        XCTAssertEqual(result.parsed.count, 3)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.counts.valid, 3)
        XCTAssertEqual(result.counts.notParsed, 1)
        XCTAssertEqual(result.counts.total, 4)
        XCTAssertEqual(result.counts.total, result.parsed.count + result.notParsed.count)
    }

    // MARK: - 确定性与不可变

    func testSnapshotDeterminismDeepEqual() {
        let root = engineC2ValidRoot(bundles: ["com.example.app"],
                                     classes: ["ExampleClass"],
                                     executables: ["ExampleApp"])
        let stubs = [EngineC2PlistStub(plistPath: "/dir/Example.plist", decodeRoot: root)]

        let coordinator1 = EngineC2Coordinator(stubs: stubs)
        let engine1 = engineC2Engine(
            coordinator: coordinator1,
            hide: EngineC2CountingParser(coordinator: coordinator1, side: .hide,
                                          delegate: RootHideFilterParser()),
            less: EngineC2CountingParser(coordinator: coordinator1, side: .less,
                                          delegate: RootlessFilterParser()))

        let coordinator2 = EngineC2Coordinator(stubs: stubs)
        let engine2 = engineC2Engine(
            coordinator: coordinator2,
            hide: EngineC2CountingParser(coordinator: coordinator2, side: .hide,
                                          delegate: RootHideFilterParser()),
            less: EngineC2CountingParser(coordinator: coordinator2, side: .less,
                                          delegate: RootlessFilterParser()))

        let record = engineC2Record(key: "Example")
        let r1 = engine1.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        let r2 = engine2.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        XCTAssertEqual(r1, r2)
    }

    func testInputSnapshotNotMutated() {
        let root = engineC2ValidRoot(bundles: ["com.example.app"])
        let stub = EngineC2PlistStub(plistPath: "/dir/Example.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "Example")
        let original = engineC2Snapshot(route: "roothide", records: [record])
        let baseline = original
        _ = engine.parse(snapshot: original)

        XCTAssertEqual(original, baseline)
        XCTAssertEqual(original.records, baseline.records)
        XCTAssertEqual(original.unknownItems, baseline.unknownItems)
        XCTAssertEqual(original.warnings, baseline.warnings)
    }
}
