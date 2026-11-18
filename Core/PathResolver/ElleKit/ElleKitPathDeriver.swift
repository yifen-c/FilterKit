//
//  ElleKitPathDeriver.swift
//  FilterKit Core — 路线 → ElleKit 目录路径推导（B4 / S1-03）
//
//  规则对齐 resolver.js `tiPath` / `dlPath`：
//  - rootless：`/var/jb` + 后缀（独立路线规则，不作 RootHide 备用路径）；
//  - rootful：后缀本身（仅诊断参照）；
//  - roothide：上游已确认 jbroot + 后缀；jbroot 未定位时不推导路径（禁止回退 /var/jb 或 /）；
//  - 未知路线：不反推，返回 nil。
//
//  本文件只做纯字符串拼接，不访问文件系统，不代表路径存在或可访问。
//

import Foundation

/// ElleKit 目录路径推导器（静态纯函数）。
public enum ElleKitPathDeriver {

    /// TweakInject 目录后缀。
    public static let tweakInjectSuffix = "/usr/lib/TweakInject/"
    /// DynamicLibraries 目录后缀。
    public static let dynamicLibrariesSuffix = "/Library/MobileSubstrate/DynamicLibraries"

    /// 推导 TweakInject 路径；无法推导（roothide 缺 jbroot / 未知路线）返回 `nil`。
    public static func tweakInjectPath(route: String?, jbroot: String?) -> String? {
        switch route {
        case "rootless":
            return "/var/jb" + tweakInjectSuffix
        case "rootful":
            return tweakInjectSuffix
        case "roothide":
            guard let jbroot, !jbroot.isEmpty else { return nil }
            return jbroot + tweakInjectSuffix
        default:
            return nil
        }
    }

    /// 推导 DynamicLibraries 路径；口径与 TweakInject 一致。
    public static func dynamicLibrariesPath(route: String?, jbroot: String?) -> String? {
        switch route {
        case "rootless":
            return "/var/jb" + dynamicLibrariesSuffix
        case "rootful":
            return dynamicLibrariesSuffix
        case "roothide":
            guard let jbroot, !jbroot.isEmpty else { return nil }
            return jbroot + dynamicLibrariesSuffix
        default:
            return nil
        }
    }
}
