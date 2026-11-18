//
//  ElleKitAdapter.swift
//  FilterKit Adapters
//
//  Stage 2.1 骨架（未编译验证）。协议契约对齐 Spec/Architecture.md §4.1：
//  Core 仅持有本协议引用，不持有具体路线类型；路线特有规则由各 Adapter 内部实现。
//  只读阶段不暴露任何写入接口；预留写入方法在后续门禁阶段再声明。
//

import Foundation
import Models

/// 绝对路径包装（避免 Core/UI 直接拼接路线路径）。
public struct AbsolutePath: Codable, Equatable {
    public var value: String
    public init(_ value: String) { self.value = value }
}

/// 环境路径快照（JBROOT、TweakInject、DynamicLibraries 等，含证据与告警）。
public struct EnvironmentPaths: Equatable {
    public var jbroot: String?
    public var tweakInject: String?
    public var dynamicLibraries: String?
    public var warnings: [ReportWarning]

    public init(jbroot: String? = nil,
                tweakInject: String? = nil,
                dynamicLibraries: String? = nil,
                warnings: [ReportWarning] = []) {
        self.jbroot = jbroot
        self.tweakInject = tweakInject
        self.dynamicLibraries = dynamicLibraries
        self.warnings = warnings
    }
}

/// 扫描阶段候选条目（未配对/未解析前的中间记录）。
public struct PluginCandidate: Equatable {
    public var base: String
    public var dylibPath: String?
    public var plistPath: String?
    public var readable: Bool?
    public var warnings: [ReportWarning]

    public init(base: String,
                dylibPath: String? = nil,
                plistPath: String? = nil,
                readable: Bool? = nil,
                warnings: [ReportWarning] = []) {
        self.base = base
        self.dylibPath = dylibPath
        self.plistPath = plistPath
        self.readable = readable
        self.warnings = warnings
    }
}

/// 双路线统一 Adapter 契约。
///
/// 实现要求：
/// - RootHide / Rootless 各自独立实现，不复用对方规则代码；
/// - 未识别 Profile 不执行扫描，返回保守只读结果并标注告警；
/// - 所有方法在只读阶段不得产生设备写入。
public protocol ElleKitAdapter {
    /// 路线标识（roothide / rootless / unknown）。
    var route: String { get }

    func getEnvironment() -> JailbreakEnvironment
    func resolvePaths() -> EnvironmentPaths
    func scanPlugins() -> [PluginCandidate]
    func readPlugin(_ candidate: PluginCandidate) -> Plugin?
    func validatePlugin(_ plugin: Plugin) -> ValidationReport
    func parseFilter(_ plugin: Plugin) -> FilterRule?
    func resolvePath(_ relative: String) -> AbsolutePath
}
