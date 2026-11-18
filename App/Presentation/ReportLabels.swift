//
//  ReportLabels.swift
//  FilterKit App Presentation（Stage 2.3 GUI Foundation）
//
//  冻结枚举 → 界面文案的唯一落点。文案不得在 View 内另起变体；枚举取值与
//  语义以 Models 冻结契约为准，本文件不增删枚举义、不把 unknown 改写为
//  已知结论。
//

import Foundation
import Models

public enum ReportLabels {

    // MARK: 环境

    public static func jailbreakType(_ value: JailbreakType) -> String {
        switch value {
        case .roothide: "RootHide"
        case .rootless: "Rootless"
        case .unknown: "Unknown"
        }
    }

    // MARK: 三层状态

    public static func installed(_ value: Bool?) -> DisplayStatus {
        switch value {
        case .some(true): DisplayStatus(kind: .success, text: "Yes")
        case .some(false): DisplayStatus(kind: .warning, text: "No")
        case .none: DisplayStatus(kind: .unknown, text: "Unknown")
        }
    }

    public static func configured(_ value: Bool) -> DisplayStatus {
        value
            ? DisplayStatus(kind: .success, text: "Yes")
            : DisplayStatus(kind: .warning, text: "No")
    }

    public static func loaded(_ value: LoadedState) -> DisplayStatus {
        switch value {
        case .loaded:
            DisplayStatus(kind: .success, text: "Loaded")
        case .notLoaded:
            DisplayStatus(kind: .warning, text: "Not Loaded")
        case .unknown:
            DisplayStatus(kind: .unknown, text: "Unknown",
                           detail: "Runtime state not verified")
        }
    }

    // MARK: 配对 / 来源 / 归属 / 证据

    public static func pairing(_ value: Pairing) -> String {
        switch value {
        case .paired: "Paired"
        case .missingPlist: "Missing Plist"
        case .orphanPlist: "Orphan Plist"
        case .missingDylib: "Missing Dylib"
        }
    }

    public static func source(_ value: SourceType) -> String {
        switch value {
        case .dpkgSileo: "dpkg / Sileo"
        case .filterkit: "FilterKit"
        case .manual: "Manual"
        case .unknown: "Unknown"
        }
    }

    public static func writablePolicy(_ value: WritablePolicy) -> String {
        switch value {
        case .readOnly: "Read Only"
        case .managed: "Managed"
        case .confirmedManaged: "Confirmed Managed"
        case .forbidden: "Forbidden"
        }
    }

    public static func evidenceLevel(_ value: EvidenceLevel) -> String {
        switch value {
        case .verified: "Verified"
        case .partial: "Partial"
        case .unverified: "Unverified"
        }
    }

    public static func confidence(_ value: Confidence) -> String {
        switch value {
        case .exactRecord: "Exact Record"
        case .heuristic: "Heuristic"
        case .unknown: "Unknown"
        }
    }

    // MARK: 解析状态（validation.status 封闭词表）

    /// 解析状态分级与文案；`read_failed` 不降级为 `parse_failed`，
    /// `not_parsed` 不展示为解析失败。
    public static func parseStatus(_ raw: String) -> DisplayStatus {
        switch raw {
        case "valid":
            DisplayStatus(kind: .success, text: "Valid")
        case "parse_failed":
            DisplayStatus(kind: .failure, text: "Parse Failed")
        case "type_mismatch":
            DisplayStatus(kind: .failure, text: "Type Mismatch")
        case "read_failed":
            DisplayStatus(kind: .failure, text: "Read Failed")
        case "not_parsed":
            DisplayStatus(kind: .unknown, text: "Not Parsed")
        default:
            DisplayStatus(kind: .unknown, text: raw.isEmpty ? "Unknown" : raw)
        }
    }

    // MARK: 路径基名（纯字符串处理，不访问文件系统）

    public static func baseName(of path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return (path as NSString).lastPathComponent
    }

    /// 缺失路径展示文案；不拼默认路径、不留空串冒充已知。
    public static func pathValue(_ path: String?) -> String {
        baseName(of: path) ?? "Unknown"
    }
}
