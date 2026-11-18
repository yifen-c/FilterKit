//
//  DiagnosticsView.swift
//  FilterKit Features — Diagnostics（Stage 2.3 GUI Foundation）
//
//  环境 / JBROOT / Dynamic Libraries / 枚举 / 解析 / Warnings / Unknown Items
//  分组只读展示；不触发重新扫描，不回写设备。
//

import SwiftUI
import Models
import Core

struct DiagnosticsView: View {
    private let dependencies: AppDependencies
    @State private var viewModel: DiagnosticsViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._viewModel = State(
            initialValue: DiagnosticsViewModel(provider: dependencies.reportProvider)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.sections) { section in
                        SectionCardView(title: section.title) {
                            if section.isEmpty {
                                Text("—")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(section.rows) { row in
                                    InfoRowView(label: row.label, value: row.value, status: row.status)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnostics")
        }
    }
}

#Preview {
    DiagnosticsView(dependencies: AppDependencies(
        reportProvider: StaticReportProvider(envelope: SyntheticReportFactory.previewEnvelope()),
        exporter: ReportExporter()
    ))
}
