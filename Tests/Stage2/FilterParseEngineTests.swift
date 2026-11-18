//
//  FilterParseEngineTests.swift
//  FilterKit Stage 2 — C3-Engine-B 双路线解析引擎专项测试（E-B1 ~ E-B6）
//
//  覆盖路线归一、短路调用次数矩阵、Reader/Decoder 状态映射、双路线隔离、
//  快照五态计数与证据/不可变性。全部合成夹具，不读取 plist 文件，不实例化
//  Adapter；Reader/Decoder/Parser 经内部协议注入只读桩并记录调用次数。
//  Engine-B 测试通过不构成 C3-C2 Runner 验收，也不替代 S1-06 基线集成验收。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class FilterParseEngineTests: XCTestCase {

    // MARK: - E-B1 Route Resolver

    func testResolverMapsKnownRoutesOnly() {
        let resolver = FilterParseRouteResolver()

        XCTAssertEqual(resolver.resolve(route: "roothide"), .rootHide)
        XCTAssertEqual(resolver.resolve(route: "rootless"), .rootless)
        XCTAssertEqual(resolver.resolve(route: "RootHide"), .rootHide)
        XCTAssertEqual(resolver.resolve(route: nil), .unknown)
        XCTAssertEqual(resolver.resolve(route: "rootful"), .unknown)
        XCTAssertEqual(resolver.resolve(route: "unknown"), .unknown)
        XCTAssertEqual(resolver.resolve(route: "other"), .unknown)
    }

    // MARK: - E-B2 Pipeline Short Circuit

    func testNonPairedNeverEntersReader() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let record = PluginPairingRecord(
            category: .missingPlist,
            pairing: .missingPlist,
            pairingKey: "Missing",
            dylib: evidence(name: "Missing.dylib", kind: .dylib, path: "/dir/Missing.dylib"),
            reason: "missing_plist",
            basis: .noOppositeCandidate
        )
        let snapshot = makeSnapshot(route: "roothide", records: [record])

        let result = engine.parse(snapshot: snapshot)

        XCTAssertEqual(reader.readCallCount, 0)
        XCTAssertEqual(decoder.decodeCallCount, 0)
        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.notParsed.first?.reason, "missing_plist")
    }

    func testUnknownRouteNeverEntersReader() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let snapshot = makeSnapshot(route: "rootful", records: [pairedRecord(key: "Example")])
        let result = engine.parse(snapshot: snapshot)

        XCTAssertEqual(reader.readCallCount, 0)
        XCTAssertEqual(decoder.decodeCallCount, 0)
        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertEqual(result.notParsed.count, 1)
        XCTAssertEqual(result.notParsed.first?.reason, "unknown_route")
    }

    func testUnresolvedSnapshotCallsNothing() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let snapshot = PluginPairingSnapshot(
            route: "roothide",
            sourceDirectory: nil,
            status: .unresolved,
            records: [pairedRecord(key: "Example")],
            unknownItems: [],
            counts: PluginPairingCounts(),
            warnings: []
        )
        let result = engine.parse(snapshot: snapshot)

        XCTAssertEqual(reader.readCallCount, 0)
        XCTAssertEqual(decoder.decodeCallCount, 0)
        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertTrue(result.parsed.isEmpty)
        XCTAssertTrue(result.notParsed.isEmpty)
        XCTAssertEqual(result.status, "unresolved")
        XCTAssertTrue(result.warnings.contains { $0.code == "inventory_unresolved" })
    }

    func testReaderFailureShortCircuitsDecoder() {
        let reader = StubReader(canned: PlistReadResult(status: .notFound, data: nil, path: "/dir/Example.plist"))
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let result = engine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))

        XCTAssertEqual(reader.readCallCount, 1)
        XCTAssertEqual(decoder.decodeCallCount, 0)
        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertEqual(result.parsed.first?.status, .readFailed)
    }

    func testDecoderFailureShortCircuitsParser() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: PlistDecodeResult(status: .parseFailed, object: nil, errorDescription: "bad plist"))
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let result = engine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))

        XCTAssertEqual(reader.readCallCount, 1)
        XCTAssertEqual(decoder.decodeCallCount, 1)
        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertEqual(result.parsed.first?.status, .parseFailed)
        XCTAssertEqual(result.parsed.first?.reason, "invalid_plist")
    }

    func testRootHideRouteCallsOnlyHideParser() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let result = engine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))

        XCTAssertEqual(reader.readCallCount, 1)
        XCTAssertEqual(decoder.decodeCallCount, 1)
        XCTAssertEqual(hide.callCount, 1)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertEqual(result.parsed.first?.route, "roothide")
    }

    func testRootlessRouteCallsOnlyRootlessParser() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let result = engine.parse(snapshot: makeSnapshot(route: "rootless", records: [pairedRecord(key: "Example")]))

        XCTAssertEqual(reader.readCallCount, 1)
        XCTAssertEqual(decoder.decodeCallCount, 1)
        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 1)
        XCTAssertEqual(result.parsed.first?.route, "rootless")
    }

    // MARK: - E-B3 Reader / Decoder 状态映射

    func testReaderStatusMapping() {
        let denied = StubReader(canned: PlistReadResult(status: .accessDenied, data: nil, path: "/x.plist"))
        let deniedEngine = makeEngine(reader: denied, decoder: StubDecoder(canned: decodeSuccess),
                                      hide: StubParser(canned: validResult(route: "roothide")),
                                      less: StubParser(canned: validResult(route: "rootless")))
        let deniedResult = deniedEngine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))
        XCTAssertEqual(deniedResult.parsed.first?.readStatus, "access_denied")
        XCTAssertEqual(deniedResult.parsed.first?.reason, "access_denied")

        let missing = StubReader(canned: PlistReadResult(status: .notFound, data: nil, path: "/x.plist"))
        let missingEngine = makeEngine(reader: missing, decoder: StubDecoder(canned: decodeSuccess),
                                       hide: StubParser(canned: validResult(route: "roothide")),
                                       less: StubParser(canned: validResult(route: "rootless")))
        let missingResult = missingEngine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))
        XCTAssertEqual(missingResult.parsed.first?.readStatus, "read_failed")
        XCTAssertEqual(missingResult.parsed.first?.reason, "read_failed")

        let failed = StubReader(canned: PlistReadResult(status: .readFailed, data: nil, path: "/x.plist"))
        let failedEngine = makeEngine(reader: failed, decoder: StubDecoder(canned: decodeSuccess),
                                      hide: StubParser(canned: validResult(route: "roothide")),
                                      less: StubParser(canned: validResult(route: "rootless")))
        let failedResult = failedEngine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))
        XCTAssertEqual(failedResult.parsed.first?.readStatus, "read_failed")
    }

    func testDecoderFormatProjection() {
        let binary = PlistDecodedObject(rootObject: ["Filter": [:] as Any], format: .binary)
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: PlistDecodeResult(status: .success, object: binary, errorDescription: nil))
        let hide = StubParser(canned: validResult(route: "roothide"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: StubParser(canned: validResult(route: "rootless")))

        _ = engine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))
        XCTAssertEqual(hide.lastPlistFormat, "binary")
    }

    // MARK: - E-B4 Dual Parser 隔离

    func testHideMismatchDoesNotFallBackToRootless() {
        let mismatch = FilterParseResult(pairingKey: "Example", route: "roothide", status: .typeMismatch, reason: "field_type")
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: mismatch)
        let less = StubParser(canned: validResult(route: "rootless"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let result = engine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))

        XCTAssertEqual(hide.callCount, 1)
        XCTAssertEqual(less.callCount, 0)
        XCTAssertEqual(result.parsed.first?.status, .typeMismatch)
    }

    func testRootlessMismatchDoesNotFallBackToHide() {
        let mismatch = FilterParseResult(pairingKey: "Example", route: "rootless", status: .typeMismatch, reason: "element_type")
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let less = StubParser(canned: mismatch)
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: less)

        let result = engine.parse(snapshot: makeSnapshot(route: "rootless", records: [pairedRecord(key: "Example")]))

        XCTAssertEqual(hide.callCount, 0)
        XCTAssertEqual(less.callCount, 1)
        XCTAssertEqual(result.parsed.first?.status, .typeMismatch)
    }

    func testParserReceivesSnapshotRoute() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: StubParser(canned: validResult(route: "rootless")))

        _ = engine.parse(snapshot: makeSnapshot(route: "roothide", records: [pairedRecord(key: "Example")]))
        XCTAssertEqual(hide.lastRoute, "roothide")
    }

    // MARK: - E-B5 Snapshot / Counts

    func testCountsAcrossFiveBuckets() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let validHide = StubParser(canned: validResult(route: "roothide"))
        let failedHide = StubParser(canned: FilterParseResult(route: "roothide", status: .parseFailed, reason: "invalid_plist"))
        let mismatchHide = StubParser(canned: FilterParseResult(route: "roothide", status: .typeMismatch, reason: "field_type"))
        let readFail = StubReader(canned: PlistReadResult(status: .readFailed, data: nil, path: "/x.plist"))

        let paired = [
            pairedRecord(key: "Valid"),
            pairedRecord(key: "ParseFail"),
            pairedRecord(key: "Mismatch"),
            pairedRecord(key: "ReadFail")
        ]
        let nonPaired = PluginPairingRecord(
            category: .orphanPlist,
            pairing: .orphanPlist,
            pairingKey: "Orphan",
            plist: evidence(name: "Orphan.plist", kind: .plist, path: "/dir/Orphan.plist"),
            reason: "missing_dylib",
            basis: .noOppositeCandidate
        )
        let upstreamUnknown = UnknownItem(path: "/dir/Other.plist", base: "Other", reason: "unknown", sourceStage: "stage2.2-c2")

        // 逐条编排以隔离不同失败桩。
        let engineValid = makeEngine(reader: reader, decoder: decoder, hide: validHide, less: StubParser(canned: validResult(route: "rootless")))
        let r1 = engineValid.parse(snapshot: makeSnapshot(records: [paired[0]]))
        let engineFail = makeEngine(reader: reader, decoder: decoder, hide: failedHide, less: StubParser(canned: validResult(route: "rootless")))
        let r2 = engineFail.parse(snapshot: makeSnapshot(records: [paired[1]]))
        let engineMismatch = makeEngine(reader: reader, decoder: decoder, hide: mismatchHide, less: StubParser(canned: validResult(route: "rootless")))
        let r3 = engineMismatch.parse(snapshot: makeSnapshot(records: [paired[2]]))
        let engineRead = makeEngine(reader: readFail, decoder: decoder, hide: validHide, less: StubParser(canned: validResult(route: "rootless")))
        let r4 = engineRead.parse(snapshot: makeSnapshot(records: [paired[3]]))
        let engineNonPaired = makeEngine(reader: reader, decoder: decoder, hide: validHide, less: StubParser(canned: validResult(route: "rootless")))
        let r5 = engineNonPaired.parse(snapshot: makeSnapshot(records: [nonPaired], unknownItems: [upstreamUnknown]))

        let merged = FilterParseSnapshotBuilder().build(
            upstream: PluginPairingSnapshot(route: "roothide", sourceDirectory: "/dir", status: .enumerated, records: [], unknownItems: [], counts: PluginPairingCounts(), warnings: []),
            parsed: r1.parsed + r2.parsed + r3.parsed + r4.parsed,
            notParsed: r5.notParsed
        )

        XCTAssertEqual(merged.counts.valid, 1)
        XCTAssertEqual(merged.counts.parseFailed, 1)
        XCTAssertEqual(merged.counts.typeMismatch, 1)
        XCTAssertEqual(merged.counts.readFailed, 1)
        XCTAssertEqual(merged.counts.notParsed, 2)
        XCTAssertEqual(merged.counts.total, 6)
        XCTAssertEqual(merged.parsed.count, 4)
        XCTAssertEqual(merged.notParsed.count, 2)
        XCTAssertEqual(merged.status, "partial")
        XCTAssertTrue(merged.warnings.contains { $0.code == "partial_parsing" })

        let validator = FilterParseIntegrationValidator()
        let validation = validator.validate(snapshot: merged)
        XCTAssertTrue(validation.allPassed, validation.checks.description)
    }

    func testAllValidSnapshotIsEnumerated() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: StubParser(canned: validResult(route: "rootless")))

        let result = engine.parse(snapshot: makeSnapshot(records: [pairedRecord(key: "A"), pairedRecord(key: "B")]))

        XCTAssertEqual(result.status, "enumerated")
        XCTAssertEqual(result.counts.valid, 2)
        XCTAssertFalse(result.warnings.contains { $0.code == "partial_parsing" })
        XCTAssertTrue(FilterParseIntegrationValidator().validate(snapshot: result).allPassed)
    }

    // MARK: - E-B6 Evidence / Immutability

    func testUpstreamSnapshotNotMutated() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: StubParser(canned: validResult(route: "rootless")))

        let original = makeSnapshot(records: [pairedRecord(key: "Example")])
        let baseline = original
        _ = engine.parse(snapshot: original)

        XCTAssertEqual(original, baseline)
        XCTAssertEqual(original.records, baseline.records)
        XCTAssertEqual(original.unknownItems, baseline.unknownItems)
    }

    func testResultPreservesRecordEvidence() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: StubParser(canned: validResult(route: "rootless")))

        let record = pairedRecord(key: "Example", dylibPath: "/lib/Example.dylib", plistPath: "/lib/Example.plist")
        let result = engine.parse(snapshot: makeSnapshot(records: [record]))

        let parsed = result.parsed.first
        XCTAssertEqual(parsed?.pairingKey, "Example")
        XCTAssertEqual(parsed?.dylibPath, "/lib/Example.dylib")
        XCTAssertEqual(parsed?.plistPath, "/lib/Example.plist")
    }

    func testUpstreamUnknownItemsPreserved() {
        let reader = StubReader(canned: readSuccess)
        let decoder = StubDecoder(canned: decodeSuccess)
        let hide = StubParser(canned: validResult(route: "roothide"))
        let engine = makeEngine(reader: reader, decoder: decoder, hide: hide, less: StubParser(canned: validResult(route: "rootless")))

        let upstream = UnknownItem(path: "/dir/Orphan.plist", base: "Orphan", reason: "missing_dylib", sourceStage: "stage2.2-c2")
        let result = engine.parse(snapshot: makeSnapshot(records: [pairedRecord(key: "Example")], unknownItems: [upstream]))

        XCTAssertEqual(result.notParsed.last, upstream)
    }

    func testValidatorDetectsCountMismatch() {
        let rule = FilterRule(bundles: ["com.example"], classes: [], executables: [], coreFoundationVersion: nil, otherKeys: [])
        let result = FilterParseResult(pairingKey: "Example", route: "roothide", status: .valid, filter: rule)
        let snapshot = FilterParseSnapshot(
            route: "roothide",
            sourceDirectory: "/dir",
            status: "enumerated",
            parsed: [result],
            notParsed: [],
            counts: FilterParseCounts(valid: 1, notParsed: 99),
            warnings: []
        )

        let validation = FilterParseIntegrationValidator().validate(snapshot: snapshot)
        XCTAssertFalse(validation.allPassed)
        XCTAssertFalse(validation.checks.first { $0.code == "C3B-002" }?.passed ?? true)
    }

    // MARK: - 夹具与桩

    private func makeEngine(reader: PlistDataReading,
                            decoder: PlistDecoding,
                            hide: FilterParsing,
                            less: FilterParsing) -> PluginFilterParseEngine {
        PluginFilterParseEngine(
            reader: reader,
            decoder: decoder,
            rootHideParser: hide,
            rootlessParser: less
        )
    }

    private func makeSnapshot(route: String? = "roothide",
                              records: [PluginPairingRecord],
                              unknownItems: [UnknownItem] = []) -> PluginPairingSnapshot {
        PluginPairingSnapshot(
            route: route,
            sourceDirectory: "/dir",
            status: .enumerated,
            records: records,
            unknownItems: unknownItems,
            counts: PluginPairingCounts(),
            warnings: []
        )
    }

    private func pairedRecord(key: String,
                              dylibPath: String? = nil,
                              plistPath: String? = nil) -> PluginPairingRecord {
        let dylibPath = dylibPath ?? "/dir/\(key).dylib"
        let plistPath = plistPath ?? "/dir/\(key).plist"
        return PluginPairingRecord(
            category: .paired,
            pairing: .paired,
            pairingKey: key,
            dylib: evidence(name: (dylibPath as NSString?)?.lastPathComponent ?? "\(key).dylib", kind: .dylib, path: dylibPath),
            plist: evidence(name: (plistPath as NSString?)?.lastPathComponent ?? "\(key).plist", kind: .plist, path: plistPath),
            basis: .exactFilenameMatch
        )
    }

    private func evidence(name: String, kind: PluginFileKind, path: String?) -> PluginFileEvidence {
        PluginFileEvidence(
            path: path,
            name: name,
            extension: name.components(separatedBy: ".").last,
            kind: kind,
            exists: true,
            readable: true
        )
    }

    private var readSuccess: PlistReadResult {
        PlistReadResult(status: .success, data: Data([0x00]), path: "/dir/Example.plist")
    }

    private var decodeSuccess: PlistDecodeResult {
        PlistDecodeResult(
            status: .success,
            object: PlistDecodedObject(rootObject: ["Filter": ["Bundles": ["com.example"]] as Any], format: .xml),
            errorDescription: nil
        )
    }

    private func validResult(route: String) -> FilterParseResult {
        let rule = FilterRule(bundles: ["com.example"], classes: [], executables: [], coreFoundationVersion: nil, otherKeys: [])
        return FilterParseResult(
            pairingKey: "Example",
            dylibPath: "/dir/Example.dylib",
            plistPath: "/dir/Example.plist",
            route: route,
            status: .valid,
            filter: rule,
            plistFormat: "xml",
            readStatus: "ok"
        )
    }
}

