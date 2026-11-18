//
//  S105FixtureLoader.swift
//  FilterKit Stage 2 — S1-05 原始配对基线夹具加载器（测试目标专用）
//
//  只读解码 `Tests/Fixtures/S1-05/<case>/{environment,metadata}.json`，
//  构造 C1 边界形态的 `PluginInventorySnapshot` 供 C2 Pipeline 回归。
//  不进入正式 App / Core；不重扫目录、不读 plist 内容、不修改夹具文件。
//
//  foreign 边界：`foreign == true` 的外路线/外目录陷阱条目按 C1 契约 PC5
//  排除出配对输入（与 Stage 1 `pairing.js` 第 48 行口径一致），不进入索引。
//

import Foundation
import Models
@testable import Core

/// S1-05 夹具加载器（测试目标内部）。
enum S105FixtureLoader {

    /// 单组夹具：C1 形态清单快照 + 冻结元数据预期。
    struct Case: Equatable {
        let name: String
        let inventory: PluginInventorySnapshot
        let metadata: S105Metadata
    }

    // MARK: - 中性解码形态

    struct EnvUpstream: Codable, Equatable {
        let route: String?
        let sourceDirectory: String?
        let inventoryStatus: String?
    }

    struct EnvItem: Codable, Equatable {
        let name: String
        let kind: String
        let path: String?
        let isSymlink: Bool?
        let symlinkTarget: String?
        let hidden: Bool
        let entryStatus: String
        let foreign: Bool?
    }

    struct EnvInventory: Codable, Equatable {
        let enumerable: Bool?
        let items: [EnvItem]
    }

    struct S105Environment: Codable, Equatable {
        let upstream: EnvUpstream
        let inventory: EnvInventory
    }

    struct ExpectedCounts: Codable, Equatable {
        let paired: Int
        let missingPlist: Int
        let orphanPlist: Int
        let ambiguous: Int
        let uncertain: Int

        enum CodingKeys: String, CodingKey {
            case paired
            case missingPlist = "missing_plist"
            case orphanPlist = "orphan_plist"
            case ambiguous
            case uncertain
        }
    }

    struct S105Expected: Codable, Equatable {
        let route: String?
        let sourceDirectory: String?
        let status: String
        let counts: ExpectedCounts
        let pairedBases: [String]
        let missingBases: [String]
        let orphanNames: [String]
        let ambiguousBases: [String]?
        let uncertainPaths: [String]?
        let dylibSymlinkFlags: [String: Bool]?
    }

    struct S105Metadata: Codable, Equatable {
        let expected: S105Expected
        let expectedWarnings: [String]
        let expectedStatus: String?
    }

    // MARK: - 加载

    static func directoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/S1-05")
    }

    /// 按夹具名加载单组；夹具缺失/解码失败直接抛错，不用 `try?` 掩盖。
    static func load(name: String) throws -> Case {
        let dir = directoryURL().appendingPathComponent(name)
        let envData = try Data(contentsOf: dir.appendingPathComponent("environment.json"))
        let metaData = try Data(contentsOf: dir.appendingPathComponent("metadata.json"))
        let environment = try JSONDecoder().decode(S105Environment.self, from: envData)
        let metadata = try JSONDecoder().decode(S105Metadata.self, from: metaData)

        let items = environment.inventory.items
            .filter { $0.foreign != true }
            .compactMap(evidence(from:))

        let status = EnumerationStatus(rawValue: environment.upstream.inventoryStatus ?? "") ?? .enumerated
        let inventory = PluginInventorySnapshot(
            route: environment.upstream.route,
            sourceDirectory: environment.upstream.sourceDirectory,
            enumeration: EnumerationBlock(status: status),
            items: items
        )
        return Case(name: name, inventory: inventory, metadata: metadata)
    }

    // MARK: - 辅助

    private static func evidence(from item: EnvItem) -> PluginFileEvidence? {
        guard let kind = PluginFileKind(rawValue: item.kind) else { return nil }
        let status = PluginEntryStatus(rawValue: item.entryStatus) ?? .ok
        return PluginFileEvidence(
            path: item.path,
            name: item.name,
            extension: Self.fileExtension(of: item.name),
            kind: kind,
            isSymlink: item.isSymlink,
            symlinkTarget: item.symlinkTarget,
            hidden: item.hidden,
            entryStatus: status
        )
    }

    private static func fileExtension(of name: String) -> String? {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        return String(name[name.index(after: dot)...])
    }
}
