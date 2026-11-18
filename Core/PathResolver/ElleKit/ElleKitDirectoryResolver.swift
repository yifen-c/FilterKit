//
//  ElleKitDirectoryResolver.swift
//  FilterKit Core — ElleKit 目录定位编排（B4 / S1-03）
//
//  串联：路线+jbroot 路径推导 → TweakInject 目录校验 → DynamicLibraries 软链检查 → 裁决。
//  不重扫 JBROOT 候选、不重复 B3 裁决；上游路线与 jbroot 由快照（B5 接 B3 结果）提供。
//
//  裁决优先级对齐 resolver.js `resolveDirectory`（顺序不可调换）：
//  1. 路径无法推导 → `unresolved`；
//  2. 目录不存在 → `not_found`；
//  3. 软链 resolved 但目标不符 → `structure_conflict`；
//  4. rootful 路线 → `rootful_diagnostic`（仅诊断，不进可执行 Profile）；
//  5. 目录 confirmed 且软链 resolved 且目标匹配 → `resolved`；
//  6. 其余 → `partial`。
//
//  本编排器不访问真实文件系统，不枚举 dylib，不装配 Adapter/Pipeline（归 B5）。
//

import Foundation
import Models

/// ElleKit 目录定位编排入口：快照 → 目录/软链证据 → 裁决结果。
public final class ElleKitDirectoryResolver {

    private let validator: ElleKitDirectoryValidator
    private let inspector: ElleKitSymlinkInspector
    private let sourceStage: String

    public init(validator: ElleKitDirectoryValidator = ElleKitDirectoryValidator(),
                inspector: ElleKitSymlinkInspector = ElleKitSymlinkInspector(),
                sourceStage: String = "S1-03") {
        self.validator = validator
        self.inspector = inspector
        self.sourceStage = sourceStage
    }

    /// 对快照执行目录定位与软链检查。
    public func resolve(_ snapshot: ElleKitDirectorySnapshot) -> ElleKitDirectoryResolution {
        let route = snapshot.upstream?.route ?? "unknown"
        let jbroot = snapshot.upstream?.jbroot

        let tiPath = ElleKitPathDeriver.tweakInjectPath(route: route, jbroot: jbroot)
        let dlPath = ElleKitPathDeriver.dynamicLibrariesPath(route: route, jbroot: jbroot)

        let tiEvidence = validator.validate(signal: snapshot.fs?.tweakInject, path: tiPath)
        let dlEvidence = inspector.inspect(signal: snapshot.fs?.dynamicLibraries, tiPath: tiPath)

        // 顶层告警：合并目录与软链告警；rootful 路线附加诊断告警。
        var warnings: [ReportWarning] = []
        for warning in tiEvidence.warnings + dlEvidence.warnings where !warnings.contains(warning) {
            warnings.append(warning)
        }
        if route == "rootful" {
            let rootfulWarning = ReportWarning(code: "rootful_route_not_profile", message: "", sourceStage: sourceStage)
            if !warnings.contains(rootfulWarning) {
                warnings.append(rootfulWarning)
            }
        }

        let outcome = Self.outcome(route: route,
                                   tiStatus: tiEvidence.status,
                                   dlState: dlEvidence.symlinkState,
                                   targetMatch: dlEvidence.targetMatch,
                                   tiPath: tiPath)

        return ElleKitDirectoryResolution(
            route: route,
            tweakInject: tiEvidence,
            dynamicLibraries: dlEvidence,
            dynamicLibrariesPath: dlPath,
            outcome: outcome,
            warnings: warnings
        )
    }

    /// 裁决优先级（纯规则；与基线逐字对齐）。
    private static func outcome(route: String,
                                tiStatus: String?,
                                dlState: String?,
                                targetMatch: Bool?,
                                tiPath: String?) -> String {
        if tiPath == nil {
            return "unresolved"
        }
        if tiStatus == "not_found" {
            return "not_found"
        }
        if dlState == "resolved" && targetMatch != true {
            return "structure_conflict"
        }
        if route == "rootful" {
            return "rootful_diagnostic"
        }
        if tiStatus == "confirmed" && dlState == "resolved" && targetMatch == true {
            return "resolved"
        }
        return "partial"
    }
}
