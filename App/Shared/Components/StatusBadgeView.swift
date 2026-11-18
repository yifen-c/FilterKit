//
//  StatusBadgeView.swift
//  FilterKit App 共享组件（Stage 2.3 GUI Foundation）
//
//  状态标签：颜色只做界面分级，不改写 Core 状态语义。
//

import SwiftUI

struct StatusBadgeView: View {
    let status: DisplayStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(status.text)
                .font(.caption)
                .lineLimit(1)
            if let detail = status.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status.kind {
        case .success: .green
        case .warning: .orange
        case .failure: .red
        case .unknown: .gray
        }
    }
}
