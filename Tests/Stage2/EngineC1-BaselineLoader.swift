//
//  EngineC1-BaselineLoader.swift
//  FilterKit Stage 2 — Engine-C1 S1-06 夹具加载器（测试目标专用）
//
//  只读解码 `Tests/Fixtures/S1-06/<case>/{environment,metadata}.json`，
//  构造 C2 边界形态的 `PluginPairingSnapshot` 与 Decoder 桩输入；不读取真实
//  plist 文件、不访问文件系统路径、不修改夹具文件。加载范式对齐既有
//  `S105FixtureLoader.swift`，测试目标内部，不进 App / Core。
//

import Foundation
import Models
@testable import Core

/// 单条 plist 桩输入（Decoder 桩按路径回灌解码对象）。
public struct EngineC1PlistInput {
    public let base: String
    public let dylibPath: String?
    public let plistPath: String?
    public let format: String
    public let readStatus: String
    public let payloadInvalid: Bool
    public let root: Any?

    public init(base: String,
                dylibPath: String?,
                plistPath: String?,
                format: String,
                readStatus: String,
                payloadInvalid: Bool,
                root: Any?) {
        self.base = base
        self.dylibPath = dylibPath
        self.plistPath = plistPath
        self.format = format
        self.readStatus = readStatus
        self.payloadInvalid = payloadInvalid
        self.root = root
    }
}

/// 加载后的一组夹具：上游快照 + plist 桩输入 + 冻结元数据期望。
public struct EngineC1LoadedFixture {
    public let snapshot: PluginPairingSnapshot
    public let inputs: [EngineC1PlistInput]
    public let metadata: EngineC1Metadata

    public init(snapshot: PluginPairingSnapshot,
                inputs: [EngineC1PlistInput],
                metadata: EngineC1Metadata) {
        self.snapshot = snapshot
        self.inputs = inputs
        self.metadata = metadata
    }
}

// MARK: - 元数据中性解码形态（对齐 `run.js compareResult` 维度）

public struct EngineC1Metadata: Codable, Equatable {
    public struct ExpectedFilter: Codable, Equatable {
        public let bundles: [String]?
        public let classes: [String]?
        public let executables: [String]?
    }

    public struct Expected: Codable, Equatable {
        public let route: String?
        public let sourceDirectory: String?
        public let status: String
        public let counts: [String: Int]
        public let statusByBase: [String: String]
        public let filterByBase: [String: ExpectedFilter]
        public let otherKeysByBase: [String: [String]]
        public let skippedFieldsByBase: [String: [String]]
    }

    public let expected: Expected
    public let expectedWarnings: [String]?
    public let expectedStatus: String?
}

/// S1-06 夹具加载器（测试目标内部）。
public enum EngineC1FixtureLoader {

    public static func directoryURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/S1-06")
    }

    /// 按夹具名加载；夹具缺失 / 解码失败直接抛错，不用 `try?` 掩盖。
    public static func load(name: String) throws -> EngineC1LoadedFixture {
        let dir = directoryURL().appendingPathComponent(name)
        let envData = try Data(contentsOf: dir.appendingPathComponent("environment.json"))
        let metaData = try Data(contentsOf: dir.appendingPathComponent("metadata.json"))
        let environment = try JSONSerialization.jsonObject(with: envData, options: [])
        let metadata = try JSONDecoder().decode(EngineC1Metadata.self, from: metaData)

        guard let env = environment as? [String: Any] else {
            throw EngineC1FixtureError.invalidEnvironment(name)
        }
        let upstream = env["upstream"] as? [String: Any] ?? [:]
        let pairing = env["pairing"] as? [String: Any] ?? [:]
        let pairDicts = pairing["pairs"] as? [[String: Any]] ?? []
        let plistDicts = env["plists"] as? [[String: Any]] ?? []

        let records = pairDicts.map { pair -> PluginPairingRecord in
            let dylib = evidence(path: pair["dylibPath"] as? String, kind: .dylib)
            let plist = evidence(path: pair["plistPath"] as? String, kind: .plist)
            return PluginPairingRecord(
                category: .paired,
                pairing: .paired,
                pairingKey: pair["base"] as? String,
                dylib: dylib,
                plist: plist,
                basis: .exactFilenameMatch
            )
        }

        let inputs: [EngineC1PlistInput] = plistDicts.map { plist in
            let plistPath = plist["plistPath"] as? String
            let pair = pairDicts.first { $0["plistPath"] as? String == plistPath }
            let root = plist["root"] is NSNull ? nil : plist["root"]
            return EngineC1PlistInput(
                base: pair?["base"] as? String ?? (plistPath as NSString?)?.lastPathComponent ?? "Unknown",
                dylibPath: pair?["dylibPath"] as? String,
                plistPath: plistPath,
                format: plist["format"] as? String ?? "unknown",
                readStatus: plist["readStatus"] as? String ?? "ok",
                payloadInvalid: plist["payloadInvalid"] as? Bool ?? false,
                root: root
            )
        }

        let status = pairingStatus(from: upstream["inventoryStatus"] as? String)
        let snapshot = PluginPairingSnapshot(
            route: upstream["route"] as? String,
            sourceDirectory: upstream["sourceDirectory"] as? String,
            status: status,
            records: records,
            unknownItems: [],
            counts: PluginPairingCounts(paired: records.count),
            warnings: []
        )
        return EngineC1LoadedFixture(snapshot: snapshot, inputs: inputs, metadata: metadata)
    }

    // MARK: - 辅助

    private static func evidence(path: String?, kind: PluginFileKind) -> PluginFileEvidence? {
        guard let path else { return nil }
        let name = (path as NSString).lastPathComponent
        return PluginFileEvidence(
            path: path,
            name: name,
            extension: name.components(separatedBy: ".").last,
            kind: kind,
            exists: true,
            readable: true
        )
    }

    private static func pairingStatus(from raw: String?) -> PairingStatus {
        switch raw {
        case "unresolved": return .unresolved
        case "partial": return .partial
        case "enumerated": return .enumerated
        default: return .enumerated
        }
    }
}

enum EngineC1FixtureError: Error {
    case invalidEnvironment(String)
}
