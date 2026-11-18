//
//  ReportBuilder.swift
//  FilterKit Core — Reporting（Stage 2.2-D，D2）
//
//  只读归并：把环境 / 枚举 / 配对 / 解析 / 归属快照组装为公共 `ReportEnvelope`。
//  本层只做既有证据的纯归并，不重新扫描、不重新解析、不补判归属、不回写
//  设备。三层状态 installed / configured / loaded 互不推导：
//  - installed：仅来自 dylib 在位 / 可读证据；
//  - configured：仅来自解析结果 `valid`；
//  - loaded：本阶段恒 `.unknown`，无运行时取证；
//  - permission.decision：恒 `undetermined`。
//  上游阶段整体缺失为 `nil` 时，对应证据留空，不回退补齐。
//

import Foundation
import Models

/// 报告归并输入（只读快照；上游阶段整体缺失为 `nil`）。
public struct ReportBuildInput {
    /// 环境快照（必填；来源 S1-01 / PathResolver）。
    public let environment: JailbreakEnvironment
    /// 枚举清单快照；缺失时 installed 证据留空。
    public let inventory: PluginInventorySnapshot?
    /// 配对清单快照；缺失时配对关系仅由现存路径证据保守推导。
    public let pairing: PluginPairingSnapshot?
    /// 解析快照；缺失时 configured / filter / 解析证据留空。
    public let parsing: FilterParseSnapshot?
    /// 归属结果，键为配对键（回退基名）；未命中归 Builder 使用 `Ownership()` 未知默认。
    public let ownershipByKey: [String: Ownership]
    /// 归属明细，键与 `ownershipByKey` 对齐；未命中为 `nil`。
    public let ownershipDetailsByKey: [String: OwnershipDetails]
    /// 报告 Profile 引用。
    public let profile: ProfileRef

    public init(environment: JailbreakEnvironment,
                inventory: PluginInventorySnapshot? = nil,
                pairing: PluginPairingSnapshot? = nil,
                parsing: FilterParseSnapshot? = nil,
                ownershipByKey: [String: Ownership] = [:],
                ownershipDetailsByKey: [String: OwnershipDetails] = [:],
                profile: ProfileRef) {
        self.environment = environment
        self.inventory = inventory
        self.pairing = pairing
        self.parsing = parsing
        self.ownershipByKey = ownershipByKey
        self.ownershipDetailsByKey = ownershipDetailsByKey
        self.profile = profile
    }
}

/// 报告归并器（纯数据转换；不访问文件系统，不做运行时取证）。
public struct ReportBuilder {
    public init() {}

    /// 按输入快照组装统一信封；不修改上游快照。
    public func build(_ input: ReportBuildInput) -> ReportEnvelope {
        let (entries, seedUnknowns) = mergeEntries(input: input)
        let plugins = entries.map { makePlugin(entry: $0, input: input) }
        let unknowns = collectUnknownItems(input: input, seedUnknowns: seedUnknowns)
        let warnings = mergeWarnings(input: input, entries: entries)

        return ReportEnvelope(
            profile: input.profile,
            environment: input.environment,
            plugins: plugins,
            unknownItems: unknowns,
            warnings: warnings
        )
    }
}

// MARK: - 归并内部结构

extension ReportBuilder {
    /// 单归并条目；键优先配对键，回退文件名基名。
    private struct ReportEntry {
        var key: String
        var base: String
        var inventoryDylib: PluginFileEvidence?
        var inventoryPlist: PluginFileEvidence?
        var record: PluginPairingRecord?
        var result: FilterParseResult?
    }

