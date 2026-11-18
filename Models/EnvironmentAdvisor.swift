//
//  EnvironmentAdvisor.swift
//  FilterKit Models — 路线 Profile 提案中性接口（B1 / S1-01）
//
//  本协议只声明中性匹配口径；具体路线的 Profile 标识与匹配条件由各 Adapter
//  实现。Models 不包含任何 RootHide / Rootless 路线规则。
//

import Foundation

/// 路线 Profile 提案顾问：由各 Adapter 实现自身路线的匹配口径。
public protocol EnvironmentProfileAdvisor {
    var route: String { get }
    /// 依据中性事实返回候选 Profile 标识；不匹配返回 `nil`。
    func proposedProfile(jailbreakType: String,
                         implementation: String,
                         versionStatus: VersionReadinessStatus) -> String?
}
