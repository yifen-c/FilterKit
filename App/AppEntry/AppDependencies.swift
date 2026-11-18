//
//  AppDependencies.swift
//  FilterKit App 组合根（Stage 2.3 GUI Foundation）
//
//  装配轮廓：报告信封来源 + 导出接缝。本文件不调用 Adapter 扫描/读取方法，
//  不实例化 Core 具体扫描器/解析器/Builder/Validator/Service；0.1-C 由静态
//  提供者注入合成或空信封，真机快照接入属 0.1-D。
//

import Foundation
import Models
import Core

/// 报告信封来源接缝。0.1-C 为静态提供者；后续阶段可替换为在线服务实现。
public protocol ReportProviding {
    /// 当前展示信封；`nil` 表示无报告，界面走空态。
    var envelope: ReportEnvelope? { get }
}

/// 静态信封提供者（只读，不触发扫描）。
public struct StaticReportProvider: ReportProviding {
    public let envelope: ReportEnvelope?

    public init(envelope: ReportEnvelope?) {
        self.envelope = envelope
    }
}

/// 应用装配依赖集合。
public struct AppDependencies {
    public let reportProvider: ReportProviding
    public let exporter: ReportExporting

    public init(reportProvider: ReportProviding, exporter: ReportExporting) {
        self.reportProvider = reportProvider
        self.exporter = exporter
    }

    /// 当前信封（只读投影，供 ViewModel 读取）。
    public var envelope: ReportEnvelope? {
        reportProvider.envelope
    }
}
