//
//  ReportEnvelope.swift
//  FilterKit Models
//
//  Stage 2.1 骨架（未编译验证）。信封对齐 S1-08 导出：schemaVersion /
//  generatorVersion / profile / generatedAt / environment / plugins /
//  unknownItems / warnings。generatedAt 不参与确定性比较；其余字段稳定排序。
//

import Foundation

/// 统一报告信封（JSON 导出顶层结构）。
public struct ReportEnvelope: Codable, Equatable {
    public var schemaVersion: String
    public var generatorVersion: String
    public var profile: ProfileRef
    public var generatedAt: String?
    public var environment: JailbreakEnvironment
    public var plugins: [Plugin]
    public var unknownItems: [UnknownItem]
    public var warnings: [ReportWarning]

    public init(schemaVersion: String = "0.1.0",
                generatorVersion: String = "0.1.0",
                profile: ProfileRef,
                generatedAt: String? = nil,
                environment: JailbreakEnvironment,
                plugins: [Plugin] = [],
                unknownItems: [UnknownItem] = [],
                warnings: [ReportWarning] = []) {
        self.schemaVersion = schemaVersion
        self.generatorVersion = generatorVersion
        self.profile = profile
        self.generatedAt = generatedAt
        self.environment = environment
        self.plugins = plugins
        self.unknownItems = unknownItems
        self.warnings = warnings
    }
}
