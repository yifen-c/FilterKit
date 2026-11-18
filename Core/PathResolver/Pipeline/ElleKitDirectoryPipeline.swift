//
//  ElleKitDirectoryPipeline.swift
//  FilterKit Core — B2/B3 → B4 跨批次编排（B5 集成层，离线只读）
//
//  组合既有编排器，不重写任何批次规则：
//  1. `JBRootResolver`：B2 收集 + B3 校验裁决；
//  2. `JBRootToDirectoryBridge`：B3 结果 → B4 上游衔接输入；
//  3. `ElleKitDirectoryResolver`：B4 目录/软链定位。
//
//  边界：本编排器不实例化具体 Adapter、不新增服务协议、不枚举 dylib、不访问真实
//  文件系统；fs 信号由离线快照注入。AdapterResolver 与服务装配归后续授权批次。
//

import Foundation
import Models

/// 跨批次集成结果：保留 B1 映射、B3 裁决、衔接输入与 B4 目录定位四层证据，便于集成层核对
/// 类型匹配、证据传递、未确认状态保留与告警不丢失。
public struct IntegratedDirectoryResolution: Equatable {
    /// B1 环境路线映射告警（B1 结果告警原样保留）。
    public var environmentWarnings: [ReportWarning]
    /// B3 JBROOT 裁决结果（含全部候选证据与告警）。
    public var jbroot: JBRootResolutionResult
    /// B3 → B4 衔接输入。
    public var pipelineInput: ElleKitDirectoryPipelineInput
    /// B4 目录/软链定位结果。
    public var directory: ElleKitDirectoryResolution

    public init(environmentWarnings: [ReportWarning] = [],
                jbroot: JBRootResolutionResult,
                pipelineInput: ElleKitDirectoryPipelineInput,
                directory: ElleKitDirectoryResolution) {
        self.environmentWarnings = environmentWarnings
        self.jbroot = jbroot
        self.pipelineInput = pipelineInput
        self.directory = directory
    }
}

/// B2/B3 → B4 目录定位编排入口（Core 内部组合根；离线信号注入）。
public final class ElleKitDirectoryPipeline {

    private let jbResolver: JBRootResolver
    private let directoryResolver: ElleKitDirectoryResolver

    public init(jbResolver: JBRootResolver = JBRootResolver(),
                directoryResolver: ElleKitDirectoryResolver = ElleKitDirectoryResolver()) {
        self.jbResolver = jbResolver
        self.directoryResolver = directoryResolver
    }

    /// 执行跨批次编排（生产入口：路线由 B1 结果经 `EnvironmentRouteMapper` 推导，避免调用方传错）。
    /// - Parameters:
    ///   - jbrootSnapshot: B2/B3 JBROOT 候选快照；
    ///   - directoryFs: B4 目录/软链离线信号；缺省表示未提供；
    ///   - environment: B1 环境识别结果。
    public func resolve(jbrootSnapshot: JBRootCandidateSnapshot,
                        directoryFs: DirectoryFsSignal? = nil,
                        environment: EnvironmentDetectionResult) -> IntegratedDirectoryResolution {
        let mapping = EnvironmentRouteMapper.route(from: environment)
        var result = resolve(jbrootSnapshot: jbrootSnapshot,
                             directoryFs: directoryFs,
                             environmentRoute: mapping.route)
        result.environmentWarnings = mapping.warnings
        return result
    }

    /// 执行跨批次编排（低层组合入口：路线由调用方显式提供；生产链路优先使用
    /// `environment:` 重载，路线由 B1 结果推导）。
    /// - Parameters:
    ///   - jbrootSnapshot: B2/B3 JBROOT 候选快照；
    ///   - directoryFs: B4 目录/软链离线信号；缺省表示未提供；
    ///   - environmentRoute: 显式路线信号；缺省由桥接规则处理。
    public func resolve(jbrootSnapshot: JBRootCandidateSnapshot,
                        directoryFs: DirectoryFsSignal? = nil,
                        environmentRoute: String? = nil) -> IntegratedDirectoryResolution {
        let jbResult = jbResolver.resolve(jbrootSnapshot)
        let input = JBRootToDirectoryBridge.bridge(jbroot: jbResult, environmentRoute: environmentRoute)

        let directorySnapshot = ElleKitDirectorySnapshot(
            upstream: DirectoryUpstreamSignal(route: input.route, jbroot: input.jbroot),
            fs: directoryFs
        )
        let directoryResult = directoryResolver.resolve(directorySnapshot)

        return IntegratedDirectoryResolution(
            jbroot: jbResult,
            pipelineInput: input,
            directory: directoryResult
        )
    }
}
