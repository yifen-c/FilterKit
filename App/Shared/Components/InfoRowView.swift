//
//  InfoRowView.swift
//  FilterKit App 共享组件（Stage 2.3 GUI Foundation）
//

import SwiftUI

/// 通用只读信息行：标题 + 值，可选状态标签。
struct InfoRowView: View {
    let label: String
    let value: String
    let status: DisplayStatus?

    init(label: String, value: String, status: DisplayStatus? = nil) {
        self.label = label
        self.value = value
        self.status = status
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .multilineTextAlignment(.trailing)
                if let status {
                    StatusBadgeView(status: status)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
