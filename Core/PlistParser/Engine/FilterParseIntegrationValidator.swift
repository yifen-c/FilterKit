//
//  FilterParseIntegrationValidator.swift
//  FilterKit Core — PlistParser Engine（C3-Engine-B3）
//
//  解析快照完整性校验（对齐 C2-C 校验器范式）：纯计算，不访问文件系统，
//  不修改快照。核对计数不变量、规则载体归属、路线一致性与目录级状态
//  一致性。校验通过只代表 Engine 内部自洽，不替代 C3-C2 Runner 验收，
//  也不构成 S1-06 基线集成验收（Engine-C 范围）。
//

import Foundation
import Models

/// 单项解析集成验收结论（C3B-001 ~ 007）。
public struct FilterParseIntegrationCheck: Equatable {
    public let code: String
    public let passed: Bool
    public let detail: String?

    public init(code: String, passed: Bool, detail: String? = nil) {
        self.code = code
        self.passed = passed
        self.detail = detail
    }
}

/// 解析集成核对结果。
public struct FilterParseIntegrationResult: Equatable {
    public var snapshot: FilterParseSnapshot
    public var parsedCount: Int
    public var notParsedCount: Int
    public var counts: FilterParseCounts
    public var checks: [FilterParseIntegrationCheck]

    public var allPassed: Bool {
        checks.allSatisfy { $0.passed }
    }

    public init(snapshot: FilterParseSnapshot,
                parsedCount: Int,
                notParsedCount: Int,
                counts: FilterParseCounts,
                checks: [FilterParseIntegrationCheck]) {
        self.snapshot = snapshot
        self.parsedCount = parsedCount
        self.notParsedCount = notParsedCount
        self.counts = counts
        self.checks = checks
    }
}

/// 解析快照完整性校验器。
public struct FilterParseIntegrationValidator {

    public init() {}

    /// 执行完整性校验。
    public func validate(snapshot: FilterParseSnapshot) -> FilterParseIntegrationResult {
        let counts = snapshot.counts
        var checks: [FilterParseIntegrationCheck] = []

        // C3B-001：进入管线的四桶和 == parsed.count。
        let pipelineBucketSum = counts.valid + counts.parseFailed + counts.typeMismatch + counts.readFailed
        checks.append(FilterParseIntegrationCheck(
            code: "C3B-001",
            passed: pipelineBucketSum == snapshot.parsed.count,
            detail: pipelineBucketSum == snapshot.parsed.count
                ? nil
                : "pipeline buckets \(pipelineBucketSum) != parsed \(snapshot.parsed.count)"
        ))

        // C3B-002：notParsed 计数 == notParsed 条目数。
        checks.append(FilterParseIntegrationCheck(
            code: "C3B-002",
            passed: counts.notParsed == snapshot.notParsed.count,
            detail: counts.notParsed == snapshot.notParsed.count
                ? nil
                : "notParsed \(counts.notParsed) != items \(snapshot.notParsed.count)"
        ))

        // C3B-003：五桶和 == parsed + notParsed 条目总数。
        let totalMatches = counts.total == snapshot.parsed.count + snapshot.notParsed.count
        checks.append(FilterParseIntegrationCheck(
            code: "C3B-003",
            passed: totalMatches,
            detail: totalMatches
                ? nil
                : "total \(counts.total) != entries \(snapshot.parsed.count + snapshot.notParsed.count)"
        ))

        // C3B-004：规则载体仅 valid 非空，其余四态恒 nil。
        let filterOwnership = snapshot.parsed.allSatisfy { result in
            result.status == .valid ? result.filter != nil : result.filter == nil
        }
        checks.append(FilterParseIntegrationCheck(code: "C3B-004", passed: filterOwnership))

        // C3B-005：路线一致；快照路线非 nil 时，各结果路线不得漂移。
        let routeConsistent: Bool
        if let snapshotRoute = snapshot.route {
            routeConsistent = snapshot.parsed.allSatisfy { $0.route == snapshotRoute }
        } else {
            routeConsistent = true
        }
        checks.append(FilterParseIntegrationCheck(code: "C3B-005", passed: routeConsistent))

        // C3B-006：目录级状态与失败桶一致。
        let failureBucket = counts.parseFailed + counts.typeMismatch + counts.readFailed
        let expectedStatus: String
        if snapshot.parsed.isEmpty && snapshot.notParsed.isEmpty {
            expectedStatus = "unresolved"
        } else if failureBucket > 0 {
            expectedStatus = "partial"
        } else {
            expectedStatus = "enumerated"
        }
        checks.append(FilterParseIntegrationCheck(
            code: "C3B-006",
            passed: snapshot.status == expectedStatus,
            detail: snapshot.status == expectedStatus
                ? nil
                : "status \(snapshot.status) != expected \(expectedStatus)"
        ))

        // C3B-007：unresolved 必须携带 inventory_unresolved 告警。
        let unresolvedWarningOk = snapshot.status != "unresolved"
            || snapshot.warnings.contains { $0.code == "inventory_unresolved" }
        checks.append(FilterParseIntegrationCheck(code: "C3B-007", passed: unresolvedWarningOk))

        return FilterParseIntegrationResult(
            snapshot: snapshot,
            parsedCount: snapshot.parsed.count,
            notParsedCount: snapshot.notParsed.count,
            counts: counts,
            checks: checks
        )
    }
}
