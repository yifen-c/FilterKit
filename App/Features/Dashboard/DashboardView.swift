//
//  DashboardView.swift
//  FilterKit Features — Dashboard（Stage 2.3 GUI Foundation）
//
//  环境卡片、插件统计、系统状态行；全部来自只读信封映射。本页不含扫描触发、
//  启停、编辑或写入入口。
//

import SwiftUI
import Models
import Core

struct DashboardView: View {
    private let dependencies: AppDependencies
    @State private var viewModel: DashboardViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._viewModel = State(
            initialValue: DashboardViewModel(provider: dependencies.reportProvider)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCardView(title: "Environment") {
                        ForEach(viewModel.overview.environmentRows) { row in
                            InfoRowView(label: row.title, value: row.value, status: row.status)
                        }
                    }

                    SectionCardView(title: "Plugins") {
                        HStack(spacing: 12) {
                            countCell(title: "Total", value: viewModel.overview.counts.total)
                            countCell(title: "Paired", value: viewModel.overview.counts.paired)
                            countCell(title: "Missing", value: viewModel.overview.counts.missing)
                            countCell(title: "Parse Failed", value: viewModel.overview.counts.parseFailed)
                        }
                    }

                    SectionCardView(title: "System") {
                        ForEach(viewModel.overview.systemRows) { row in
                            InfoRowView(label: row.title, value: row.value, status: row.status)
                        }
                    }

                    Text("只读界面：展示信封由 Core/Models 生成；本阶段不含扫描、启停或写入功能。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("FilterKit")
        }
    }

    private func countCell(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardView(dependencies: AppDependencies(
        reportProvider: StaticReportProvider(envelope: SyntheticReportFactory.previewEnvelope()),
        exporter: ReportExporter()
    ))
}