// MARK: - 调用次数桩

private final class StubReader: PlistDataReading {
    var readCallCount = 0
    let canned: PlistReadResult

    init(canned: PlistReadResult) {
        self.canned = canned
    }

    func read(path: String) -> PlistReadResult {
        readCallCount += 1
        return canned
    }
}

private final class StubDecoder: PlistDecoding {
    var decodeCallCount = 0
    let canned: PlistDecodeResult

    init(canned: PlistDecodeResult) {
        self.canned = canned
    }

    func decode(data: Data) -> PlistDecodeResult {
        decodeCallCount += 1
        return canned
    }
}

private final class StubParser: FilterParsing {
    var callCount = 0
    var lastRoute: String?
    var lastPlistFormat: String?
    let canned: FilterParseResult

    init(canned: FilterParseResult) {
        self.canned = canned
    }

    func parse(object: Any?,
               pairingKey: String?,
               dylibPath: String?,
               plistPath: String?,
               route: String?,
               plistFormat: String,
               readStatus: String) -> FilterParseResult {
        callCount += 1
        lastRoute = route
        lastPlistFormat = plistFormat
        // 与真实 Parser 契约一致：pairingKey / dylibPath / plistPath / route 为上游透传，
        // 桩在保留 canned 状态/规则/告警的前提下回显入参，避免硬编码路径掩盖证据透传。
        return FilterParseResult(
            pairingKey: pairingKey ?? canned.pairingKey,
            dylibPath: dylibPath,
            plistPath: plistPath,
            route: route,
            status: canned.status,
            reason: canned.reason,
            filter: canned.filter,
            isTweakManager: canned.isTweakManager,
            skippedFields: canned.skippedFields,
            otherKeys: canned.otherKeys,
            warnings: canned.warnings,
            plistFormat: canned.plistFormat,
            readStatus: canned.readStatus
        )
    }
}
