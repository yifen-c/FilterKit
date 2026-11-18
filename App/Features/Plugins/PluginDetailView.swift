//
//  PluginDetailView.swift
//  FilterKit Features — Plugin Detail（Stage 2.3 GUI Foundation）
//
//  状态 / 文件 / 配对 / Filter 规则 / 归属 / 证据分区，全部由 `PluginDetailModel`
//  只读派生。详情页只读，无编辑、删除、修复或启停入口。
//

import SwiftUI
import Models

struct PluginDetailView: View {
    private let plugin: Plugin
    private let model: PluginDetailModel

    init(plugin: Plugin) {
        self.plugin = plugin
        self.model = PluginDetailModel(plugin: plugin)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(model.pluginID)
                    .font(.caption)
                    .foregroundColor(.secondary)
                section("Plugin Status", model.statusRows)
                section("Files", model.fileRows)
                section("Pairing", model.pairingRows)
                section("Filter Rules", model.filterRows)
                section("Ownership", model.ownershipRows)
                section("Evidence", model.evidenceRows)
            }
            .padding()
        }
        .navigationTitle(model.name)
    }

    private func section(_ title: String, _ rows: [DetailRow]) -> some View {
        SectionCardView(title: title) {
            if rows.isEmpty {
                Text("—")
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows) { row in
                    InfoRowView(label: row.label, value: row.value, status: row.status)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PluginDetailView(plugin: SyntheticReportFactory.previewEnvelope().plugins[0])
    }
}
