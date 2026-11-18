//
//  EngineC2EvidenceTraceTests.swift
//  FilterKit Stage 2 — Engine-C2-D3：错误证据完整性与三层追溯（测试目标专用）
//
//  按短路顺序核对各状态下证据停在哪一层：身份 / 路径 / 路线在各状态透传；
//  Reader 失败不进入 Decoder 与 Parser；Decoder 失败不产出有效 Parser 结果；
//  非 paired 与未知路线不触发下游调用；not_parsed 不计解析失败桶；失败条目
//  不携带有效规则。证据维度对齐既有 `FilterParseResult` / `UnknownItem` 模型，
//  不另写只比最终状态的简化比较器。
//
//  桩边界：Reader / Decoder 受控回灌；Parser 计数包装委托真实实现。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2EvidenceTraceTests: XCTestCase {

    private func makeEngine(coordinator: EngineC2Coordinator) -> PluginFilterParseEngine {
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        return engineC2Engine(coordinator: coordinator, hide: hide, less: less)
    }

    // MARK: - valid 条目身份 / 路径 / 路线证据完整透传

    func testValidEntryCarriesFullIdentityEvidence() {
        let root = engineC2ValidRoot(bundles: ["com.example.app"],
                                    classes: ["ExampleClass"],
                                    executables: ["ExampleApp"])
        let stub = EngineC2PlistStub(plistPath: "/dir/Example.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let engine = makeEngine(coordinator: coordinator)

        let record = engineC2Record(key: "Example",
                                   plistPath: "/dir/Example.plist",
                                   dylibPath: "/dir/Example.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        let entry = result.parsed.first { $0.pairingKey == "Example" }

        XCTAssertEqual(entry?.status, .valid)
        XCTAssertEqual(entry?.pairingKey, "Example")
        XCTAssertEqual(entry?.dylibPath, "/dir/Example.dylib")
        XCTAssertEqual(entry?.plistPath, "/dir/Example.plist")
        XCTAssertEqual(entry?.route, "roothide")
        XCTAssertEqual(entry?.readStatus, "ok")
        XCTAssertEqual(entry?.plistFormat, "xml")
        XCTAssertNotNil(entry?.filter)
        // 有效条目规则三数组与 otherKeys 归属 Parser 证据，Engine 不剥离。
        XCTAssertEqual(entry?.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(entry?.filter?.classes, ["ExampleClass"])
        XCTAssertEqual(entry?.filter?.executables, ["ExampleApp"])
    }

    // MARK: - Reader 失败：证据停在 Reader，无 Decoder / Parser 结果

    func testReadFailureStopsBeforeDecoderAndParser() {
        let stub = EngineC2PlistStub(plistPath: "/dir/AppB.plist", readStatus: .notFound)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let engine = makeEngine(coordinator: coordinator)

        let record = engineC2Record(key: "AppB",
                                    plistPath: "/dir/AppB.plist",
                                    dylibPath: "/dir/AppB.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        let entry = result.parsed.first { $0.pairingKey == "AppB" }

        XCTAssertEqual(coordinator.readerCallCount, 1)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)

        XCTAssertEqual(entry?.status, .readFailed)
        XCTAssertEqual(entry?.reason, "read_failed")
        XCTAssertEqual(entry?.readStatus, "read_failed")
        XCTAssertNil(entry?.filter)
        // 身份与路径仍回溯到配对记录。
        XCTAssertEqual(entry?.dylibPath, "/dir/AppB.dylib")
        XCTAssertEqual(entry?.plistPath, "/dir/AppB.plist")
        XCTAssertEqual(entry?.route, "roothide")
    }

    func testAccessDeniedCarriesReaderSpecificReason() {
        let stub = EngineC2PlistStub(plistPath: "/dir/AppC.plist", readStatus: .accessDenied)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let engine = makeEngine(coordinator: coordinator)

        let record = engineC2Record(key: "AppC",
                                    plistPath: "/dir/AppC.plist",
                                    dylibPath: "/dir/AppC.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "rootless", records: [record]))
        let entry = result.parsed.first { $0.pairingKey == "AppC" }

        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertEqual(entry?.status, .readFailed)
        XCTAssertEqual(entry?.reason, "access_denied")
        XCTAssertEqual(entry?.readStatus, "access_denied")
        XCTAssertNil(entry?.filter)
    }

    // MARK: - Decoder 失败：不进入任一 Parser，无有效规则

    func testDecoderFailureStopsBeforeParser() {
        let stub = EngineC2PlistStub(plistPath: "/dir/AppD.plist", decodeFailed: true)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let engine = makeEngine(coordinator: coordinator)

        let record = engineC2Record(key: "AppD",
                                    plistPath: "/dir/AppD.plist",
                                    dylibPath: "/dir/AppD.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        let entry = result.parsed.first { $0.pairingKey == "AppD" }

        XCTAssertEqual(coordinator.readerCallCount, 1)
        XCTAssertEqual(coordinator.decoderCallCount, 1)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)

        XCTAssertEqual(entry?.status, .parseFailed)
        XCTAssertEqual(entry?.reason, "invalid_plist")
        XCTAssertEqual(entry?.readStatus, "ok")
        XCTAssertNil(entry?.filter)
        XCTAssertEqual(entry?.plistPath, "/dir/AppD.plist")
    }

    // MARK: - 类型失败：字段级 skipped 证据随条目保留

    func testTypeMismatchCarriesFieldLevelSkippedEvidence() {
        let root: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stub = EngineC2PlistStub(plistPath: "/dir/AppE.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let engine = makeEngine(coordinator: coordinator)

        let record = engineC2Record(key: "AppE",
                                    plistPath: "/dir/AppE.plist",
                                    dylibPath: "/dir/AppE.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))
        let entry = result.parsed.first { $0.pairingKey == "AppE" }

        XCTAssertEqual(entry?.status, .typeMismatch)
        XCTAssertNil(entry?.filter)
        XCTAssertFalse(entry?.skippedFields.isEmpty ?? true)
        let bundleSkip = entry?.skippedFields.first { $0.key == "Bundles" }
        XCTAssertNotNil(bundleSkip)
        XCTAssertEqual(bundleSkip?.route, "roothide")
    }

    // MARK: - 非 paired：notParsed 未知项，Reader / Decoder / Parser 零调用

    func testNonPairedRecordBecomesUnknownItemWithoutReader() {
        let orphan = PluginPairingRecord(
            category: .orphanPlist,
            pairing: .orphanPlist,
            pairingKey: "Orphan",
            plist: engineC2Evidence(name: "Orphan.plist", kind: .plist, path: "/dir/Orphan.plist"),
            reason: "missing_dylib",
            basis: .noOppositeCandidate
        )
        let coordinator = EngineC2Coordinator(stubs: [])
        let engine = makeEngine(coordinator: coordinator)

        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [orphan]))

        XCTAssertEqual(coordinator.readerCallCount, 0)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        let unknown = result.notParsed.first { $0.base == "Orphan" }
        XCTAssertEqual(unknown?.reason, "missing_dylib")
        XCTAssertEqual(result.counts.notParsed, 1)
        // not_parsed 不计入任何解析失败桶。
        XCTAssertEqual(result.counts.readFailed, 0)
        XCTAssertEqual(result.counts.parseFailed, 0)
        XCTAssertEqual(result.counts.typeMismatch, 0)
    }

    // MARK: - 未知路线：notParsed 未知项，不跨路线重试

    func testUnknownRouteRecordBecomesUnknownItemWithoutRetry() {
        let record = engineC2Record(key: "Rootful",
                                   plistPath: "/dir/Rootful.plist",
                                   dylibPath: "/dir/Rootful.dylib")
        let coordinator = EngineC2Coordinator(stubs: [])
        let engine = makeEngine(coordinator: coordinator)

        let result = engine.parse(snapshot: engineC2Snapshot(route: "rootful", records: [record]))

        XCTAssertEqual(coordinator.readerCallCount, 0)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        let unknown = result.notParsed.first { $0.base == "Rootful" }
        XCTAssertEqual(unknown?.reason, "unknown_route")
        XCTAssertEqual(result.counts.notParsed, 1)
    }

    // MARK: - 混合批次：仅 valid 条目携带规则

    func testNoFailureStateCarriesValidRule() {
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

        let records = [
            engineC2Record(key: "Valid", plistPath: "/dir/Valid.plist", dylibPath: "/dir/Valid.dylib"),
            engineC2Record(key: "ReadFail", plistPath: "/dir/ReadFail.plist", dylibPath: "/dir/ReadFail.dylib"),
            engineC2Record(key: "DecodeFail", plistPath: "/dir/DecodeFail.plist", dylibPath: "/dir/DecodeFail.dylib"),
            engineC2Record(key: "Mismatch", plistPath: "/dir/Mismatch.plist", dylibPath: "/dir/Mismatch.dylib")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        XCTAssertEqual(result.counts.valid, 1)
        XCTAssertEqual(result.counts.readFailed, 1)
        XCTAssertEqual(result.counts.parseFailed, 1)
        XCTAssertEqual(result.counts.typeMismatch, 1)

        let byKey = Dictionary(uniqueKeysWithValues: result.parsed.map { ($0.pairingKey, $0) })
        XCTAssertNotNil(byKey["Valid"]?.filter)
        XCTAssertNil(byKey["ReadFail"]?.filter)
        XCTAssertNil(byKey["DecodeFail"]?.filter)
        XCTAssertNil(byKey["Mismatch"]?.filter)
    }
}
