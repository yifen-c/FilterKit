//
//  VersionParser.swift
//  FilterKit Core — 版本五态解析（B1 / S1-01）
//
//  纯离线只读解析：只依据版本信号推导 VersionReadiness，不访问文件系统，
//  不含 RootHide / Rootless 路线规则。规则对齐 Stage 1 detector.js：
//  未提供 = not_installed；不可读 = unreadable；格式不匹配 = unparsable；
//  格式匹配 = parsed。
//

import Foundation
import Models

/// 版本号格式校验（对齐 Stage 1 `VERSION_RE`：主.次[.修订][-修订号]）。
public enum VersionNumberFormat {
    private static let regex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^\d+\.\d+(?:\.\d+)?(?:-\d+)?$"#)
    }()

    public static func matches(_ string: String) -> Bool {
        guard let regex else { return false }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
}

/// 版本信号 → 版本就绪证据。
public final class VersionParser {
    private let sourceStage: String

    public init(sourceStage: String = "S1-01") {
        self.sourceStage = sourceStage
    }

    public func classify(signal: EnvironmentSignalValue?) -> VersionReadiness {
        guard let signal, signal.isPresent else {
            return VersionReadiness(status: .notInstalled)
        }

        if signal.readability == "unreadable" {
            return VersionReadiness(
                status: .unreadable,
                warnings: [warning("access_limited")]
            )
        }

        let raw = signal.raw ?? signal.value
        guard let raw, !raw.isEmpty, VersionNumberFormat.matches(raw) else {
            return VersionReadiness(
                status: .unparsable,
                warnings: [warning("version_unparsable")]
            )
        }

        // 当前离线夹具 parsedVersion 与 rawVersion 一致；归一化算法归后续 Adapter。
        return VersionReadiness(
            status: .parsed,
            rawVersion: raw,
            parsedVersion: raw
        )
    }

    private func warning(_ code: String) -> ReportWarning {
        ReportWarning(code: code, message: "", sourceStage: sourceStage)
    }
}
