//
//  ElleKitDirectoryValidator.swift
//  FilterKit Core — TweakInject 目录状态校验（B4 / S1-03）
//
//  状态分层对齐 resolver.js：
//  - 路径无法推导（roothide 缺 jbroot / 未知路线）→ `unresolved` + `directory_unresolved`；
//  - 不存在 → `not_found` + `directory_not_found`；
//  - 存在但不可读或不可枚举 → `partial` + `access_limited`；
//  - 存在且可读、可枚举 → `confirmed`。
//
//  三态口径：`exists/readable/enumerable/structureMatch` 未验证保持 `nil`，不填 `false`；
//  裁决时 `true` 才算通过，`false`/`nil` 按未通过参与判定。目录状态（D9）独立于证据等级。
//  本层不枚举 dylib，不访问真实文件系统。
//

import Foundation
import Models

/// TweakInject 目录状态校验器。
public final class ElleKitDirectoryValidator {

    /// 目录状态封闭集（D9；文档化，非强枚举）。
    public static let directoryStatuses: Set<String> = [
        "unresolved", "not_found", "partial", "confirmed"
    ]

    private let sourceStage: String

    public init(sourceStage: String = "S1-03") {
        self.sourceStage = sourceStage
    }

    /// 依据目录信号与推导路径产出目录路径证据。
    public func validate(signal: DirectoryTiSignal?, path: String?) -> PathLocationEvidence {
        var warnings: [ReportWarning] = []
        let status: String

        switch path {
        case nil:
            // roothide 上游 jbroot 未定位 / 未知路线：不推导路径，禁止回退备用根。
            status = "unresolved"
            appendWarning(&warnings, code: "directory_unresolved")
        default:
            if signal?.exists != true {
                status = "not_found"
                appendWarning(&warnings, code: "directory_not_found")
            } else if signal?.readable != true || signal?.enumerable != true {
                // 可读与可枚举独立记录：readable=false 不得推断 enumerable=true，反之亦然。
                status = "partial"
                appendWarning(&warnings, code: "access_limited")
            } else {
                status = "confirmed"
            }
        }

        return PathLocationEvidence(
            requestedPath: path,
            resolvedPath: signal?.realpath,
            exists: signal?.exists,
            readable: signal?.readable,
            enumerable: signal?.enumerable,
            structureMatch: signal?.structureMatch,
            status: status,
            warnings: warnings
        )
    }

    private func appendWarning(_ warnings: inout [ReportWarning], code: String) {
        let warning = ReportWarning(code: code, message: "", sourceStage: sourceStage)
        guard !warnings.contains(warning) else { return }
        warnings.append(warning)
    }
}
