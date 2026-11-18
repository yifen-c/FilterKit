//
//  SettingsView.swift
//  FilterKit Features — Settings（Stage 2.3 GUI Foundation）
//
//  版本信息与只读 JSON 导出；导出文件落在 App 临时目录，经 Share Sheet 分享。
//  本页不含权限放行、目录写入、插件启停或规则修改入口。
//

import SwiftUI
import Models
import Core

struct SettingsView: View {
    private let dependencies: AppDependencies
    @State private var viewModel: SettingsViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._viewModel = State(
            initialValue: SettingsViewModel(
                provider: dependencies.reportProvider,
                exporter: dependencies.exporter
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Report") {
                    InfoRowView(label: "Schema", value: viewModel.schemaVersion ?? "Unknown")
                    InfoRowView(label: "Generator", value: viewModel.generatorVersion ?? "Unknown")
                    InfoRowView(
                        label: "Profile",
                        value: "\(viewModel.profileId ?? "Unknown") · \(viewModel.profileRoute ?? "?")"
                    )
                    InfoRowView(label: "Generated At", value: viewModel.generatedAt ?? "Unknown")
                }

                Section("Export") {
                    Button("Export JSON Report") {
                        viewModel.exportReport()
                    }
                    .disabled(!viewModel.canExport)

                    if let url = viewModel.exportedFileURL {
                        ShareLink(item: url) {
                            Label("Share Report", systemImage: "square.and.arrow.up")
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section("About") {
                    Text("FilterKit 0.1-C GUI Foundation · 只读界面")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(dependencies: AppDependencies(
        reportProvider: StaticReportProvider(envelope: SyntheticReportFactory.previewEnvelope()),
        exporter: ReportExporter()
    ))
}
