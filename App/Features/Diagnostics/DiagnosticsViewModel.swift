//
//  DiagnosticsViewModel.swift
//  FilterKit Features — Diagnostics（Stage 2.3 GUI Foundation）
//

import SwiftUI
import Models

@Observable
final class DiagnosticsViewModel {
    let sections: [DiagnosticsSection]

    init(provider: ReportProviding) {
        self.sections = DiagnosticsMapper.sections(provider.envelope)
    }
}
