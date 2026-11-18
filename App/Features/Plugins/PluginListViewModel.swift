//
//  PluginListViewModel.swift
//  FilterKit Features — Plugins（Stage 2.3 GUI Foundation）
//
//  搜索与筛选全部委托 Presentation 映射；ViewModel 不做配对、解析或归属判断。
//

import SwiftUI
import Models

@Observable
final class PluginListViewModel {
    var keyword: String = ""
    var segment: PluginListSegment = .all

    private let plugins: [Plugin]

    init(plugins: [Plugin]) {
        self.plugins = plugins
    }

    var summaries: [PluginRowSummary] {
        let base = PluginListMapper.summarize(plugins)
        let searched = PluginListMapper.search(base, keyword: keyword)
        return PluginListMapper.filter(searched, segment: segment)
    }

    func plugin(id: String) -> Plugin? {
        plugins.first { $0.pluginID == id }
    }
}
