//
//  PlistReadResult.swift
//  FilterKit Core — PlistParser Reader（C3-B）
//
//  单条 plist 读取结果。读取失败时 `data` 恒为 `nil`，不得以空 Data 冒充
//  成功；`errorCode / errorDescription` 仅保留诊断证据，不参与业务归类。
//

import Foundation

/// Reader 读取结果（Core 中间层，不进入公共 Codable Models）。
public struct PlistReadResult: Equatable {
    /// 读取状态。
    public let status: PlistReadStatus
    /// 成功读取的字节；失败恒为 `nil`。
    public let data: Data?
    /// 原始请求路径（不做路径猜测、不替换为 C2 提供路径以外的位置）。
    public let path: String
    /// 底层错误码（POSIX / Cocoa code）；成功为 `nil`。
    public let errorCode: Int?
    /// 底层错误描述；成功为 `nil`。
    public let errorDescription: String?

    public init(status: PlistReadStatus,
                data: Data?,
                path: String,
                errorCode: Int? = nil,
                errorDescription: String? = nil) {
        self.status = status
        self.data = data
        self.path = path
        self.errorCode = errorCode
        self.errorDescription = errorDescription
    }
}
