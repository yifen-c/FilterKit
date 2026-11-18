//
//  ReportService.swift
//  FilterKit Core — Reporting（Stage 2.2-D，D5）
//
//  Reporting 组合根：Builder → Validator → Exporter 三段装配。三段均可
//  注入替换，默认使用冻结实现；本服务不做重新扫描 / 重新解析 / 归属补判，
//  不实现 OwnershipResolver，不接触文件系统与运行时取证。GUI 后续只消费
//  本服务，不另写扫描器。
//

import Foundation
import Models

/// Reporting 服务协议（构建 → 校验 → 导出）。
public protocol ReportServiceProtocol {
    /// 由只读快照归并统一信封。
    func buildReport(input: ReportBuildInput) -> ReportEnvelope
    /// 对信封做只读一致性校验。
    func validate(_ report: ReportEnvelope) -> ReportValidationResult
    /// 导出确定性 JSON 数据；编码失败抛出 `ReportExportError`。
    func exportJSON(_ report: ReportEnvelope) throws -> Data
}

/// 构建接缝（便于测试替换桩；生产默认 `ReportBuilder`）。
public protocol ReportBuilding {
    func build(_ input: ReportBuildInput) -> ReportEnvelope
}

/// 校验接缝（便于测试替换桩；生产默认 `ReportValidator`）。
public protocol ReportValidating {
    func validate(_ report: ReportEnvelope) -> ReportValidationResult
}

/// 导出接缝（便于测试替换桩；生产默认 `ReportExporter`）。
public protocol ReportExporting {
    func export(_ report: ReportEnvelope) throws -> Data
}

extension ReportBuilder: ReportBuilding {}
extension ReportValidator: ReportValidating {}
extension ReportExporter: ReportExporting {}

/// Reporting 默认装配。
public struct ReportService: ReportServiceProtocol {
    private let builder: ReportBuilding
    private let validator: ReportValidating
    private let exporter: ReportExporting

    public init(builder: ReportBuilding = ReportBuilder(),
                validator: ReportValidating = ReportValidator(),
                exporter: ReportExporting = ReportExporter()) {
        self.builder = builder
        self.validator = validator
        self.exporter = exporter
    }

    public func buildReport(input: ReportBuildInput) -> ReportEnvelope {
        builder.build(input)
    }

    public func validate(_ report: ReportEnvelope) -> ReportValidationResult {
        validator.validate(report)
    }

    public func exportJSON(_ report: ReportEnvelope) throws -> Data {
        try exporter.export(report)
    }
}
