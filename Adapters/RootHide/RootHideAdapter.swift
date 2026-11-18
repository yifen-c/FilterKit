//
//  RootHideAdapter.swift
//  FilterKit Adapters — RootHide 路线
//
//  Stage 2.1 骨架（未编译验证，未接入真实文件系统）。
//  路线口径：.jbroot-<jbrand> 容器、jbroot() 路径翻译、1.2-3 严格同名配对、
//  严格类型校验、DynamicLibraries 软链只读核对。具体扫描/解析逻辑属 2.2 迁移范围。
//
//  隔离要求：本文件不得引用 RootlessAdapter 或上游 rootless 规则。
//

import Foundation
import Models

public final class RootHideAdapter: ElleKitAdapter {
    public let route = "roothide"

    public init() {}

    public func getEnvironment() -> JailbreakEnvironment {
        // 2.2：接入 RootHide 环境识别（S1-01 逻辑迁移）。
        return JailbreakEnvironment(profileId: "unknown-profile")
    }

    public func resolvePaths() -> EnvironmentPaths {
        // 2.2：JBROOT / TweakInject / DynamicLibraries 定位（S1-02、S1-03）。
        return EnvironmentPaths()
    }

    public func scanPlugins() -> [PluginCandidate] {
        // 2.2：目录枚举与配对编排（S1-04、S1-05）。
        return []
    }

    public func readPlugin(_ candidate: PluginCandidate) -> Plugin? {
        // 2.2：按候选读取并装配插件记录。
        return nil
    }

    public func validatePlugin(_ plugin: Plugin) -> ValidationReport {
        // 2.2：RootHide 严格类型校验。
        return ValidationReport()
    }

    public func parseFilter(_ plugin: Plugin) -> FilterRule? {
        // 2.2：RootHide Filter 严格语义解析。
        return nil
    }

    public func resolvePath(_ relative: String) -> AbsolutePath {
        // 2.2：jbroot() 路径翻译（进程内可用性待 2.4 探针）。
        return AbsolutePath(relative)
    }
}

extension RootHideAdapter: EnvironmentProfileAdvisor {
    /// RootHide 路线 Profile 匹配口径（B1 / S1-01）：
    /// 类型 roothide + 实现 roothide + 版本已解析，才给出 RootHide Profile 候选。
    public func proposedProfile(jailbreakType: String,
                                implementation: String,
                                versionStatus: VersionReadinessStatus) -> String? {
        guard jailbreakType == "roothide",
              implementation == "roothide",
              versionStatus == .parsed else { return nil }
        return "RootHideProfile_1_2_3"
    }
}
