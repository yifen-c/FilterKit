//
//  RootlessAdapter.swift
//  FilterKit Adapters — Rootless 路线
//
//  Stage 2.1 骨架（未编译验证，未接入真实文件系统）。
//  路线口径：/var/jb 前缀、上游 ElleKit 规则；解析以 Swift Codable 模型为准，
//  C injector 仅作兼容性风险记录，不合并为宽松规则。当前无真机，结论待
//  [Rootless 真机待验证]，不以 RootHide 结果覆盖。
//
//  隔离要求：本文件不得引用 RootHideAdapter 或 RootHide 严格校验规则。
//

import Foundation
import Models

public final class RootlessAdapter: ElleKitAdapter {
    public let route = "rootless"

    public init() {}

    public func getEnvironment() -> JailbreakEnvironment {
        // 2.2：Rootless 环境识别（S1-01 rootless 分支迁移）。
        return JailbreakEnvironment(profileId: "unknown-profile")
    }

    public func resolvePaths() -> EnvironmentPaths {
        // 2.2：/var/jb 前缀与上游 TweakInject 定位（S1-02、S1-03）。
        return EnvironmentPaths()
    }

    public func scanPlugins() -> [PluginCandidate] {
        // 2.2：上游目录枚举与同名配对（S1-04、S1-05）。
        return []
    }

    public func readPlugin(_ candidate: PluginCandidate) -> Plugin? {
        // 2.2：按候选读取并装配插件记录。
        return nil
    }

    public func validatePlugin(_ plugin: Plugin) -> ValidationReport {
        // 2.2：Rootless Codable 模型校验；C injector 差异记为兼容风险。
        return ValidationReport()
    }

    public func parseFilter(_ plugin: Plugin) -> FilterRule? {
        // 2.2：上游 Filter 语义解析。
        return nil
    }

    public func resolvePath(_ relative: String) -> AbsolutePath {
        // 2.2：/var/jb 前缀归一。
        return AbsolutePath(relative)
    }
}

extension RootlessAdapter: EnvironmentProfileAdvisor {
    /// Rootless 路线 Profile 匹配口径（B1 / S1-01）：
    /// 类型 rootless + 实现 upstream + 版本已解析，才给出上游 Profile 候选。
    public func proposedProfile(jailbreakType: String,
                                implementation: String,
                                versionStatus: VersionReadinessStatus) -> String? {
        guard jailbreakType == "rootless",
              implementation == "upstream",
              versionStatus == .parsed else { return nil }
        return "RootlessProfile_upstream"
    }
}
