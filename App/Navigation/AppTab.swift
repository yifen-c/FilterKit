//
//  AppTab.swift
//  FilterKit App 底部 Tab（Stage 2.3 GUI Foundation）
//

import Foundation

/// 四个只读页面。
public enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case plugins
    case diagnostics
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .plugins: "Plugins"
        case .diagnostics: "Diagnostics"
        case .settings: "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .dashboard: "gauge"
        case .plugins: "puzzlepiece"
        case .diagnostics: "stethoscope"
        case .settings: "gearshape"
        }
    }
}
