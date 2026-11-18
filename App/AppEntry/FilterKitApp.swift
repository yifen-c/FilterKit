//
//  FilterKitApp.swift
//  FilterKit App 唯一入口（Stage 2.3 GUI Foundation 组合根）
//
//  职责：装配报告信封来源与导出接缝，挂载四页只读 Tab。本入口不调用 Adapter
//  扫描/读取方法，不实例化 Core 具体扫描器/解析器/Builder/Validator/Service；
//  0.1-C 使用静态合成信封做界面预览，真机快照接入属 0.1-D。
//

import SwiftUI
import Core

@main
struct FilterKitApp: App {
    private let dependencies: AppDependencies

    init() {
        let provider = StaticReportProvider(
            envelope: SyntheticReportFactory.previewEnvelope()
        )
        self.dependencies = AppDependencies(
            reportProvider: provider,
            exporter: ReportExporter()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
