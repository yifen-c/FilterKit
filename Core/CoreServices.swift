//
//  CoreServices.swift
//  FilterKit Core（共享管理核心）
//
//  Stage 2.1 骨架（未编译验证）。Core 只编排 Adapter 调用与模型聚合，不写路线
//  特有规则，不散落路线 if/else。各服务方法对应 Stage 1 环节，2.2 迁移实现：
//  Environment→S1-01；PathResolver→S1-02/03；Scanner/Pairing→S1-04/05；
//  PlistParser→S1-06；Ownership→S1-07；ReportExporter→S1-08。
//

import Foundation
import Models
import Adapters

/// 环境识别编排。
public protocol EnvironmentService {
    func environment() -> JailbreakEnvironment
}

/// 路径定位编排。
public protocol PathResolutionService {
    func paths(for environment: JailbreakEnvironment) -> EnvironmentPaths
}

/// 插件扫描与配对编排。
public protocol PluginScanService {
    func candidates() -> [PluginCandidate]
}

/// 解析与归属编排。
public protocol PluginParseService {
    func plugin(for candidate: PluginCandidate) -> Plugin?
}

/// 归属识别编排。
public protocol OwnershipService {
    func resolveOwnership(for plugin: inout Plugin)
}

/// 统一模型与 JSON 导出编排。
public protocol ReportExportService {
    func export(environment: JailbreakEnvironment,
                plugins: [Plugin],
                unknownItems: [UnknownItem],
                warnings: [ReportWarning]) -> ReportEnvelope
}

/// 组合根：按 Profile 选择 Adapter，装配 Core 服务与 ViewModel。
///
/// 2.1 仅保留装配轮廓；Adapter 选择由环境/Profile 识别结果决定，
/// 未知 Profile 不执行扫描。具体注入与服务实现在 2.2 落地。
public protocol AdapterResolver {
    /// 返回与当前环境匹配的 Adapter；识别失败返回 nil（保守只读模式）。
    func resolveAdapter(for environment: JailbreakEnvironment) -> ElleKitAdapter?
}
