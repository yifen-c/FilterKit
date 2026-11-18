//
//  DashboardViewModel.swift
//  FilterKit Features — Dashboard（Stage 2.3 GUI Foundation）
//
//  仅装配 `DashboardOverview` 映射结果；不扫描、不解析、不调用 Core 具体实现。
//

import SwiftUI
import Models

@Observable
final class DashboardViewModel {
    let overview: DashboardOverview

    init(provider: ReportProviding) {
        self.overview = DashboardOverview(envelope: provider.envelope)
    }
}
