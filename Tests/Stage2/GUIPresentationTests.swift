//
//  GUIPresentationTests.swift
//  FilterKit Stage 2.3 — GUI Foundation Presentation 纯映射单测
//
//  覆盖冻结规格 §11 GUI-01 ～ GUI-08。只核对 Models → 展示模型的映射口径、
//  三态保留、搜索筛选归类与导出接缝往返；不访问文件系统、不触发扫描、
//  不替代真机权限或真实加载证据。
//

import Foundation
import XCTest
@testable import Models
@testable import Core
@testable import AppPresentation

final class GUIPresentationTests: XCTestCase {

    // MARK: - 桩构造器

    private func makePlugin(id: String,
                            name: String,
                            pairing: Pairing = .paired,
                            installed: Bool? = true,
                            configured: Bool = true,
                            status: String = "valid",
                            filter: FilterRule? = FilterRule(bundles: ["com.example.app"]),
                            ownershipDetails: OwnershipDetails? = nil) -> Plugin {
        Plugin(
            pluginID: id,
            name: name,
            version: "1.0.0",
            dylibPath: "/dir/\(id).dylib",
            plistPath: "/dir/\(id).plist",
            pairing: pairing,
            source: .dpkgSileo,
            ownership: Ownership(sourceType: .dpkgSileo, packageID: id,
                                 confidence: .exactRecord, writablePolicy: .readOnly),
            ownershipDetails: ownershipDetails,
            filter: filter,
            installed: installed,
            configured: configured,
            loaded: .unknown,
            validation: ValidationReport(status: status, warnings: ["w:\(id)"]),
            profileId: "roothide-preview",
            evidence: EvidenceBlock(sourceStages: ["enumeration"], evidenceType: "fixture",
                                    evidenceLevel: .partial)
        )
    }

    private func makeEnvelope(plugins: [Plugin],
                              unknowns: [UnknownItem] = [],
                              warnings: [ReportWarning] = []) -> ReportEnvelope {
        ReportEnvelope(
            schemaVersion: "0.1.0",
            generatorVersion: "0.1.0-test",
            profile: ProfileRef(id: "roothide-preview", route: "roothide"),
            environment: JailbreakEnvironment(
                jailbreakType: .roothide,
                profileId: "roothide-preview",
                pathEvidence: PathEvidence()
            ),
            plugins: plugins,
            unknownItems: unknowns,
            warnings: warnings
        )
    }

    // MARK: - GUI-01 空信封

    func testGUI01EmptyEnvelope() {
        let overview = DashboardOverview(envelope: nil)
        XCTAssertEqual(overview.counts.total, 0)
        XCTAssertEqual(overview.counts.paired, 0)
        XCTAssertEqual(overview.counts.missing, 0)
        XCTAssertEqual(overview.counts.parseFailed, 0)
        XCTAssertTrue(overview.environmentRows.allSatisfy { $0.value == "Unknown" })

        let sections = DiagnosticsMapper.sections(nil)
        XCTAssertEqual(sections.count, 7)
        XCTAssertTrue(sections.dropFirst().allSatisfy { $0.isEmpty })
    }

    // MARK: - GUI-02 Dashboard 计数归类

    func testGUI02DashboardCounts() {
        let plugins = [
            makePlugin(id: "p1", name: "Paired Valid", status: "valid"),
            makePlugin(id: "p2", name: "Orphan", pairing: .orphanPlist,
                       configured: false, status: "not_parsed", filter: nil),
            makePlugin(id: "p3", name: "Parse Failed", status: "parse_failed", filter: nil),
            makePlugin(id: "p4", name: "Type Mismatch", status: "type_mismatch", filter: nil),
            makePlugin(id: "p5", name: "Read Failed", status: "read_failed", filter: nil)
        ]
        let overview = DashboardOverview(envelope: makeEnvelope(plugins: plugins))

        XCTAssertEqual(overview.counts.total, 5)
        XCTAssertEqual(overview.counts.paired, 4)
        XCTAssertEqual(overview.counts.missing, 1)
        // not_parsed 不计入 Parse Failed；parse_failed/type_mismatch/read_failed 计入。
        XCTAssertEqual(overview.counts.parseFailed, 3)
    }

    // MARK: - GUI-03 列表搜索

    func testGUI03SearchCaseInsensitive() {
        let plugins = [
            makePlugin(id: "com.alpha.tweak", name: "Alpha Tweak"),
            makePlugin(id: "com.beta.tweak", name: "Beta Helper")
        ]
        let summaries = PluginListMapper.summarize(plugins)

        XCTAssertEqual(PluginListMapper.search(summaries, keyword: "").count, 2)
        XCTAssertEqual(PluginListMapper.search(summaries, keyword: "alpha").count, 1)
        XCTAssertEqual(PluginListMapper.search(summaries, keyword: "BETA").count, 1)
        XCTAssertEqual(PluginListMapper.search(summaries, keyword: "com.alpha").first?.pluginID,
                       "com.alpha.tweak")
        XCTAssertEqual(PluginListMapper.search(summaries, keyword: "zzz").count, 0)
    }