    /// 归并枚举 / 配对 / 解析三侧条目；歧义、不确定与非插件条目直接进未知归集。
    private func mergeEntries(input: ReportBuildInput) -> ([ReportEntry], [UnknownItem]) {
        var order: [String] = []
        var byKey: [String: ReportEntry] = [:]
        var seedUnknowns: [UnknownItem] = []

        func entry(key: String, base: String) -> ReportEntry {
            if let existing = byKey[key] { return existing }
            let entry = ReportEntry(key: key, base: base)
            byKey[key] = entry
            order.append(key)
            return entry
        }

        // 侧一：枚举清单。
        if let inventory = input.inventory {
            for item in inventory.items {
                switch item.kind {
                case .dylib, .plist:
                    let base = baseName(of: item.name) ?? item.name
                    var entry = entry(key: base, base: base)
                    if item.kind == .dylib { entry.inventoryDylib = item } else { entry.inventoryPlist = item }
                    byKey[entry.key] = entry
                case .directory, .symlink, .other:
                    seedUnknowns.append(UnknownItem(
                        path: item.path,
                        base: baseName(of: item.name),
                        reason: item.kind.rawValue,
                        sourceStage: "stage2.2-c1",
                        detail: ["entryStatus": item.entryStatus.rawValue]
                    ))
                }
            }
        }

        // 侧二：配对记录。ambiguous / uncertain 不并入 Pairing 枚举，留置未知归集。
        if let pairing = input.pairing {
            for record in pairing.records {
                switch record.category {
                case .ambiguous, .uncertain:
                    seedUnknowns.append(UnknownItem(
                        path: record.dylib?.path ?? record.plist?.path,
                        base: record.pairingKey ?? record.dylib?.name ?? record.plist?.name,
                        reason: record.reason ?? record.category.rawValue,
                        sourceStage: "stage2.2-c3",
                        detail: [
                            "basis": record.basis.rawValue,
                            "candidates": String(record.candidates.count)
                        ]
                    ))
                default:
                    let base = record.pairingKey ?? record.dylib?.name ?? record.plist?.name ?? "unknown"
                    var entry = entry(key: record.pairingKey ?? base, base: base)
                    entry.record = record
                    if entry.inventoryDylib == nil, let dylib = record.dylib { entry.inventoryDylib = dylib }
                    if entry.inventoryPlist == nil, let plist = record.plist { entry.inventoryPlist = plist }
                    byKey[entry.key] = entry
                }
            }
        }

        // 侧三：解析结果。`not_parsed` 与未知路线条目不具备进入插件清单的
        // 条件，留置未知归集，不跨路线回填规则或状态。
        if let parsing = input.parsing {
            for result in parsing.parsed {
                if result.status == .notParsed || result.route == "unknown" {
                    seedUnknowns.append(UnknownItem(
                        path: result.dylibPath ?? result.plistPath,
                        base: result.pairingKey ?? lastComponent(of: result.plistPath),
                        reason: result.reason ?? result.status.rawValue,
                        sourceStage: "stage2.2-c3",
                        detail: ["route": result.route ?? "unknown"]
                    ))
                    continue
                }
                let base = result.pairingKey ?? lastComponent(of: result.dylibPath) ?? lastComponent(of: result.plistPath) ?? "unknown"
                var entry = entry(key: result.pairingKey ?? base, base: base)
                entry.result = result
                byKey[entry.key] = entry
            }
        }

        let entries = order.compactMap { byKey[$0] }
        return (entries, seedUnknowns)
    }
}

// MARK: - 插件装配

extension ReportBuilder {
    private func makePlugin(entry: ReportEntry, input: ReportBuildInput) -> Plugin {
        let ownership = input.ownershipByKey[entry.key]
            ?? input.ownershipByKey[entry.base]
            ?? Ownership()
        let details = input.ownershipDetailsByKey[entry.key]
            ?? input.ownershipDetailsByKey[entry.base]

        let result = entry.result
        let record = entry.record

        let dylibPath = record?.dylib?.path ?? result?.dylibPath ?? entry.inventoryDylib?.path
        let plistPath = record?.plist?.path ?? result?.plistPath ?? entry.inventoryPlist?.path

        let name = record?.plist?.name
            ?? record?.dylib?.name
            ?? result.flatMap { lastComponent(of: $0.plistPath) }
            ?? entry.inventoryPlist?.name
            ?? entry.inventoryDylib?.name
            ?? entry.base

        let pairing = resolvePairing(record: record, dylibPath: dylibPath, plistPath: plistPath)

        let installed: Bool?
        if let dylib = record?.dylib ?? entry.inventoryDylib {
            installed = dylib.exists ?? dylib.readable
        } else {
            installed = nil
        }

        let configured = result?.status == .valid
        let filter = result?.status == .valid ? result?.filter : nil

        let validation: ValidationReport
        if let result {
            validation = ValidationReport(
                status: result.status.rawValue,
                warnings: result.warnings.map { "\($0.code): \($0.message)" },
                skippedFields: result.skippedFields.map { "\($0.key):\($0.reason)" }
            )
        } else {
            validation = ValidationReport(status: "not_parsed")
        }

        let pluginID: String
        if let packageID = ownership.packageID, !packageID.isEmpty {
            pluginID = "\(packageID):\(entry.base)"
        } else {
            pluginID = entry.base
        }

        var stages: [String] = ["environment"]
        if input.inventory != nil { stages.append("inventory") }
        if input.pairing != nil { stages.append("pairing") }
        if input.parsing != nil { stages.append("parsing") }

        return Plugin(
            pluginID: pluginID,
            name: name,
            version: nil,
            dylibPath: dylibPath,
            plistPath: plistPath,
            pairing: pairing,
            source: ownership.sourceType,
            ownership: ownership,
            ownershipDetails: details,
            filter: filter,
            isTweakManager: result?.isTweakManager ?? false,
            loadCategory: .unknown,
            installed: installed,
            configured: configured,
            loaded: .unknown,
            validation: validation,
            permission: PermissionState(),
            profileId: input.profile.id,
            evidence: EvidenceBlock(sourceStages: stages, evidenceType: "fixture", evidenceLevel: .partial)
        )
    }

