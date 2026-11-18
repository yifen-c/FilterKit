//
//  JBRootToDirectoryBridge.swift
//  FilterKit Core — B3 JBROOT 裁决 → B4 ElleKit 目录定位 的衔接映射（B5 集成层）
//
//  本层只做结果映射，不重新收集候选、不重新裁决、不猜测路线：
//  1. 仅 B3 `resolved` 且确认 jbroot 非空时，向下游转发 jbroot；其余 outcome
//     （ambiguous / partial / resolve_failed / cross_route_only / no_candidate）
//     一律不注入已确认路径；
//  2. 不从候选列表重新挑选 JBROOT，选中路径以 B3 `jbroot` 为准；
//  3. ambiguous 不进入确认路径解析；
//  4. 路线不猜测：优先 B1 环境识别给出的显式路线；仅 resolved 场景可由选中候选
//     回填路线；否则保留 `nil`（unknown），由 B4 按未知路线处理。
//
//  衔接对象为 Core 内部结构；不进 Adapter 协议、不改 B3 冻结模型、不写入导出信封。
//

import Foundation
import Models

/// B3 → B4 Pipeline 衔接输入（Core 内部；证据保留 B3 原始 outcome 与告警）。
public struct ElleKitDirectoryPipelineInput: Codable, Equatable {
    /// 下游 B4 路线信号；`nil` 表示路线未确认，B4 不得反推。
    public var route: String?
    /// 已确认 JBROOT；未唯一确认时为 `nil`，不得由候选重新挑选补齐。
    public var jbroot: String?
    /// B3 原始裁决 outcome（证据保留，不向下游重新分类）。
    public var jbrootOutcome: String?
    /// B3 是否歧义（多有效候选）。
    public var ambiguous: Bool
    /// B3 顶层告警（证据不丢失，原样保留到集成层）。
    public var warnings: [ReportWarning]

    public init(route: String? = nil,
                jbroot: String? = nil,
                jbrootOutcome: String? = nil,
                ambiguous: Bool = false,
                warnings: [ReportWarning] = []) {
        self.route = route
        self.jbroot = jbroot
        self.jbrootOutcome = jbrootOutcome
        self.ambiguous = ambiguous
        self.warnings = warnings
    }
}

/// B3 裁决结果到 B4 上游输入的桥接器（纯映射，无文件系统访问）。
public enum JBRootToDirectoryBridge {

    /// 由 B3 裁决结果构造 B4 衔接输入。
    /// - Parameters:
    ///   - result: B3 `JBRootResolutionResult`；
    ///   - environmentRoute: B1 环境识别给出的显式路线信号；缺省 `nil`。
    public static func bridge(jbroot result: JBRootResolutionResult,
                              environmentRoute: String? = nil) -> ElleKitDirectoryPipelineInput {
        let confirmed = result.outcome == "resolved"
            && (result.jbroot?.isEmpty == false)

        let route = resolveRoute(result: result,
                                 environmentRoute: environmentRoute,
                                 confirmed: confirmed)

        return ElleKitDirectoryPipelineInput(
            route: route,
            jbroot: confirmed ? result.jbroot : nil,
            jbrootOutcome: result.outcome,
            ambiguous: result.ambiguous,
            warnings: result.warnings
        )
    }

    /// 路线解析：显式环境路线优先；仅唯一确认场景可由选中候选回填；其余留 `nil`。
    private static func resolveRoute(result: JBRootResolutionResult,
                                     environmentRoute: String?,
                                     confirmed: Bool) -> String? {
        if let env = environmentRoute?.trimmingCharacters(in: .whitespaces), !env.isEmpty {
            return env
        }
        guard confirmed, let jbroot = result.jbroot else { return nil }
        return result.candidates.first(where: { $0.path == jbroot })?.route
    }
}
