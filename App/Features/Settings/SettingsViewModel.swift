//
//  SettingsViewModel.swift
//  FilterKit Features — Settings（Stage 2.3 GUI Foundation）
//
//  版本信息展示与只读 JSON 导出。导出经 Core `ReportExporting` 接缝产出 Data；
//  本层只负责写入 App 临时目录与触发分享，不重新编码、不重排键序、不写越狱目录。
//

import Foundation
import Models
import Core

@Observable
final class SettingsViewModel {
    private let provider: ReportProviding
    private let exporter: ReportExporting

    var exportedFileURL: URL?
    var errorMessage: String?

    init(provider: ReportProviding, exporter: ReportExporting) {
        self.provider = provider
        self.exporter = exporter
    }

    var envelope: ReportEnvelope? { provider.envelope }

    var canExport: Bool { envelope != nil }

    var schemaVersion: String? { envelope?.schemaVersion }
    var generatorVersion: String? { envelope?.generatorVersion }
    var profileId: String? { envelope?.profile.id }
    var profileRoute: String? { envelope?.profile.route }
    var generatedAt: String? { envelope?.generatedAt }

    /// 导出当前信封到 App 临时目录；失败保留错误文案，不返回空文件。
    func exportReport() {
        guard let envelope else {
            exportedFileURL = nil
            errorMessage = "No report available to export."
            return
        }

        do {
            let data = try exporter.export(envelope)
            let dir = FileManager.default.temporaryDirectory
            let safeVersion = Self.sanitize(envelope.generatorVersion)
            let fileName = "FilterKit-Report-\(safeVersion).json"
            let url = dir.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            exportedFileURL = url
            errorMessage = nil
        } catch {
            exportedFileURL = nil
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private static func sanitize(_ version: String) -> String {
        let cleaned = version
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return cleaned.isEmpty ? "unknown" : cleaned
    }
}
