//
//  EngineC2-EndToEndTests.swift
//  FilterKit Stage 2 — Engine-C2-A：双路线端到端测试
//
//  验证现有 Engine 真实调用链：C2 Pairing Snapshot → Engine → Reader →
//  Decoder → 路线 Parser → Snapshot。RootHide 走真实 Parser；Rootless 对称
//  端到端在 C-G2（#151）关闭后解除挂起。Mock 仅用于
//  受控 Reader / Decoder 回灌，不冒充 Parser 成功结果。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2EndToEndTests: XCTestCase {

    // MARK: - RootHide 真实 Parser 端到端

    func testRootHideSingleValidEndToEnd() {
        let stub = EngineC2PlistStub(
            plistPath: "/dir/AppA.plist",
            decodeRoot: engineC2ValidRoot(bundles: ["com.a.app"],
                                           classes: ["AClass"],
                                           executables: ["AProc"])
        )
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "AppA",
                                     plistPath: "/dir/AppA.plist",
                                     dylibPath: "/dir/AppA.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))

        XCTAssertEqual(result.parsed.count, 1)
        let entry = result.parsed.first
        XCTAssertEqual(entry?.status, .valid)
        XCTAssertEqual(entry?.filter?.bundles, ["com.a.app"])
        XCTAssertEqual(entry?.filter?.classes, ["AClass"])
        XCTAssertEqual(entry?.filter?.executables, ["AProc"])
        XCTAssertEqual(entry?.route, "roothide")
        XCTAssertEqual(entry?.plistPath, "/dir/AppA.plist")
        XCTAssertEqual(entry?.dylibPath, "/dir/AppA.dylib")
        XCTAssertEqual(entry?.pairingKey, "AppA")

        XCTAssertEqual(coordinator.hideCallCount, 1)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertEqual(coordinator.readerCallCount, 1)
        XCTAssertEqual(coordinator.decoderCallCount, 1)
        XCTAssertEqual(result.counts.valid, 1)
        XCTAssertTrue(FilterParseIntegrationValidator().validate(snapshot: result).allPassed)
    }

    func testRootHideMultiPluginValidEndToEnd() {
        let roots: [(String, [String])] = [
            ("AppA", ["com.a.app"]),
            ("AppB", ["com.b.app", "com.b2.app"]),
            ("AppC", ["com.c.app"])
        ]
        let stubs = roots.map { name, bundles in
            EngineC2PlistStub(plistPath: "/dir/\(name).plist",
                              decodeRoot: engineC2ValidRoot(bundles: bundles))
        }
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records = roots.map { name, _ in
            engineC2Record(key: name,
                           plistPath: "/dir/\(name).plist",
                           dylibPath: "/dir/\(name).dylib")
        }
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        XCTAssertEqual(result.parsed.count, 3)
        XCTAssertEqual(result.counts.valid, 3)
        XCTAssertEqual(coordinator.hideCallCount, 3)
        XCTAssertEqual(coordinator.lessCallCount, 0)

        // 逐条身份与路径对齐，不发生跨插件串线。
        for (name, bundles) in roots {
            let entry = result.parsed.first { $0.pairingKey == name }
            XCTAssertEqual(entry?.status, .valid, name)
            XCTAssertEqual(entry?.filter?.bundles, bundles, name)
            XCTAssertEqual(entry?.plistPath, "/dir/\(name).plist", name)
            XCTAssertEqual(entry?.dylibPath, "/dir/\(name).dylib", name)
            XCTAssertEqual(entry?.route, "roothide", name)
        }
    }

    func testRootHideMultiPluginMixedStatusEndToEnd() {
        let validA = engineC2ValidRoot(bundles: ["com.a.app"])
        let validB = engineC2ValidRoot(bundles: ["com.b.app"])
        let mismatchRoot: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stubs = [
            EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: validA),
            EngineC2PlistStub(plistPath: "/dir/AppB.plist", decodeRoot: validB),
            EngineC2PlistStub(plistPath: "/dir/AppC.plist", decodeRoot: mismatchRoot)
        ]
        let coordinator = EngineC2Coordinator(stubs: stubs)
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let records = ["AppA", "AppB", "AppC"].map {
            engineC2Record(key: $0, plistPath: "/dir/\($0).plist", dylibPath: "/dir/\($0).dylib")
        }
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: records))

        XCTAssertEqual(result.parsed.count, 3)
        XCTAssertEqual(result.counts.valid, 2)
        XCTAssertEqual(result.counts.typeMismatch, 1)
        XCTAssertEqual(coordinator.hideCallCount, 3)
        XCTAssertEqual(coordinator.lessCallCount, 0)

        let mismatch = result.parsed.first { $0.pairingKey == "AppC" }
        XCTAssertEqual(mismatch?.status, .typeMismatch)
        XCTAssertEqual(mismatch?.reason, "field_type")
        XCTAssertNil(mismatch?.filter)
        XCTAssertEqual(mismatch?.plistPath, "/dir/AppC.plist")
    }

    // MARK: - Rootless 对称端到端（C-G2 关闭后解除挂起）

    func testRootlessSymmetricEndToEnd() {
        let stub = EngineC2PlistStub(
            plistPath: "/dir/RL.plist",
            decodeRoot: ["Filter": ["Bundles": ["com.example.app"],
                                   "Executables": ["rlapp"]] as [String: Any]]
        )
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "RL",
                                    plistPath: "/dir/RL.plist",
                                    dylibPath: "/dir/RL.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "rootless", records: [record]))

        XCTAssertEqual(coordinator.lessCallCount, 1)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(result.parsed.first?.route, "rootless")
    }

    // MARK: - 非配对 / 未知路线零调用

    func testNonPairedNeverEntersReader() {
        let coordinator = EngineC2Coordinator(stubs: [])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let orphan = PluginPairingRecord(
            category: .orphanPlist,
            pairing: .orphanPlist,
            pairingKey: "Orphan",
            plist: engineC2Evidence(name: "Orphan.plist", kind: .plist, path: "/dir/Orphan.plist"),
            reason: "missing_dylib",
            basis: .noOppositeCandidate
        )
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [orphan]))

        XCTAssertEqual(coordinator.readerCallCount, 0)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.notParsed.first?.reason, "missing_dylib")
    }

    func testUnknownRouteNeverEntersDownstream() {
        let coordinator = EngineC2Coordinator(stubs: [])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "Example",
                                    plistPath: "/dir/Example.plist",
                                    dylibPath: "/dir/Example.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "rootful", records: [record]))

        XCTAssertEqual(coordinator.readerCallCount, 0)
        XCTAssertEqual(coordinator.decoderCallCount, 0)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.notParsed.first?.reason, "unknown_route")
    }
}
