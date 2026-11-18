//
//  EngineC2RouteSymmetryTests.swift
//  FilterKit Stage 2 — Engine-C2-D2：双路线对称性测试（测试目标专用）
//
//  RootHide 严格类型校验与 Rootless Codable 解码分别验证；两条路线只共享公共
//  `FilterRule` 模型与通用基础能力，Parser 规则不合并、不互相回退。路线选边
//  以快照 `route` 为准，Engine 不产生第二套路线推断机制。
//
//  桩边界：Reader / Decoder 为按路径受控桩；双 Parser 由 `EngineC2CountingParser`
//  包装委托真实 `RootHideFilterParser()` / `RootlessFilterParser()`，真实解析行为
//  不以 Mock 成功结果冒充。不实例化 Adapter、不访问真实文件系统。
//

import Foundation
import XCTest
@testable import Core
@testable import Models

final class EngineC2RouteSymmetryTests: XCTestCase {

    // MARK: - 路线选边：RootHide 只进 Hide Parser

    func testRootHideRouteSelectsHideParserOnly() {
        let root: [String: Any] = [
            "Filter": [
                "Bundles": ["com.a.app"],
                "Classes": ["AHook"],
                "Executables": ["AProc"],
                "CoreFoundationVersion": [1600]
            ] as [String: Any],
            "IsTweakManager": true
        ]
        let stub = EngineC2PlistStub(plistPath: "/dir/AppA.plist", decodeRoot: root)
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

        XCTAssertEqual(coordinator.readerCallCount, 1)
        XCTAssertEqual(coordinator.decoderCallCount, 1)
        XCTAssertEqual(coordinator.hideCallCount, 1)
        XCTAssertEqual(coordinator.lessCallCount, 0)

        let entry = result.parsed.first
        XCTAssertEqual(entry?.status, .valid)
        XCTAssertEqual(entry?.route, "roothide")
        XCTAssertEqual(entry?.filter?.bundles, ["com.a.app"])
        XCTAssertEqual(entry?.filter?.classes, ["AHook"])
        XCTAssertEqual(entry?.filter?.executables, ["AProc"])
        XCTAssertEqual(entry?.isTweakManager, true)
        XCTAssertEqual(entry?.filter?.coreFoundationVersion?.mode, .max)
        XCTAssertEqual(entry?.filter?.coreFoundationVersion?.max, 1600)
    }

    // MARK: - 路线选边：Rootless 只进 Less Parser

    func testRootlessRouteSelectsLessParserOnly() {
        let root: [String: Any] = [
            "Filter": [
                "Bundles": ["Com.Example.App"],
                "Executables": ["RLApp"]
            ] as [String: Any],
            "UnloadAfter": true,
            "Classes": ["RLClass"],
            "CoreFoundationVersion": [1600],
            "IsTweakManager": true
        ]
        let stub = EngineC2PlistStub(plistPath: "/dir/RL.plist", decodeRoot: root)
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

        XCTAssertEqual(coordinator.readerCallCount, 1)
        XCTAssertEqual(coordinator.decoderCallCount, 1)
        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 1)

