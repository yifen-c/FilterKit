//
//  ModelEnums.swift
//  FilterKit Models
//
//  Stage 2.1 骨架（未编译验证）。枚举取值与 Spec/Plugin-Data-Model.md §4 及
//  Tests/S1-08/exporter.js 实际导出保持一致；不得在 GUI 展示侧增删改义。
//  路线特有口径由 Adapter/Profile 快照承载，不进入公共枚举。
//

import Foundation

/// 越狱类型；识别失败 = unknown，不套用任一开放路线规则。
public enum JailbreakType: String, Codable {
    case roothide
    case rootless
    case unknown
}

/// 来源类型（dpkg 前端差异不改变归属性质，详见 S1-07）。
public enum SourceType: String, Codable {
    case dpkgSileo = "dpkg_sileo"
    case filterkit = "filterkit"
    case manual = "manual"
    case unknown
}

/// 归属状态（建模用；与 SourceType 区分，不互相替代）。
public enum OwnershipStatus: String, Codable {
    case ownedPackage = "owned_package"
    case filterkitManaged = "filterkit_managed"
    case manualImport = "manual_import"
    case unknown
}

/// 加载类别（建模分类，不等同运行结果）。
public enum LoadCategory: String, Codable {
    case manager
    case oldabi
    case tweak
    case unknown
}

/// 运行层加载状态；无独立运行时证据恒 unknown。
public enum LoadedState: String, Codable {
    case unknown
    case loaded
    case notLoaded = "not_loaded"
}

/// 证据等级；二手内省不得标 verified。
public enum EvidenceLevel: String, Codable {
    case verified
    case partial
    case unverified
}

/// 可写策略（归属识别 ≠ 管理授权，见 PermissionDecision）。
public enum WritablePolicy: String, Codable {
    case readOnly = "read_only"
    case managed
    case confirmedManaged = "confirmed_managed"
    case forbidden
}

/// 归属置信度。
public enum Confidence: String, Codable {
    case exactRecord = "exact_record"
    case heuristic
    case unknown
}

/// dylib ↔ plist 配对分类。
public enum Pairing: String, Codable {
    case paired
    case missingPlist = "missing_plist"
    case orphanPlist = "orphan_plist"
    case missingDylib = "missing_dylib"
}

/// 管理授权决策；Stage 2 只读阶段恒 undetermined，不由归属自动推导。
public enum PermissionDecision: String, Codable {
    case undetermined
}

/// Filter 规则版本约束模式。
public enum CoreFoundationMode: String, Codable {
    case max
    case range
}
