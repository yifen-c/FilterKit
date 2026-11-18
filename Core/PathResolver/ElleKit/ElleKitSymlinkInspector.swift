//
//  ElleKitSymlinkInspector.swift
//  FilterKit Core — DynamicLibraries 软链检查（B4 / S1-03）
//
//  软链五态（D10）：`resolved / broken / loop / denied / not_symlink`；
//  `targetMatch` 独立表达软链目标是否符合预期，不并入五态，也不以存在检查代替软链检查。
//  规则对齐 resolver.js：
//  - 仅 `resolved` 且同时有目标与预期目录路径时，做词法规范化后比较；
//  - broken → `symlink_broken`；loop → `symlink_loop`；denied → `symlink_target_denied`；
//    非软链且存在 → `not_a_symlink`；resolved 但目标不符 → `structure_conflict`。
//
//  本层不创建/删除软链，不访问真实文件系统。
//

import Foundation
import Models

/// DynamicLibraries 软链检查器。
public final class ElleKitSymlinkInspector {

    /// 软链五态封闭集（D10；文档化，非强枚举）。
    public static let symlinkStates: Set<String> = [
        "resolved", "broken", "loop", "denied", "not_symlink"
    ]

    private let sourceStage: String

    public init(sourceStage: String = "S1-03") {
        self.sourceStage = sourceStage
    }

    /// 依据软链信号与预期 TweakInject 路径产出软链证据。
    public func inspect(signal: DirectoryDlSignal?, tiPath: String?) -> SymlinkEvidence {
        let rawState = signal?.symlinkState
        let state = (rawState?.isEmpty == false) ? rawState! : "not_symlink"

        let target = signal?.symlinkTarget
        let hasTarget = target != nil && target!.isEmpty == false

        let targetMatch: Bool
        if state == "resolved", hasTarget, let tiPath {
            targetMatch = JBRootCandidateCollector.normalizeLexical(target)
                == JBRootCandidateCollector.normalizeLexical(tiPath)
        } else {
            targetMatch = false
        }

        var warnings: [ReportWarning] = []
        switch state {
        case "broken":
            appendWarning(&warnings, code: "symlink_broken")
        case "loop":
            appendWarning(&warnings, code: "symlink_loop")
        case "denied":
            appendWarning(&warnings, code: "symlink_target_denied")
        case "not_symlink":
            if signal?.exists == true {
                appendWarning(&warnings, code: "not_a_symlink")
            }
        case "resolved":
            if tiPath != nil && !targetMatch {
                appendWarning(&warnings, code: "structure_conflict")
            }
        default:
            // 五态外取值原样保留状态串，不映射、不丢弃（D5/D7 口径）。
            break
        }

        return SymlinkEvidence(
            isSymlink: signal?.isSymlink,
            targetPath: signal?.symlinkTarget,
            realpath: signal?.realpath,
            symlinkState: state,
            targetMatch: targetMatch,
            warnings: warnings
        )
    }

    private func appendWarning(_ warnings: inout [ReportWarning], code: String) {
        let warning = ReportWarning(code: code, message: "", sourceStage: sourceStage)
        guard !warnings.contains(warning) else { return }
        warnings.append(warning)
    }
}
