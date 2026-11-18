//
//  PluginPairingRecord.swift
//  FilterKit Core — 单条配对记录（G-C3，契约冻结 §4.3）
//
//  记录单个配对结果：五桶分类 + 既有 `Pairing` 四值（ambiguous/uncertain
//  为 `nil`）+ 两侧条目证据 + 歧义全量候选。候选必须完整保留，不得取
//  `first` 作为任意选择；不确定条目留置对应候选，不判缺失/孤儿。
//  本结构为中间层记录，不组装最终 `Plugin`，不推断 `loaded`。
//

import Foundation
import Models

/// 单条配对记录。
public struct PluginPairingRecord: Codable, Equatable {
    /// 五态分类（封闭集）。
    public var category: PairingCategory
    /// 映射到既有 `Pairing` 四值；ambiguous/uncertain 为 `nil`。
    public var pairing: Pairing?
    /// 配对键（剥离后缀的基名）；空键不产生记录。
    public var pairingKey: String?
    /// dylib 侧证据；按归类按需存在。
    public var dylib: PluginFileEvidence?
    /// plist 侧证据；按归类按需存在。
    public var plist: PluginFileEvidence?
    /// 歧义全量候选（含两侧）；非歧义桶为空数组。
    public var candidates: [PluginFileEvidence]
    /// 不确定原因（uncertain 承载 entryStatus 原始值）；孤儿 plist = `missing_dylib`。
    public var reason: String?
    /// 匹配依据封闭码。
    public var basis: PairingEvidenceBasis
    /// 可选证据块；复用既有 `EvidenceBlock`，不新增自由字符串证据协议。
    public var evidence: EvidenceBlock?
    /// 记录级告警。
    public var warnings: [ReportWarning]

    public init(category: PairingCategory,
                pairing: Pairing? = nil,
                pairingKey: String? = nil,
                dylib: PluginFileEvidence? = nil,
                plist: PluginFileEvidence? = nil,
                candidates: [PluginFileEvidence] = [],
                reason: String? = nil,
                basis: PairingEvidenceBasis,
                evidence: EvidenceBlock? = nil,
                warnings: [ReportWarning] = []) {
        self.category = category
        self.pairing = pairing
        self.pairingKey = pairingKey
        self.dylib = dylib
        self.plist = plist
        self.candidates = candidates
        self.reason = reason
        self.basis = basis
        self.evidence = evidence
        self.warnings = warnings
    }

    private enum CodingKeys: String, CodingKey {
        case category, pairing, pairingKey, dylib, plist, candidates
        case reason, basis, evidence, warnings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        category = try c.decodeIfPresent(PairingCategory.self, forKey: .category) ?? .paired
        pairing = try c.decodeIfPresent(Pairing.self, forKey: .pairing)
        pairingKey = try c.decodeIfPresent(String.self, forKey: .pairingKey)
        dylib = try c.decodeIfPresent(PluginFileEvidence.self, forKey: .dylib)
        plist = try c.decodeIfPresent(PluginFileEvidence.self, forKey: .plist)
        candidates = try c.decodeIfPresent([PluginFileEvidence].self, forKey: .candidates) ?? []
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        basis = try c.decodeIfPresent(PairingEvidenceBasis.self, forKey: .basis) ?? .uncertainAccess
        evidence = try c.decodeIfPresent(EvidenceBlock.self, forKey: .evidence)
        warnings = try c.decodeIfPresent([ReportWarning].self, forKey: .warnings) ?? []
    }
}
