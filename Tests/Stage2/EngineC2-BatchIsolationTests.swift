//
//  EngineC2-BatchIsolationTests.swift
//  FilterKit Stage 2 — Engine-C2-B：五态传递与多插件失败隔离
//
//  单次 Engine 运行处理混合状态批次：单条失败不中断整轮，后续条目继续处理；
//  每条记录保留自身身份、路径与原因；五态互斥，非 valid 恒无规则载体；
//  读取/解码/类型失败不互相转换。Mock 仅用于受控 Reader / Decoder 故障注入。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2BatchIsolationTests: XCTestCase {

    // MARK: - 混合五态批次（核心场景）

    func testMixedFivePluginSingleBatch() {
        let validA = engineC2ValidRoot(bundles: ["com.a.app"])
        let validE = engineC2ValidRoot(bundles: ["com.e.app"])
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]

        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: validA),
            EngineC2PlistStub(plistPath: "/dir/AppB.plist", readStatus: .notFound),
            EngineC2PlistStub(plistPath: "/dir/AppC.plist", decodeRoot: mismatchRoot),
            EngineC2PlistStub(plistPath: "/dir/AppE.plist", decodeRoot: validE)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records: [PluginPairingRecord] = [
            engineC2Record(key: "AppA", plistPath: "/dir/AppA.plist", dylibPath: "/dir/AppA.dylib"),
            engineC2Record(key: "AppB", plistPath: "/dir/AppB.plist", dylibPath: "/dir/AppB.dylib"),
            engineC2Record(key: "AppC", plistPath: "/dir/AppC.plist", dylibPath: "/dir/AppC.dylib"),
            orphanRecord(key: "AppD", plistPath: "/dir/AppD.plist"),
            engineC2Record(key: "AppE", plistPath: "/dir/AppE.plist", dylibPath: "/dir/AppE.dylib")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        // 计数：valid 2 / parse_failed 0 / type_mismatch 1 / read_failed 1 / not_parsed 1。
        XCTAssertEqual(result.counts.valid, 2)
        XCTAssertEqual(result.counts.parseFailed, 0)
        XCTAssertEqual(result.counts.typeMismatch, 1)
        XCTAssertEqual(result.counts.readFailed, 1)
        XCTAssertEqual(result.counts.notParsed, 1)
        XCTAssertEqual(result.counts.total, 5)
        XCTAssertEqual(result.parsed.count, 4)
        XCTAssertEqual(result.notParsed.count, 1)

        // 处理顺序稳定，失败条目不丢弃后续记录。
        XCTAssertEqual(result.parsed.map { $0.pairingKey }, ["AppA", "AppB", "AppC", "AppE"])
        XCTAssertEqual(result.notParsed.map { $0.base }, ["AppD"])

        // 逐条状态 / 原因 / 路径关联。
        let byKey = Dictionary(uniqueKeysWithValues: result.parsed.map { ($0.pairingKey ?? "", $0) })
        XCTAssertEqual(byKey["AppA"]?.status, .valid)
        XCTAssertEqual(byKey["AppA"]?.plistPath, "/dir/AppA.plist")
        XCTAssertEqual(byKey["AppB"]?.status, .readFailed)
        XCTAssertEqual(byKey["AppB"]?.reason, "read_failed")
        XCTAssertEqual(byKey["AppB"]?.readStatus, "read_failed")
        XCTAssertEqual(byKey["AppB"]?.plistPath, "/dir/AppB.plist")
        XCTAssertEqual(byKey["AppC"]?.status, .typeMismatch)
        XCTAssertEqual(byKey["AppC"]?.reason, "field_type")
        XCTAssertEqual(byKey["AppC"]?.plistPath, "/dir/AppC.plist")
        XCTAssertEqual(byKey["AppE"]?.status, .valid)
        XCTAssertEqual(byKey["AppE"]?.plistPath, "/dir/AppE.plist")

        let validator = FilterParseIntegrationValidator().validate(snapshot: result)
        XCTAssertTrue(validator.allPassed, validator.checks.description)
    }

    func testFailureDoesNotStopFollowingPlugins() {
        let validC = engineC2ValidRoot(bundles: ["com.c.app"])
        let validE = engineC2ValidRoot(bundles: ["com.e.app"])
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppB.plist", readStatus: .readFailed),
            EngineC2PlistStub(plistPath: "/dir/AppC.plist", decodeRoot: validC),
            EngineC2PlistStub(plistPath: "/dir/AppE.plist", decodeRoot: validE)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records = [
            engineC2Record(key: "AppB", plistPath: "/dir/AppB.plist", dylibPath: "/dir/AppB.dylib"),
            engineC2Record(key: "AppC", plistPath: "/dir/AppC.plist", dylibPath: "/dir/AppC.dylib"),
            engineC2Record(key: "AppE", plistPath: "/dir/AppE.plist", dylibPath: "/dir/AppE.dylib")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        // 首条失败后，后续两条仍被处理，顺序不变。
        XCTAssertEqual(result.parsed.map { $0.pairingKey }, ["AppB", "AppC", "AppE"])
        XCTAssertEqual(result.counts.readFailed, 1)
        XCTAssertEqual(result.counts.valid, 2)
        XCTAssertEqual(coordinator.readerCallCount, 3)
        XCTAssertEqual(coordinator.hideCallCount, 2)
    }

    // MARK: - 五态不可转换矩阵

    func testStatesTransferWithoutConversion() {
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: mismatchRoot),
            EngineC2PlistStub(plistPath: "/dir/AppB.plist", readStatus: .accessDenied),
            EngineC2PlistStub(plistPath: "/dir/AppC.plist", decodeFailed: true)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records: [PluginPairingRecord] = [
            engineC2Record(key: "AppA", plistPath: "/dir/AppA.plist", dylibPath: "/dir/AppA.dylib"),
            engineC2Record(key: "AppB", plistPath: "/dir/AppB.plist", dylibPath: "/dir/AppB.dylib"),
            engineC2Record(key: "AppC", plistPath: "/dir/AppC.plist", dylibPath: "/dir/AppC.dylib"),
            orphanRecord(key: "AppD", plistPath: "/dir/AppD.plist")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        let byKey = Dictionary(uniqueKeysWithValues: result.parsed.map { ($0.pairingKey ?? "", $0) })

        // RootHide 类型不符保持 type_mismatch，不转 parse_failed。
        XCTAssertEqual(byKey["AppA"]?.status, .typeMismatch)
        XCTAssertEqual(byKey["AppA"]?.reason, "field_type")
        // Reader 受限保持 read_failed，不转 parse_failed。
        XCTAssertEqual(byKey["AppB"]?.status, .readFailed)
        XCTAssertEqual(byKey["AppB"]?.reason, "access_denied")
        XCTAssertEqual(byKey["AppB"]?.readStatus, "access_denied")
        // Decoder 失败归 parse_failed / invalid_plist，Parser 零调用。
        XCTAssertEqual(byKey["AppC"]?.status, .parseFailed)
        XCTAssertEqual(byKey["AppC"]?.reason, "invalid_plist")
        // 非配对归集 not_parsed，不计失败桶。
        XCTAssertEqual(result.notParsed.first?.reason, "missing_dylib")

        XCTAssertEqual(result.counts.typeMismatch, 1)
        XCTAssertEqual(result.counts.readFailed, 1)
        XCTAssertEqual(result.counts.parseFailed, 1)
        XCTAssertEqual(result.counts.notParsed, 1)
        XCTAssertEqual(result.counts.total, 4)
        XCTAssertEqual(coordinator.hideCallCount, 1)
    }

    func testStatesAreMutexAndFilterOwnedByValidOnly() {
        let validA = engineC2ValidRoot(bundles: ["com.a.app"])
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": 123]]
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: validA),
            EngineC2PlistStub(plistPath: "/dir/AppB.plist", decodeRoot: mismatchRoot)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records = [
            engineC2Record(key: "AppA", plistPath: "/dir/AppA.plist", dylibPath: "/dir/AppA.dylib"),
            engineC2Record(key: "AppB", plistPath: "/dir/AppB.plist", dylibPath: "/dir/AppB.dylib")
        ]
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        // 每条只落入一个状态桶；规则载体仅 valid 非空。
        for entry in result.parsed {
            let ownsFilter = entry.status == .valid
            XCTAssertEqual(entry.filter != nil, ownsFilter, entry.pairingKey ?? "")
        }
        let validator = FilterParseIntegrationValidator().validate(snapshot: result)
        XCTAssertTrue(validator.checks.contains { $0.code == "C3B-004" && $0.passed })
    }

    // MARK: - 辅助

    private func orphanRecord(key: String, plistPath: String) -> PluginPairingRecord {
        PluginPairingRecord(
            category: .orphanPlist,
            pairing: .orphanPlist,
            pairingKey: key,
            plist: engineC2Evidence(name: (plistPath as NSString).lastPathComponent,
                                    kind: .plist, path: plistPath),
            reason: "missing_dylib",
            basis: .noOppositeCandidate
        )
    }
}
