//
//  ElleKitDirectoryResolution.swift
//  FilterKit Core — ElleKit 目录定位裁决结果（B4 / S1-03）
//
//  字段对齐 S1-03 基线输出；目录证据与软链证据复用 Models 冻结结构
//  （`PathLocationEvidence` / `SymlinkEvidence`），不另造平行证据模型。
//  本结构为 Core 内部裁决结果，装配进 `EnvironmentPaths` / 导出信封归 B5 Pipeline。
//

import Foundation
import Models

/// ElleKit 目录定位裁决结果。
public struct ElleKitDirectoryResolution: Equatable {
    /// 路线标识（roothide / rootless / rootful / unknown）。
    public var route: String
    /// TweakInject 目录路径证据；路径无法推导时仍保留未解析状态证据。
    public var tweakInject: PathLocationEvidence?
    /// DynamicLibraries 软链证据。
    public var dynamicLibraries: SymlinkEvidence?
    /// DynamicLibraries 推导路径（对应基线 `dynamicLibraries.value`）。
    public var dynamicLibrariesPath: String?
    /// 最终裁决结果封闭集：
    /// `unresolved / not_found / structure_conflict / rootful_diagnostic / resolved / partial`。
    public var outcome: String
    /// 顶层告警（按 code+message 去重合并）。
    public var warnings: [ReportWarning]

    public init(route: String,
                tweakInject: PathLocationEvidence? = nil,
                dynamicLibraries: SymlinkEvidence? = nil,
                dynamicLibrariesPath: String? = nil,
                outcome: String,
                warnings: [ReportWarning] = []) {
        self.route = route
        self.tweakInject = tweakInject
        self.dynamicLibraries = dynamicLibraries
        self.dynamicLibrariesPath = dynamicLibrariesPath
        self.outcome = outcome
        self.warnings = warnings
    }
}
