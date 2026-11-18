//
//  PluginPairingIntegrationTests.swift
//  FilterKit Stage 2 — C2-C C1→C2 集成专项测试（集成契约 §3）
//
//  A 输入转换 / B 状态与告警传递 / C 配对行为集成 / D 稳定性与隔离。
//  全部离线合成快照，不访问真实文件系统，不读取 plist 内容，不实例化 Adapter。
//

import Foundation
import XCTest
@testable import Models
@testable import Core

final class PluginPairingIntegrationTests: XCTestCase {

    private let pipeline = PluginPairingPipeline()
    private let validator = PluginPairingIntegrationValidator()

    // MARK: - A. 输入转换

    func testA01OnlyDylibPassedToInput() {
        let inv = inventory(items: [evidence(name: "A.dylib", kind: .dylib)])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files.count, 1)
        XCTAssertEqual(input.files.first?.kind, .dylib)
    }

    func testA02OnlyPlistPassedToInput() {
        let inv = inventory(items: [evidence(name: "A.plist", kind: .plist)])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files.count, 1)
        XCTAssertEqual(input.files.first?.kind, .plist)
    }

    func testA03MixedFilesPassed() {
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib),
            evidence(name: "A.plist", kind: .plist),
            evidence(name: "B.dylib", kind: .dylib)
        ])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files.count, 3)
    }

    func testA04DirectoryExcludedFromInput() {
        let inv = inventory(items: [
            evidence(name: "Classes", kind: .directory),
            evidence(name: "A.dylib", kind: .dylib)
        ])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files.map(\.kind), [.dylib])
    }

    func testA05SymlinkExcludedFromInput() {
        let inv = inventory(items: [
            evidence(name: "Link.dylib", kind: .symlink),
            evidence(name: "A.plist", kind: .plist)
        ])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files.map(\.kind), [.plist])
    }

    func testA06OtherKindExcludedFromInput() {
        let inv = inventory(items: [
            evidence(name: "Notes.txt", kind: .other),
            evidence(name: "Tweak.deb", kind: .other)
        ])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files, [])
    }

    func testA07OriginalEvidenceFieldsUnchanged() {
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib, status: .accessDenied, readable: nil),
            evidence(name: "A.plist", kind: .plist, readable: true)
        ])
        let input = PluginPairingInputAdapter.makeInput(from: inv)

        XCTAssertEqual(input.files, inv.items.filter { $0.kind == .dylib || $0.kind == .plist })
    }

    func testA08EmptyDirectoryHandled() {
        let inv = inventory(items: [])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.counts.total, 0)
        XCTAssertEqual(snapshot.status, .enumerated)
    }

    // MARK: - B. 状态与告警传递

    func testB09EnumeratedTransitionsNormally() {
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib),
            evidence(name: "A.plist", kind: .plist)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.status, .enumerated)
        XCTAssertEqual(snapshot.records.count, 1)
    }

    func testB10PartialRetainsAvailableEvidence() {
        let inv = inventory(
            items: [
                evidence(name: "A.dylib", kind: .dylib),
                evidence(name: "A.plist", kind: .plist)
            ],
            status: .partial
        )
        let input = PluginPairingInputAdapter.makeInput(from: inv)
        let snapshot = pipeline.execute(inventory: inv)
        let result = validator.validate(baseline: inv, after: inv, input: input, snapshot: snapshot)

        XCTAssertEqual(snapshot.status, .partial)
        XCTAssertFalse(snapshot.records.isEmpty)
        XCTAssertTrue(result.checks.first { $0.code == "INT-C2-010" }?.passed == true)
    }

    func testB11EnumerationFailedShortCircuits() {
        let inv = inventory(
            items: [evidence(name: "A.dylib", kind: .dylib)],
            status: .enumerationFailed
        )
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.status, .enumerationFailed)
        XCTAssertEqual(snapshot.records, [])
        XCTAssertEqual(snapshot.counts.total, 0)
        XCTAssertTrue(snapshot.warnings.contains { $0.code == "inventory_unresolved" })
    }

    func testB12UnresolvedShortCircuits() {
        let inv = inventory(
            items: [evidence(name: "A.dylib", kind: .dylib)],
            dir: nil,
            status: .unresolved
        )
        let input = PluginPairingInputAdapter.makeInput(from: inv)
        let snapshot = pipeline.execute(inventory: inv)
        let result = validator.validate(baseline: inv, after: inv, input: input, snapshot: snapshot)

        XCTAssertEqual(snapshot.status, .unresolved)
        XCTAssertEqual(snapshot.records, [])
        XCTAssertTrue(result.checks.first { $0.code == "INT-C2-009" }?.passed == true)
    }

    func testB13UnknownItemsNotLost() {
        let unknown = UnknownItem(path: nil, base: "Notes.txt", reason: "other_ext", sourceStage: "stage2.2-c1")
        let inv = inventory(items: [evidence(name: "A.dylib", kind: .dylib)], unknown: [unknown])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertTrue(snapshot.unknownItems.contains(unknown))
    }

    func testB14WarningsNotLost() {
        let warning = ReportWarning(code: "partial_enumeration", message: "部分枚举", sourceStage: "stage2.2-c1")
        let inv = inventory(items: [evidence(name: "A.dylib", kind: .dylib)], warnings: [warning])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertTrue(snapshot.warnings.contains(warning))
    }

    func testB15AddedWarningDoesNotOverwriteExisting() {
        let existing = ReportWarning(code: "partial_enumeration", message: "部分枚举", sourceStage: "stage2.2-c1")
        let inv = inventory(
            items: [evidence(name: "Locked.dylib", kind: .dylib, status: .accessDenied)],
            warnings: [existing]
        )
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertTrue(snapshot.warnings.contains(existing))
        XCTAssertTrue(snapshot.warnings.contains { $0.code == "partial_pairing" })
    }

    // MARK: - C. 配对行为集成

    func testC16SinglePairing() {
        let inv = inventory(items: [
            evidence(name: "Alpha.dylib", kind: .dylib),
            evidence(name: "Alpha.plist", kind: .plist)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.records.first?.category, .paired)
        XCTAssertEqual(snapshot.records.first?.pairing, .paired)
    }

    func testC17MissingPlist() {
        let inv = inventory(items: [evidence(name: "Only.dylib", kind: .dylib)])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.records.first?.category, .missingPlist)
        XCTAssertEqual(snapshot.records.first?.pairing, .missingPlist)
    }

    func testC18OrphanPlist() {
        let inv = inventory(items: [evidence(name: "Lone.plist", kind: .plist)])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.records.first?.category, .orphanPlist)
        XCTAssertEqual(snapshot.records.first?.reason, "missing_dylib")
    }

    func testC19AmbiguousMultipleDylibs() {
        let inv = inventory(items: [
            evidence(name: "Case.dylib", kind: .dylib, path: "/a/Case.dylib"),
            evidence(name: "Case.dylib", kind: .dylib, path: "/b/Case.dylib"),
            evidence(name: "Case.plist", kind: .plist)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        let record = snapshot.records.first
        XCTAssertEqual(record?.category, .ambiguous)
        XCTAssertEqual(record?.candidates.count, 3)
        XCTAssertNil(record?.pairing)
    }

    func testC20AmbiguousMultiplePlists() {
        let inv = inventory(items: [
            evidence(name: "Case.dylib", kind: .dylib),
            evidence(name: "Case.plist", kind: .plist, path: "/a/Case.plist"),
            evidence(name: "Case.plist", kind: .plist, path: "/b/Case.plist")
        ])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.records.first?.category, .ambiguous)
        XCTAssertEqual(snapshot.records.first?.candidates.count, 3)
    }

    func testC21RestrictedEntryUncertain() {
        let inv = inventory(items: [
            evidence(name: "Locked.dylib", kind: .dylib, status: .readFailed),
            evidence(name: "Locked.plist", kind: .plist)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        let record = snapshot.records.first
        XCTAssertEqual(record?.category, .uncertain)
        XCTAssertEqual(record?.reason, "read_failed")
        XCTAssertNil(record?.pairing)
    }

    func testC22ReadableNilWithOkStatusPaired() {
        let dylib = PluginFileEvidence(
            name: "A.dylib", extension: "dylib", kind: .dylib,
            readable: nil, entryStatus: .ok
        )
        let plist = PluginFileEvidence(
            name: "A.plist", extension: "plist", kind: .plist,
            readable: nil, entryStatus: .ok
        )
        let snapshot = pipeline.execute(inventory: inventory(items: [dylib, plist]))

        XCTAssertEqual(snapshot.records.first?.category, .paired)
    }

    func testC23CountsMutex() {
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib),
            evidence(name: "A.plist", kind: .plist),
            evidence(name: "B.dylib", kind: .dylib),
            evidence(name: "C.plist", kind: .plist)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.counts.total, snapshot.records.count)
        let sum = snapshot.counts.paired + snapshot.counts.missingPlist
            + snapshot.counts.orphanPlist + snapshot.counts.ambiguous
            + snapshot.counts.uncertain
        XCTAssertEqual(sum, snapshot.records.count)
    }

    func testC24PairingFourValueCompatibility() {
        let inv = inventory(items: [
            evidence(name: "P.dylib", kind: .dylib),
            evidence(name: "P.plist", kind: .plist),
            evidence(name: "M.dylib", kind: .dylib),
            evidence(name: "O.plist", kind: .plist)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        let byKey = Dictionary(uniqueKeysWithValues: snapshot.records.map { ($0.pairingKey ?? "", $0) })
        XCTAssertEqual(byKey["P"]?.pairing, .paired)
        XCTAssertEqual(byKey["M"]?.pairing, .missingPlist)
        XCTAssertEqual(byKey["O"]?.pairing, .orphanPlist)
    }

    // MARK: - D. 稳定性与隔离

    func testD25ShuffledInputOrderStable() {
        let items = [
            evidence(name: "Alpha.dylib", kind: .dylib),
            evidence(name: "Alpha.plist", kind: .plist),
            evidence(name: "Beta.dylib", kind: .dylib),
            evidence(name: "Gamma.plist", kind: .plist)
        ]
        let first = pipeline.execute(inventory: inventory(items: items))
        let second = pipeline.execute(inventory: inventory(items: items.reversed()))

        XCTAssertEqual(first.records, second.records)
    }

    func testD26RepeatedRunsDeterministic() {
        let inv = inventory(items: [
            evidence(name: "Case.dylib", kind: .dylib),
            evidence(name: "Case.plist", kind: .plist),
            evidence(name: "Case.plist", kind: .plist, path: "/b/Case.plist")
        ])
        let baseline = pipeline.execute(inventory: inv)
        for _ in 0..<100 {
            XCTAssertEqual(pipeline.execute(inventory: inv).records, baseline.records)
        }
        let second = pipeline.execute(inventory: inv)
        let result = validator.validate(
            baseline: inv, after: inv,
            input: PluginPairingInputAdapter.makeInput(from: inv),
            snapshot: baseline, secondSnapshot: second
        )
        XCTAssertTrue(result.checks.first { $0.code == "INT-C2-013" }?.passed == true)
    }

    func testD27InputSnapshotNotMutated() {
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib),
            evidence(name: "A.plist", kind: .plist)
        ])
        let before = inv
        _ = pipeline.execute(inventory: inv)

        XCTAssertEqual(inv, before)
    }

    func testD28RootHideRouteIsolation() {
        let inv = inventory(
            items: [evidence(name: "A.dylib", kind: .dylib)],
            route: "roothide"
        )
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.route, "roothide")
        XCTAssertEqual(PluginPairingInputAdapter.makeInput(from: inv).route, "roothide")
    }

    func testD29RootlessRouteIsolation() {
        let inv = inventory(
            items: [evidence(name: "A.dylib", kind: .dylib)],
            route: "rootless"
        )
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.route, "rootless")
        XCTAssertNotEqual(snapshot.route, "roothide")
    }

    func testD30DoesNotReadPlistContent() {
        // 配对只依赖文件名/类型/条目状态；证据内无内容解析位，快照不由可读内容推导。
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib, readable: nil),
            evidence(name: "A.plist", kind: .plist, readable: nil)
        ])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.records.first?.category, .paired)
    }

    func testD31DoesNotAccessRealFilesystem() {
        // 离线内存快照构造；路径仅作为身份字符串保留，不发生目录解析。
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib, path: "/var/containers/Bundle/Application/.jbroot-X/usr/lib/TweakInject/A.dylib"),
            evidence(name: "A.plist", kind: .plist, path: "/var/containers/Bundle/Application/.jbroot-X/usr/lib/TweakInject/A.plist")
        ])
        let snapshot = pipeline.execute(inventory: inv)

        XCTAssertEqual(snapshot.sourceDirectory, inv.sourceDirectory)
        XCTAssertEqual(snapshot.records.count, 1)
    }

    func testD32OriginalDataNotModified() {
        let inv = inventory(items: [
            evidence(name: "A.dylib", kind: .dylib, status: .accessDenied),
            evidence(name: "A.plist", kind: .plist)
        ])
        let before = inv
        let inputBefore = PluginPairingInputAdapter.makeInput(from: inv)

        _ = pipeline.execute(inventory: inv)

        let inputAfter = PluginPairingInputAdapter.makeInput(from: inv)
        XCTAssertEqual(inv, before)
        XCTAssertEqual(inputBefore, inputAfter)
    }

    // MARK: - 辅助

    private func inventory(
        items: [PluginFileEvidence],
        dir: String? = "/var/containers/Bundle/Application/.jbroot-X/usr/lib/TweakInject/",
        status: EnumerationStatus = .enumerated,
        route: String? = "roothide",
        unknown: [UnknownItem] = [],
        warnings: [ReportWarning] = []
    ) -> PluginInventorySnapshot {
        PluginInventorySnapshot(
            route: route,
            sourceDirectory: dir,
            enumeration: EnumerationBlock(status: status),
            items: items,
            unknownItems: unknown,
            warnings: warnings
        )
    }

    private func evidence(
        name: String,
        kind: PluginFileKind,
        status: PluginEntryStatus = .ok,
        path: String? = nil,
        readable: Bool? = nil
    ) -> PluginFileEvidence {
        PluginFileEvidence(
            path: path,
            name: name,
            extension: kind == .dylib ? "dylib" : kind == .plist ? "plist" : nil,
            kind: kind,
            readable: readable,
            entryStatus: status
        )
    }
}
