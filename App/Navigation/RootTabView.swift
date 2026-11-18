//
//  RootTabView.swift
//  FilterKit App 底部 Tab 容器（Stage 2.3 GUI Foundation）
//

import SwiftUI

struct RootTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            DashboardView(dependencies: dependencies)
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage)
                }

            PluginListView(dependencies: dependencies)
                .tabItem {
                    Label(AppTab.plugins.title, systemImage: AppTab.plugins.systemImage)
                }

            DiagnosticsView(dependencies: dependencies)
                .tabItem {
                    Label(AppTab.diagnostics.title, systemImage: AppTab.diagnostics.systemImage)
                }

            SettingsView(dependencies: dependencies)
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                }
        }
    }
}
