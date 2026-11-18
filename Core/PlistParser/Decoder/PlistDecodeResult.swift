//
//  PlistDecodeResult.swift
//  FilterKit Core — PlistParser Decoder（C3-B）
//
//  单条解码结果。解码失败时 `object` 恒为 `nil`，不返回虚假空对象；
//  `errorDescription` 仅为诊断证据，业务归类由上层按路线规则执行。
//

import Foundation

/// Decoder 解码结果（Core 中间层，不进入公共 Codable Models）。
public struct PlistDecodeResult {
    /// 解码状态。
    public let status: PlistDecodeStatus
    /// 解码成功对象；失败恒为 `nil`。
    public let object: PlistDecodedObject?
    /// 解码失败诊断描述；成功为 `nil`。
    public let errorDescription: String?

    public init(status: PlistDecodeStatus,
                object: PlistDecodedObject? = nil,
                errorDescription: String? = nil) {
        self.status = status
        self.object = object
        self.errorDescription = errorDescription
    }
}
