//
//  JBRootResolver.swift
//  FilterKit Core — JBROOT 校验裁决编排（B3 / S1-02）
//
//  串联三段职责（边界沿用 B2/B3 分工，不改收集语义）：
//  1. B2 `JBRootCandidateCollector`：候选归集（规范化/路线/顺序/去重/未知告警）；
//  2. B3 `JBRootValidator`：回填五项三态校验位、六态状态与状态告警；
//  3. B3 `JBRootDecisionResolver`：多候选最终裁决。
//
//  本编排器不访问真实文件系统，不定位目录/软链（B4），不检查 TweakInject，
//  不装配 Adapter/Pipeline（归 B5）。
//

import Foundation
import Models

/// JBROOT 校验裁决编排入口：快照 → 候选集合 → 校验分类 → 最终裁决。
public final class JBRootResolver {

    private let collector: JBRootCandidateCollector
    private let validator: JBRootValidator
    private let decisionResolver: JBRootDecisionResolver
    private let sourceStage: String

    public init(collector: JBRootCandidateCollector = JBRootCandidateCollector(),
                validator: JBRootValidator = JBRootValidator(),
                decisionResolver: JBRootDecisionResolver = JBRootDecisionResolver(),
                sourceStage: String = "S1-02") {
        self.collector = collector
        self.validator = validator
        self.decisionResolver = decisionResolver
        self.sourceStage = sourceStage
    }

    /// 对快照执行完整校验裁决流程。
    public func resolve(_ snapshot: JBRootCandidateSnapshot) -> JBRootResolutionResult {
        let collected = collector.collect(snapshot)

        // 以「规范化路径 + 来源」为键配对原始信号；B2 规范化/去重规则保持不变。
        var signalByKey: [String: JBRootCandidateSignal] = [:]
        for signal in snapshot.signals.candidates {
            guard let path = JBRootCandidateCollector.normalizeLexical(signal.root) else { continue }
            let source = signal.source?.trimmingCharacters(in: .whitespaces) ?? ""
            signalByKey[Self.pairKey(path: path, source: source)] = signal
        }

        let validated = collected.candidates.map { candidate in
            let signal = signalByKey[Self.pairKey(path: candidate.path, source: candidate.source)]
            return validator.validate(candidate: candidate, signal: signal)
        }

        var result = decisionResolver.resolve(candidates: validated)

        // 合并 B2 收集层顶层告警（未知来源/重复剔除/非法路径等），与裁决告警去重。
        for warning in collected.warnings where !result.warnings.contains(warning) {
            result.warnings.append(warning)
        }

        return result
    }

    private static func pairKey(path: String, source: String) -> String {
        "\(path)\u{1}\(source)"
    }
}
