//
//  JBRootCandidateCollector.swift
//  FilterKit Core — JBROOT 候选收集（B2 / S1-02）
//
//  职责边界（契约冻结 §8、B 子规格 §9 B2 行）：
//  - 只做候选归集：词法规范化、来源/路线归属、顺序保留、同路径多来源保留、
//    精确重复去重、未知来源告警；
//  - 不做命名/存在/结构/可读/realpath 校验裁决，不填六态 status，不选择最终
//    JBROOT；校验与裁决归 B3。
//
//  规则对齐 Stage 1 resolver.js 的收集口径：
//  - 已知来源：api / scan / bootstrap / rootless / rootful（D7）；
//  - 路线映射：rootless→rootless、rootful→rootful，其余已知来源→roothide；
//    未知来源不反推路线，route 保守留空并附未知告警（D5）；
//  - 词法规范化纯字符串处理：折叠重复分隔符、解析 `.`/`..`、去尾斜杠，
//    不访问文件系统，不代表路径已存在或可解析。
//

import Foundation
import Models

/// B2 候选收集结果：候选集合 + 顶层告警；不含最终裁决结论。
public struct JBRootCandidateCollectionResult: Equatable {
    public var candidates: [JBRootCandidate]
    public var warnings: [ReportWarning]

    public var candidateCount: Int { candidates.count }

    public init(candidates: [JBRootCandidate] = [], warnings: [ReportWarning] = []) {
        self.candidates = candidates
        self.warnings = warnings
    }
}

public final class JBRootCandidateCollector {

    /// 契约 D7 已知来源封闭集（文档化，非强枚举；未知值原样保留）。
    public static let knownSources: Set<String> = ["api", "scan", "bootstrap", "rootless", "rootful"]

    private let sourceStage: String

    public init(sourceStage: String = "S1-02") {
        self.sourceStage = sourceStage
    }

    // MARK: - 收集编排

    public func collect(_ snapshot: JBRootCandidateSnapshot) -> JBRootCandidateCollectionResult {
        var candidates: [JBRootCandidate] = []
        var warnings: [ReportWarning] = []
        var seenKeys = Set<String>()

        for signal in snapshot.signals.candidates {
            let rawSource = signal.source?.trimmingCharacters(in: .whitespaces)
            let normalizedPath = Self.normalizeLexical(signal.root)

            guard let path = normalizedPath else {
                appendWarning(&warnings, code: "candidate_path_invalid",
                              message: signal.root ?? "")
                continue
            }

            let source = rawSource ?? ""
            let knownSource = Self.knownSources.contains(source)
            let route = Self.route(ofSource: source, known: knownSource)

            // 精确重复（同规范化路径 + 同来源）去重：先判重，避免重复条目再产生来源告警。
            let dedupKey = "\(path)\u{1}\(source)"
            guard !seenKeys.contains(dedupKey) else {
                appendWarning(&warnings, code: "duplicate_candidate_removed",
                              message: path)
                continue
            }
            seenKeys.insert(dedupKey)

            var candidateWarnings: [ReportWarning] = []
            if !knownSource {
                let warning = ReportWarning(code: "unknown_candidate_source",
                                            message: source,
                                            sourceStage: sourceStage)
                candidateWarnings.append(warning)
                appendWarning(&warnings, warning)
            }

            let validation = JBRootValidationBits(
                nameValid: nil, // B3 命名校验；B2 未验证，留 nil
                exists: signal.exists,
                structureMatch: signal.structureMatch,
                readable: signal.readable,
                realpath: signal.realpath
            )

            let candidate = JBRootCandidate(
                path: path,
                source: source,
                route: route,
                validation: validation,
                status: nil, // B3 裁决六态；B2 不导出 pending/confirmed
                warnings: candidateWarnings
            )
            candidates.append(candidate)
        }

        return JBRootCandidateCollectionResult(candidates: candidates, warnings: warnings)
    }

    // MARK: - 路线与规范化（纯词法/映射，无文件系统访问）

    /// 来源 → 路线归属。已知来源按基线映射；未知来源不反推，route 留空串保守值。
    static func route(ofSource source: String, known: Bool) -> String {
        guard known else { return "" }
        switch source {
        case "rootless": return "rootless"
        case "rootful": return "rootful"
        default: return "roothide"
        }
    }

    /// 词法规范化（对齐 resolver.js normalizeLexical）：
    /// 折叠重复分隔符、解析 `.`/`..`（超出根停在根，不越界）、去尾斜杠；
    /// 空串/非字符串返回 `nil`；纯根返回 `/`。
    public static func normalizeLexical(_ pathStr: String?) -> String? {
        guard let pathStr, !pathStr.isEmpty else { return nil }
        var parts: [String] = []
        for seg in pathStr.split(separator: "/", omittingEmptySubsequences: false) {
            let segment = String(seg)
            if segment.isEmpty || segment == "." { continue }
            if segment == ".." {
                if !parts.isEmpty { parts.removeLast() }
                continue
            }
            parts.append(segment)
        }
        let out = "/" + parts.joined(separator: "/")
        return out == "/" ? "/" : out
    }

    // MARK: - 告警辅助

    private func appendWarning(_ warnings: inout [ReportWarning], code: String, message: String) {
        appendWarning(&warnings, ReportWarning(code: code, message: message, sourceStage: sourceStage))
    }

    private func appendWarning(_ warnings: inout [ReportWarning], _ warning: ReportWarning) {
        guard !warnings.contains(where: { $0.code == warning.code && $0.message == warning.message }) else {
            return
        }
        warnings.append(warning)
    }
}
