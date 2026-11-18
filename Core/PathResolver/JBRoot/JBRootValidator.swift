//
//  JBRootValidator.swift
//  FilterKit Core — JBROOT 候选单项校验（B3 / S1-02）
//
//  输入为 B2 收集器产出的候选（顺序、来源、去重、未知告警均由 B2 保留，本层不改）；
//  与候选配对的夹具信号仅用于回填三态校验位事实与软链状态。校验口径对齐 S1-02：
//  - `nameValid`：仅 roothide 路线做命名校验；其余路线留 `nil`（未验证，不填 false）；
//  - `exists` / `structureMatch` / `readable`：信号事实原样保留三态；
//  - `realpath`：软链解析失败（broken / loop）时置 `nil`；realpath 成功不等于可读；
//  - 状态与告警由 `JBRootStatusClassifier` 按基线优先级产出。
//
//  本层不访问真实文件系统，不做目录/软链定位（归 B4），不检查 TweakInject。
//

import Foundation
import Models

/// JBROOT 候选单项校验器：填充五项三态校验位并触发六态分类。
public final class JBRootValidator {

    private let sourceStage: String

    public init(sourceStage: String = "S1-02") {
        self.sourceStage = sourceStage
    }

    /// 校验单个候选。`signal` 为与候选配对的原始夹具信号；缺失时事实位留 `nil`。
    public func validate(candidate: JBRootCandidate, signal: JBRootCandidateSignal?) -> JBRootCandidate {
        let symlinkFailed = Self.isSymlinkFailed(signal?.symlinkState)

        // 命名校验仅对 roothide 路线进行；跨路线/未知路线不反推命名结论。
        let nameValid: Bool? = candidate.route == "roothide"
            ? JBRootNameValidator.isJbrootName(candidate.path)
            : nil

        // 软链失败不产出 realpath；其余情况沿用信号 realpath，不通过 realpath 反推路线或可读性。
        let realpath: String? = symlinkFailed ? nil : signal?.realpath

        let bits = JBRootValidationBits(
            nameValid: nameValid,
            exists: signal?.exists ?? candidate.validation.exists,
            structureMatch: signal?.structureMatch ?? candidate.validation.structureMatch,
            readable: signal?.readable ?? candidate.validation.readable,
            realpath: realpath
        )

        let classification = JBRootStatusClassifier.classify(
            route: candidate.route,
            nameValid: nameValid,
            exists: bits.exists,
            readable: bits.readable,
            symlinkFailed: symlinkFailed,
            sourceStage: sourceStage
        )

        // 保留 B2 已产生的候选告警（未知来源等），追加基线状态告警并去重。
        var warnings = candidate.warnings
        for warning in classification.warnings where !warnings.contains(warning) {
            warnings.append(warning)
        }

        return JBRootCandidate(
            path: candidate.path,
            source: candidate.source,
            route: candidate.route,
            validation: bits,
            status: classification.status,
            warnings: warnings
        )
    }

    /// 软链解析失败口径：broken / loop 视为失败（对齐 resolver.js symlinkState）。
    static func isSymlinkFailed(_ symlinkState: String?) -> Bool {
        symlinkState == "broken" || symlinkState == "loop"
    }
}
