//
//  SectionCardView.swift
//  FilterKit App 共享组件（Stage 2.3 GUI Foundation）
//

import SwiftUI

/// 分区卡片：标题 + 内容容器。
struct SectionCardView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