    private func resolvePairing(record: PluginPairingRecord?,
                                dylibPath: String?,
                                plistPath: String?) -> Pairing {
        if let pairing = record?.pairing { return pairing }
        if dylibPath != nil && plistPath != nil { return .paired }
        if dylibPath != nil { return .missingPlist }
        if plistPath != nil { return .orphanPlist }
        return .missingDylib
    }
}

// MARK: - 未知归集与告警

extension ReportBuilder {
    private func collectUnknownItems(input: ReportBuildInput,
                                     seedUnknowns: [UnknownItem]) -> [UnknownItem] {
        var unknowns = seedUnknowns
        if let inventory = input.inventory { unknowns.append(contentsOf: inventory.unknownItems) }
        if let pairing = input.pairing { unknowns.append(contentsOf: pairing.unknownItems) }
        if let parsing = input.parsing { unknowns.append(contentsOf: parsing.notParsed) }
        return unknowns
    }

    private func mergeWarnings(input: ReportBuildInput, entries: [ReportEntry]) -> [ReportWarning] {
        var warnings: [ReportWarning] = []

        if input.inventory == nil {
            warnings.append(ReportWarning(
                code: "inventory_unresolved",
                message: "枚举阶段结果缺失，installed 证据留空",
                sourceStage: "builder"))
        }
        if input.pairing == nil {
            warnings.append(ReportWarning(
                code: "pairing_unresolved",
                message: "配对阶段结果缺失，配对关系由现存路径证据保守推导",
                sourceStage: "builder"))
        }
        if input.parsing == nil {
            warnings.append(ReportWarning(
                code: "parsing_unresolved",
                message: "解析阶段结果缺失，configured / filter 证据留空",
                sourceStage: "builder"))
        }

        if let inventory = input.inventory { warnings.append(contentsOf: inventory.warnings) }
        if let pairing = input.pairing { warnings.append(contentsOf: pairing.warnings) }
        if let parsing = input.parsing { warnings.append(contentsOf: parsing.warnings) }
        for entry in entries {
            warnings.append(contentsOf: conflictWarnings(entry: entry))
            if let record = entry.record { warnings.append(contentsOf: record.warnings) }
            if let result = entry.result { warnings.append(contentsOf: result.warnings) }
        }

        return Self.dedup(warnings)
    }

    /// 归并冲突：配对侧与解析侧路径证据不一致时不强行合并，保留两侧并追加告警。
    private func conflictWarnings(entry: ReportEntry) -> [ReportWarning] {
        let recordDylib = entry.record?.dylib?.path
        let recordPlist = entry.record?.plist?.path
        let resultDylib = entry.result?.dylibPath
        let resultPlist = entry.result?.plistPath
        var mismatches: [String] = []
        if let recordDylib, let resultDylib, recordDylib != resultDylib { mismatches.append("dylib") }
        if let recordPlist, let resultPlist, recordPlist != resultPlist { mismatches.append("plist") }
        guard !mismatches.isEmpty else { return [] }
        return [ReportWarning(
            code: "pairing_ambiguous",
            message: "归并路径不一致（\(mismatches.joined(separator: ","))）：\(entry.key)",
            sourceStage: "builder")]
    }

    /// 告警去重键：code + message + sourceStage；保留首次出现顺序。
    private static func dedup(_ warnings: [ReportWarning]) -> [ReportWarning] {
        var seen = Set<String>()
        return warnings.filter { warning in
            let key = [warning.code, warning.message, warning.sourceStage].joined(separator: "\u{1F}")
            return seen.insert(key).inserted
        }
    }

    /// 路径末段；Swift `String` 不暴露 `lastPathComponent`，经 `NSString` 取值。
    private func lastComponent(of path: String?) -> String? {
        guard let path else { return nil }
        return (path as NSString).lastPathComponent
    }

    private func baseName(of name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        if let dot = name.lastIndex(of: ".") {
            return String(name[..<dot])
        }
        return name
    }
}