    // MARK: - GUI-04 分段筛选

    func testGUI04SegmentFilter() {
        let plugins = [
            makePlugin(id: "p1", name: "Valid", status: "valid"),
            makePlugin(id: "p2", name: "Orphan", pairing: .orphanPlist,
                       configured: false, status: "not_parsed", filter: nil),
            makePlugin(id: "p3", name: "Broken", status: "parse_failed", filter: nil)
        ]
        let summaries = PluginListMapper.summarize(plugins)

        XCTAssertEqual(PluginListMapper.filter(summaries, segment: .all).count, 3)
        XCTAssertEqual(PluginListMapper.filter(summaries, segment: .paired).count, 2)
        XCTAssertEqual(PluginListMapper.filter(summaries, segment: .issues).count, 2)
    }

    // MARK: - GUI-05 三态标签与 loaded unknown 口径

    func testGUI05ThreeStateLabels() {
        let yes = makePlugin(id: "yes", name: "Yes", installed: true)
        let no = makePlugin(id: "no", name: "No", installed: false)
        let unknown = makePlugin(id: "unknown", name: "Unknown", installed: nil)

        XCTAssertEqual(ReportLabels.installed(yes.installed).text, "Yes")
        XCTAssertEqual(ReportLabels.installed(no.installed).text, "No")
        XCTAssertEqual(ReportLabels.installed(unknown.installed).text, "Unknown")

        let loadedUnknown = ReportLabels.loaded(.unknown)
        XCTAssertEqual(loadedUnknown.text, "Unknown")
        XCTAssertEqual(loadedUnknown.detail, "Runtime state not verified")
        XCTAssertNotEqual(loadedUnknown.text, "Not Loaded")
    }

    // MARK: - GUI-06 详情映射：缺失路径 / 空规则 / 归属明细

    func testGUI06DetailMapping() {
        let plugin = Plugin(
            pluginID: "com.detail.sample",
            name: "Detail Sample",
            dylibPath: nil,
            plistPath: nil,
            pairing: .missingPlist,
            source: .manual,
            ownership: Ownership(sourceType: .manual, confidence: .heuristic),
            ownershipDetails: OwnershipDetails(
                conflicts: ["conflict-a", "conflict-b"],
                notes: ["note-a"]
            ),
            filter: nil,
            installed: nil,
            configured: false,
            loaded: .unknown,
            validation: ValidationReport(status: "not_parsed"),
            profileId: "roothide-preview"
        )
        let model = PluginDetailModel(plugin: plugin)

        let dylibRow = model.fileRows.first { $0.label == "Dynamic Library" }
        XCTAssertEqual(dylibRow?.value, "Unknown")
        let plistRow = model.fileRows.first { $0.label == "Filter Plist" }
        XCTAssertEqual(plistRow?.value, "Unknown")

        let bundlesRow = model.filterRows.first { $0.label == "Bundles" }
        XCTAssertEqual(bundlesRow?.value, "—")

        let conflictsRow = model.ownershipRows.first { $0.label == "Conflicts" }
        XCTAssertEqual(conflictsRow?.value, "conflict-a, conflict-b")
        let notesRow = model.ownershipRows.first { $0.label == "Notes" }
        XCTAssertEqual(notesRow?.value, "note-a")
    }

    // MARK: - GUI-07 诊断分组完整归集

    func testGUI07DiagnosticsCollection() {
        let envelope = makeEnvelope(
            plugins: [makePlugin(id: "p1", name: "One")],
            unknowns: [
                UnknownItem(path: "/dir/a.plist", base: "a.plist", reason: "orphan",
                            sourceStage: "enumeration"),
                UnknownItem(path: "/dir/b.plist", base: "b.plist", reason: "denied",
                            sourceStage: "parsing")
            ],
            warnings: [
                ReportWarning(code: "W-1", message: "first", sourceStage: "builder"),
                ReportWarning(code: "W-2", message: "second", sourceStage: "exporter")
            ]
        )
        let sections = DiagnosticsMapper.sections(envelope)

        let warningSection = sections.first { $0.id == "warnings" }
        XCTAssertEqual(warningSection?.rows.count, 2)
        let unknownSection = sections.first { $0.id == "unknown-items" }
        XCTAssertEqual(unknownSection?.rows.count, 2)
    }

    // MARK: - GUI-08 导出接缝往返

    func testGUI08ExportSeamRoundTrip() throws {
        let envelope = makeEnvelope(
            plugins: [
                makePlugin(id: "p1", name: "One"),
                makePlugin(id: "p2", name: "Two", pairing: .missingDylib,
                           configured: false, status: "read_failed", filter: nil)
            ]
        )

        let data = try ReportExporter().export(envelope)
        XCTAssertFalse(data.isEmpty)

        let decoded = try JSONDecoder().decode(ReportEnvelope.self, from: data)
        XCTAssertEqual(decoded, envelope)
    }
}
