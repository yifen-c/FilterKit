//
//  ReportExporter.swift
//  FilterKit Core — ReportExporter（Stage 2.2-D，D4）
//
//  把校验后的 `ReportEnvelope` 编码为确定性 JSON 数据。只做序列化：
//  不重新扫描、不补全字段、不访问文件系统；编码失败以明确错误类型抛出，
//  不吞错、不返回空数据。除 `generatedAt` 外，相同输入两次导出字节一致。
//

import Foundation
import Models

/// 导出错误（封闭枚举；编码失败原因随附）。
public enum ReportExportError: Error, Equatable {
    case encodingFailed(String)
}

/// JSON 导出器（纯数据编码；Builder / Validator 由调用方在前序阶段完成）。
public struct ReportExporter {
    public init() {}

    /// 排序后编码为 JSON；不修改传入的信封原值。
    public func export(_ report: ReportEnvelope) throws -> Data {
        var snapshot = report
        snapshot.plugins = ReportSerialization.sortedPlugins(report.plugins)
        snapshot.unknownItems = ReportSerialization.sortedUnknownItems(report.unknownItems)
        snapshot.warnings = ReportSerialization.sortedWarnings(report.warnings)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(snapshot)
        } catch {
            throw ReportExportError.encodingFailed("\(error)")
        }
    }
}
