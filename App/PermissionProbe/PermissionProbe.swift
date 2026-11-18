//
//  PermissionProbe.swift
//  FilterKit App — 权限探针预留（Stage 2.4 实现）
//
//  Stage 2.1 仅保留接口轮廓；本阶段不执行任何真机访问，不下权限结论。
//  探针必须在 GUI App 自身进程内独立执行，CLI 结果不得冒充 GUI 权限。
//
//  计划探针项（对齐 Stage-2 计划 §5.4）：
//  1. 进程内自身环境识别；2. JBROOT 定位与可达性；3. TweakInject 访问；
//  4. dylib/plist 枚举；5. plist 读取；6. dpkg 数据库读取；
//  7. jbroot() 符号可用性与路径解析；8. 冷启动后权限保持。
//  附加核对：entitlement 保留、amfid/ldid 放行、sandbox/容器限制。
//

import Foundation

/// 单项探针结果（规划模型，2.4 落地取证）。
public struct ProbeItem: Equatable {
    public let item: String
    public var reached: Bool
    public var readable: Bool
    public var errno: Int32?
    public var reason: String?
    public var evidence: String

    public init(item: String,
                reached: Bool = false,
                readable: Bool = false,
                errno: Int32? = nil,
                reason: String? = nil,
                evidence: String = "权限待验证") {
        self.item = item
        self.reached = reached
        self.readable = readable
        self.errno = errno
        self.reason = reason
        self.evidence = evidence
    }
}

/// 探针服务预留协议；2.1 无实现。
public protocol PermissionProbeService {
    func runProbes() -> [ProbeItem]
}