        let entry = result.parsed.first
        XCTAssertEqual(entry?.status, .valid)
        XCTAssertEqual(entry?.route, "rootless")
        // Rootless Codable 映射规范化为小写；Classes / CFV / IsTweakManager 入 otherKeys。
        XCTAssertEqual(entry?.filter?.bundles, ["com.example.app"])
        XCTAssertEqual(entry?.filter?.executables, ["rlapp"])
        XCTAssertEqual(entry?.filter?.classes, [])
        XCTAssertEqual(entry?.otherKeys, ["Classes", "CoreFoundationVersion", "IsTweakManager"])
        // Rootless 不产出 IsTweakManager 布尔口径。
        XCTAssertNil(entry?.isTweakManager)
    }

    // MARK: - 不跨路线回退：路线形状不符也不换 Parser

    func testRouteSelectionDoesNotCrossFallback() {
        // roothide 路线下喂 Rootless 形状（仅 Bundles/Executables）：仍只进 Hide，
        // 不回退到 Less 产出成功规则。
        let hideShapeRoot: [String: Any] = [
            "Filter": ["Bundles": ["com.a.app"], "Executables": ["AProc"]] as [String: Any]
        ]
        let hideStub = EngineC2PlistStub(plistPath: "/dir/A.plist", decodeRoot: hideShapeRoot)
        let hideCoordinator = EngineC2Coordinator(stubs: [hideStub])
        let hideParser = EngineC2CountingParser(coordinator: hideCoordinator, side: .hide,
                                                delegate: RootHideFilterParser())
        let lessParserA = EngineC2CountingParser(coordinator: hideCoordinator, side: .less,
                                                 delegate: RootlessFilterParser())
        let hideEngine = engineC2Engine(coordinator: hideCoordinator, hide: hideParser, less: lessParserA)
        let hideRecord = engineC2Record(key: "A", plistPath: "/dir/A.plist", dylibPath: "/dir/A.dylib")
        let hideResult = hideEngine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [hideRecord]))

        XCTAssertEqual(hideCoordinator.hideCallCount, 1)
        XCTAssertEqual(hideCoordinator.lessCallCount, 0)
        XCTAssertEqual(hideResult.parsed.first?.route, "roothide")

        // rootless 路线下喂 RootHide 形状（Classes 数组）：仍只进 Less，不回退到 Hide。
        let lessShapeRoot: [String: Any] = [
            "Filter": ["Bundles": ["com.b.app"], "Classes": ["BHook"]] as [String: Any]
        ]
        let lessStub = EngineC2PlistStub(plistPath: "/dir/B.plist", decodeRoot: lessShapeRoot)
        let lessCoordinator = EngineC2Coordinator(stubs: [lessStub])
        let hideParserB = EngineC2CountingParser(coordinator: lessCoordinator, side: .hide,
                                                delegate: RootHideFilterParser())
        let lessParserB = EngineC2CountingParser(coordinator: lessCoordinator, side: .less,
                                                delegate: RootlessFilterParser())
        let lessEngine = engineC2Engine(coordinator: lessCoordinator, hide: hideParserB, less: lessParserB)
        let lessRecord = engineC2Record(key: "B", plistPath: "/dir/B.plist", dylibPath: "/dir/B.dylib")
        let lessResult = lessEngine.parse(snapshot: engineC2Snapshot(route: "rootless", records: [lessRecord]))

        XCTAssertEqual(lessCoordinator.hideCallCount, 0)
        XCTAssertEqual(lessCoordinator.lessCallCount, 1)
        XCTAssertEqual(lessResult.parsed.first?.route, "rootless")
    }

    // MARK: - 失败语义分路线：RootHide 严格类型 = type_mismatch

    func testRootHideStrictTypeFailureIsTypeMismatch() {
        let root: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stub = EngineC2PlistStub(plistPath: "/dir/C.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "C", plistPath: "/dir/C.plist", dylibPath: "/dir/C.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [record]))

        XCTAssertEqual(coordinator.hideCallCount, 1)
        XCTAssertEqual(coordinator.lessCallCount, 0)
        let entry = result.parsed.first
        XCTAssertEqual(entry?.status, .typeMismatch)
        XCTAssertNil(entry?.filter)
    }

    // MARK: - 失败语义分路线：Rootless Codable 失败 = parse_failed

    func testRootlessCodableFailureIsParseFailed() {
        let root: [String: Any] = ["Filter": ["Bundles": "not-an-array"]]
        let stub = EngineC2PlistStub(plistPath: "/dir/RLC.plist", decodeRoot: root)
        let coordinator = EngineC2Coordinator(stubs: [stub])
        let hide = EngineC2CountingParser(coordinator: coordinator, side: .hide,
                                           delegate: RootHideFilterParser())
        let less = EngineC2CountingParser(coordinator: coordinator, side: .less,
                                          delegate: RootlessFilterParser())
        let engine = engineC2Engine(coordinator: coordinator, hide: hide, less: less)

        let record = engineC2Record(key: "RLC", plistPath: "/dir/RLC.plist", dylibPath: "/dir/RLC.dylib")
        let result = engine.parse(snapshot: engineC2Snapshot(route: "rootless", records: [record]))

        XCTAssertEqual(coordinator.hideCallCount, 0)
        XCTAssertEqual(coordinator.lessCallCount, 1)
        let entry = result.parsed.first
        XCTAssertEqual(entry?.status, .parseFailed)
        XCTAssertNil(entry?.filter)
    }

    // MARK: - 公共规则模型：两路线 valid 条目同构，非 valid 恒无规则

    func testBothRoutesShareCommonFilterRuleModel() {
        let hideRoot: [String: Any] = [
            "Filter": ["Bundles": ["com.hide.app"], "Classes": ["Hook"], "Executables": ["Proc"]] as [String: Any]
        ]
        let hideStub = EngineC2PlistStub(plistPath: "/dir/H.plist", decodeRoot: hideRoot)
        let hideCoordinator = EngineC2Coordinator(stubs: [hideStub])
        let hideEngine = engineC2Engine(
            coordinator: hideCoordinator,
            hide: EngineC2CountingParser(coordinator: hideCoordinator, side: .hide,
                                         delegate: RootHideFilterParser()),
            less: EngineC2CountingParser(coordinator: hideCoordinator, side: .less,
                                         delegate: RootlessFilterParser()))
        let hideRecord = engineC2Record(key: "H", plistPath: "/dir/H.plist", dylibPath: "/dir/H.dylib")
        let hideEntry = hideEngine.parse(snapshot: engineC2Snapshot(route: "roothide", records: [hideRecord])).parsed.first

        let lessRoot: [String: Any] = [
            "Filter": ["Bundles": ["Com.Less.App"], "Executables": ["LessProc"]] as [String: Any]
        ]
        let lessStub = EngineC2PlistStub(plistPath: "/dir/L.plist", decodeRoot: lessRoot)
        let lessCoordinator = EngineC2Coordinator(stubs: [lessStub])
        let lessEngine = engineC2Engine(
            coordinator: lessCoordinator,
            hide: EngineC2CountingParser(coordinator: lessCoordinator, side: .hide,
                                         delegate: RootHideFilterParser()),
            less: EngineC2CountingParser(coordinator: lessCoordinator, side: .less,
                                         delegate: RootlessFilterParser()))
        let lessRecord = engineC2Record(key: "L", plistPath: "/dir/L.plist", dylibPath: "/dir/L.dylib")
        let lessEntry = lessEngine.parse(snapshot: engineC2Snapshot(route: "rootless", records: [lessRecord])).parsed.first

        XCTAssertEqual(hideEntry?.status, .valid)
        XCTAssertEqual(lessEntry?.status, .valid)
        // 公共模型字段在位；不要求两路线规则内容相同。
        XCTAssertEqual(hideEntry?.filter?.bundles, ["com.hide.app"])
        XCTAssertEqual(lessEntry?.filter?.bundles, ["com.less.app"])
        XCTAssertNotNil(hideEntry?.filter?.classes)
        XCTAssertNotNil(lessEntry?.filter?.executables)
    }
}
