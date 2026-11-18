//
//  JBRootDecisionResolver.swift
//  FilterKit Core — JBROOT 多候选最终裁决（B3 / S1-02）
//
//  裁决优先级严格对齐 Stage 1 resolver.js `resolvePaths`（不可调换，不静默选边）：
//  1. roothide 有效候选 > 1 个  → outcome `ambiguous` + `multiple_candidates`，不选边；
//  2. roothide 有效候选 = 1 个 → 取该候选：`jbroot/jbrand/realpath/selectedSource`，
//     outcome 为 `resolved`（confirmed）或 `partial`；
//  3. 存在 `resolve_failed`    → outcome `resolve_failed`；
//  4. 仅有跨路线候选且无 roothide 候选 → outcome `cross_route_only`；
//  5. 候选为空                 → outcome `no_candidate` + `no_jbroot_candidate`；
//  6. 其余                     → outcome `no_candidate`。
//
//  有效（rhEligible）口径：route = roothide 且状态不在
//  `rejected_invalid / rejected_missing / resolve_failed`。
//  候选状态与最终决策分离：单候选 confirmed 不代表多候选可唯一确认。
//

import Foundation
import Models

/// 多候选裁决结果（对齐 S1-02 基线输出；不新增公共领域枚举，字段语义以基线为准）。
public struct JBRootResolutionResult: Equatable {
    /// 选中 JBROOT 路径；未唯一确认时为 `nil`。
    public var jbroot: String?
    /// 选中候选的 jbrand（大写 16 位后缀）；未选中时为 `nil`。
    public var jbrand: String?
    /// 选中候选的 realpath；未选中或软链失败时为 `nil`。
    public var realpath: String?
    /// 是否存在多个有效候选导致歧义。
    public var ambiguous: Bool
    /// 最终裁决结果：resolved / partial / ambiguous / resolve_failed / cross_route_only / no_candidate。
    public var outcome: String
    /// 选中候选来源（原始来源串）；未选中时为 `nil`。
    public var selectedSource: String?
    /// 候选总数（含被拒绝/跨路线/失败候选，证据不丢弃）。
    public var candidateCount: Int
    /// 全部经校验分类后的候选（证据与告警完整保留）。
    public var candidates: [JBRootCandidate]
    /// 顶层告警（按 code+message 去重合并）。
    public var warnings: [ReportWarning]

    public init(jbroot: String? = nil,
                jbrand: String? = nil,
                realpath: String? = nil,
                ambiguous: Bool = false,
                outcome: String,
                selectedSource: String? = nil,
                candidateCount: Int = 0,
                candidates: [JBRootCandidate] = [],
                warnings: [ReportWarning] = []) {
        self.jbroot = jbroot
        self.jbrand = jbrand
        self.realpath = realpath
        self.ambiguous = ambiguous
        self.outcome = outcome
        self.selectedSource = selectedSource
        self.candidateCount = candidateCount
        self.candidates = candidates
        self.warnings = warnings
    }
}

/// JBROOT 多候选裁决器。
public final class JBRootDecisionResolver {

    /// 不属于 roothide 有效候选的拒绝/失败状态。
    private static let ineligibleStatuses: Set<String> = [
        "rejected_invalid", "rejected_missing", "resolve_failed"
    ]

    private let sourceStage: String

    public init(sourceStage: String = "S1-02") {
        self.sourceStage = sourceStage
    }

    public func resolve(candidates: [JBRootCandidate]) -> JBRootResolutionResult {
        let rhEligible = candidates.filter { candidate in
            candidate.route == "roothide"
                && !Self.ineligibleStatuses.contains(candidate.status ?? "")
        }
        let crossRoute = candidates.filter {
            $0.route == "rootless" || $0.route == "rootful"
        }
        let hasRoothideCandidate = candidates.contains { $0.route == "roothide" }

        // 顶层告警：合并全部候选告警（去重）。
        var warnings: [ReportWarning] = []
        for candidate in candidates {
            for warning in candidate.warnings where !warnings.contains(warning) {
                warnings.append(warning)
            }
        }

        // 1. 多个 roothide 有效候选：歧义，不静默选边。
        if rhEligible.count > 1 {
            appendWarning(&warnings, code: "multiple_candidates")
            return JBRootResolutionResult(
                ambiguous: true,
                outcome: "ambiguous",
                candidateCount: candidates.count,
                candidates: candidates,
                warnings: warnings
            )
        }

        // 2. 唯一 roothide 有效候选：确认或部分证据。
        if rhEligible.count == 1 {
            let selected = rhEligible[0]
            let outcome = selected.status == "confirmed" ? "resolved" : "partial"
            return JBRootResolutionResult(
                jbroot: selected.path,
                jbrand: JBRootNameValidator.parseJbrand(selected.path),
                realpath: selected.validation.realpath,
                ambiguous: false,
                outcome: outcome,
                selectedSource: selected.source,
                candidateCount: candidates.count,
                candidates: candidates,
                warnings: warnings
            )
        }

        // 3. 存在软链解析失败候选。
        if candidates.contains(where: { $0.status == "resolve_failed" }) {
            return JBRootResolutionResult(
                ambiguous: false,
                outcome: "resolve_failed",
                candidateCount: candidates.count,
                candidates: candidates,
                warnings: warnings
            )
        }

        // 4. 仅跨路线候选、无任何 roothide 候选。
        if !crossRoute.isEmpty && !hasRoothideCandidate {
            return JBRootResolutionResult(
                ambiguous: false,
                outcome: "cross_route_only",
                candidateCount: candidates.count,
                candidates: candidates,
                warnings: warnings
            )
        }

        // 5. 候选为空。
        if candidates.isEmpty {
            appendWarning(&warnings, code: "no_jbroot_candidate")
            return JBRootResolutionResult(
                ambiguous: false,
                outcome: "no_candidate",
                candidateCount: 0,
                candidates: candidates,
                warnings: warnings
            )
        }

        // 6. 其余情形（如 roothide 候选全部被拒绝）：无候选确认。
        return JBRootResolutionResult(
            ambiguous: false,
            outcome: "no_candidate",
            candidateCount: candidates.count,
            candidates: candidates,
            warnings: warnings
        )
    }

    private func appendWarning(_ warnings: inout [ReportWarning], code: String) {
        let warning = ReportWarning(code: code, message: "", sourceStage: sourceStage)
        guard !warnings.contains(warning) else { return }
        warnings.append(warning)
    }
}
