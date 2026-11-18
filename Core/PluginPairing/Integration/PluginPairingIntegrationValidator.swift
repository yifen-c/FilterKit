//
//  PluginPairingIntegrationValidator.swift
//  FilterKit Core — C1 → C2 完整性校验（C2-C 集成契约 §3）
//
//  逐项核对 INT-C2-001 ~ 014：身份/证据/归集/告警/状态/计数/不可变性/
//  确定性/路线隔离。校验为纯计算，不访问文件系统，不修改任何快照。
//

import Foundation
import Models

/// 集成完整性校验器。
public struct PluginPairingIntegrationValidator {

    public init() {}

    /// 执行集成校验。
    /// - Parameters:
    ///   - baseline: 执行前 C1 快照；
    ///   - after: 执行后 C1 快照（应与 baseline 深比较相等）；
    ///   - input: 适配器产出的配对输入视图；
    ///   - snapshot: C2 配对快照；
    ///   - secondSnapshot: 二次执行快照（确定性核对，可选）。
    public func validate(
        baseline: PluginInventorySnapshot,
        after: PluginInventorySnapshot,
        input: PluginPairingInput,
        snapshot: PluginPairingSnapshot,
        secondSnapshot: PluginPairingSnapshot? = nil
    ) -> PluginPairingIntegrationResult {

        let expectedCandidates = baseline.items.filter {
            $0.kind == .dylib || $0.kind == .plist
        }
        let recordEvidence = snapshot.records.flatMap(Self.evidence(of:))
        let unknownKept = baseline.unknownItems.allSatisfy { snapshot.unknownItems.contains($0) }
        let warningsKept = baseline.warnings.allSatisfy { snapshot.warnings.contains($0) }

        var checks: [PluginPairingIntegrationCheck] = []

        // INT-C2-001 route 原样传递
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-001",
            passed: snapshot.route == baseline.route
        ))

        // INT-C2-002 sourceDirectory 原样传递
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-002",
            passed: snapshot.sourceDirectory == baseline.sourceDirectory
        ))

        // INT-C2-003 dylib/plist 证据完整传递
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-003",
            passed: input.files == expectedCandidates
        ))

        // INT-C2-004 非候选文件不进入配对索引
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-004",
            passed: recordEvidence.allSatisfy { $0.kind == .dylib || $0.kind == .plist }
        ))

        // INT-C2-005 C1 unknownItems 不丢失
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-005",
            passed: unknownKept
        ))

        // INT-C2-006 C1 warnings 不丢失
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-006",
            passed: warningsKept
        ))

        // INT-C2-007 entryStatus 不被改变
        let statusKept = input.files.count == expectedCandidates.count
            && zip(input.files, expectedCandidates).allSatisfy { $0.entryStatus == $1.entryStatus }
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-007",
            passed: statusKept
        ))

        // INT-C2-008 readable=nil 不被转换成 false
        let readableKept = input.files.count == expectedCandidates.count
            && zip(input.files, expectedCandidates).allSatisfy { $0.readable == $1.readable }
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-008",
            passed: readableKept
        ))

        // INT-C2-009 unresolved 正确处理
        let isUnresolved = baseline.sourceDirectory == nil
            || baseline.enumeration.status == .unresolved
        if isUnresolved {
            let unresolvedOk = snapshot.status == .unresolved
                && snapshot.records.isEmpty
                && snapshot.counts.total == 0
                && snapshot.warnings.contains { $0.code == "inventory_unresolved" }
            checks.append(PluginPairingIntegrationCheck(
                code: "INT-C2-009",
                passed: unresolvedOk
            ))
        } else {
            checks.append(PluginPairingIntegrationCheck(
                code: "INT-C2-009",
                passed: true,
                detail: "输入非 unresolved"
            ))
        }

        // INT-C2-010 partial 正确处理
        if baseline.enumeration.status == .partial {
            let partialOk = snapshot.status == .partial && warningsKept
            checks.append(PluginPairingIntegrationCheck(
                code: "INT-C2-010",
                passed: partialOk
            ))
        } else {
            checks.append(PluginPairingIntegrationCheck(
                code: "INT-C2-010",
                passed: true,
                detail: "输入非 partial"
            ))
        }

        // INT-C2-011 五桶计数互斥
        let bucketSum = snapshot.counts.paired
            + snapshot.counts.missingPlist
            + snapshot.counts.orphanPlist
            + snapshot.counts.ambiguous
            + snapshot.counts.uncertain
        let mutexOk = snapshot.counts.total == snapshot.records.count
            && bucketSum == snapshot.records.count
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-011",
            passed: mutexOk
        ))

        // INT-C2-012 输入快照执行前后一致
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-012",
            passed: baseline == after
        ))

        // INT-C2-013 重复执行结果一致
        if let second = secondSnapshot {
            checks.append(PluginPairingIntegrationCheck(
                code: "INT-C2-013",
                passed: second == snapshot
            ))
        } else {
            checks.append(PluginPairingIntegrationCheck(
                code: "INT-C2-013",
                passed: true,
                detail: "未提供二次执行快照"
            ))
        }

        // INT-C2-014 路线不交叉转换
        let routeKept = snapshot.route == baseline.route && input.route == baseline.route
        checks.append(PluginPairingIntegrationCheck(
            code: "INT-C2-014",
            passed: routeKept
        ))

        return PluginPairingIntegrationResult(
            input: input,
            snapshot: snapshot,
            inventoryItemCount: baseline.items.count,
            candidateCount: input.files.count,
            unknownItemCount: baseline.unknownItems.count,
            warningCount: baseline.warnings.count,
            recordCount: snapshot.records.count,
            counts: snapshot.counts,
            checks: checks
        )
    }

    /// 记录中承载的全部证据（两侧位 + 歧义/不确定候选）。
    private static func evidence(of record: PluginPairingRecord) -> [PluginFileEvidence] {
        var evidence: [PluginFileEvidence] = []
        if let dylib = record.dylib { evidence.append(dylib) }
        if let plist = record.plist { evidence.append(plist) }
        evidence.append(contentsOf: record.candidates)
        return evidence
    }
}
