//
//  JBRootStatusClassifier.swift
//  FilterKit Core — JBROOT 候选六态分类（B3 / S1-02）
//
//  优先级严格对齐 Stage 1 resolver.js（顺序不可调换）：
//  1. route = rootless                 → cross_route + rootless_route_not_jbroot
//  2. route = rootful                  → cross_route + rootful_route_not_jbroot
//  3. symlinkState = broken / loop    → resolve_failed + symlink_resolve_failed
//  4. nameValid === false              → rejected_invalid + invalid_container_name
//  5. exists !== true                  → rejected_missing + candidate_missing
//  6. readable !== true                → partial + access_limited
//  7. 其余                             → confirmed
//
//  六态封闭集（契约 D4）：confirmed / partial / cross_route / rejected_invalid /
//  rejected_missing / resolve_failed；`pending` 仅内部初始态，不导出。
//  分类器只依据已给定的校验位与路线事实判定，不访问文件系统，不修改收集语义。
//

import Foundation
import Models

/// 候选六态分类器（纯规则；输入校验位/路线/软链失败标志，输出状态与告警）。
public enum JBRootStatusClassifier {

    /// 契约 D4 六态封闭集（文档化；未知状态原样保留，不在此拒绝）。
    public static let statuses: Set<String> = [
        "confirmed", "partial", "cross_route",
        "rejected_invalid", "rejected_missing", "resolve_failed"
    ]

    /// 裁决结果：六态状态 + 该状态对应的基线告警。
    public struct Classification: Equatable {
        public let status: String
        public let warnings: [ReportWarning]
    }

    /// 按基线优先级分类。
    ///
    /// - Parameters:
    ///   - route: 候选路线（roothide / rootless / rootful / 未知空串）；
    ///   - nameValid: 命名校验三态位（非 roothide 路线为 `nil`）；
    ///   - exists: 存在性事实（`true` 才算存在；`false`/`nil` 按不存在参与裁决）；
    ///   - readable: 可读性事实（`true` 才算可读；`false`/`nil` 按不可读参与裁决）；
    ///   - symlinkFailed: 软链解析是否失败（broken / loop）；
    ///   - sourceStage: 告警归属阶段。
    public static func classify(route: String,
                                nameValid: Bool?,
                                exists: Bool?,
                                readable: Bool?,
                                symlinkFailed: Bool,
                                sourceStage: String) -> Classification {
        switch route {
        case "rootless":
            return Classification(status: "cross_route",
                                  warnings: [warning(code: "rootless_route_not_jbroot", sourceStage: sourceStage)])
        case "rootful":
            return Classification(status: "cross_route",
                                  warnings: [warning(code: "rootful_route_not_jbroot", sourceStage: sourceStage)])
        default:
            break
        }

        if symlinkFailed {
            return Classification(status: "resolve_failed",
                                  warnings: [warning(code: "symlink_resolve_failed", sourceStage: sourceStage)])
        }

        if nameValid == false {
            return Classification(status: "rejected_invalid",
                                  warnings: [warning(code: "invalid_container_name", sourceStage: sourceStage)])
        }

        if exists != true {
            return Classification(status: "rejected_missing",
                                  warnings: [warning(code: "candidate_missing", sourceStage: sourceStage)])
        }

        if readable != true {
            return Classification(status: "partial",
                                  warnings: [warning(code: "access_limited", sourceStage: sourceStage)])
        }

        return Classification(status: "confirmed", warnings: [])
    }

    private static func warning(code: String, sourceStage: String) -> ReportWarning {
        ReportWarning(code: code, message: "", sourceStage: sourceStage)
    }
}
