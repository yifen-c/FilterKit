//
//  PluginPairingIntegrationResult.swift
//  FilterKit Core — C1 → C2 集成核对结果（C2-C 集成契约 §3）
//
//  内部测试辅助结构：记录输入/输出摘要与逐项验收结论；不加入公共 Models、
//  不进入 ReportEnvelope、不产出最终 Plugin。
//

import Foundation
import Models

/// 单项集成验收结论（INT-C2-001 ~ 014）。
public struct PluginPairingIntegrationCheck: Equatable {

    /// 验收编号（如 `INT-C2-001`）。
    public let code: String

    /// 是否通过。
    public let passed: Bool

    /// 失败/补充说明；通过时可为 `nil`。
    public let detail: String?

    public init(code: String, passed: Bool, detail: String? = nil) {
        self.code = code
        self.passed = passed
        self.detail = detail
    }
}

/// 集成核对结果：输入视图、C2 快照、计数摘要与逐项结论。
public struct PluginPairingIntegrationResult: Equatable {

    /// 配对输入视图。
    public var input: PluginPairingInput

    /// C2 配对快照。
    public var snapshot: PluginPairingSnapshot

    /// C1 原始条目总数。
    public var inventoryItemCount: Int

    /// 进入配对视图的候选条目数。
    public var candidateCount: Int

    /// C1 unknownItems 数量。
    public var unknownItemCount: Int

    /// C1 warnings 数量。
    public var warningCount: Int

    /// C2 记录组数。
    public var recordCount: Int

    /// C2 五桶计数。
    public var counts: PluginPairingCounts

    /// 逐项验收结论。
    public var checks: [PluginPairingIntegrationCheck]

    /// 全部验收通过。
    public var passed: Bool {
        checks.allSatisfy { $0.passed }
    }

    public init(input: PluginPairingInput,
                snapshot: PluginPairingSnapshot,
                inventoryItemCount: Int,
                candidateCount: Int,
                unknownItemCount: Int,
                warningCount: Int,
                recordCount: Int,
                counts: PluginPairingCounts,
                checks: [PluginPairingIntegrationCheck]) {
        self.input = input
        self.snapshot = snapshot
        self.inventoryItemCount = inventoryItemCount
        self.candidateCount = candidateCount
        self.unknownItemCount = unknownItemCount
        self.warningCount = warningCount
        self.recordCount = recordCount
        self.counts = counts
        self.checks = checks
    }
}
