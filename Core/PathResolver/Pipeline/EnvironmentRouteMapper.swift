//
//  EnvironmentRouteMapper.swift
//  FilterKit Core — B1 环境识别结果 → Pipeline 路线信号映射（B5 衔接层）
//
//  规则严格跟随 B1 冻结语义，不从文件路径/jbroot 格式反推路线：
//  - `roothide` → `roothide`；`rootless` → `rootless`；`rootful` → `rootful`；
//  - `unknown` / 冲突 / 未识别 → `nil`（保守只读，不选边）；
//  - B1 已有告警原样保留，映射层不新增猜测性告警。
//
//  本层为纯函数映射，不访问文件系统，不实例化 Adapter，不覆盖 B1 识别结论。
//

import Foundation
import Models

/// 环境路线映射结果：路线信号（未识别为 `nil`）+ 保留的 B1 告警。
public struct EnvironmentRouteMapping: Equatable {
    public var route: String?
    public var warnings: [ReportWarning]

    public init(route: String? = nil, warnings: [ReportWarning] = []) {
        self.route = route
        self.warnings = warnings
    }
}

/// B1 结果到 Pipeline 路线信号的映射器（纯函数）。
public enum EnvironmentRouteMapper {

    /// 由环境识别结果推导路线；冲突/未识别返回 `nil`，告警原样保留。
    public static func route(from environment: EnvironmentDetectionResult) -> EnvironmentRouteMapping {
        // 冲突状态：B1 已归零类型并附加 `route_signal_conflict`；映射层同样保守返回 nil。
        guard environment.outcome != "conflict_no_profile" else {
            return EnvironmentRouteMapping(route: nil, warnings: environment.warnings)
        }

        let route: String?
        switch environment.jailbreakType.lowercased() {
        case "roothide": route = "roothide"
        case "rootless": route = "rootless"
        case "rootful": route = "rootful"
        default: route = nil
        }

        return EnvironmentRouteMapping(route: route, warnings: environment.warnings)
    }
}
