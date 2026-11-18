//
//  FilterParseSnapshotBuilder.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B3）
//
//  解析结果汇总器：把管线产出的 `parsed` 与归集的 `notParsed` 汇总为
//  `FilterParseSnapshot`，计算五桶计数、目录级状态与去重告警。纯计算，
//  不访问文件系统，不修改上游配对快照。
//

import Foundation
import Models

/// 解析快照汇总器。
public struct FilterParseSnapshotBuilder {

    public init() {}

    /// 非 unresolved 路径汇总。
    public func build(upstream: PluginPairingSnapshot,
                      parsed: [FilterParseResult],
                      notParsed: [UnknownItem]) -> FilterParseSnapshot {
        let counts = Self.counts(parsed: parsed, notParsed: notParsed)
        let partial = counts.parseFailed + counts.typeMismatch + counts.readFailed > 0
        let status = partial ? "partial" : "enumerated"
        let entryWarnings = parsed.flatMap { $0.warnings }
        let extraWarnings = partial ? ["partial_parsing"] : []
        let warnings = Self.deduplicated(
            upstream: upstream.warnings,
            entry: entryWarnings,
            extra: extraWarnings
        )

        return FilterParseSnapshot(
            route: upstream.route,
            sourceDirectory: upstream.sourceDirectory,
            status: status,
            parsed: parsed,
            notParsed: notParsed,
            counts: counts,
            warnings: warnings
        )
    }

    /// Stage 0 unresolved 路径：空快照 + `inventory_unresolved`，下游零调用。
    public func buildUnresolved(upstream: PluginPairingSnapshot) -> FilterParseSnapshot {
        FilterParseSnapshot(
            route: upstream.route,
            sourceDirectory: upstream.sourceDirectory,
            status: "unresolved",
            parsed: [],
            notParsed: [],
            counts: FilterParseCounts(),
            warnings: Self.deduplicated(
                upstream: upstream.warnings,
                entry: [],
                extra: ["inventory_unresolved"]
            )
        )
    }

    // MARK: - 计数与告警

    private static func counts(parsed: [FilterParseResult], notParsed: [UnknownItem]) -> FilterParseCounts {
        var counts = FilterParseCounts(notParsed: notParsed.count)
        for result in parsed {
            switch result.status {
            case .valid: counts.valid += 1
            case .parseFailed: counts.parseFailed += 1
            case .typeMismatch: counts.typeMismatch += 1
            case .readFailed: counts.readFailed += 1
            case .notParsed: counts.notParsed += 1
            }
        }
        return counts
    }

    private static func deduplicated(upstream: [ReportWarning],
                                      entry: [ReportWarning],
                                      extra: [String]) -> [ReportWarning] {
        var seen = Set<String>()
        var output: [ReportWarning] = []
        for warning in upstream + entry {
            guard !seen.contains(warning.code) else { continue }
            seen.insert(warning.code)
            output.append(warning)
        }
        for code in extra where !seen.contains(code) {
            seen.insert(code)
            output.append(ReportWarning(
                code: code,
                message: warningMessage(code),
                sourceStage: "stage2.2-c3"
            ))
        }
        return output
    }

    private static func warningMessage(_ code: String) -> String {
        switch code {
        case "inventory_unresolved": return "配对目录未定位，未执行解析"
        case "partial_parsing": return "部分条目解析失败，快照按 partial 汇总"
        case "invalid_plist": return "plist 解码失败"
        case "access_denied": return "plist 访问受限"
        case "read_failed": return "plist 读取失败"
        default: return code
        }
    }
}
