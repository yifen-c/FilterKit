//
//  PluginEnumerationTests.swift
//  FilterKit Stage 2 — C1 S1-04 枚举基线回归（附加回归，不计入 71 项冻结回归）
//
//  对齐：`Stage-2.2-C-Enumeration-Pairing-Parser.md` C1 门槛（23 例 ENUM）与
//  `Stage-2.2-C-Enumeration-Models-Contract.md` G-C1/G-C2 契约。
//  只读解码夹具 `environment.json`，经 `PluginDirectoryEnumerator` 产出清单快照，
//  与 `metadata.json` 基线关键字段/计数/告警集合深比较；不复制第二套基线，
//  不访问真实文件系统。既有冻结测试文件与方法保持原样，本文件为独立回归层。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginEnumerationTests: XCTestCase {

    // MARK: - 元数据解码形态

    private struct ExpectedCounts: Codable, Equatable {
        let dylib: Int
        let plist: Int
        let directory: Int
        let symlink: Int
        let other: Int
    }

    private struct Expected: Codable, Equatable {
        let route: String?
        let sourceDirectory: String?
        let status: String
        let counts: ExpectedCounts
        let itemCount: Int
        let unknownCount: Int
        let names: [String]
        let excludedNested: [String]?
    }

    private struct Meta: Codable, Equatable {
        let expected: Expected
        let expectedWarnings: [String]
        let expectedStatus: String?
    }

    // MARK: - 辅助

    private static func batchURL(batch: String) -> URL {
        let testsDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return testsDir.appendingPathComponent("Fixtures/\(batch)")
    }

    private func kinds(of batch: String) -> [String] {
        let dir = Self.batchURL(batch: batch)
        let entries = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        return entries?
            .filter { $0.hasDirectoryPath }
            .map { $0.lastPathComponent }
            .sorted() ?? []
    }

    private func decode<T: Decodable>(_ type: T.Type, batch: String, kind: String, file: String) throws -> T {
        let url = Self.batchURL(batch: batch)
            .appendingPathComponent(kind)
            .appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    private func warningCodes(_ warnings: [ReportWarning]) -> Set<String> {
        Set(warnings.map(\.code))
    }

    private func makeSignal(route: String,
                            sourceDirectory: String?,
                            enumerable: Bool = true,
                            entries: [PluginInventoryFixtureSignal.EntrySignal]) -> PluginInventoryFixtureSignal {
        PluginInventoryFixtureSignal(
            upstream: .init(route: route, sourceDirectory: sourceDirectory),
            fs: .init(enumerable: enumerable, entries: entries)
        )
    }

    // MARK: - S1-04：13 组夹具深比较（路由/目录/状态/计数/顺序/未知条目/告警）

    func testS104FixturesDeepComparison() throws {
        let enumerator = PluginDirectoryEnumerator()
        for kind in kinds(of: "S1-04") {
            let signal = try decode(PluginInventoryFixtureSignal.self,
                                    batch: "S1-04", kind: kind, file: "environment.json")
            let meta = try decode(Meta.self, batch: "S1-04", kind: kind, file: "metadata.json")
            let snapshot = enumerator.enumerate(signal)

            XCTAssertEqual(snapshot.route, meta.expected.route, "\(kind) route")
            XCTAssertEqual(snapshot.sourceDirectory, meta.expected.sourceDirectory, "\(kind) sourceDirectory")
            XCTAssertEqual(snapshot.enumeration.status.rawValue, meta.expected.status, "\(kind) status")
            XCTAssertEqual(snapshot.items.count, meta.expected.itemCount, "\(kind) itemCount")
            XCTAssertEqual(snapshot.unknownItems.count, meta.expected.unknownCount, "\(kind) unknownCount")
            XCTAssertEqual(snapshot.items.map(\.name), meta.expected.names, "\(kind) names")

            XCTAssertEqual(snapshot.counts.dylib, meta.expected.counts.dylib, "\(kind) counts.dylib")
            XCTAssertEqual(snapshot.counts.plist, meta.expected.counts.plist, "\(kind) counts.plist")
            XCTAssertEqual(snapshot.counts.directory, meta.expected.counts.directory, "\(kind) counts.directory")
            XCTAssertEqual(snapshot.counts.symlink, meta.expected.counts.symlink, "\(kind) counts.symlink")
            XCTAssertEqual(snapshot.counts.other, meta.expected.counts.other, "\(kind) counts.other")

            XCTAssertEqual(warningCodes(snapshot.warnings), Set(meta.expectedWarnings), "\(kind) warnings")
            if let expectedStatus = meta.expectedStatus {
                XCTAssertEqual(snapshot.enumeration.status.rawValue, expectedStatus, "\(kind) expectedStatus")
            }
        }
    }

    // MARK: - ENUM-011：同名条目按完整路径保留，不按基名合并

    func testEnum011PathIdentityPreserved() throws {
        let enumerator = PluginDirectoryEnumerator()
        let entry = PluginInventoryFixtureSignal.EntrySignal(
            name: "Same.dylib", type: "file", exists: true, readable: true,
            entryStatus: "ok"
        )
        let signalA = makeSignal(route: "roothide",
                                 sourceDirectory: "/root/A/usr/lib/TweakInject/",
                                 entries: [entry])
        let signalB = makeSignal(route: "roothide",
                                 sourceDirectory: "/root/B/usr/lib/TweakInject/",
                                 entries: [entry])

        let resultA = enumerator.enumerate(signalA)
        let resultB = enumerator.enumerate(signalB)

        XCTAssertEqual(resultA.items.count, 1)
        XCTAssertEqual(resultB.items.count, 1)
        XCTAssertNotEqual(resultA.items[0].path, resultB.items[0].path)
    }

    // MARK: - ENUM-014：相同信号重复枚举，清单/顺序/计数确定

    func testEnum014DeterministicRepeatedEnumeration() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-mixed", file: "environment.json")
        let resultA = enumerator.enumerate(signal)
        let resultB = enumerator.enumerate(signal)
        XCTAssertEqual(resultA, resultB)
    }

    // MARK: - ENUM-013：RootHide 未定位目录不得回退 /var/jb

    func testEnum013RouteIsolationNoFallback() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "route-guard", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)

        XCTAssertNil(snapshot.sourceDirectory)
        XCTAssertEqual(snapshot.items.count, 0)
        XCTAssertEqual(snapshot.enumeration.status, .unresolved)
        XCTAssertFalse(snapshot.items.contains { $0.path?.hasPrefix("/var/jb") == true })
    }

    // MARK: - 分类：扩展名大小写敏感

    func testExtensionIsCaseSensitive() {
        let enumerator = PluginDirectoryEnumerator()
        let entries = [
            PluginInventoryFixtureSignal.EntrySignal(name: "Good.dylib", type: "file", exists: true, readable: true, entryStatus: "ok"),
            PluginInventoryFixtureSignal.EntrySignal(name: "Bad.DYLIB", type: "file", exists: true, readable: true, entryStatus: "ok"),
            PluginInventoryFixtureSignal.EntrySignal(name: "Good.plist", type: "file", exists: true, readable: true, entryStatus: "ok"),
            PluginInventoryFixtureSignal.EntrySignal(name: "Bad.PLIST", type: "file", exists: true, readable: true, entryStatus: "ok")
        ]
        let snapshot = enumerator.enumerate(makeSignal(route: "roothide",
                                                       sourceDirectory: "/tweak/",
                                                       entries: entries))
        let kinds = Dictionary(grouping: snapshot.items, by: \.kind).mapValues(\.count)
        XCTAssertEqual(kinds[.dylib], 1)
        XCTAssertEqual(kinds[.plist], 1)
        XCTAssertEqual(kinds[.other], 2)
    }

    // MARK: - 非递归：嵌套条目不进入清单

    func testNonRecursiveNestedEntriesExcluded() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-dir-entry", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        XCTAssertEqual(snapshot.items.map(\.name), ["Plugins"])
        XCTAssertFalse(snapshot.items.contains { $0.name.contains("/") })
    }

    // MARK: - 软链：记录自身不跟随，目标与状态保留

    func testSymlinkRetainedWithoutFollowing() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-symlink-broken", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        XCTAssertEqual(snapshot.items.count, 1)
        let link = try XCTUnwrap(snapshot.items.first)
        XCTAssertEqual(link.kind, .symlink)
        XCTAssertEqual(link.isSymlink, true)
        XCTAssertEqual(link.symlinkTarget, "Missing.dylib")
        XCTAssertEqual(link.symlinkState, "broken")
    }

    // MARK: - 权限异常：条目保留，可读位 false 不与不存在混同

    func testAccessDeniedEntryRetained() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-bad-permission", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        XCTAssertEqual(snapshot.items.count, 2)
        let locked = try XCTUnwrap(snapshot.items.first { $0.name == "Locked.dylib" })
        XCTAssertEqual(locked.readable, false)
        XCTAssertEqual(locked.exists, true)
        XCTAssertEqual(locked.entryStatus, .accessDenied)
        XCTAssertEqual(snapshot.enumeration.status, .partial)
    }

    // MARK: - 隐藏条目保留并标记

    func testHiddenEntriesRetained() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-hidden-file", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        XCTAssertEqual(snapshot.items.count, 2)
        XCTAssertTrue(snapshot.items.allSatisfy { $0.hidden })
    }

    // MARK: - 三态：readable 缺失为 nil，不转 false

    func testMissingReadableStaysNil() {
        let enumerator = PluginDirectoryEnumerator()
        let entry = PluginInventoryFixtureSignal.EntrySignal(
            name: "Unknown.dylib", type: "file", exists: true
        )
        let snapshot = enumerator.enumerate(makeSignal(route: "roothide",
                                                       sourceDirectory: "/tweak/",
                                                       entries: [entry]))
        let item = snapshot.items[0]
        XCTAssertNil(item.readable)
        XCTAssertNil(item.isSymlink)
        XCTAssertNil(item.symlinkTarget)
    }

    // MARK: - 哈希：首版只承载信号，缺失为 nil，不执行计算

    func testHashSignalPassedThroughWithoutComputation() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-metadata-missing", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        let item = try XCTUnwrap(snapshot.items.first)
        XCTAssertNil(item.hash)
        XCTAssertNil(item.size)
        XCTAssertEqual(item.entryStatus, .metadataUnavailable)
    }

    // MARK: - 五类计数：目录/软链/其他不丢失

    func testFiveKindCountsComplete() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-mixed", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        XCTAssertEqual(snapshot.counts.dylib, 2)
        XCTAssertEqual(snapshot.counts.plist, 1)
        XCTAssertEqual(snapshot.counts.directory, 0)
        XCTAssertEqual(snapshot.counts.symlink, 0)
        XCTAssertEqual(snapshot.counts.other, 1)
    }

    // MARK: - 空目录：enumerated，计数全零，不判失败

    func testEmptyDirectoryIsEnumeratedWithZeroCounts() {
        let enumerator = PluginDirectoryEnumerator()
        let snapshot = enumerator.enumerate(makeSignal(route: "roothide",
                                                        sourceDirectory: "/tweak/",
                                                        entries: []))
        XCTAssertEqual(snapshot.enumeration.status, .enumerated)
        XCTAssertEqual(snapshot.items, [])
        XCTAssertEqual(snapshot.unknownItems, [])
        XCTAssertEqual(snapshot.counts, PluginKindCounts())
    }

    // MARK: - 排序：按文件名字母序（大小写敏感）稳定输出

    func testNamesSortedDeterministically() throws {
        let enumerator = PluginDirectoryEnumerator()
        let signal = try decode(PluginInventoryFixtureSignal.self,
                                batch: "S1-04", kind: "rh-mixed", file: "environment.json")
        let snapshot = enumerator.enumerate(signal)
        let names = snapshot.items.map(\.name)
        XCTAssertEqual(names, names.sorted())
    }
}
